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
#   - a `schema_version` that is absent, or unquoted (a YAML float, not a string), or
#     whose major does not parseInt — each of which loads ZERO cases
#   - `graders` present but empty, or a grader with no `type` (the exact rejection above)
#   - a `prompt.md` with no `graders/*.md`, or a `graders/*.md` whose frontmatter carries
#     no `type:` (or none at all). The NAME is not checked: until 2026-09-17 this branch
#     held graders to a six-name allowlist while the case.yaml branch asked only for
#     presence, so one grader shape was gated by a list the runner never published and
#     the other was not. The runner is the authority on which types exist; both branches
#     now ask the same question — is there a non-empty `type`.
#   - a non-numeric or non-positive `runs` / `max_turns`
#   - a `context.scaffold_script` naming a file that is not in the case directory. The
#     runner reports nothing for it without `--scaffold`, so the broken path only shows
#     up on a paid run of a suite somebody trusted enough to pass the flag to.
#   - (WARN) a suite with a scaffolded case whose plugin README never names `--scaffold`.
#     `--scaffold` is OFF by default; on 2026-09-22 five of fourteen cases declared a
#     scaffold and only `overseer`'s README said so, so candor's three ran against
#     whatever happened to be in the operator's unstaged workspace and scored it.
#   - (WARN) `runs` below 3 on a case carrying an `llm` grader. CLAUDE.md's own rule:
#     three runs cannot separate a regression from a flake — fewer cannot even try.
#   - (FREE LOAD) per suite, the documented zero-cost invocation
#     `claude plugin eval ./plugins/<p> --max-cost-usd 0 --no-publish --trust-plugin`,
#     failing on the runner's `not granted` and `cannot pass with the granted tools`
#     lines. Those are operator-grant facts, not file facts: a case that legitimately
#     declares Write/Edit/Bash in `execution.allowed_tools` draws them under the bare
#     command no matter what it contains. So the FAIL is discharged by DOCUMENTING the
#     grant — the plugin's own README naming `--allow-tools` — which is the defect the
#     2026-09-22 panel actually found (candor's grant lived in CHANGELOG:26 and nowhere
#     an installer reads). Measured that day: `ran-a-command` in
#     candor/limitation-checked-before-stated cannot pass under the bare command, and
#     ask-ledger/named-things-accounted reports Write, Edit not granted.
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
#   - a `schema_version` MAJOR the installed CLI is too old for. The runner rejects one
#     above its own ceiling (`1` on 2.1.273); that constant lives in the binary and moves
#     with it, so this gate checks the shape and leaves the ceiling to the runner —
#     copying the number here is how CLAUDE.md's stale-count rule gets broken again.
#   - how the runner merges a case that ships BOTH files. The runner's own usage line
#     admits the combination, so a `case.yaml` beside a `prompt.md` is held to `name`
#     only: the prompt.md body is the prompt and graders/*.md are the graders, and
#     demanding `execution.prompt` there (as this did until 2026-09-17) failed a shape
#     the runner loads. A key that IS present is still shape-checked; whether the runner
#     prefers the yaml's `graders:` list or the directory when both exist is unmeasured.
#   - which grader KEYS the runner accepts. Only `type` is asserted; on 2026-09-18 this
#     loaded a case whose grader carried a `target:` key the runner rejected at run time
#     (rationale/fable-distillation-2026-09-18.md). The key set is the runner's, not this
#     script's — see the schema-drift bullet above.
#   - anything INSIDE a case. A case dir is the first directory on a branch holding a
#     `case.yaml` or a `prompt.md`; the walk stops there, so a `prompt.md` under its
#     `resources/` or `mocks/` is a fixture the case reads, neither counted nor failed.
#     Cases NEST: the runner's own usage line globs `<eval dir>/**/case.yaml or
#     prompt.md + graders/*.md` (`claude plugin eval --help`, 2.1.273), so a case may
#     sit at any depth. Until 2026-09-17 this walked `evals/*/` only and FAILED the
#     PARENT of a nested case as "not a case" — a gate rejecting a layout the runner
#     loads, and a regression against the recursive `find` it replaced.
#   - whether a scaffold_script that EXISTS builds the workspace the prompt assumes, or
#     whether the README's documented grant is the RIGHT grant. Both are agent-graded:
#     this checks that the file is there and that the flag is named, nothing more.
#   - anything at all when `claude` is not on PATH — the free load check then prints a
#     WARN and is skipped, exactly as `official-validate.sh` does. A gate that skips is
#     not a gate, so the skip is printed by name rather than swallowed.
#   - a suite under a directory with no `.claude-plugin/plugin.json`. The runner resolves
#     a plugin from the target path; with no manifest there is nothing to resolve, so the
#     free load check is skipped there (which is also what keeps the synthetic fixtures in
#     scripts/smoke/eval-case-tests.sh from invoking the binary).
set -u
cd "$(dirname "$0")/.." || exit 1
rc=0
fail() { printf 'FAIL: %s\n' "$1" >&2; rc=1; }
warn() { printf 'WARN: %s\n' "$1" >&2; }

