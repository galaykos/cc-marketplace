#!/usr/bin/env bash
# mutation-lens.sh — runs the project's OWN Infection, Stryker or mutmut 3 on the files changed vs a base and lists each surviving mutant as `path:line — mutator — what survived`, plus the score.
# Misses: untracked files (`git add -N` brings one in); a tool not configured (it never installs one; mutmut needs its [tool.mutmut] table); mutmut 2.x; Stryker with inPlace (refused) or clearTextReporter.reportMutants off. Stryker's --mutate replaces the config's mutate globs.
# Why, limits, history: rationale/derivations/plugin-testing.md § plugins/testing/scripts/mutation-lens.sh (marketplace repository)
#
#   mutation-lens.sh [--dir DIR] [--base REF] [--max-seconds N]
#
#   --dir          project root holding the tool's config (default .)
#   --base         diff base (default: the merge-base of HEAD with the default branch)
#   --max-seconds  wall-clock cap per tool run (default 900); at the cap, or on an interrupt, the tool's process group gets SIGINT, 10 s, SIGTERM, 2 s, SIGKILL
#
# Exit: 0 no surviving mutant · 1 survivors · 2 usage · 3 no tool it can run (none configured or installed, or Stryker inPlace) · 4 a tool failed, hit --max-seconds or was interrupted
set -u
PROG=${0##*/}

usage() { printf '%s: %s\n' "$PROG" "$1" >&2; exit 2; }
help() { awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"; }

dir=. ; base="" ; maxs=900
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) [ $# -ge 2 ] || usage "--dir needs a value"; dir=$2; shift 2 ;;
    --base) [ $# -ge 2 ] || usage "--base needs a value"; base=$2; shift 2 ;;
    --max-seconds) [ $# -ge 2 ] || usage "--max-seconds needs a value"; maxs=$2; shift 2 ;;
    -h|--help) help; exit 0 ;;
    *) usage "unknown argument $1" ;;
  esac
done
case "$maxs" in ''|*[!0-9]*) usage "--max-seconds must be a positive integer" ;; esac
[ "$maxs" -gt 0 ] || usage "--max-seconds must be a positive integer"
cd "$dir" 2>/dev/null || usage "--dir $dir is not a directory"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || usage "$(pwd) is not in a git work tree; the lens scopes by git diff"

WORK=$(mktemp -d) || exit 4
CHILD="" ; WATCH="" ; SCOPE="" ; GRACE=10
alive_after() { local i=0; while [ "$i" -lt "$1" ] && kill -0 -- -"$2" 2>/dev/null; do sleep 1; i=$((i + 1)); done; kill -0 -- -"$2" 2>/dev/null; }
# SIGINT (what Ctrl-C sends) first, SIGKILL last: a tool killed mid-mutant cannot put a source back.
stop_group() {
  kill -INT -- -"$1" 2>/dev/null || return 0
  alive_after "$GRACE" "$1" || return 0
  kill -TERM -- -"$1" 2>/dev/null
  alive_after 2 "$1" || return 0
  kill -KILL -- -"$1" 2>/dev/null
}
killed_note() { # a run cut short may have left a mutant in a source it touched
  [ -n "$SCOPE" ] || return 0
  printf '  a run cut short can leave a mutant in a source file; check: git diff --'
  printf '%s\n' "$SCOPE" | while IFS= read -r f; do [ -n "$f" ] && printf ' %q' "$f"; done
  printf '\n'
}
cleanup() {
  [ -n "$CHILD" ] && kill -KILL -- -"$CHILD" 2>/dev/null
  [ -n "$WATCH" ] && kill -KILL -- -"$WATCH" 2>/dev/null
  rm -rf "$WORK"
}
on_signal() {
  trap '' INT TERM HUP
  if [ -n "$CHILD" ]; then
    [ -n "$WATCH" ] && kill -KILL -- -"$WATCH" 2>/dev/null
    WATCH=""
    printf '\nmutation-lens: interrupted; stopping the tool (SIGINT, then SIGTERM and SIGKILL after %ss)\n' "$GRACE"
    stop_group "$CHILD"; CHILD=""
    killed_note
  fi
  exit 4
}
trap cleanup EXIT
trap on_signal INT TERM HUP

