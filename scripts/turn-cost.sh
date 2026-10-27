#!/usr/bin/env bash
# Turn cost: what a plugin's WORKFLOW costs, as opposed to what its bytes weigh.
#
#   turn-cost.sh [--project PATH] [--min-blocks N] [--since DAYS] [--json]
#   turn-cost.sh --skills [--project PATH] [--since DAYS]
#   turn-cost.sh --workflow [--project PATH] [--since DAYS] [--json] [--suite-regex RE]
#
# --workflow counts what each turn block set off, its subagents' transcripts included, in
# ONE project's transcript dir (default: this checkout's main repo): questions, subagents,
# Stop-check blocks, suite runs, browser calls. It counts events; it never judges them.
#
# --since filters RECORDS by their own timestamp, not files by modification time,
# so a months-old session appended to yesterday contributes only its recent turns.
#
# MAINTAINER PATH, NOT A GATE. Always exits 0. It reports; it never fails a build
# and it never proposes a change by itself.
#
# THE UNIT. A "turn block" is one real user prompt and every model request that
# followed it before the next real user prompt. Tool results are user-role records
# too and are NOT boundaries — only a genuine human turn is. That is the closest
# thing to "cost per completed task" that a transcript can actually witness:
# completion itself is not recorded anywhere, so this measures cost per
# INSTRUCTION, and says so rather than claiming the stronger thing.
#
# Misses: VALUE (it measures cost), subagent turns, other machines, deleted transcripts. Per-plugin figures are UPPER BOUNDS (attribution is incomplete
# and carries forward), cost comes from a static price table, a ratio needs --min-blocks blocks (default 10), and every project is in scope unless --project narrows it.
# Why, limits, history: rationale/derivations/scripts.md § scripts/turn-cost.sh
set -u

min_blocks=10
since_days=0
as_json=0
skills_mode=0
workflow=0
suite_regex=""
project=""
while [ $# -gt 0 ]; do
  case "$1" in
    # A value-taking flag given last made `shift 2` (with $#=1) a no-op and the loop spin forever: report it and exit 0.
    --project|--min-blocks|--since|--suite-regex)
      [ $# -ge 2 ] || { printf 'turn-cost: %s needs a value\n' "$1" >&2; exit 0; }
      case "$1" in
        --project)    project="$2" ;;
        --suite-regex) suite_regex="$2" ;;
        --min-blocks) case "$2" in ''|*[!0-9]*) printf 'turn-cost: --min-blocks needs an integer, got %s\n' "$2" >&2; exit 0 ;; esac; min_blocks="$2" ;;
        --since)      case "$2" in ''|*[!0-9.]*|.|*.*.*) printf 'turn-cost: --since needs a number of days, got %s\n' "$2" >&2; exit 0 ;; esac; since_days="$2" ;;
      esac; shift 2 ;;
    --json)        as_json=1; shift ;;
    --skills)      skills_mode=1; shift ;;
    --workflow)    workflow=1; shift ;;
    # Only the header block is documentation; '^#' alone also dumped the price
    # table and schema-drift internals living further down the file.
    -h|--help)     awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"; exit 0 ;;
    *) printf 'turn-cost: unknown argument %s\n' "$1" >&2; exit 0 ;;
  esac
done

# Same guard shape context-budget.sh uses for jq: a missing interpreter is a skip,
# never a failure, because this is not allowed to fail anything.
command -v python3 >/dev/null 2>&1 || { echo "turn-cost: python3 not found, skipping"; exit 0; }
# Combined, --workflow's one-project file set would silently narrow --skills.
[ "$skills_mode" = 1 ] && [ "$workflow" = 1 ] && { echo "turn-cost: --skills and --workflow are separate modes; pick one" >&2; exit 0; }

root="$(cd "$(dirname "$0")/.." && pwd)"
if [ "$workflow" = 1 ] && [ -z "$project" ]; then
  common=$(git -C "$root" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) \
    && project=$(dirname "$common") || project="$root"
