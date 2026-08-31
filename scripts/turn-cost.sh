#!/usr/bin/env bash
# Turn cost: what a plugin's WORKFLOW costs, as opposed to what its bytes weigh.
#
#   turn-cost.sh [--project PATH] [--min-blocks N] [--since DAYS] [--json]
#
# --since filters RECORDS by their own timestamp, not files by modification time,
# so a months-old session appended to yesterday contributes only its recent turns.
#
# MAINTAINER PATH, NOT A GATE. Always exits 0. It reports; it never fails a build
# and it never proposes a change by itself.
#
# WHY THIS EXISTS. Every cost instrument in this repo meters BYTES:
# context-budget.sh's three channels, pc_skill_budget, pc_budget_crowding, the
# description linter, the listing channel. rationale/2026-08-31-token-cost-review.md
# measured what those bytes are worth against real spend and found the whole
# always-on surface is ~1% of a session, while 61.8% of the bill is cache reads —
# context re-read every request. The term that actually moves that is how many
# model requests a piece of work takes, and NOTHING here measures it. Same run:
# task-runner-attributed context cost 19% of all measured spend across 464
# requests, against a shipped byte surface worth ~$2.80 a session. A ~40:1 gap
# between what a plugin ships and what its workflow costs, in the channel with no
# instrument.
#
# THE UNIT. A "turn block" is one real user prompt and every model request that
# followed it before the next real user prompt. Tool results are user-role records
# too and are NOT boundaries — only a genuine human turn is. That is the closest
# thing to "cost per completed task" that a transcript can actually witness:
# completion itself is not recorded anywhere, so this measures cost per
# INSTRUCTION, and says so rather than claiming the stronger thing.
#
# WHAT THE NUMBERS DO AND DO NOT MEAN — read before quoting any of them:
#   - This measures COST, NEVER VALUE. A plugin that turns one instruction into
#     200 requests may be buying 200 requests of work you would otherwise have
#     driven by hand. Nothing here can tell those apart, and this repo's one real
#     ablation (rationale/eval-ablation-2026-08-20.md) measured zero delta in
#     every arm. This is a denominator. It is not a verdict, and a high number is
#     not a finding.
#   - Attribution is INCOMPLETE and the script measures its own coverage on every
#     run — see the coverage table it prints. On the machine this was written for,
#     one Claude Code version accounted for 48.6% of all requests and emitted no
#     attribution records at all. Unattributed cost is reported as its own row,
#     never silently spread over the plugins.
#   - Attribution also carries FORWARD, and turn blocks are delimited by user
#     prompts, so a plugin keeps being charged across a block boundary into an
#     instruction about something else. Per-plugin figures are UPPER BOUNDS, and
#     the two errors compound.
#   - SUBAGENT TURNS ARE INVISIBLE. No `isSidechain` record appeared in any
#     transcript measured; subagent requests are billed and do not show up here.
#     This systematically UNDER-counts exactly the orchestration-heavy plugins the
#     instrument was built to look at. That is the biggest known hole in it.
#   - Cost is ESTIMATED from a static price table (below), not read from a bill.
#     Cache multipliers: read 0.1x, 1h write 2x, 5m write 1.25x. The TTL split is
#     read per request from usage.cache_creation, because assuming the 1.25x
#     default under-states a 1h-TTL session's write channel by 60%.
#
# HONEST LIMITATION, stated the way this repo's convention asks. It cannot see:
# subagents (above); anything on another machine; sessions whose transcripts have
# been deleted; and whether a turn was useful. It reports a per-plugin ratio only
# once that plugin has --min-blocks turn blocks (default 10), because a $/block
# figure at n=3 is noise wearing a table — the same failure retirement-queue.sh's
# header warns about. Below the threshold it prints the raw count and withholds
# the ratio.
#
# WHY IT DEFAULTS TO ALL PROJECTS, unlike retirement-queue.sh: a plugin's turn
# cost appears where the plugin is USED, which is essentially never this repo.
# Scoped to the marketplace checkout it would measure authoring sessions and
# report nothing about any plugin. Use --project to narrow.
set -u

min_blocks=10
since_days=0
as_json=0
project=""
while [ $# -gt 0 ]; do
  case "$1" in
    --project)     project="${2:-}"; shift 2 ;;
    --min-blocks)  min_blocks="${2:-10}"; shift 2 ;;
    --since)       since_days="${2:-0}"; shift 2 ;;
    --json)        as_json=1; shift ;;
    -h|--help)     grep -E '^#' "$0" | sed 's/^#!.*//; s/^# \{0,1\}//'; exit 0 ;;
    *) printf 'turn-cost: unknown argument %s\n' "$1" >&2; exit 0 ;;
  esac
