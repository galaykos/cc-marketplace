#!/usr/bin/env bash
# verify-teeth-lint.sh — author-time DENYLIST lint for taskmaster Verify lines: blocks known-weak SYNTACTIC forms; a pass means "not obviously toothless", never "proven to have teeth".
# Misses: an empty suite, a vacuous assertion, whether a named test exercises the behavior (runtime gates); a build command such as `mvn package` is blocked under the bare-suite-pass name; ui-static-only's static-command list is a closed heuristic, and legacy **Verify:** cards carry no <file> to check.
# Why, limits, history: rationale/derivations/plugin-taskmaster.md § plugins/taskmaster/scripts/verify-teeth-lint.sh (marketplace repository)

# Blocked weak forms (each -> exit 2, `verify-teeth: <reason>` on stderr, the
# reason names the matched pattern):
#   existence-only  : `test -f/-e/-d`, `[ -f ... ]`, or `ls ` as the whole check
#   always-true     : `|| true`, `; true`, or `|| :` anywhere, incl. when
#                     followed by `;`/`)`/`"` (neuters the exit status)
#   require-only    : `node -e "require(...)"`  with no assertion following
#   import-only     : `python -c "import ..."`  with no assertion following
#   compile-only    : `tsc --noEmit`, `-fsyntax-only`, or `go build` as the whole check
#                     (plus a NOTE when the root tsconfig is `"files": []` + `"references"`: there it checks nothing)
#   migration-run-only : a migration command (artisan migrate / alembic upgrade /
#                     db:migrate / flyway / goose / prisma migrate deploy) whose whole
#                     check is that it ran.
#   bare-suite-pass : a test runner (npm test / pytest / jest / go test / cargo test /
#                     rspec / pest / phpunit / php artisan test / composer test /
#                     ./gradlew / mvn / ./mvnw / dotnet test / sbt test / bazel test /
#                     ctest ...) with NO named test/assertion token (no
#                     -k/-t/--tests/-Dtest=/--filter/named file) AND no trailing
#                     `asserts <x>` / `including <x>` clause.
# Anything else (a line naming a specific new test / assertion / observable)
# passes with exit 0.
#
# Non-blocking WARN (exit stays 0, `verify-teeth: WARN <reason>` on stderr, run record
# verdict `warn`), --card mode only, checked only on a line that cleared every block:
#   ui-static-only  : a <file mode="edit|create"> in the card is a UI component or view
#                     (.tsx/.jsx/.vue/.svelte/.blade.php under a views/, pages/ or
#                     components/ directory, any case; *.test.* / *.spec.* / __tests__/
#                     excluded), and every command segment of the line (split on && || ; |
#                     after quoted strings are dropped) is a type-check, lint, build, grep
#                     or existence command, with no test runner and no browser test.
#                     The message says whether the card has a <walk> line.
#
# CLI:
#   verify-teeth-lint.sh --line "<verify text>"
#   verify-teeth-lint.sh --card <card.md>     # lints the card's <verify> element, or its legacy **Verify:** line
# Exit codes:
#   0  teeth OK (no known-weak form matched)
#   2  weak form matched (reason on stderr)
#   3  usage error (Honest limitation law: .claude/skills/authoring-skills/SKILL.md (in the marketplace repository) "The four laws".)
set -euo pipefail

# Run record (card-lint-record.sh), written on every outcome: the lint ran and what it said, never that the card is good.
_cardlint_target=""
. "$(dirname "$0")/card-lint-record.sh" 2>/dev/null || true
record_run() { # $1 = verdict. No-op in --line mode: no file to key the record on.
  [ -n "$_cardlint_target" ] || return 0
  command -v cardlint_write >/dev/null 2>&1 || return 0
  cardlint_write verify-teeth "$_cardlint_target" "$1"
}

die_usage() {
  printf 'verify-teeth: usage error: %s\n' "$1" >&2
  exit 3
}

weak() {
  record_run block
  printf 'verify-teeth: %s\n' "$1" >&2
  exit 2
}

mode=""
value=""
while [ $# -gt 0 ]; do
  case "$1" in
    --line)
      [ $# -ge 2 ] || die_usage "--line needs an argument"
      mode="line"; value="$2"; shift 2 ;;
    --card)
      [ $# -ge 2 ] || die_usage "--card needs an argument"
      mode="card"; value="$2"; shift 2 ;;
    -h|--help)
      grep -E '^#' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *)
      die_usage "unknown argument: $1" ;;
  esac
done

[ -n "$mode" ] || die_usage "need --line \"<verify text>\" or --card <file>"