python3 -c 'import yaml' 2>/dev/null || {
  echo "FAIL: python3 cannot import yaml — this gate cannot run, and a gate that skips is not a gate" >&2
  exit 1
}

grader_type_ok() { # grader_type_ok <graders/x.md> — stdout: the defect, exit 1, when its frontmatter has no usable type
  python3 - "$1" <<'PY'
import sys, yaml
path = sys.argv[1]
raw = open(path, "rb").read()
if raw.startswith(b"\xef\xbb\xbf"):
    raw = raw[3:]
lines = raw.decode("utf-8", "replace").replace("\r\n", "\n").split("\n")
if not lines or lines[0] != "---":
    print("no type: frontmatter (the 2026-09-14 rejection, not a dead shape)"); sys.exit(1)
try:
    end = lines.index("---", 1)
except ValueError:
    print("frontmatter opened on line 1 and never closed"); sys.exit(1)
try:
    fm = yaml.safe_load("\n".join(lines[1:end]))
except Exception as e:
    print(f"frontmatter is not valid YAML: {e}"); sys.exit(1)
if not isinstance(fm, dict) or not str(fm.get("type") or "").strip():
    print("no type: frontmatter (the 2026-09-14 rejection, not a dead shape)"); sys.exit(1)
PY
}

case_dirs() { # case_dirs <evals dir> — one `case<TAB><dir>` or `dead<TAB><dir>` line per directory
  # A case dir is the first directory on a branch carrying a case definition; the walk
  # does not descend into one, so its fixtures are never mistaken for cases. A branch
  # that bottoms out with no case definition anywhere on it is `dead` — the scratch dir
  # that looks like a suite and loads nothing. results/ is the runner's output dir,
  # mocks/ its MCP stand-ins, and graders/ belongs to the case above it.
  python3 - "$1" <<'PYCD'
import os, sys
root = sys.argv[1]
SKIP = {"results", "mocks", "graders"}
def subdirs(d):
    try:
        names = os.listdir(d)
    except OSError:
        return []
    return sorted(n for n in names
                  if n not in SKIP and not n.startswith(".")
                  and os.path.isdir(os.path.join(d, n)))
def walk(d):
    if os.path.isfile(os.path.join(d, "case.yaml")) or os.path.isfile(os.path.join(d, "prompt.md")):
        print("case\t" + d)
        return True
    subs = subdirs(d)
    if not subs:
        print("dead\t" + d)
        return False
    return any([walk(os.path.join(d, n)) for n in subs])
for n in subdirs(root):
    walk(os.path.join(root, n))
PYCD
}