fi

TC_MIN_BLOCKS="$min_blocks" TC_SINCE="$since_days" TC_JSON="$as_json" \
TC_SKILLS="$skills_mode" TC_ROOT="$root" TC_WORKFLOW="$workflow" TC_SUITE_RE="$suite_regex" \
TC_PROJECT="$project" python3 - <<'PY'
import json, glob, os, re, sys, statistics, collections, time, datetime

MIN_BLOCKS = int(os.environ.get("TC_MIN_BLOCKS") or 10)
SINCE      = float(os.environ.get("TC_SINCE") or 0)
AS_JSON    = os.environ.get("TC_JSON") == "1"
SKILLS     = os.environ.get("TC_SKILLS") == "1"
WORKFLOW   = os.environ.get("TC_WORKFLOW") == "1"
ROOT       = os.environ.get("TC_ROOT") or "."
PROJECT    = os.environ.get("TC_PROJECT") or ""

ARG = r"""(?:"[^"]*"|'[^']*'|\S+)"""
COMMAND_AT = (r"(?:^|[;&|(])\s*(?:(?:timeout(?:\s+-\S+)*\s+" + ARG + r"|time|flock(?:\s+-\S+)*\s+" + ARG
              + r"|env|[A-Za-z_]\w*=" + ARG + r"?|npx|bunx|pnpm(?:\s+exec)?|yarn|exec)\s+)*")
SUITE_DEFAULT = COMMAND_AT + r"(?:" + "|".join((
    r"(?:\S*/)?(?:pest|phpunit|vitest|jest|pytest)\b",
    r"python3?\s+-m\s+pytest\b",
    r"(?:npm|pnpm|yarn|bun|composer)\s+(?:run\s+)?test\b",
    r"php\s+artisan\s+test\b",
    r"bash\s+(?:-\S+\s+)*\S*scripts/(?:validate|context-budget|check-version-bumps|official-validate|mod-tests)\.sh\b",
    r"(?:bash\s+)?\S*scripts/generate\.sh\s+--check\b",
    r"for\s+\w+\s+in\s+[^;\n]*(?:scripts/smoke/\*\.sh|plugins/\*/scripts/__tests__/\*)",
)) + r")"
HEREDOC_OPEN = re.compile(r"(?<!<)<<(?!<)-?\s*(['\"]?)([A-Za-z_]\w*)\1")

def without_heredoc_bodies(cmd):
    out, pending = [], []
    for line in cmd.split("\n"):
        if pending:
            if line.strip() == pending[0]:
                pending.pop(0)
            continue
        out.append(line)
        pending = [m.group(2) for m in HEREDOC_OPEN.finditer(line)]
    return "\n".join(out)

try:
    SUITE_RE = re.compile(os.environ.get("TC_SUITE_RE") or SUITE_DEFAULT, re.M)
except re.error as e:
    print(f"turn-cost: --suite-regex does not compile: {e}", file=sys.stderr)
    sys.exit(0)
WF_KEYS = ("questions_calls", "questions_asked", "subagents", "stop_blocks", "suite_runs", "browser_calls")
CMD_TAG = re.compile(r"<command-name>\s*(/[^<\s]+)\s*</command-name>")