if [ "$mode" = "card" ]; then
  [ -f "$value" ] || die_usage "card file not found: $value"
  _cardlint_target="$value"
  # The tagged <verify>…</verify> element first (a card carrying both is linted on it), else the legacy **Verify:** label.
  raw=$(grep -E -m1 '<verify>.*</verify>' "$value" 2>/dev/null || true)
  if [ -n "$raw" ]; then
    line=$(printf '%s' "$raw" | sed -e 's/.*<verify>//' -e 's/<\/verify>.*//')
  else
    raw=$(grep -E -m1 '\*\*Verify:\*\*' "$value" 2>/dev/null || true)
    [ -n "$raw" ] || die_usage "no <verify> element or **Verify:** line in card: $value"
    line=${raw#*\*\*Verify:\*\*}
  fi
else
  line="$value"
fi

# Normalize: trim, then strip one surrounding layer of backticks, then trim again.
line=$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
line=$(printf '%s' "$line" | sed -e 's/^`//' -e 's/`$//')
line=$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

[ -n "$line" ] || die_usage "empty Verify line"

# has <extended-regex> : case-insensitive substring/regex test against $line.
has() { printf '%s' "$line" | grep -Eiq -- "$1"; }

# A closed jest-matcher list, not `\.to[a-z]+`: the wildcard matched `.toString` and passed a bare `require(...).toString()`.
assert_re='assert|expect|throw|===|!==|\.to(Be|Equal|Contain|Match|Throw|Have|Strict|Return|Close|Greater|Less|Instance|Satisfy)|console\.assert|process\.exit|exit\([1-9]|==[[:space:]]*[0-9]|!=[[:space:]]|-eq[[:space:]]|[[:space:]]status[[:space:]]'
strong_guard='&&|\|[[:space:]]*grep|\|[[:space:]]*wc|assert|expect'

# 1) always-true — the trailing boundary is any non-word char, so `cmd || true;`, `(cmd || true)` or `"npm test || true"` cannot slip past.
if has '(\|\|[[:space:]]*(true|:)|;[[:space:]]*(true|:))([^[:alnum:]_]|$)'; then
  weak "always-true: '|| true' / '; true' / '|| :' neuters the exit status"
fi

# 2) existence-only — `test -f/-e/-d`, `[ -f ]` or `ls` as the whole check, unless a real assertion (&&/grep) follows.
if has '^[[:space:]]*(test[[:space:]]+-[fed][[:space:]]|\[[[:space:]]+-[fed][[:space:]]|ls([[:space:]]|$))' \
   && ! has "$strong_guard"; then
  weak "existence-only: test -f/-e/-d, [ -f ], or ls proves a path exists, not that behavior works"
fi

# 3a) project-references NOTE, never a block (a guess from the current directory's tsconfig.json); before 3) so a compile-only line says why it is worse.
if has 'tsc[^|;&]*--noemit' && [ -f tsconfig.json ] \
   && grep -Eq '"files"[[:space:]]*:[[:space:]]*\[[[:space:]]*\]' tsconfig.json \
   && grep -Eq '"references"[[:space:]]*:' tsconfig.json; then
  printf 'verify-teeth: NOTE project-references root here (files: [] + references): `tsc --noEmit` type-checks NOTHING and exits 0 — use `tsc -b`\n' >&2
fi

# 3) compile-only — compiles/type-checks, as the whole check.
if has '(tsc[^|;&]*--noemit|-fsyntax-only|^[[:space:]]*go[[:space:]]+build([[:space:]]|$))' \
   && ! has "$strong_guard"; then
  weak "compile-only: compiles/type-checks but runs no assertion (on a files:[] + references root, nothing at all)"
fi

# 4) require-only / import-only — a bare load with nothing asserted.
if has 'node[[:space:]]+-e' && has 'require[[:space:]]*\(' && ! has "$assert_re"; then
  weak "require-only: require() loads a module but asserts nothing about behavior"
fi
if has 'python[0-9]?[[:space:]]+-c' && has '(^|[^._a-z])import[[:space:]]' && ! has "$assert_re"; then
  weak "import-only: import succeeds but asserts nothing about behavior"
fi

# 5) bare-suite-pass — a test runner with no named test and no assertion clause.
runner_re='npm[[:space:]]+(run[[:space:]]+)?test|yarn[[:space:]]+test|pnpm[[:space:]]+(run[[:space:]]+)?test|(^|[^a-z])pytest|(^|[^a-z])jest|(^|[^a-z])vitest|(^|[^a-z])mocha|go[[:space:]]+test|rspec|cargo[[:space:]]+test|(^|[^a-z])mvnw?([[:space:]]|$)|(^|[^a-z])gradlew?([[:space:]]|$)|dotnet[[:space:]]+test|sbt[[:space:]]+test|bazel[[:space:]]+test|(^|[^a-z])ctest([[:space:]]|$)|php[[:space:]]+artisan[[:space:]]+test|(^|[^a-z])pest|(^|[^a-z])phpunit|composer[[:space:]]+test'
named_re='-k[[:space:]]|-t[[:space:]]|-g[[:space:]]|--grep|--tests[[:space:]=]|-dtest=|--filter[[:space:]=]|-run[[:space:]]|-run=|::[a-z_]|_test\.|\.test\.|\.spec\.|test_[a-z]|-e[[:space:]]+["'\'']?[a-z]'
clause_re='assert|including|expects?[[:space:]]|verif(y|ies|ying)|observ'
if has "$runner_re" && ! has "$named_re" && ! has "$clause_re"; then
  weak "bare-suite-pass: test runner with no named test (-k/-t/--tests/-Dtest=/file) or asserts/including clause"