done

# Same guard shape context-budget.sh uses for jq: a missing interpreter is a skip,
# never a failure, because this is not allowed to fail anything.
command -v python3 >/dev/null 2>&1 || { echo "turn-cost: python3 not found, skipping"; exit 0; }

TC_MIN_BLOCKS="$min_blocks" TC_SINCE="$since_days" TC_JSON="$as_json" \
TC_PROJECT="$project" python3 - <<'PY'
import json, glob, os, sys, statistics, collections, time, datetime

MIN_BLOCKS = int(os.environ.get("TC_MIN_BLOCKS") or 10)
SINCE      = float(os.environ.get("TC_SINCE") or 0)
AS_JSON    = os.environ.get("TC_JSON") == "1"
PROJECT    = os.environ.get("TC_PROJECT") or ""

# $/MTok (input, output). Source: the claude-api skill's model table, cached
# 2026-06-24. A model absent from this table is priced at the Opus rate and NAMED
# in the output, so an unknown model shows up as a caveat rather than as silence.
PRICE = {
    "claude-fable-5": (10.0, 50.0), "claude-mythos-5": (10.0, 50.0),
    "claude-opus-5": (5.0, 25.0), "claude-opus-4-8": (5.0, 25.0),
    "claude-opus-4-7": (5.0, 25.0), "claude-opus-4-6": (5.0, 25.0),
    "claude-sonnet-5": (2.0, 10.0), "claude-sonnet-4-6": (3.0, 15.0),
    "claude-haiku-4-5": (1.0, 5.0),
}
DEFAULT_PRICE = (5.0, 25.0)
unknown_models = collections.Counter()

def price_for(model):
    if model:
        for k, v in PRICE.items():
            if model.startswith(k):
                return v
    unknown_models[model or "(none)"] += 1
    return DEFAULT_PRICE

def request_cost(u, model):
    """Dollars for one request. Reads the cache_creation TTL split per request."""
    pin, pout = price_for(model)
    cc = u.get("cache_creation") or {}
    w1 = cc.get("ephemeral_1h_input_tokens", 0) or 0
    w5 = cc.get("ephemeral_5m_input_tokens", 0) or 0
    if not (w1 or w5):
        # Older records carry only the flat total. Price it at the cheaper 5m
        # write rather than guess upward — an under-estimate that is visible in
        # the notes beats an over-estimate that is not.
        w5 = u.get("cache_creation_input_tokens", 0) or 0
    return (
        (u.get("input_tokens", 0) or 0) * pin
        + w1 * pin * 2.0
        + w5 * pin * 1.25
        + (u.get("cache_read_input_tokens", 0) or 0) * pin * 0.1
        + (u.get("output_tokens", 0) or 0) * pout
    ) / 1e6

def ctx_of(u):
    return ((u.get("input_tokens", 0) or 0)
            + (u.get("cache_creation_input_tokens", 0) or 0)
            + (u.get("cache_read_input_tokens", 0) or 0))

def is_human_turn(o):
    """A real user instruction, not a tool result and not harness chatter.
    Tool results are user-role records too; treating them as boundaries would
    turn every block into a single request and the whole metric into 1.0."""
    if o.get("type") != "user" or o.get("toolUseResult") or o.get("isMeta"):
        return False
    c = (o.get("message") or {}).get("content")
    if isinstance(c, list):
        return not any(isinstance(b, dict) and b.get("type") == "tool_result" for b in c)
    return bool(c)

base = os.path.expanduser("~/.claude/projects/")
files = sorted(glob.glob(base + "*/*.jsonl"))
cutoff = time.time() - SINCE * 86400 if SINCE else 0
undated = 0

def too_old(o):
    """--since filters RECORDS by their own `timestamp`, not files by mtime.
    A long-running session appended to yesterday would otherwise drag five weeks
    of its own history into a --since 7 window, in full. Every user and
    usage-bearing record carries an ISO-8601 timestamp; a record without one is
    KEPT and counted in `undated`, because dropping unstamped records would
    silently shrink the sample."""
    if not cutoff:
        return False
    ts = o.get("timestamp")
    if not ts:
        global undated
        undated += 1
        return False
    try:
        return datetime.datetime.fromisoformat(
            ts.replace("Z", "+00:00")).timestamp() < cutoff
    except Exception:
        return False