# Own process group per run, so the cap stops the tool's workers too, not only the launcher.
run_capped() { # log cmd... -> the command's rc, or 124 at the cap
  local log=$1 rc; shift
  rm -f "$WORK/capped"
  set -m
  "$@" </dev/null >"$log" 2>&1 &
  CHILD=$!
  ( sleep "$maxs"; : > "$WORK/capped"; stop_group "$CHILD" ) </dev/null >/dev/null 2>&1 &
  WATCH=$!
  set +m
  wait "$CHILD" 2>/dev/null; rc=$?
  if [ -f "$WORK/capped" ]; then wait "$WATCH" 2>/dev/null; kill -KILL -- -"$CHILD" 2>/dev/null; rc=124
  else kill -KILL -- -"$WATCH" 2>/dev/null; wait "$WATCH" 2>/dev/null; fi
  CHILD="" ; WATCH=""
  return "$rc"
}

# --- detection: the project's own config and its own install, never a download ---
inf_cfg="" ; inf_bin=""
for f in infection.json5 infection.json infection.json5.dist infection.json.dist; do
  [ -f "$f" ] && { inf_cfg=$f; break; }
done
if [ -x vendor/bin/infection ]; then inf_bin=vendor/bin/infection
elif command -v infection >/dev/null 2>&1; then inf_bin=$(command -v infection); fi

str_cfg="" ; str_dep=0 ; str_bin="" ; str_inplace=0
for p in "" .; do for s in .config .conf; do for e in json mjs js cjs; do
  [ -z "$str_cfg" ] && [ -f "${p}stryker${s}.$e" ] && str_cfg="${p}stryker${s}.$e"
done; done; done
[ -n "$str_cfg" ] && grep -qE "inPlace[\"']?[[:space:]]*:[[:space:]]*true" "$str_cfg" && str_inplace=1
[ -f package.json ] && grep -q '"@stryker-mutator/' package.json && str_dep=1
[ -x node_modules/.bin/stryker ] && str_bin=node_modules/.bin/stryker

mm_cfg="" ; mm_bin="" ; py_proj=0
grep -qE '^\[mutmut\]' setup.cfg 2>/dev/null && mm_cfg="setup.cfg [mutmut]"
grep -qE '^\[tool\.mutmut\]' pyproject.toml 2>/dev/null && mm_cfg="pyproject.toml [tool.mutmut]"
{ [ -f pyproject.toml ] || [ -f setup.py ] || [ -f setup.cfg ]; } && py_proj=1
command -v mutmut >/dev/null 2>&1 && mm_bin=mutmut

run_inf=0 ; run_str=0 ; run_mm=0 ; notes=""
note() { notes="$notes$1"$'\n'; }
if [ -n "$inf_cfg" ] && [ -n "$inf_bin" ]; then run_inf=1
elif [ -n "$inf_cfg" ]; then note "Infection is configured ($inf_cfg) but not installed: no vendor/bin/infection and none on PATH (composer install)."
elif [ -n "$inf_bin" ] && [ -x vendor/bin/infection ]; then note "Infection is installed but has no infection.json5: run without one it starts its interactive configure and writes a config. Create it with: vendor/bin/infection configure"
fi
if { [ -n "$str_cfg" ] || [ "$str_dep" = 1 ]; } && [ -n "$str_bin" ] && [ "$str_inplace" = 1 ]; then
  note "Stryker is not run: $str_cfg sets inPlace: true, so it mutates your source files, and a run cut short (the cap, an outer timeout, a SIGKILL) can leave a mutant in them. Run Stryker yourself, or drop inPlace."
