#!/usr/bin/env bash
# Maintainer command: run ONE plugin's eval suite against a no-plugin control arm under a
# hard cost cap, and write a summary that is safe to commit under rationale/evals/.
#
#   RUN_EVALS=1 bash scripts/run-evals.sh <plugin> [extra `claude plugin eval` args…]
#
# WHY THIS EXISTS. Nothing in the repo ran `claude plugin eval` for real: scripts/eval-cases.sh
# only LOADS suites. A hand run leaves its result under the gitignored plugins/<p>/evals/results/,
# in a document full of prompts and absolute paths, so no run left a committable record, and
# CLAUDE.md forbids stating a delta without its run count and vote spread. This fixes the
# flags (control arm, cap, local report, output kept out of the plugin) and writes those
# counts to a file that can be committed.
#
# WHAT IT DOES. Refuses (exit 3, before any `claude` call) unless RUN_EVALS=1. Refuses (exit
# 64, also before any call) a missing plugin, one with no plugins/<p>/evals/, a non-numeric
# cap, python3 without yaml, a suite with any case.yaml declaring `context.scaffold_script`
# or not readable as a YAML mapping, and any extra argument off an ALLOW-list: `--runs`,
# `--case`, `--model`, `--judge-model`, `--threshold` (one value each) and `--tag`,
# `--allow-tools` (one or more values), each as `--flag v…` or `--flag=v`; a bare token is
# accepted only as the value of the allowed flag before it. An allow-list because the CLI
# keeps the last value of a repeated flag: a new or aliased flag would otherwise override a
# fixed one (`--max-cost-usd`, `--json`…) or run code outside the sandbox (`--scaffold`,
# `--allow-real-servers`, `--mocks off`) while the summary recorded the fixed value. Runs
#   claude plugin eval ./plugins/<p> --ablation with-without --max-cost-usd <cap>
#     --no-publish --trust-plugin --output-dir <tmp> --report <tmp>/report.html
#     --json <tmp>/aggregate.json <extra…>
# with cap = RUN_EVALS_MAX_COST_USD (default 5). Then writes
# rationale/evals/<YYYY-MM-DD>-<HHMMSS>-<p>.json (UTC; dir overridable by RUN_EVALS_OUT_DIR)
# and exits with the CLI's exit code — 0 pass, 1 below threshold or load error, 2 partial
# (cost ceiling or auth), 130 interrupted. A serialized summary matching a home path or a
# UUID (session-id shape) is refused: exit 65, nothing written. No result document from the
# CLI means no summary. When the summariser fails after the CLI wrote a document, the temp
# dir is kept, its document path is printed, and the script exits with the summariser's code.
#
# FIELDS IT RELIES ON, as observed rather than documented: a `--max-cost-usd 0` load of
# candor on CLI 2.1.285 (2026-09-30) wrote `cases: []` with no per-case run count anywhere,
# `partial: true`, `partialReason: "cost_ceiling"`; completed documents from CLI 2.1.283
# carry `cases[].runsPerCase` and a numeric `cases[].arms.{with,without}[].score`, neither
# in the docs' field table. Read: `claudeVersion`, `costUsd`, `partial`, `partialReason`,
# `cases[].name`, `cases[].runsPerCase`, `cases[].arms.*[].score`, `cases[].aggregates.delta`.
# Case files (plugins/<p>/evals/**/case.yaml: `name`, else the directory; `runs`; `tags`) are
# read with PyYAML before the paid call. The summary's cases are the document's `cases[]`;
# only a partial document, or one listing no cases, gains the case files it omits, 0
# completed, and only those the `--case`/`--tag` filters select. The filters are applied as
# CLI 2.1.285 applies them, measured by zero-cost loads 2026-09-30: `--case` (last one wins)
# against the whole `name`, case-sensitive, `*` any run and `?` one character, every other
# character literal (NOT fnmatch: `[n]amed-one` selects nothing); `--tag` accumulates across
# repeats and selects a case carrying ANY of them; both together are ANDed. Planned runs per
# arm: `--runs`, else the document's `runsPerCase`, else the case file's `runs`, else 3.
# Nothing else is copied: no prompt, grader text, `error` string, path or trace id.
#
# WHAT IT DOES NOT:
#   - show a skill helped. A case whose `without` spread is n/n has no headroom: it is a
#     regression guard and can never measure the skill (CLAUDE.md's ceiling rule).
#   - separate a regression from a flake at fewer than three runs per arm. The summary
#     carries the counts and per-arm spread so a delta quoted from it can carry them too.
#   - meter spend. `costUsd` is the CLI's list-price estimate, not plan usage, and the cap
#     is checked before each run launches, so runs already in flight can pass it.
#   - keep the HTML report or the full document after a summary is written; both leave with
#     the temp dir, because they hold prompts, grader evidence and paths.
#   - track a later CLI's filter rules; the ones above are one version's. A case.yaml the
#     runner rejects on load is still planned in a partial record, and a prompt.md-shaped
#     case (no case.yaml) is counted only if the document lists it.
#   - run a suite that needs `--scaffold`. Without it a scaffolded case is paid for while
#     scoring the repo root, so the suite is refused, whatever the filters select; the
#     plugin README carries the manual command. A prompt.md case's frontmatter is not read.
#   - catch a leak the regex does not match; the field whitelist is the real defence.
#
# Standing: `recorded` — nothing runs it in CI. scripts/smoke/run-evals-tests.sh proves the
# plumbing (refusal, flags, summary shape, a zero-cost real load), never a score.
set -u
cd "$(dirname "$0")/.." || exit 1

