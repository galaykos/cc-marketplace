#!/usr/bin/env bash
# BLOCKING gate: every shipped eval suite must LOAD.
#
# WHY THIS EXISTS. On 2026-09-14 two of the three shipped eval suites were found to have
# never run — `resilience` and `web-dev` loaded 0 cases on CLI 2.1.270 (`invalid
# case.yaml: graders: Required`). They sat dead for weeks. Nothing noticed, because
# nothing runs an eval in CI, and a dead suite is indistinguishable from a passing one
# when nobody executes it: the files are present, `validate.sh` is happy, the directory
# looks maintained.
#
# THE ROOT CAUSE WAS MISNAMED for two days. Both suites used the `prompt.md` +
# `graders/*.md` shape, and this script's first revision failed that SHAPE as dead. It is
# not: the runner's own usage line reads `case.yaml or prompt.md + graders/*.md`, and a
# `prompt.md` beside a `graders/says-hello.md` carrying `type: regex` frontmatter loaded
# and scored 1.00 on 2.1.273 (measured 2026-09-16,
# rationale/marketplace-trend-audit-2026-09-16.md A1). What the two suites shipped was a
# grader with NO frontmatter at all — prose from line 1
# (`git show 4878150702^:plugins/resilience/evals/timeout-and-retry/graders/retry-idempotency.md`)
# — so the runner had no `type:` to build a grader from. That is the same defect as a
# `case.yaml` grader entry with no `type`, reached through a different file.
#
# Running the evals in CI is the expensive fix — a full resilience matrix measured
# $10.13 and 12 minutes on 2026-09-15, it needs a live model and a credential, and its
# result is a score rather than a verdict. LOADING them is nearly free and catches the
# failure that actually happened. That is the whole claim of this script.
#
# WHAT IT CATCHES:
#   - an `evals/` directory that resolves to ZERO cases (the 2026-09-14 bug)
#   - a case directory holding neither `case.yaml` nor `prompt.md`
#   - a `case.yaml` that is not valid YAML, or is not a mapping
#   - a missing `name`, `execution.prompt`, or `graders`
#   - `graders` present but empty, or a grader with no `type` (the exact rejection above)
#   - a `prompt.md` with no `graders/*.md`, or a `graders/*.md` whose frontmatter carries
#     no `type:` from the runner's set (regex tool_used tool_order file_exists llm baseline)
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
#   - how the runner merges a case that ships BOTH files. Each file is checked on its own
#     terms; a `case.yaml` beside a `prompt.md` is still held to `execution.prompt`.
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

  found=$(find "$dir" \( -name case.yaml -o -name prompt.md \) -type f 2>/dev/null | sort)
  if [ -z "$found" ]; then
    fail "$plugin: $dir contains no case.yaml or prompt.md — the suite loads ZERO cases and every run of it is a no-op."
    continue
  fi

  # results/ is the runner's output dir and mocks/ its MCP stand-ins; neither is a case.
  for cdir in "$dir"/*/; do
    [ -d "$cdir" ] || continue
    case "$(basename "$cdir")" in results|mocks) continue ;; esac
    find "$cdir" \( -name case.yaml -o -name prompt.md \) -type f 2>/dev/null | grep -q . \
      || fail "$plugin: $cdir holds neither case.yaml nor prompt.md — it is not a case and loads nothing"
  done

  cases=$((cases + $(printf '%s\n' "$found" | sed 's|/[^/]*$||' | sort -u | wc -l)))
  while IFS= read -r case_file; do
    [ -n "$case_file" ] || continue
    if [ "$(basename "$case_file")" = prompt.md ]; then
      gdir="$(dirname "$case_file")/graders"
      graders=$(find "$gdir" -maxdepth 1 -name '*.md' -type f 2>/dev/null | sort)
      [ -n "$graders" ] || { fail "$case_file: prompt.md with no graders/*.md — graders: Required (0 cases loaded on 2026-09-14)"; continue; }
      while IFS= read -r g; do
        [ -n "$g" ] || continue
        gtype=$(awk 'NR==1 && $0!="---"{exit} NR>1 && /^---$/{exit} NR>1 && /^type:/{sub(/^type:[[:space:]]*/,""); sub(/[[:space:]]+$/,""); print; exit}' "$g")
        case "$gtype" in
          '') fail "$g: no type: frontmatter (the 2026-09-14 rejection, not a dead shape)" ;;
          regex|tool_used|tool_order|file_exists|llm|baseline) ;;
          *) fail "$g: type: $gtype is not one of regex|tool_used|tool_order|file_exists|llm|baseline" ;;
        esac
      done <<< "$graders"
      continue
    fi
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