elif { [ -n "$str_cfg" ] || [ "$str_dep" = 1 ]; } && [ -n "$str_bin" ]; then run_str=1
elif [ -n "$str_cfg" ] || [ "$str_dep" = 1 ]; then note "Stryker is configured (${str_cfg:-package.json @stryker-mutator}) but node_modules/.bin/stryker is missing (npm install)."
fi
if [ -n "$mm_bin" ] && [ -n "$mm_cfg" ]; then
  mm_major=$(mutmut --version 2>/dev/null | sed -n 's/.*version \([0-9][0-9]*\).*/\1/p' | head -1)
  if [ -n "$mm_major" ] && [ "$mm_major" -ge 3 ]; then run_mm=1
  else note "\`mutmut --version\` printed no 3.x version: mutmut 2, whose output this lens does not read (run \`mutmut run --paths-to-mutate <files>\` yourself), or mutmut 3 that cannot find its sources (set source_paths under [tool.mutmut])."; fi
elif [ -n "$mm_cfg" ]; then note "mutmut is configured ($mm_cfg) but not on PATH (activate the project's virtualenv)."
elif [ -n "$mm_bin" ] && [ "$py_proj" = 1 ]; then note "mutmut is on PATH but this project has no [tool.mutmut] table in pyproject.toml (or [mutmut] in setup.cfg), so it is not run: a mutmut from another environment would guess the sources. Add the table with source_paths."
fi

if [ $((run_inf + run_str + run_mm)) -eq 0 ]; then
  printf 'mutation-lens: no mutation tool to run in %s.\n' "$(pwd)"
  [ -n "$notes" ] && printf '%s' "$notes"
  if [ -z "$notes" ]; then
    printf 'None is configured. The config that would enable one:\n'
    any=0
    [ -f composer.json ] && { any=1; printf '  PHP: infection.json5 plus `composer require --dev infection/infection`\n'; }
    [ -f package.json ] && { any=1; printf '  JS/TS: stryker.config.json plus the @stryker-mutator/core devDependency\n'; }
    [ "$py_proj" = 1 ] && { any=1; printf '  Python: a [tool.mutmut] table in pyproject.toml plus mutmut 3 in the virtualenv\n'; }
    [ "$any" = 1 ] || printf '  PHP: infection.json5 (Infection) · JS/TS: stryker.config.json (Stryker) · Python: [tool.mutmut] in pyproject.toml (mutmut 3)\n'
  fi
  printf 'mutation-lens never installs a tool.\n'
  exit 3
fi

# --- scope: tracked files added or modified vs the base, working tree included (Infection's own semantics) ---
if [ -n "$base" ]; then
  git rev-parse --verify --quiet "$base^{commit}" >/dev/null || usage "--base $base is not a commit"
  base_ref=$base ; base_label=$base
else
  def=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)
  if [ -z "$def" ]; then
    for b in main master; do git rev-parse --verify --quiet "refs/heads/$b" >/dev/null && { def=$b; break; }; done
  fi
  [ -n "$def" ] || usage "cannot find the default branch (no origin/HEAD, main or master); pass --base <ref>"
  base_ref=$(git merge-base HEAD "$def" 2>/dev/null) || usage "HEAD and $def share no commit; pass --base <ref>"
  base_label="merge-base of HEAD and $def ($(git rev-parse --short "$base_ref"))"
fi
changed=$(git -c core.quotePath=false diff --name-only --no-renames --relative --diff-filter=AM "$base_ref" -- . 2>/dev/null)
untracked=$(git ls-files --others --exclude-standard -- . | wc -l | tr -d ' ')

pick() { printf '%s\n' "$changed" | grep -E "$1" | grep -vE "$2" ; }
php_files=$(pick '\.php$' '(^|/)vendor/')
js_files=$(pick '\.(js|jsx|ts|tsx|mjs|cjs|mts|cts|vue|svelte)$' '(^|/)(node_modules|__tests__|__mocks__|tests?|spec|e2e)/|\.(test|spec)\.[^/]+$|\.d\.[cm]?ts$|(^|/)[^/]*\.(config|conf)\.[^/]+$')
py_files=$(pick '\.py$' '(^|/)(tests?|testing)/|(^|/)test_[^/]*\.py$|_test\.py$|(^|/)conftest\.py$')

