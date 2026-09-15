#!/usr/bin/env bash
# BLOCKING gate: every shipped eval suite must LOAD.
#
# WHY THIS EXISTS. On 2026-09-14 two of the three shipped eval suites were found to have
# never run — `resilience` and `web-dev` used a `prompt.md` + `graders/*.md` shape that
# `CLAUDE.md` documented as functional and that the runner rejects (`invalid case.yaml:
# graders: Required`, 0 cases loaded). They sat dead for weeks. Nothing noticed, because
# nothing runs an eval in CI, and a dead suite is indistinguishable from a passing one
# when nobody executes it: the files are present, `validate.sh` is happy, the directory
# looks maintained.
#
# Running the evals in CI is the expensive fix — a full resilience matrix measured
# $10.13 and 12 minutes on 2026-09-15, it needs a live model and a credential, and its
# result is a score rather than a verdict. LOADING them is nearly free and catches the
# failure that actually happened. That is the whole claim of this script.
#
# WHAT IT CATCHES:
#   - an `evals/` directory that resolves to ZERO cases (the 2026-09-14 bug)
#   - a `case.yaml` that is not valid YAML, or is not a mapping
#   - a missing `name`, `execution.prompt`, or `graders`
#   - `graders` present but empty, or a grader with no `type` (the exact rejection above)
#   - the DEAD shape: a `prompt.md` or a `graders/` directory under `evals/`
#   - a non-numeric or non-positive `runs` / `max_turns`
#
# WHAT IT DOES NOT CATCH, stated because this repo tiers its claims:
#   - whether a case MEASURES anything. A case whose control arm passes is a regression
#     guard with no headroom, and it loads exactly like a case that measures a skill.
#     That distinction is `CLAUDE.md`'s ceiling rule and it is `recorded`, not gated.
#   - whether a grader's criteria are any good, or whether the prompt elicits the
#     behaviour the grader scores. Both are agent-graded at best.
#   - whether the suite would PASS. This never runs a model and never spends a cent.
#   - drift between the runner's schema and this checker's idea of it. The runner is the
#     authority; this asserts the subset whose absence has actually broken a suite here.
set -u
cd "$(dirname "$0")/.." || exit 1
rc=0
fail() { printf 'FAIL: %s\n' "$1" >&2; rc=1; }

python3 -c 'import yaml' 2>/dev/null || {
  echo "FAIL: python3 cannot import yaml — this gate cannot run, and a gate that skips is not a gate" >&2
  exit 1
}

suites=0
cases=0
for dir in plugins/*/evals; do
  [ -d "$dir" ] || continue
  suites=$((suites + 1))
  plugin=$(basename "$(dirname "$dir")")

  # The dead shape, named explicitly: it looks like a suite and loads nothing.
  if [ -f "$dir/prompt.md" ] || [ -d "$dir/graders" ]; then
    fail "$plugin: $dir uses the prompt.md + graders/ shape, which the runner rejects (measured 2026-09-14, 0 cases loaded). Convert to <case>/case.yaml."
  fi

  found=$(find "$dir" -name case.yaml -type f 2>/dev/null | sort)
  if [ -z "$found" ]; then
    fail "$plugin: $dir contains no case.yaml — the suite loads ZERO cases and every run of it is a no-op."
    continue
  fi

  while IFS= read -r case_file; do
    [ -n "$case_file" ] || continue
    cases=$((cases + 1))
    msg=$(python3 - "$case_file" <<'PY'
import sys, yaml, os
path = sys.argv[1]
try:
    with open(path) as fh:
        d = yaml.safe_load(fh)
except Exception as e:
    print(f"is not valid YAML: {e}"); sys.exit(1)
if not isinstance(d, dict):
    print("is not a YAML mapping"); sys.exit(1)

errs = []
if not d.get("name"):
    errs.append("no `name`")
else:
    want = os.path.basename(os.path.dirname(path))
    if d["name"] != want:
        errs.append(f"`name: {d['name']}` does not match its directory `{want}` — --case globs match the name")

ex = d.get("execution")
if not isinstance(ex, dict):
    errs.append("no `execution` mapping")
else:
    if not str(ex.get("prompt") or "").strip():
        errs.append("`execution.prompt` is empty")
    mt = ex.get("max_turns")
    if mt is not None and (not isinstance(mt, int) or isinstance(mt, bool) or mt < 1):
        errs.append(f"`max_turns: {mt!r}` is not a positive integer")

g = d.get("graders")
if g is None:
    errs.append("no `graders` — this is the exact key whose absence loaded 0 cases on 2026-09-14")
elif not isinstance(g, list) or not g:
    errs.append("`graders` is not a non-empty list")
else:
    for i, one in enumerate(g):
        if not isinstance(one, dict):
            errs.append(f"grader {i} is not a mapping")
        elif not one.get("type"):
            errs.append(f"grader {i} has no `type`")
        elif one.get("type") == "llm" and not str(one.get("criteria") or "").strip():
            errs.append(f"grader {i} is `type: llm` with empty `criteria`")

r = d.get("runs")
if r is not None and (not isinstance(r, int) or isinstance(r, bool) or r < 1):
    errs.append(f"`runs: {r!r}` is not a positive integer")

if errs:
    print("; ".join(errs)); sys.exit(1)
PY
    ) || fail "$case_file $msg"
  done <<< "$found"
done

if [ "$rc" -eq 0 ]; then
  echo "OK: $cases eval case(s) across $suites suite(s) load"
fi
exit "$rc"