# $/MTok (input, output, cache read). Source: the model catalog baked into CLI
# 2.1.300 (`pricing_tiers`), read 2026-10-15; it agrees with the changelog: Haiku 5.5
# at $0.10/$0.50 (2.1.293), Sonnet 5.5 cache reads at $0.10 (2.1.296). Longest prefix
# wins, so claude-opus-5-5 is never priced as claude-opus-5. A model absent from this
# table is priced at the Opus 5 rate and NAMED in the output, so an unknown model
# shows up as a caveat rather than as silence.
PRICE = {
    "claude-fable-5-1": (10.0, 50.0, 0.25), "claude-mythos-5-1": (10.0, 50.0, 0.25),
    "claude-fable-5": (10.0, 50.0, 1.0), "claude-mythos-5": (10.0, 50.0, 1.0),
    "claude-opus-5-5": (4.0, 20.0, 0.2),
    "claude-opus-5": (5.0, 25.0, 0.5), "claude-opus-4-8": (5.0, 25.0, 0.5),
    "claude-opus-4-7": (5.0, 25.0, 0.5), "claude-opus-4-6": (5.0, 25.0, 0.5),
    "claude-sonnet-5-5": (2.0, 10.0, 0.1),
    "claude-sonnet-5": (2.0, 10.0, 0.2), "claude-sonnet-4-6": (3.0, 15.0, 0.3),
    "claude-haiku-5-5": (0.1, 0.5, 0.01), "claude-haiku-4-5": (1.0, 5.0, 0.1),
    "claude-opus-4-5": (5.0, 25.0, 0.5),
    "claude-opus-4-1": (15.0, 75.0, 1.5), "claude-opus-4-0": (15.0, 75.0, 1.5),
    "claude-sonnet-4-5": (3.0, 15.0, 0.3), "claude-sonnet-4-0": (3.0, 15.0, 0.3),
    "claude-3-7-sonnet": (3.0, 15.0, 0.3), "claude-3-5-sonnet": (3.0, 15.0, 0.3),
    "claude-3-5-haiku": (0.8, 4.0, 0.08),
    # The 4.0 pair's first-party ids, the ones transcripts record, drop the "-0".
    "claude-opus-4-20250514": (15.0, 75.0, 1.5), "claude-sonnet-4-20250514": (3.0, 15.0, 0.3),
}
# A Haiku 5.5 request whose prompt (input + cache read + cache write) tops 100K tokens
# is billed whole at the long-prompt rate — the CLI's own rule.
LONG_PROMPT = {"claude-haiku-5-5": (100_000, (0.5, 2.5, 0.05))}
DEFAULT_PRICE = (5.0, 25.0, 0.5)
PRICE_KEYS = sorted(PRICE, key=len, reverse=True)
unknown_models = collections.Counter()

def price_for(model, prompt_tokens=0):
    if model:
        for k in PRICE_KEYS:
            if model.startswith(k):
                above, long_price = LONG_PROMPT.get(k, (None, None))
                return long_price if above is not None and prompt_tokens > above else PRICE[k]
    unknown_models[model or "(none)"] += 1
    return DEFAULT_PRICE

def request_cost(u, model):
    """Dollars for one request. Reads the cache_creation TTL split per request."""
    pin, pout, pread = price_for(model, ctx_of(u))
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
        + (u.get("cache_read_input_tokens", 0) or 0) * pread
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
    if (o.get("type") != "user" or o.get("toolUseResult") or o.get("isMeta")
            or o.get("isCompactSummary")):
        return False
    c = (o.get("message") or {}).get("content")
    if isinstance(c, list):
        human = not any(isinstance(b, dict) and b.get("type") == "tool_result" for b in c)
    else:
        human = bool(c)
    return human and not is_harness_frame(o)

FRAME_PREFIXES = ("<task-notification", "Another Claude session sent a message:")

def is_harness_frame(o):
    """A user-role record the harness writes (a background task finishing, a peer's
    message), so its requests belong to the instruction already running."""
    c = (o.get("message") or {}).get("content")
    if o.get("type") != "user" or o.get("toolUseResult") or (
            isinstance(c, list) and any(isinstance(b, dict) and b.get("type") == "tool_result" for b in c)):
        return False
    origin = o.get("origin")
    if isinstance(origin, dict) and origin.get("kind"):
        return origin["kind"] != "human"
    return text_of(c).lstrip().startswith(FRAME_PREFIXES)

def text_of(c):
    if isinstance(c, list):
        return next(((b.get("text") or "") for b in c
                     if isinstance(b, dict) and b.get("type") == "text"), "")
    return c if isinstance(c, str) else ""

def wf_zero():
    return dict.fromkeys(WF_KEYS, 0)

seen_tool_ids = set()
tool_uses_seen = 0