printf 'mutation-lens: base %s\n' "$base_label"
[ "$untracked" -gt 0 ] && printf 'note: %s untracked file(s) are not in scope (git diff cannot see them; `git add -N <file>` brings one in)\n' "$untracked"
[ -n "$notes" ] && printf '%s' "$notes"

survivors=0 ; failed=0
REPORT="$WORK/report"

tool_failed() { # name rc log
  failed=1
  if [ "$2" = 124 ]; then printf '  FAILED: %s ran past --max-seconds %s and was stopped; no verdict. Raise the cap or narrow the base.\n' "$1" "$maxs"; killed_note
  else printf '  FAILED: %s exited %s with no report to read. Last lines:\n' "$1" "$2"; tail -n 15 "$3" | sed 's/^/    | /'; fi
}

emit_report() { # prints the parsed survivors and counts them
  local n
  n=$(grep -c . "$REPORT" 2>/dev/null); n=${n:-0}
  if [ "$n" -gt 0 ]; then printf '  surviving mutants (%s):\n' "$n"; sed 's/^/    /' "$REPORT"
  else printf '  surviving mutants: none\n'; fi
  survivors=$((survivors + n))
}

# --- Infection: its own --git-diff-filter/--git-diff-base scope; --with-uncovered, since by default it drops untested lines (0.35.9) ---
if [ "$run_inf" = 1 ]; then
  printf '\n== Infection (%s, %s) ==\n' "$inf_bin" "$inf_cfg"
  if [ -z "$php_files" ]; then
    printf '  no changed .php file vs the base: nothing to mutate\n'
  else
    txt="$WORK/infection.txt" ; sj="$WORK/infection-summary.json" ; SCOPE=$php_files
    run_capped "$WORK/infection.log" "$inf_bin" --git-diff-filter=AM --git-diff-base="$base_ref" \
      --logger-text="$txt" --logger-summary-json="$sj" --with-uncovered --no-progress --no-interaction
    rc=$?
    if [ "$rc" != 124 ] && [ -f "$txt" ]; then
      awk -v r1="$(pwd)/" -v r2="$(pwd -P)/" '
        function flush() { if (path != "") { w = (minus != "" || plus != "") ? "`" minus "` → `" plus "`" : "(no diff in the report)"
            if (sec == "uncovered") w = w " — no test covers this line"
            printf "%s:%s — %s — %s\n", path, line, mut, w }
          path = ""; minus = ""; plus = "" }
        function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
        /^Escaped mutants:$/ { flush(); sec = "escaped"; next }
        /^Not Covered mutants:$/ { flush(); sec = "uncovered"; next }
        /^[A-Z][A-Za-z ]* mutants:$/ { flush(); sec = ""; next }
        sec != "" && /^[0-9]+\) .*\[M\] / { flush()
          h = $0; sub(/^[0-9]+\) /, "", h); i = index(h, "[M] ")
          loc = trim(substr(h, 1, i - 1)); mut = substr(h, i + 4); sub(/ \[ID\].*$/, "", mut)
          if (match(loc, /:[0-9]+$/)) { path = substr(loc, 1, RSTART - 1); line = substr(loc, RSTART + 1) } else { path = loc; line = "?" }
          if (index(path, r1) == 1) path = substr(path, length(r1) + 1); else if (index(path, r2) == 1) path = substr(path, length(r2) + 1)
          next }
        path != "" && /^-/ && !/^---/ && minus == "" { minus = trim(substr($0, 2)) }
        path != "" && /^\+/ && !/^\+\+\+/ && plus == "" { plus = trim(substr($0, 2)) }
        END { flush() }' "$txt" > "$REPORT"
      emit_report
      msi=$(grep -o '"msi":[0-9.]*' "$sj" 2>/dev/null | head -1 | cut -d: -f2)
      [ -n "$msi" ] || msi=$(sed -n 's/.*Mutation Score Indicator (MSI): \([0-9.]*\)%.*/\1/p' "$WORK/infection.log" | head -1)
      printf '  score: MSI %s%% (Infection'"'"'s Mutation Score Indicator over the changed files)\n' "${msi:-unknown}"
    elif [ "$rc" = 0 ]; then
      printf '  no mutants in scope: %s\n' "$(sed -n '/\[OK\]/,$p' "$WORK/infection.log" | tr -s ' \n' ' ' | sed 's/^ *\[OK\] *//; s/ *$//')"
    else
      tool_failed Infection "$rc" "$WORK/infection.log"
    fi
  fi