fi

# 6) migration-run-only — its own reason, since bare-suite-pass would misname a migration runner.
migrate_re='artisan[[:space:]]+migrate|alembic[[:space:]]+upgrade|db:migrate|migrate[[:space:]]+up|goose[[:space:]]+up|flyway[[:space:]]+migrate|knex[[:space:]]+migrate|prisma[[:space:]]+migrate[[:space:]]+deploy'
if has "$migrate_re" && ! has "$named_re" && ! has "$clause_re"; then
  weak "migration-run-only: migration command with no assertion about the resulting schema or data"
fi

# 7) ui-static-only — WARN, never a block: the lint cannot know whether the repo has a JS or browser test runner.
if [ "$mode" = "card" ]; then
  ui_path_re='(^|/)(views|pages|components)/(.*/)?[^/]+\.(tsx|jsx|vue|svelte|blade\.php)$'
  ui_file=$(grep -E '^[[:space:]]*<file[[:space:]].*mode="(edit|create)"' "$value" 2>/dev/null \
    | grep -Eo 'path="[^"]*"' | sed -e 's/^path="//' -e 's/"$//' \
    | grep -Eiv '(\.test|\.spec)\.|(^|/)__tests__/' | grep -Ei -- "$ui_path_re" | head -1 || true)
  browser_re='playwright|cypress|artisan[[:space:]]+dusk|webdriverio|(^|[^a-z])wdio|testcafe|nightwatch|test-storybook|--browser'
  if [ -n "$ui_file" ] && ! has "$runner_re" && ! has "$browser_re"; then
    static_head='^(cd|grep|egrep|rg|wc|test|\[|ls|cat|head|tail|echo|stat|find|diff|tsc|vue-tsc|svelte-check|eslint|biome|oxlint|stylelint|prettier|phpstan|psalm|pint|php-cs-fixer|rector)([[:space:]]|$)'
    static_framework='^(npx[[:space:]]+)?(vite|next|nuxt|nuxi|astro)[[:space:]]+(build|lint|typecheck|check)([[:space:]]|$)'
    static_script='^(npx|bunx|pnpm([[:space:]]+(exec|dlx|run))?|yarn([[:space:]]+run)?|npm[[:space:]]+run(-script)?|bun[[:space:]]+(run|x)|composer([[:space:]]+(run|run-script|exec))?|(\./)?vendor/bin/|(\./)?node_modules/\.bin/)[[:space:]]*[a-z0-9:_./-]*(type|lint|check|build|format|tsc|stan|psalm|pint|prettier|eslint|biome)[a-z0-9:_./-]*([[:space:]]|$)'
    all_static=1; segs=0
    while IFS= read -r seg; do
      seg=$(printf '%s' "$seg" | sed -e 's/^[[:space:](]*//' -e 's/[[:space:])]*$//')
      [ -n "$seg" ] || continue
      segs=$((segs + 1))
      printf '%s' "$seg" | grep -Eiq -- "$static_head|$static_framework|$static_script" || { all_static=0; break; }
    done < <(printf '%s' "$line" | sed -e "s/'[^']*'//g" -e 's/"[^"]*"//g' | awk '{ gsub(/&&|\|\||;|\|/, "\n"); print }')
    if [ "$all_static" = 1 ] && [ "$segs" -gt 0 ]; then
      walk_note="the card's <walk> line is the only look at it"
      grep -Eq '<walk([[:space:]>]|$)' "$value" 2>/dev/null || walk_note="add a <walk> line (surface, 1280/375, state) — this card has none"
      printf 'verify-teeth: WARN ui-static-only: %s is UI and this verify is type-check/lint/build/grep only — it proves the markup exists, not that it renders or behaves. Name a component or browser test if the repo has a runner; otherwise %s\n' "$ui_file" "$walk_note" >&2
      record_run warn
      exit 0
    fi
  fi
fi

# No known-weak form matched: the line names something specific enough to pass.
record_run pass
exit 0