def wf_events(o, acc):
    """Adds one record's workflow events to acc; returns the tool_use ids it carries."""
    global tool_uses_seen
    c = (o.get("message") or {}).get("content")
    if o.get("type") == "user" and o.get("isMeta") and text_of(c).startswith("Stop hook feedback:"):
        acc["stop_blocks"] += 1
    ids = []
    for b in (c if isinstance(c, list) else []):
        if not isinstance(b, dict) or b.get("type") != "tool_use":
            continue
        tid = b.get("id")
        if tid:
            ids.append(tid)
            if tid in seen_tool_ids:
                continue
            seen_tool_ids.add(tid)
        tool_uses_seen += 1
        name, inp = b.get("name") or "", b.get("input") or {}
        if name == "AskUserQuestion":
            acc["questions_calls"] += 1
            qs = inp.get("questions")
            acc["questions_asked"] += len(qs) if isinstance(qs, list) else 0
        elif name in ("Agent", "Task"):
            acc["subagents"] += 1
        elif name == "Bash" and SUITE_RE.search(without_heredoc_bodies(str(inp.get("command") or ""))):
            acc["suite_runs"] += 1
        if any(k in name.lower() for k in ("playwright", "chrome", "browser_")):
            acc["browser_calls"] += 1
    return ids

def slash_command(o):
    t = text_of((o.get("message") or {}).get("content")).lstrip()
    if t.startswith("<command-"):
        m = CMD_TAG.search(t)
        return m.group(1) if m else None
    tok = t.split()[0] if t.split() else ""
    return tok if tok.startswith("/") and len(tok) > 1 and "/" not in tok[1:] else None

base = os.path.expanduser("~/.claude/projects/")
files = sorted(glob.glob(base + "*/*.jsonl"))
if WORKFLOW:
    # Claude Code names a project's transcript dir after its path, every non-alphanumeric as '-'.
    tdir = os.path.join(base, re.sub(r"[^A-Za-z0-9]", "-", PROJECT.rstrip("/")))
    files = sorted(glob.glob(os.path.join(glob.escape(tdir), "*.jsonl")))
wf_blocks, wf_files, tool_block = [], [], {}
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
skill_att = collections.Counter()
sidechain = 0
sessions = 0
scanned = 0
total_reqs = 0
total_usd = 0.0
attributed_reqs = 0
contexts = []
projects = collections.Counter()
seen_msg_ids = set()
harness_frames = compact_summaries = 0

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
    # Path-boundary match, not string prefix: '/a/proj' must not admit '/a/proj2'.
    if PROJECT:
        proot = PROJECT.rstrip("/")
        if not cwd or not (cwd == proot or cwd.startswith(proot + "/")):
            continue
    scanned += 1
    if not any((o.get("message") or {}).get("usage") for o in recs):
        continue
    sessions += 1
    if cwd:
        projects[cwd] += 1
    sid = os.path.splitext(os.path.basename(f))[0]
    if WORKFLOW:
        wf_files.append(f)

    cur_reqs, cur_usd, cur_plugins = 0, 0.0, set()
    cur_wf, cur_ids, cur_open = wf_zero(), [], (sid, None, None)
    att, ver = None, None

    def close_block():
        if cur_reqs:
            blocks.append((cur_reqs, cur_usd, frozenset(cur_plugins)))
            for p in cur_plugins:
                per_plugin[p]["blocks"] += 1
        if WORKFLOW:
            for i in cur_ids:
                tool_block.setdefault(i, len(wf_blocks) if cur_reqs else None)
            if cur_reqs:
                s, ts, cmd = cur_open
                wf_blocks.append(dict(cur_wf, session=s, started=ts, command=cmd, requests=cur_reqs))

    for o in recs:
        if too_old(o):
            if WORKFLOW:
                for i in wf_events(o, wf_zero()):
                    tool_block.setdefault(i, None)
            continue
        ver = o.get("version") or ver
        harness_frames += is_harness_frame(o)
        compact_summaries += bool(o.get("isCompactSummary"))
        if is_human_turn(o):
            close_block()
            cur_reqs, cur_usd, cur_plugins = 0, 0.0, set()
            if WORKFLOW:
                cur_wf, cur_ids, cur_open = wf_zero(), [], (sid, o.get("timestamp"), slash_command(o))
        if WORKFLOW:
            cur_ids += wf_events(o, cur_wf)
        if o.get("attributionPlugin"):
            att = o["attributionPlugin"]
            ver_att[ver] += 1
        if o.get("attributionSkill"):
            skill_att[o["attributionSkill"]] += 1
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
        # One API response is written as one record per content block, each with the
        # same message.id and usage; the first one stands for the request.
        mid = msg.get("id")
        if mid:
            if mid in seen_msg_ids:
                continue
            seen_msg_ids.add(mid)
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

