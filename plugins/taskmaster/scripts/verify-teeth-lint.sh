#!/usr/bin/env bash
# verify-teeth-lint.sh — author-time DENYLIST lint for taskmaster Verify lines.
#
# LIMITATION (this is a DENYLIST, not a completeness guarantee):
#   This lint blocks only KNOWN-WEAK *SYNTACTIC* forms of a Verify line. It does
#   NOT — and cannot — detect an empty test suite, a tautological/vacuous
#   assertion, or whether a named test actually exercises the target behavior.
#   Those are RUNTIME gates (B1 empty-suite / B3b semantic teeth) enforced
#   elsewhere. A line that PASSES this lint is only "not obviously toothless",
#   never "proven to have teeth".
#
# Blocked weak forms (each -> exit 2, `verify-teeth: <reason>` on stderr, the
# reason names the matched pattern):
#   existence-only  : `test -f`, `test -e`, or `ls ` as the whole check
#   always-true     : `|| true`, `; true`, or `|| :` anywhere, incl. when
#                     followed by `;`/`)`/`"` (neuters the exit status)
#   require-only    : `node -e "require(...)"`  with no assertion following
#   import-only     : `python -c "import ..."`  with no assertion following
#   compile-only    : `tsc --noEmit`, `-fsyntax-only`, or `go build` as the whole check
#   bare-suite-pass : a test runner (npm test / pytest / jest / go test ...) with
#                     NO named test/assertion token (no -k/-t/named file) AND no
#                     trailing `asserts <x>` / `including <x>` clause
# Anything else (a line naming a specific new test / assertion / observable)
# passes with exit 0.
#
# CLI:
#   verify-teeth-lint.sh --line "<verify text>"
#   verify-teeth-lint.sh --card <card.md>     # lints the file's **Verify:** line
# Exit codes:
#   0  teeth OK (no known-weak form matched)
#   2  weak form matched (reason on stderr)
#   3  usage error
set -euo pipefail

die_usage() {
  printf 'verify-teeth: usage error: %s\n' "$1" >&2
  exit 3
}

weak() {
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
  raw=$(grep -E -m1 '\*\*Verify:\*\*' "$value" 2>/dev/null || true)
  [ -n "$raw" ] || die_usage "no **Verify:** line in card: $value"
  line=${raw#*\*\*Verify:\*\*}
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

assert_re='assert|expect|throw|===|!==|\.to[a-z]+|console\.assert|process\.exit|exit\([1-9]|==[[:space:]]*[0-9]|!=[[:space:]]|-eq[[:space:]]|[[:space:]]status[[:space:]]'
strong_guard='&&|\|[[:space:]]*grep|\|[[:space:]]*wc|assert|expect'

# 1) always-true — an unconditional pass neuters whatever precedes it. The
#    trailing boundary is ANY non-word char (or end), so a following `;`, `)`,
#    or closing quote cannot smuggle it past the lint
#    (`cmd || true;`, `(cmd || true)`, `bash -c "npm test || true"`). Both the
#    `true` command and the `:` no-op builtin count as an always-true tail.
if has '(\|\|[[:space:]]*(true|:)|;[[:space:]]*(true|:))([^[:alnum:]_]|$)'; then
  weak "always-true: '|| true' / '; true' / '|| :' neuters the exit status"
fi

# 2) existence-only — proves a path exists, as the whole check.
if has '^[[:space:]]*(test[[:space:]]+-[fe][[:space:]]|ls([[:space:]]|$))' \
   && ! has "$strong_guard"; then
  weak "existence-only: test -f/-e/ls proves a path exists, not that behavior works"
fi

# 3) compile-only — compiles/type-checks, as the whole check.
if has '(tsc[^|;&]*--noemit|-fsyntax-only|^[[:space:]]*go[[:space:]]+build([[:space:]]|$))' \
   && ! has "$strong_guard"; then
  weak "compile-only: compiles/type-checks but runs no assertion"
fi

# 4) require-only / import-only — a bare load with nothing asserted.
if has 'node[[:space:]]+-e' && has 'require[[:space:]]*\(' && ! has "$assert_re"; then
  weak "require-only: require() loads a module but asserts nothing about behavior"
fi
if has 'python[0-9]?[[:space:]]+-c' && has '(^|[^._a-z])import[[:space:]]' && ! has "$assert_re"; then
  weak "import-only: import succeeds but asserts nothing about behavior"
fi

# 5) bare-suite-pass — a test runner with no named test and no assertion clause.
runner_re='npm[[:space:]]+(run[[:space:]]+)?test|yarn[[:space:]]+test|pnpm[[:space:]]+(run[[:space:]]+)?test|(^|[^a-z])pytest|(^|[^a-z])jest|(^|[^a-z])vitest|(^|[^a-z])mocha|go[[:space:]]+test|rspec|cargo[[:space:]]+test|mvn[[:space:]]+test|gradle[[:space:]]+test'
named_re='-k[[:space:]]|-t[[:space:]]|-g[[:space:]]|--grep|-run[[:space:]]|-run=|::[a-z_]|_test\.|\.test\.|\.spec\.|test_[a-z]|-e[[:space:]]+["'\'']?[a-z]'
clause_re='assert|including|expects?[[:space:]]|verif(y|ies|ying)|observ'
if has "$runner_re" && ! has "$named_re" && ! has "$clause_re"; then
  weak "bare-suite-pass: test runner with no named test (-k/-t/file) or asserts/including clause"
fi

# No known-weak form matched: the line names something specific enough to pass.
exit 0