cap="${RUN_EVALS_MAX_COST_USD:-5}"
if [ "${RUN_EVALS:-}" != 1 ]; then
  echo "REFUSED: run-evals.sh spends real model calls (cap \$$cap per invocation) — re-run with RUN_EVALS=1" >&2
  exit 3
fi

plugin="${1:-}"
case "$plugin" in
  ''|*/*|.*) echo "usage: RUN_EVALS=1 bash scripts/run-evals.sh <plugin> [extra claude plugin eval args…]" >&2; exit 64 ;;
esac
shift
refuse_arg() {
  echo "run-evals.sh: $1 — refused; extra arguments are limited to --runs, --case, --tag, --allow-tools, --model, --judge-model and --threshold with their values" >&2
  exit 64
}
need=; more=; prev=
for a in "$@"; do
  if [ -n "$need" ]; then
    case "$a" in -*) refuse_arg "$prev takes a value, got $a" ;; esac
    need=; continue
  fi
  case "$a" in
    --runs|--case|--model|--judge-model|--threshold) need=1; more= ;;
    --tag|--allow-tools) need=1; more=1 ;;
    --runs=?*|--case=?*|--model=?*|--judge-model=?*|--threshold=?*|--tag=?*|--allow-tools=?*) more= ;;
    -*) refuse_arg "$a is not on the allow-list" ;;
    *) [ -n "$more" ] || refuse_arg "$a is not the value of an allowed flag" ;;
  esac
  prev=$a
done
[ -z "$need" ] || refuse_arg "$prev takes a value"
[ -d "plugins/$plugin/evals" ] || { echo "run-evals.sh: plugins/$plugin/evals/ does not exist — nothing to run" >&2; exit 64; }
[[ "$cap" =~ ^[0-9]+([.][0-9]+)?$ ]] || { echo "run-evals.sh: RUN_EVALS_MAX_COST_USD='$cap' is not a non-negative number" >&2; exit 64; }
python3 -c 'import yaml' 2>/dev/null || {
  echo "run-evals.sh: python3 cannot import yaml — the case files must be read before the paid run, so nothing ran" >&2
  exit 64
}

tmp=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp"' EXIT

python3 - "plugins/$plugin/evals" "$plugin" "$tmp/plan.json" "$@" <<'PY' || exit $?
import json, os, re, sys, yaml

evals_dir, plugin, plan_path = sys.argv[1:4]
extra = sys.argv[4:]

def pos_int(v):
    try:
        n = int(v)
    except (TypeError, ValueError):
        return None
    return n if n > 0 and not isinstance(v, bool) else None

runs_override, case_glob, tag_filters, flag = None, None, [], None
for a in extra:
    if a.startswith("-"):
        flag, eq, val = a.partition("=")
        if not eq:
            continue
    else:
        val = a
    if flag == "--runs":
        runs_override = pos_int(val)
    elif flag == "--case":
        case_glob = val
    elif flag == "--tag":
        tag_filters.append(val)

def selected(name, tags):
    if case_glob is not None:
        rx = "".join(".*" if ch == "*" else "." if ch == "?" else re.escape(ch) for ch in case_glob)
        if not re.fullmatch(rx, name, re.S):
            return False
    return not tag_filters or bool(set(tag_filters) & set(tags))

def case_files(root):
    found = []
    for d, subdirs, files in os.walk(root):
        subdirs[:] = sorted(s for s in subdirs if s not in ("results", "mocks", "graders") and not s.startswith("."))
        if "case.yaml" in files:
            found.append(os.path.join(d, "case.yaml"))
            subdirs[:] = []
    return found

cases, scaffolded, unreadable = [], [], []
for path in case_files(evals_dir):
    rel = os.path.relpath(os.path.dirname(path), evals_dir)
    try:
        with open(path) as fh:
            d = yaml.safe_load(fh)
    except Exception:
        d = None
    if not isinstance(d, dict):
        unreadable.append(rel)
        continue
    ctx = d.get("context")
    if isinstance(ctx, dict) and "scaffold_script" in ctx:
        scaffolded.append(rel)
    name = str(d.get("name") or os.path.basename(os.path.dirname(path)))
    tags = [str(t) for t in d["tags"]] if isinstance(d.get("tags"), list) else []
    if selected(name, tags):
        cases.append({"name": name, "runs": d.get("runs")})

if scaffolded:
    print("run-evals.sh: refused — these cases declare scaffold_script, and without --scaffold (never passed here) each would be paid for while scoring the repo root:", file=sys.stderr)
    for rel in scaffolded:
        print("  " + rel, file=sys.stderr)
    print("  run the manual `claude plugin eval` command in plugins/%s/README.md instead" % plugin, file=sys.stderr)
if unreadable:
    print("run-evals.sh: refused — these case.yaml files are not a YAML mapping, so whether they declare scaffold_script cannot be read:", file=sys.stderr)
    for rel in unreadable:
        print("  " + rel, file=sys.stderr)
if scaffolded or unreadable:
    sys.exit(64)
with open(plan_path, "w") as fh:
    json.dump({"runsOverride": runs_override, "cases": cases}, fh)
PY

out_dir="${RUN_EVALS_OUT_DIR:-rationale/evals}"
mkdir -p "$out_dir" || exit 1
started=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
stamp="${started:0:10}-${started:11:2}${started:14:2}${started:17:2}"

claude plugin eval "./plugins/$plugin" --ablation with-without --max-cost-usd "$cap" \
  --no-publish --trust-plugin --output-dir "$tmp" --report "$tmp/report.html" \
  --json "$tmp/aggregate.json" "$@"
rc=$?

[ -s "$tmp/aggregate.json" ] || { echo "run-evals.sh: the CLI wrote no result document (exit $rc) — no summary written" >&2; exit "$rc"; }
summary="$out_dir/$stamp-$plugin.json"

python3 - "$tmp/aggregate.json" "$tmp/plan.json" "$plugin" "$started" "$cap" "$rc" "$summary" <<'PY'
import json, os, re, sys

doc_path, plan_path, plugin, started, cap, rc, summary = sys.argv[1:8]
doc = json.load(open(doc_path))
plan = json.load(open(plan_path))
runs_override = plan["runsOverride"]
file_runs = {c["name"]: c["runs"] for c in plan["cases"]}

def num(v):
    return v if isinstance(v, (int, float)) and not isinstance(v, bool) else None

def pos_int(v):
    try:
        n = int(v)
    except (TypeError, ValueError):
        return None
    return n if n > 0 and not isinstance(v, bool) else None

doc_cases = {str(c.get("name")): c for c in (doc.get("cases") or []) if isinstance(c, dict)}
names = list(doc_cases)
if doc.get("partial") is True or not doc_cases:
    names = list(file_runs) + [n for n in doc_cases if n not in file_runs]

cases = []
for name in names:
    c = doc_cases.get(name, {})
    n = runs_override or pos_int(c.get("runsPerCase")) or pos_int(file_runs.get(name)) or 3
    arms = c.get("arms") if isinstance(c.get("arms"), dict) else {}
    runs = {a: [r for r in (arms.get(a) or []) if isinstance(r, dict)] for a in ("with", "without")}
    scores = {a: [s for s in (num(r.get("score")) for r in runs[a]) if s is not None] for a in runs}
    agg = c.get("aggregates") if isinstance(c.get("aggregates"), dict) else {}
    cases.append({
        "name": name,
        "planned": {"with": n, "without": n},
        "completed": {a: len(runs[a]) for a in runs},
        "scores": scores,
        "spread": {a: "%d/%d" % (sum(1 for s in scores[a] if s >= 1), len(runs[a])) for a in runs},
        "delta": num(agg.get("delta")),
    })

cap_n = float(cap)
reason = doc.get("partialReason")
out = {
    "schema": 1,
    "plugin": plugin,
    "startedAt": started,
    "claudeVersion": doc.get("claudeVersion") if isinstance(doc.get("claudeVersion"), str) else None,
    "maxCostUsd": int(cap_n) if cap_n.is_integer() else cap_n,
    "costUsd": num(doc.get("costUsd")),
    "exitCode": int(rc),
    "partial": doc.get("partial") is True,
    "partialReason": reason if reason in ("cost_ceiling", "interrupted", "auth_failed") else None,
    "arms": ["with", "without"],
    "runsPerCaseOverride": runs_override,
    "plannedRuns": sum(c["planned"]["with"] + c["planned"]["without"] for c in cases),
    "completedRuns": sum(c["completed"]["with"] + c["completed"]["without"] for c in cases),
    "cases": cases,
}
text = json.dumps(out, indent=2) + "\n"
leak = re.search(r"/Users/|/home/|/root/|[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", text)
if leak:
    print("run-evals.sh: REFUSED to write the summary — it matches a home path or a session-id-shaped UUID (%r)" % leak.group(0), file=sys.stderr)
    sys.exit(65)
part = summary + ".part"
with open(part, "w") as fh:
    fh.write(text)
os.replace(part, summary)
print("Summary: " + summary)
PY
st=$?
if [ "$st" -ne 0 ]; then
  trap - EXIT
  echo "run-evals.sh: no summary written (summariser exit $st); the paid run's result document is kept at $tmp/aggregate.json — it holds prompts and paths, never commit it" >&2
  exit "$st"
fi
exit "$rc"
