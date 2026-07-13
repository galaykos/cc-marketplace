#!/usr/bin/env bash
# Tests scripts/lib/template-engine.sh: substitution, missing-key hard error, block
# include (+ variable inside a block), conditional true/false, block-not-found error,
# byte-exact output, and determinism (double render diff). Local harness; run anywhere.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/template-engine.sh
source "$SCRIPT_DIR/../lib/template-engine.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/blocks"
rc=0
pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n    %s\n' "$1" "${2:-}"; rc=1; }

assert_eq() { # desc expected actual
  if [[ "$2" == "$3" ]]; then pass "$1"; else fail "$1" "exp=[$2] got=[$3]"; fi
}

# 1. plain substitution
printf 'Hello {{name}}!' > "$WORK/sub.tmpl"
assert_eq "substitution" "Hello World!" "$(render_template "$WORK/sub.tmpl" '{"name":"World"}')"

# 2. missing key = hard error naming key + template
if err=$(render_template "$WORK/sub.tmpl" '{}' 2>&1 >/dev/null); then
  fail "missing-key errors" "exit was 0"
elif [[ "$err" == *"missing key name"* && "$err" == *"sub.tmpl"* ]]; then
  pass "missing-key errors (names key + template)"
else
  fail "missing-key errors (names key + template)" "stderr=[$err]"
fi

# 3. block include + variable inside the included block
printf 'Hi {{who}}' > "$WORK/blocks/greeting.md"
printf '{{> greeting}}!' > "$WORK/inc.tmpl"
assert_eq "block include + var-in-block" "Hi Sam!" \
  "$(render_template "$WORK/inc.tmpl" '{"who":"Sam"}')"

# 4. conditional true keeps body
printf 'A{{#if flag}}B{{/if}}C' > "$WORK/cond.tmpl"
assert_eq "conditional true keeps body" "ABC" \
  "$(render_template "$WORK/cond.tmpl" '{"flag":true}')"

# 5. conditional false drops body
assert_eq "conditional false drops body" "AC" \
  "$(render_template "$WORK/cond.tmpl" '{"flag":false}')"

# 5b. conditional falsy on empty string / missing key
assert_eq "conditional empty-string is falsy" "AC" \
  "$(render_template "$WORK/cond.tmpl" '{"flag":""}')"
assert_eq "conditional missing-key is falsy" "AC" \
  "$(render_template "$WORK/cond.tmpl" '{}')"

# 6. block-not-found = hard error naming block + template
printf '{{> nope}}' > "$WORK/badinc.tmpl"
if err=$(render_template "$WORK/badinc.tmpl" '{}' 2>&1 >/dev/null); then
  fail "block-not-found errors" "exit was 0"
elif [[ "$err" == *"block nope not found"* && "$err" == *"badinc.tmpl"* ]]; then
  pass "block-not-found errors (names block + template)"
else
  fail "block-not-found errors" "stderr=[$err]"
fi

# 7. byte-exact output incl. trailing newline preserved (diff, not $() compare)
printf 'top\n{{> greeting}}\n{{#if flag}}kept {{name}}{{/if}}\nend\n' > "$WORK/full.tmpl"
printf 'top\nHi Sam\nkept World\nend\n' > "$WORK/full.golden"
render_template "$WORK/full.tmpl" '{"who":"Sam","flag":true,"name":"World"}' > "$WORK/full.out" 2>/dev/null
if diff -u "$WORK/full.golden" "$WORK/full.out" >/dev/null; then
  pass "byte-exact output (trailing newline preserved)"
else
  fail "byte-exact output" "$(diff -u "$WORK/full.golden" "$WORK/full.out")"
fi

# 8. determinism: two renders of the same inputs are byte-identical
render_template "$WORK/full.tmpl" '{"who":"Sam","flag":true,"name":"World"}' > "$WORK/d1" 2>/dev/null
render_template "$WORK/full.tmpl" '{"who":"Sam","flag":true,"name":"World"}' > "$WORK/d2" 2>/dev/null
if diff "$WORK/d1" "$WORK/d2" >/dev/null; then
  pass "determinism (double render byte-identical)"
else
  fail "determinism" "$(diff -u "$WORK/d1" "$WORK/d2")"
fi

if [[ $rc -eq 0 ]]; then printf '\nAll template-engine asserts passed.\n'; else printf '\nSome asserts FAILED.\n'; fi
exit $rc