free_load_check() { # free_load_check <plugin>
  # The documented zero-cost invocation. `--max-cost-usd 0` aborts before the first run
  # launches (exit 2, "partial"), so no model is called and no credential is needed — but
  # the runner has already resolved the plugin, read every case and printed the grant
  # diagnostics by then. That is the whole of what this reads.
  local plugin="$1" out tmp granted docs
  [ -f "plugins/$plugin/.claude-plugin/plugin.json" ] || return 0
  command -v claude >/dev/null 2>&1 || { warn "$plugin: free load check SKIPPED — claude is not on PATH"; return 0; }
  tmp=$(mktemp -d) || return 0
  # --output-dir AND --report: the first redirects aggregate-result.json, the second the
  # HTML report, and only both together keep the runner out of `plugins/<p>/evals/results/`
  # (gitignored, so this litters rather than dirties — measured 2026-09-22). HOME is
  # throwaway so the check cannot depend on, or write to, the operator's config.
  out=$(HOME="$tmp" DISABLE_AUTOUPDATER=1 CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
        claude plugin eval "./plugins/$plugin" --max-cost-usd 0 --no-publish --trust-plugin \
        --output-dir "$tmp/results" --report "$tmp/report.html" </dev/null 2>&1)
  rm -rf "$tmp"
  case "$out" in
    *"Plugin under test:"*) ;;
    *) warn "$plugin: free load check SKIPPED — the runner never reported a plugin under test: ${out%%$'\n'*}"; return 0 ;;
  esac
  granted=$(printf '%s\n' "$out" | grep -E 'not granted|cannot pass with the granted tools')
  [ -n "$granted" ] || return 0
  # Discharged by documenting the grant: the lines are a property of the bare command,
  # not of the files, so the fix an author can make is to name `--allow-tools` where an
  # installer reads it. A CHANGELOG entry is not that place (candor, 2026-09-22).
  docs=$(grep -l -- '--allow-tools' "plugins/$plugin/README.md" 2>/dev/null)
  if [ -n "$docs" ]; then return 0; fi
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    fail "$plugin: ${line# }  — and plugins/$plugin/README.md never names \`--allow-tools\`, so the invocation it documents cannot run this suite"
  done <<< "$granted"
}