# Subagent transcripts live beside their session as <sid>/subagents/agent-*.jsonl; each
# .meta.json names the Agent tool_use that spawned it, which places it in a turn block.
sub_pending, sub_joined, inside = [], 0, wf_zero()
for f in wf_files:
    sdir = os.path.join(os.path.dirname(f), os.path.splitext(os.path.basename(f))[0], "subagents")
    for sf in sorted(glob.glob(os.path.join(glob.escape(sdir), "*.jsonl"))):
        try:
            parent = json.load(open(sf[:-len(".jsonl")] + ".meta.json")).get("toolUseId")
        except Exception:
            parent = None
        acc, ids = wf_zero(), []
        for line in open(sf, encoding="utf-8", errors="replace"):
            try:
                o = json.loads(line)
            except Exception:
                continue
            ids += wf_events(o, wf_zero() if too_old(o) else acc)
        sub_pending.append((parent, acc, ids))
progress = True
while sub_pending and progress:
    progress = False
    for item in list(sub_pending):
        parent, acc, ids = item
        if parent not in tool_block:
            continue
        sub_pending.remove(item)
        progress = True
        idx = tool_block[parent]
        for i in ids:
            tool_block[i] = idx
        if idx is None:
            continue
        sub_joined += 1
        for k in WF_KEYS:
            wf_blocks[idx][k] += acc[k]
            inside[k] += acc[k]

