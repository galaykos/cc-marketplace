#!/usr/bin/env bash
# RUN_EVALS=1 bash scripts/run-evals.sh <plugin> [extra `claude plugin eval` args…] — one plugin's eval suite against a no-plugin control arm under a cost cap (RUN_EVALS_MAX_COST_USD, default 5); writes a committable summary to rationale/evals/ and exits with the CLI's code.
# Refuses before any call: no RUN_EVALS=1 (exit 3); a bad plugin or cap, an arg off the allow-list, no PyYAML, a scaffolded or unreadable case.yaml (64). Writes no summary matching a home path or UUID (65). Misses: whether a skill helped, a flake, real spend.
# Why, limits, history: rationale/derivations/scripts.md § scripts/run-evals.sh
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
# An allow-list on purpose: the CLI keeps the LAST value of a repeated flag, so a new or aliased flag could override --max-cost-usd/--json or leave the sandbox — do not widen it lightly.
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
    voted = {a: [r for r in runs[a] if not r.get("error")] for a in runs}
    scores = {a: [s for s in (num(r.get("score")) for r in voted[a]) if s is not None] for a in runs}
    errored = {a: [s for s in (num(r.get("score")) for r in runs[a] if r.get("error")) if s is not None] for a in runs}
    agg = c.get("aggregates") if isinstance(c.get("aggregates"), dict) else {}
    cases.append({
        "name": name,
        "planned": {"with": n, "without": n},
        "completed": {a: len(runs[a]) for a in runs},
        "scores": scores,
        "spread": {a: "%d/%d" % (sum(1 for s in scores[a] if s >= 1), len(voted[a])) for a in runs},
        "errors": {a: len(runs[a]) - len(voted[a]) for a in runs},
        "erroredScores": errored,
        "delta": num(agg.get("delta")),
    })

cap_n = float(cap)
reason = doc.get("partialReason")
out = {
    "schema": 2,
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