suites=0
cases=0
for dir in plugins/*/evals; do
  [ -d "$dir" ] || continue
  suites=$((suites + 1))
  plugin=$(basename "$(dirname "$dir")")
  ncases=0
  scaffolded=0

  while IFS=$'\t' read -r kind cdir; do
    [ -n "${cdir:-}" ] || continue
    if [ "$kind" = dead ]; then
      fail "$plugin: $cdir/ holds neither case.yaml nor prompt.md, and no directory under it does — it is not a case and loads nothing"
      continue
    fi
    has_prompt=0; has_yaml=0
    [ -f "$cdir/prompt.md" ] && has_prompt=1
    [ -f "$cdir/case.yaml" ] && has_yaml=1
    ncases=$((ncases + 1))

    if [ "$has_prompt" -eq 1 ]; then
      graders=$(find "$cdir/graders" -maxdepth 1 -name '*.md' -type f 2>/dev/null | sort)
      if [ -z "$graders" ]; then
        fail "$cdir/prompt.md: prompt.md with no graders/*.md — graders: Required (0 cases loaded on 2026-09-14)"
      else
        while IFS= read -r g; do
          [ -n "$g" ] || continue
          gmsg=$(grader_type_ok "$g") || fail "$g: $gmsg"
        done <<< "$graders"
      fi
    fi

    [ "$has_yaml" -eq 1 ] || continue
    grep -qE '^[[:space:]]*scaffold_script:' "$cdir/case.yaml" && scaffolded=1
    case_file="$cdir/case.yaml"
    msg=$(python3 - "$case_file" "$has_prompt" <<'PY'
import sys, yaml, os, re
path = sys.argv[1]
# A sibling prompt.md supplies the prompt and graders/*.md the graders; only a
# case.yaml that is the whole case must carry them itself.
whole = sys.argv[2] == "0"
try:
    with open(path) as fh:
        d = yaml.safe_load(fh)
except Exception as e:
    print(f"is not valid YAML: {e}"); sys.exit(1)
if not isinstance(d, dict):
    print("is not a YAML mapping"); sys.exit(1)

errs = []

# The runner's FIRST check after "is it a mapping", and the one this gate went
# without until 2026-09-17. Read out of the 2.1.273 binary (`ms(e)`): schema_version
# must be a STRING — an unquoted `1.0` is a YAML float and draws the identical
# `missing required field schema_version` rejection — and parseInt of the text before
# the first `.` must not be NaN. Both load ZERO cases, which is this gate's whole
# subject. The runner's third condition, major <= the binary's max, is NOT modelled
# here: that ceiling is a constant inside the CLI (1 on 2.1.273) and copying it into
# this file is how a number goes stale, per CLAUDE.md's own recount rule.
sv = d.get("schema_version")
if not isinstance(sv, str):
    got = "absent" if sv is None else f"a YAML {type(sv).__name__}, not a string (quote it)"
    errs.append(f'`schema_version` is {got} — the runner requires `schema_version: "1.0"` and loads 0 cases without it')
elif not re.match(r"\s*[+-]?\d", sv.split(".", 1)[0]):
    errs.append(f'`schema_version: "{sv}"` is not a valid version string — the runner parseInts the text before the first `.`')

if not d.get("name"):
    errs.append("no `name`")
else:
    want = os.path.basename(os.path.dirname(path))
    if d["name"] != want:
        errs.append(f"`name: {d['name']}` does not match its directory `{want}` — --case globs match the name")

ex = d.get("execution")
if ex is None and whole:
    errs.append("no `execution` mapping")
elif ex is not None and not isinstance(ex, dict):
    errs.append("`execution` is not a mapping")
elif ex is not None:
    if whole and not str(ex.get("prompt") or "").strip():
        errs.append("`execution.prompt` is empty")
    mt = ex.get("max_turns")
    if mt is not None and (not isinstance(mt, int) or isinstance(mt, bool) or mt < 1):
        errs.append(f"`max_turns: {mt!r}` is not a positive integer")

g = d.get("graders")
if g is None:
    if whole:
        errs.append("no `graders` — this is the exact key whose absence loaded 0 cases on 2026-09-14")
elif not isinstance(g, list) or not g:
    errs.append("`graders` is not a non-empty list")
else:
    for i, one in enumerate(g):
        if not isinstance(one, dict):
            errs.append(f"grader {i} is not a mapping")
        elif not str(one.get("type") or "").strip():
            errs.append(f"grader {i} has no `type`")
        elif one.get("type") == "llm" and not str(one.get("criteria") or "").strip():
            errs.append(f"grader {i} is `type: llm` with empty `criteria`")

r = d.get("runs")
if r is not None and (not isinstance(r, int) or isinstance(r, bool) or r < 1):
    errs.append(f"`runs: {r!r}` is not a positive integer")

# A scaffold the runner cannot find is only discovered on a paid --scaffold run.
ctx = d.get("context")
if isinstance(ctx, dict):
    ss = str(ctx.get("scaffold_script") or "").strip()
    if ss and not os.path.isfile(os.path.join(os.path.dirname(path), ss)):
        errs.append(f"`context.scaffold_script: {ss}` is not a file in this case directory")

# WARNs go to stderr and never set the exit status: neither stops the suite loading,
# which is this gate's subject. They are here because both were counted by hand on
# 2026-09-22 and nothing re-counts them.
has_llm = isinstance(g, list) and any(
    isinstance(one, dict) and one.get("type") == "llm" for one in g)
if has_llm and isinstance(r, int) and not isinstance(r, bool) and r < 3:
    print(f"WARN: {path}: `runs: {r}` with an `llm` grader — CLAUDE.md's rule is that "
          "three runs cannot separate a regression from a flake; fewer cannot try",
          file=sys.stderr)

if errs:
    print("; ".join(errs)); sys.exit(1)
PY
    ) || fail "$case_file $msg"
  done <<< "$(case_dirs "$dir")"

  [ "$ncases" -gt 0 ] \
    || fail "$plugin: $dir contains no case.yaml or prompt.md — the suite loads ZERO cases and every run of it is a no-op."
  cases=$((cases + ncases))

  if [ "$scaffolded" -eq 1 ] && ! grep -q -- '--scaffold' "plugins/$plugin/README.md" 2>/dev/null; then
    warn "$plugin: a case declares scaffold_script and plugins/$plugin/README.md never names \`--scaffold\` — the flag is OFF by default, so anyone following the README runs the case against their own unstaged workspace"
  fi

  free_load_check "$plugin"
done

if [ "$rc" -eq 0 ]; then
  echo "OK: $cases eval case(s) across $suites suite(s) load"
fi
exit "$rc"
