#!/usr/bin/env bash
# eval-cases.sh — BLOCKING: every plugins/*/evals suite must LOAD: a case.yaml or prompt.md per case dir; quoted schema_version, name, execution.prompt, typed graders; typed graders/*.md; runs >= 3 with an llm grader; an existing scaffold_script; and a free load whose grant lines the README documents as --allow-tools.
# Misses: whether a case measures anything (control arm), grader quality, a pass, --runs at run time, runner schema drift and its version ceiling, grader keys, anything inside a case; the free load skips without `claude` or plugin.json. An undocumented --scaffold is a WARN.
# Why, limits, history: rationale/derivations/scripts.md § scripts/eval-cases.sh
set -u
cd "$(dirname "$0")/.." || exit 1
rc=0
fail() { printf 'FAIL: %s\n' "$1" >&2; rc=1; }
warn() { printf 'WARN: %s\n' "$1" >&2; }

python3 -c 'import yaml' 2>/dev/null || {
  echo "FAIL: python3 cannot import yaml — this gate cannot run, and a gate that skips is not a gate" >&2
  exit 1
}

frontmatter_check() { # frontmatter_check type <graders/x.md> | frontmatter_check runs <prompt.md> <newline-separated graders/*.md> — stdout: the defect, exit 1
  python3 - "$@" <<'PY'
import sys, os, yaml
def frontmatter(path):
    # (mapping-or-None, defect-or-None); (None, None) when line 1 is not `---`.
    raw = open(path, "rb").read()
    if raw.startswith(b"\xef\xbb\xbf"):
        raw = raw[3:]
    lines = raw.decode("utf-8", "replace").replace("\r\n", "\n").split("\n")
    if not lines or lines[0] != "---":
        return None, None
    try:
        end = lines.index("---", 1)
    except ValueError:
        return None, "frontmatter opened on line 1 and never closed"
    try:
        return yaml.safe_load("\n".join(lines[1:end])), None
    except Exception as e:
        return None, f"frontmatter is not valid YAML: {e}"

mode, path = sys.argv[1], sys.argv[2]
if mode == "type":
    fm, defect = frontmatter(path)
    if defect:
        print(defect); sys.exit(1)
    if not isinstance(fm, dict) or not str(fm.get("type") or "").strip():
        print("no type: frontmatter (the 2026-09-14 rejection, not a dead shape)"); sys.exit(1)
    sys.exit(0)

graders = [g for g in sys.argv[3].split("\n") if g]
if not any(isinstance(fm, dict) and fm.get("type") == "llm"
           for fm in (frontmatter(g)[0] for g in graders)):
    sys.exit(0)
# The runner's precedence: prompt.md frontmatter overrides a sibling case.yaml.
fm = frontmatter(path)[0]
if isinstance(fm, dict) and "runs" in fm:
    r = fm["runs"]
else:
    side = os.path.join(os.path.dirname(path), "case.yaml")
    r = None
    if os.path.isfile(side):
        try:
            with open(side) as fh:
                d = yaml.safe_load(fh)
        except Exception:
            d = None
        if not isinstance(d, dict):
            sys.exit(0)  # the case.yaml branch fails an unreadable or non-mapping sibling
        r = d.get("runs")
if r is None:
    print("an `llm` grader and no `runs` key — declare `runs: 3` or more; "
          "the runner's default is a CLI constant, not a property of this case"); sys.exit(1)
if not isinstance(r, int) or isinstance(r, bool) or r < 1:
    print(f"`runs: {r!r}` is not a positive integer"); sys.exit(1)
if r < 3:
    print(f"`runs: {r}` with an `llm` grader — three runs cannot separate a "
          "regression from a flake; fewer cannot try (CLAUDE.md)"); sys.exit(1)
PY
}
grader_type_ok() { frontmatter_check type "$1"; }

case_dirs() { # case_dirs <evals dir> — one `case<TAB><dir>` or `dead<TAB><dir>` line per directory
  # A case dir is the first directory on a branch with a case definition (never descended into); a branch with none is `dead`. results/, mocks/ and graders/ are skipped.
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
  # `--max-cost-usd 0` aborts before the first run (no model, no credential), after the runner has printed its grant diagnostics.
  local plugin="$1" out tmp granted docs
  [ -f "plugins/$plugin/.claude-plugin/plugin.json" ] || return 0
  command -v claude >/dev/null 2>&1 || { warn "$plugin: free load check SKIPPED — claude is not on PATH"; return 0; }
  tmp=$(mktemp -d) || return 0
  # --output-dir AND --report keep the runner out of plugins/<p>/evals/results/; a throwaway HOME keeps it off the operator's config.
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
  # The grant lines belong to the bare command, so naming `--allow-tools` in the README discharges them; a CHANGELOG is not that place.
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
        rmsg=$(frontmatter_check runs "$cdir/prompt.md" "$graders") || fail "$cdir/prompt.md: $rmsg"
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

has_llm = isinstance(g, list) and any(
    isinstance(one, dict) and one.get("type") == "llm" for one in g)
if has_llm and r is None:
    errs.append("an `llm` grader and no `runs` key — declare `runs: 3` or more; "
                "the runner's default is a CLI constant, not a property of this case")
elif has_llm and isinstance(r, int) and not isinstance(r, bool) and r < 3:
    errs.append(f"`runs: {r}` with an `llm` grader — three runs cannot separate a "
                "regression from a flake; fewer cannot try (CLAUDE.md)")

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