fi

# --- Stryker: --mutate <files> and --reporters clear-text (verified in @stryker-mutator/core 10.1.1 stryker-cli.ts) ---
if [ "$run_str" = 1 ]; then
  printf '\n== Stryker (%s, %s) ==\n' "$str_bin" "${str_cfg:-package.json}"
  if [ -z "$js_files" ]; then
    printf '  no changed JS/TS source file vs the base (tests, configs and .d.ts excluded): nothing to mutate\n'
  else
    list=$(printf '%s\n' "$js_files" | paste -sd, -)
    printf '  mutating: %s\n' "$list"
    SCOPE=$js_files
    run_capped "$WORK/stryker.log" "$str_bin" run --mutate "$list" --reporters clear-text
    rc=$?
    esc=$(printf '\033'); sed "s/${esc}\[[0-9;]*m//g" "$WORK/stryker.log" > "$WORK/stryker.txt" 2>/dev/null
    if [ "$rc" != 124 ] && grep -qE '^[[:space:]]*All files[[:space:]]*\|' "$WORK/stryker.txt"; then
      awk '
        function flush() { if (path != "") { w = "`" minus "` → `" plus "`"; if (st == "NoCoverage") w = w " — no test covers this line"
            printf "%s:%s — %s — %s\n", path, line, mut, w }
          path = ""; minus = ""; plus = ""; inb = 0 }
        function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
        /^\[[^]]*(Survived|NoCoverage)\] / { flush(); st = ($0 ~ /NoCoverage\]/) ? "NoCoverage" : "Survived"
          mut = $0; sub(/^\[[^]]*\] /, "", mut); wantloc = 1; next }
        wantloc { wantloc = 0; if (match($0, /:[0-9]+:[0-9]+$/)) { path = substr($0, 1, RSTART - 1); split(substr($0, RSTART + 1), a, ":"); line = a[1]; inb = 1 }; next }
        inb && /^-   / && minus == "" { minus = trim(substr($0, 5)); next }
        inb && /^\+   / && plus == "" { plus = trim(substr($0, 5)); next }
        inb && /^[[:space:]]*$/ { flush() }
        END { flush() }' "$WORK/stryker.txt" > "$REPORT"
      emit_report
      score=$(awk -F'|' '/^[[:space:]]*All files[[:space:]]*\|/ { s = $2; gsub(/[[:space:]]/, "", s); print s; exit }' "$WORK/stryker.txt")
      printf '  score: %s%% (Stryker'"'"'s mutation score, the "All files" row)\n' "${score:-unknown}"
    else
      tool_failed Stryker "$rc" "$WORK/stryker.txt"
    fi
  fi
fi