# ---- SKILLS MODE: the retirement queue, folded in from scripts/retirement-queue.sh
# (deleted 2026-08-31). That script read two ledgers — skill-router's surfaced.jsonl
# (what the router OFFERED, SessionEnd) and hindsight's skills.jsonl (what was
# INVOKED) — scoped to the current project, where neither had records; the records
# existed under the projects where plugins are USED (measured 2026-09-01: 45 router,
# 195 hindsight, earliest 2026-08-22). Transcript attributionSkill records are
# the data that actually exists, so this mode joins shipped skills against all
# THREE sources and names which ones had data. Ledger semantics preserved from the
# original: `fired` and `pending_low_flushed` count as surfaced; a bare
# `pending_low` does not (it accumulated and may never have been shown); old lines
# without the split field fall back to pending_low.
if SKILLS:
    import glob as _g
    shipped = []
    for f in sorted(_g.glob(os.path.join(ROOT, "plugins/*/skills/*/SKILL.md"))):
        # parts[-4] is the plugin dir of `plugins/<p>/skills/<s>/SKILL.md`, counted from
        # the END. `parts.index("plugins")` counted from the front and hit the FIRST
        # "plugins" segment, which on the installer's own path
        # (~/.claude/plugins/marketplaces/cc-plugins-marketplace/plugins/<p>/…) is the
        # host's cache dir — every row then read plugin "marketplaces". Found 2026-09-22
        # while verifying the invocation README.md now documents.
        parts = f.split(os.sep)
        shipped.append((parts[-2], parts[-4]))
    surfaced, invoked = collections.Counter(), collections.Counter()
    led_srf = led_inv = 0
    for f in _g.glob(os.path.expanduser("~/.claude/skill-router/*/surfaced.jsonl")):
        for line in open(f, encoding="utf-8", errors="replace"):
            try: o = json.loads(line)
            except Exception: continue
            led_srf += 1
            for k in (o.get("fired") or []): surfaced[k] += 1
            flushed = o.get("pending_low_flushed") if "pending_low_flushed" in o else o.get("pending_low")
            for k in (flushed or []): surfaced[k] += 1
    for f in _g.glob(os.path.expanduser("~/.claude/hindsight/*/skills.jsonl")):
        for line in open(f, encoding="utf-8", errors="replace"):
            try: o = json.loads(line)
            except Exception: continue
            led_inv += 1
            k = (o.get("skill") or "").split(":")[-1]
            if k: invoked[k] += 1
    tr = collections.Counter()
    for k, v in skill_att.items():
        tr[k.split(":")[-1]] += v
    print("skill usage — retirement queue (folded from retirement-queue.sh)")
    print(f"sources: router ledger {led_srf} record(s), hindsight ledger {led_inv} record(s), "
          f"transcripts {sum(skill_att.values())} attribution record(s) "
          f"({(100.0*attributed_reqs/total_reqs if total_reqs else 0):.0f}% of requests carry attribution)\n")
    rows = sorted(((surfaced[n], invoked[n], tr[n], n, p) for n, p in shipped))
    print(f"{'skill':34} {'plugin':22} {'surfaced':>8} {'invoked':>8} {'transcript':>10}")
    never = 0
    for sc, ic, tc, n, p in rows:
        if sc == 0 and ic == 0 and tc == 0: never += 1
        print(f"{n:34} {p:22} {sc:8} {ic:8} {tc:10}")
    print(f"\n{never} of {len(shipped)} shipped skills show no recorded use in ANY source.")
    print("""
WHAT TO DO WITH THAT, in order:
  1. Ask whether the skill's stack is even present in the sampled projects. A
     Laravel skill reading zero in a Go repo is the system working, not a candidate.
  2. For a survivor that SHOULD have fired and did not, the defect is usually
     ROUTING, not the skill — check plugins/skill-router/rules.tsv; most skills
     have no routing row, so "never surfaced" mostly measures the router's coverage.
  3. Only then does a skill enter the control/treatment queue; the doctrine and
     the shapes that already measured zero are in rationale/stack-skill-baselines.md
     and rationale/measured-zero-shapes.md.

This is a queue, not a verdict. Zero here proves nobody used it in THIS sample;
non-zero proves it fired, never that it helped. Half the transcript sample carries
no attribution at all (see the coverage table in the default report), so every
count is a floor. The skill inventory is read from the LIVE tree: a concurrently
running smoke harness can inject a scratch fixture into it for the duration of a
test — the same concurrency caveat CLAUDE.md records for context-budget.sh.""")
    sys.exit(0)

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

def pctl(vals, q):
    """Nearest-rank percentile. The naive vals[int(n*q)] returns MAX for every
    n <= 1/(1-q) — at n=10 the 'p90' was just the maximum, silently."""
    v = sorted(vals)
    import math
    return v[max(0, math.ceil(q * len(v)) - 1)]