blocks = []                                   # (requests, dollars, plugins_seen)
per_plugin = collections.defaultdict(lambda: {"blocks": 0, "reqs": 0, "usd": 0.0})
ver_reqs, ver_att = collections.Counter(), collections.Counter()
sidechain = 0
sessions = 0
scanned = 0
total_reqs = 0
total_usd = 0.0
attributed_reqs = 0
contexts = []
projects = collections.Counter()

for f in files:
    # Pure optimisation, safe because a file's mtime is >= its newest record:
    # a file untouched since the cutoff cannot hold a record after it. The real
    # --since filter is per-record, in too_old().
    if cutoff and os.path.getmtime(f) < cutoff:
        continue
    recs = []
    for line in open(f, encoding="utf-8", errors="replace"):
        try:
            recs.append(json.loads(line))
        except Exception:
            continue
    # The project a transcript belongs to is read from the records' own `cwd`,
    # never reconstructed from the directory name: `-Users-me-Work-a-b` is
    # ambiguous about where the dashes were path separators.
    cwd = next((o["cwd"] for o in recs if o.get("cwd")), None)
    if PROJECT and (not cwd or not cwd.startswith(PROJECT)):
        continue
    scanned += 1
    if not any((o.get("message") or {}).get("usage") for o in recs):
        continue
    sessions += 1
    if cwd:
        projects[cwd] += 1

    cur_reqs, cur_usd, cur_plugins = 0, 0.0, set()
    att, ver = None, None

    def close_block():
        if cur_reqs:
            blocks.append((cur_reqs, cur_usd, frozenset(cur_plugins)))
            for p in cur_plugins:
                per_plugin[p]["blocks"] += 1

    for o in recs:
        if too_old(o):
            continue
        ver = o.get("version") or ver
        if is_human_turn(o):
            close_block()
            cur_reqs, cur_usd, cur_plugins = 0, 0.0, set()
        if o.get("attributionPlugin"):
            att = o["attributionPlugin"]
            ver_att[ver] += 1
        if o.get("isSidechain"):
            sidechain += 1
        msg = o.get("message") or {}
        u = msg.get("usage")
        if not u:
            continue
        model = msg.get("model")
        # `<synthetic>` marks a message Claude Code generated locally (an error
        # notice, a cancellation). It carries a usage block but was never an API
        # call, so counting it would inflate both the request count and the bill.
        if model == "<synthetic>":
            continue
        d = request_cost(u, model)
        total_reqs += 1
        total_usd += d
        ver_reqs[ver] += 1
        contexts.append(ctx_of(u))
        cur_reqs += 1
        cur_usd += d
        key = att
        if key:
            attributed_reqs += 1
        # `None` is added as a member too, so the (unattributed) row's blocks and
        # reqs columns are computed on the same basis as every plugin's.
        cur_plugins.add(key)
        per_plugin[key]["reqs"] += 1
        per_plugin[key]["usd"] += d
    close_block()

# ---- schema-drift check. This script always exits 0, so a schema change would
# otherwise surface as a confident table of zeros. Say it loudly instead; that is
# the one failure nothing else in this repo would catch.
drift = []
if not files:
    drift.append("no transcripts found under ~/.claude/projects/")
elif total_reqs == 0:
    drift.append("scanned %d transcript file(s) and found ZERO usage records — "
                 "the transcript schema has probably changed" % len(files))
elif not blocks:
    drift.append("found requests but ZERO turn blocks — the user-record shape "
                 "used to detect a human turn has probably changed")
elif attributed_reqs == 0:
    drift.append("found requests but ZERO attributionPlugin records — either "
                 "this Claude Code version does not emit them, or the field "
                 "was renamed")

def pct(a, b):
    return (100.0 * a / b) if b else 0.0

if AS_JSON:
    out = {
        "sessions": sessions, "requests": total_reqs, "usd": round(total_usd, 4),
        "turn_blocks": len(blocks),
        "requests_per_block": {
            "median": statistics.median([b[0] for b in blocks]) if blocks else 0,
            "mean": round(sum(b[0] for b in blocks) / len(blocks), 1) if blocks else 0,
            "max": max((b[0] for b in blocks), default=0),
        },
        "attribution_coverage_pct": round(pct(attributed_reqs, total_reqs), 1),
        "min_blocks": MIN_BLOCKS,
        "plugins": {
            (k or "(unattributed)"): {
                "blocks": v["blocks"], "requests": v["reqs"],
                "usd": round(v["usd"], 4),
                "scored": v["blocks"] >= MIN_BLOCKS,
            } for k, v in per_plugin.items()
        },
        "drift": drift,
        "subagent_records_seen": sidechain,
    }
    print(json.dumps(out, indent=2))
    sys.exit(0)