# --- mutmut 3: `mutmut run <mutant-name globs>` then `mutmut show <name>` (verified in mutmut 3.8.1 __main__.py) ---
if [ "$run_mm" = 1 ]; then
  printf '\n== mutmut (%s) ==\n' "$mm_cfg"
  if [ -z "$py_files" ]; then
    printf '  no changed Python source file vs the base (tests excluded): nothing to mutate\n'
  else
    # mutmut names a mutant <module>.x_<func>__mutmut_<n>; an __init__.py drops its own segment from the module.
    globs=$(printf '%s\n' "$py_files" | sed -e 's/\.py$//' -e 's#/#.#g' -e 's/^src\.//' | awk '
      /(^|\.)__init__$/ { m = $0; sub(/\.?__init__$/, "", m); print m ".x_*"; print m ".xǁ*"; next } { print $0 ".*" }')
    set -f
    # shellcheck disable=SC2086
    set -- $globs
    set +f
    printf '  mutating: %s\n' "$(printf '%s\n' "$py_files" | paste -sd, -)"
    SCOPE=$py_files
    run_capped "$WORK/mutmut.log" mutmut run "$@"
    rc=$?
    tr '\r' '\n' < "$WORK/mutmut.log" > "$WORK/mutmut.txt"
    if [ "$rc" != 124 ] && grep -q '^Mutant results$' "$WORK/mutmut.txt"; then
      awk '/^Mutant results$/ { getline; on = 1; next } on && /^[[:space:]]*$/ { exit } on { print $1, $2 }' "$WORK/mutmut.txt" > "$WORK/mutmut.results"
      : > "$REPORT"
      while read -r emoji name; do
        case "$emoji" in "🙁") why="" ;; "🫥") why=" — no test covers this line" ;; *) continue ;; esac
        mutmut show "$name" > "$WORK/show.txt" 2>/dev/null
        path=$(sed -n 's/^--- //p' "$WORK/show.txt" | head -1)
        minus=$(grep -E '^-' "$WORK/show.txt" | grep -vE '^---' | head -1 | sed 's/^-//; s/^[[:space:]]*//; s/[[:space:]]*$//')
        plus=$(grep -E '^\+' "$WORK/show.txt" | grep -vE '^\+\+\+' | head -1 | sed 's/^+//; s/^[[:space:]]*//; s/[[:space:]]*$//')
        fn=${name##*.}; fn=${fn%__mutmut_*}; case "$fn" in x_*) fn=${fn#x_} ;; *) fn=${fn##*ǁ} ;; esac
        # mutmut shows a function-relative diff; the file line is the removed text's first match after the def.
        line=$(awk -v fn="$fn" -v want="$minus" '
          function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
          !d && $0 ~ ("^[ \t]*(async[ \t]+)?def[ \t]+" fn "[ \t]*\\(") { d = NR }
          d && trim($0) == want { print NR; exit }
          END { if (d) print d }' "$path" 2>/dev/null | head -1)
        printf '%s:%s — %s — `%s` → `%s`%s\n' "${path:-?}" "${line:-?}" "$name" "$minus" "$plus" "$why" >> "$REPORT"
      done < "$WORK/mutmut.results"
      emit_report
      score=$(awk '{ t++ } $1 == "🎉" { k++ } $1 == "⏰" { k++ } $1 == "🔇" { s++ }
        END { if (t - s > 0) printf "%.1f", 100 * k / (t - s); else print "n/a" }' "$WORK/mutmut.results")
      printf '  score: %s%% (killed + timeout over total − skipped, mutmut'"'"'s own badge formula; %s mutant(s))\n' "$score" "$(grep -c . "$WORK/mutmut.results")"
    elif grep -q 'nothing matches' "$WORK/mutmut.txt"; then
      printf '  no mutants in scope: mutmut generated none in the changed files (outside its source paths?)\n'
    else
      tool_failed mutmut "$rc" "$WORK/mutmut.log"
    fi
  fi
fi

printf '\n'
if [ "$survivors" -gt 0 ]; then
  printf '%s surviving mutant(s). Each is a missing assertion with an address: write the test that fails on that\n' "$survivors"
  printf 'mutant, or say why the mutant is equivalent (no input can tell it apart). Never weaken the mutator config to clear one.\n'
  [ "$failed" = 1 ] && printf 'A tool above FAILED, so its files have no verdict.\n'
  exit 1
fi
if [ "$failed" = 1 ]; then printf 'no verdict: a tool failed (above).\n'; exit 4; fi
printf 'no surviving mutant in the changed files.\n'
exit 0