if WORKFLOW:
    wf_drift = []
    if not files:
        wf_drift.append(f"no transcripts found under {tdir}")
    elif total_reqs == 0:
        wf_drift.append("ZERO usage records — the transcript schema has probably changed")
    elif not blocks:
        wf_drift.append("ZERO turn blocks — the human-turn record shape has probably changed")
    elif not tool_uses_seen:
        wf_drift.append("ZERO tool_use blocks — the assistant content shape has probably changed")

    def summary(k):
        v = [b[k] for b in wf_blocks]
        return {"total": sum(v), "median": statistics.median(v) if v else 0,
                "p90": pctl(v, 0.9) if v else 0, "max": max(v, default=0)}
    regex_src = SUITE_RE.pattern + ("" if os.environ.get("TC_SUITE_RE") else "  (default)")
    if AS_JSON:
        print(json.dumps({
            "mode": "workflow", "project": PROJECT, "transcript_dir": tdir,
            "files": len(files), "sessions": sessions, "turn_blocks": len(wf_blocks),
            "harness_frames": harness_frames, "compact_summaries": compact_summaries,
            "subagent_transcripts": {"joined": sub_joined, "unlinked": len(sub_pending)},
            "suite_regex": SUITE_RE.pattern,
            "totals": {k: summary(k) for k in WF_KEYS},
            "inside_subagents": inside, "blocks": wf_blocks, "drift": wf_drift,
        }, indent=2))
        sys.exit(0)

    print("turn-cost --workflow — what each human instruction set off")
    print("MAINTAINER PATH: reports only, exits 0, counts events and never judges them.\n")
    if wf_drift:
        print("!! POSSIBLE SCHEMA DRIFT — do not trust the numbers below:")
        for d in wf_drift:
            print("   " + d)
        print()
    print(f"scanned   {scanned} of {len(files)} transcript file(s) in {tdir}, "
          f"{sessions} with model requests" + (f", --since {SINCE:g}d" if SINCE else ""))
    print(f"joined    {sub_joined} subagent transcript(s) to the block that spawned them; "
          f"{len(sub_pending)} unlinked, not counted")
    print(f"suites    {regex_src}")
    cols = WF_KEYS
    heads = ("asks", "qs", "agents", "stops", "suites", "browser")
    busy = [(i, b) for i, b in enumerate(wf_blocks) if any(b[k] for k in cols)]
    print(f"\nPER TURN BLOCK ({len(busy)} of {len(wf_blocks)} blocks had at least one event)")
    print(f"  {'#':>4} {'session':8} {'started':16} {'opened by':24} {'reqs':>5} "
          + " ".join(f"{h:>7}" for h in heads))
    for i, b in busy:
        print(f"  {i:4} {b['session'][:8]:8} {(b['started'] or '')[:16]:16} {(b['command'] or '')[:24]:24} "
              f"{b['requests']:5} " + " ".join(f"{b[k]:7}" for k in cols))
    print(f"\nTOTALS over {len(wf_blocks)} turn blocks "
          f"({harness_frames} harness frames and {compact_summaries} compaction summaries "
          "folded into the block already open)")
    print(f"  {'measure':22} {'total':>7} {'median':>7} {'p90':>5} {'max':>5}")
    labels = ("questions (calls)", "questions (asked)", "subagents spawned",
              "Stop-check blocks", "full-suite runs", "browser calls")
    for k, label in zip(cols, labels):
        s = summary(k)
        print(f"  {label:22} {s['total']:7} {s['median']:7g} {s['p90']:5} {s['max']:5}")
    print("  of which inside subagents: " + ", ".join(f"{h} {inside[k]}" for k, h in zip(cols, heads)))
    print("\nnotes")
    print("  - a turn block is the default report's: one human prompt and every request after")
    print("    it. A harness frame (a task notification, a peer's message) or a compaction")
    print("    summary opens no block.")
    print("  - suite runs are Bash commands matching the regex: a filtered or failed run counts")
    print("    as one, and a chain of gates in one command counts once.")
    print("  - sessions launched in a worktree have their own transcript dir; pass its path.")
    sys.exit(0)

if AS_JSON:
    out = {
        "sessions": sessions, "requests": total_reqs, "usd": round(total_usd, 4),
        "turn_blocks": len(blocks),
        "requests_per_block": {
            "median": statistics.median([b[0] for b in blocks]) if blocks else 0,
            "p90": pctl([b[0] for b in blocks], 0.9) if blocks else 0,
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
    print(f"  requests/block   median {statistics.median(r)}   mean {sum(r)/len(r):.1f}   "
          f"p90 {pctl(r, 0.9)}   max {r[-1]}")
    print(f"  $/block          median ${statistics.median(d):.2f}   mean ${sum(d)/len(d):.2f}   "
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