print("turn-cost — model requests per human instruction, and what they cost")
print("MAINTAINER PATH: reports only, exits 0, measures cost and never value.\n")

if drift:
    print("!! POSSIBLE SCHEMA DRIFT — do not trust the numbers below:")
    for d in drift:
        print("   " + d)
    print()

print(f"scanned   {scanned} of {len(files)} transcript file(s), "
      f"{sessions} with model requests"
      + (f" (--project {PROJECT})" if PROJECT else "")
      + (f", --since {int(SINCE)}d" if SINCE else ""))
print(f"requests  {total_reqs:,}   estimated spend ${total_usd:,.2f}"
      + (f"   (${total_usd/total_reqs:.3f}/request)" if total_reqs else ""))
if contexts:
    contexts.sort()
    print(f"context   median {contexts[len(contexts)//2]:,} tok, "
          f"p90 {contexts[int(len(contexts)*0.9)]:,}, max {contexts[-1]:,}")

if blocks:
    r = sorted(b[0] for b in blocks)
    d = sorted(b[1] for b in blocks)
    print(f"\nTURN BLOCKS (one human instruction -> the requests it took)  n={len(r)}")
    print(f"  requests/block   median {r[len(r)//2]}   mean {sum(r)/len(r):.1f}   "
          f"p90 {r[int(len(r)*0.9)]}   max {r[-1]}")
    print(f"  $/block          median ${d[len(d)//2]:.2f}   mean ${sum(d)/len(d):.2f}   "
          f"max ${d[-1]:.2f}")

print(f"\nATTRIBUTION COVERAGE  {attributed_reqs:,}/{total_reqs:,} requests "
      f"({pct(attributed_reqs, total_reqs):.1f}%) carry a plugin")
print(f"  {'claude code':14} {'requests':>9} {'attrib recs':>12}")
for v in sorted(set(list(ver_reqs) + list(ver_att)), key=lambda x: (x or "")):
    flag = "   <- emits none" if ver_reqs[v] and not ver_att[v] else ""
    print(f"  {str(v):14} {ver_reqs[v]:9,} {ver_att[v]:12,}{flag}")

rows = sorted(per_plugin.items(), key=lambda kv: -kv[1]["usd"])
print(f"\nPER PLUGIN (upper bounds — attribution carries forward across blocks)")
print(f"  {'plugin':24} {'blocks':>6} {'reqs':>6} {'$':>9} {'req/block':>10} {'$/block':>9}")
for k, v in rows:
    name = k or "(unattributed)"
    if v["blocks"] >= MIN_BLOCKS:
        rb = f"{v['reqs']/v['blocks']:10.1f}"
        db = f"{v['usd']/v['blocks']:9.2f}"
    else:
        rb, db = f"{'n too low':>10}", f"{'—':>9}"
    print(f"  {name:24} {v['blocks']:6} {v['reqs']:6} {v['usd']:9.2f} {rb} {db}")

under = [k or "(unattributed)" for k, v in rows if v["blocks"] < MIN_BLOCKS]
print("\nnotes")
if under:
    print(f"  - ratio withheld for {len(under)} entr{'y' if len(under)==1 else 'ies'} "
          f"under --min-blocks {MIN_BLOCKS}: {', '.join(sorted(under))}.")
    print("    A $/block figure at single-digit n is noise wearing a table. Collect")
    print("    more sessions, or lower the threshold deliberately and say you did.")
print("  - the (unattributed) row is a SEPARATE POPULATION, not a peer. It is mostly")
print("    whole sessions from a Claude Code version that emits no attribution at all")
print("    (see the coverage table); reading down the column compares different work.")
print("  - $/block also tracks WHERE in a session a block landed — context grows and")
print("    compaction only halves it periodically — so that column ranks session")
print("    position as much as it ranks workflow.")
print(f"  - subagent turns are INVISIBLE here ({sidechain} isSidechain records seen). "
      "They are billed.")
print("    Orchestration-heavy plugins are under-counted by an unknown amount.")
print("  - cost is ESTIMATED from a static price table, not read from a bill.")
if unknown_models:
    print(f"    models not in the table, priced at Opus rates: "
          f"{', '.join(sorted(unknown_models))}")
print("  - this measures COST, NOT VALUE. A plugin that spends turns may be earning")
print("    them. Nothing here can tell the difference; see the header.")
if SINCE and undated:
    print(f"  - {undated} record(s) carried no timestamp and were KEPT despite --since.")
if projects and not PROJECT:
    print(f"  - {len(projects)} project(s) in scope; --project PATH narrows it.")
PY
exit 0
