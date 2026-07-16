#!/usr/bin/env bash
# Tests for negative-control.sh (B3b isolated red-before-green).
#
# SAFETY: every fixture is built under a mktemp -d workspace; negative-control.sh
# is always invoked with CWD set to a fixture dir, so it only ever copies+mutates
# a throwaway temp - never the live repo. Each fixture case snapshots
# `git status --porcelain` (from the repo root) before and after and asserts it is
# byte-identical, proving the control left the caller's tree untouched.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
NC="$here/../negative-control.sh"
repo_root=$(cd "$here" && git rev-parse --show-toplevel)

[ -x "$NC" ] || { printf 'FAIL: negative-control.sh not executable at %s\n' "$NC"; exit 1; }

WS=$(mktemp -d)
trap 'rm -rf "$WS"' EXIT

pass=0; fail=0
git_snap() { ( cd "$repo_root" && git status --porcelain ); }

# ---- real fixture harness: assert exit code AND live-tree-untouched ----
case_run() {
  local desc="$1" wd="$2" exp="$3"; shift 3
  local before after out rc ok reason
  before=$(git_snap)
  set +e
  out=$( cd "$wd" && "$NC" "$@" 2>&1 )
  rc=$?
  set -e
  after=$(git_snap)
  ok=1; reason=""
  [ "$rc" = "$exp" ] || { ok=0; reason="rc=$rc want=$exp"; }
  if [ "$before" != "$after" ]; then ok=0; reason="$reason; git-status CHANGED (live tree mutated!)"; fi
  if [ "$ok" = 1 ]; then
    printf 'PASS: %s (rc=%s, tree-untouched)\n' "$desc" "$rc"; pass=$((pass+1))
  else
    printf 'FAIL: %s (%s)\n' "$desc" "$reason"
    printf '%s\n' "$out" | tail -8 | sed 's/^/  | /'
    fail=$((fail+1))
  fi
}

# ---- classifier-signature harness: deterministic, no runtime needed ----
case_classify() {
  local desc="$1" exp="$2" blob="$3"
  local before after got treeok
  before=$(git_snap)
  got=$(printf '%s' "$blob" | "$NC" --classify-stdin)
  after=$(git_snap)
  treeok=yes; [ "$before" = "$after" ] || treeok=no
  if [ "$got" = "$exp" ] && [ "$treeok" = yes ]; then
    printf 'PASS: classify %s -> %s (tree-untouched)\n' "$desc" "$got"; pass=$((pass+1))
  else
    printf 'FAIL: classify %s -> got=%s want=%s tree-untouched=%s\n' "$desc" "$got" "$exp" "$treeok"
    fail=$((fail+1))
  fi
}

# ===================== node fixtures (always available) =====================

# --- vacuous: the test never checks the feature, so the mutation is undetected ---
V="$WS/vacuous"; mkdir -p "$V"
cat > "$V/impl.js" <<'JS'
function feature() { return 42; }
module.exports = { feature };
JS
cat > "$V/smoke.test.js" <<'JS'
const test = require('node:test');
const assert = require('node:assert');
require('./impl.js');            // feature loads but is never asserted against
test('smoke', () => { assert.ok(true); });
JS
case_run "vacuous: mutation undetected -> green in both states" "$V" 2 \
  --verify 'node --test smoke.test.js' --target impl.js --mutate 's/return 42/return 0/'

# --- discriminating: a real assertion that the mutation breaks ---
D="$WS/disc"; mkdir -p "$D"
cat > "$D/impl.js" <<'JS'
function add(a, b) { return a + b; }
module.exports = { add };
JS
cat > "$D/add.test.js" <<'JS'
const test = require('node:test');
const assert = require('node:assert');
const { add } = require('./impl.js');
test('add', () => { assert.strictEqual(add(2, 3), 5); });
JS
case_run "discriminating: assertion-red on mutated, green on unmutated" "$D" 0 \
  --verify 'node --test add.test.js' --target impl.js --mutate 's/a + b/a - b/'

# --- invalid-control: mutation breaks syntax -> build red (not an assertion) ---
case_run "invalid-control: mutation -> SyntaxError build red" "$D" 4 \
  --verify 'node --test add.test.js' --target impl.js --mutate 's/return a + b;/return a + b);/'

# --- discriminating via --auto: auto picks a feature-disabling edit ---
A="$WS/auto"; mkdir -p "$A"
cat > "$A/impl.js" <<'JS'
function flag() { return true; }
module.exports = { flag };
JS
cat > "$A/flag.test.js" <<'JS'
const test = require('node:test');
const assert = require('node:assert');
const { flag } = require('./impl.js');
test('flag', () => { assert.strictEqual(flag(), true); });
JS
case_run "auto: chosen edit disables feature -> assertion red" "$A" 0 \
  --verify 'node --test flag.test.js' --target impl.js --auto

# ===================== regression: classifier precedence (Fix 1 + Fix 2) =====================

# --- Fix 1: an ASSERTION whose failure message merely CONTAINS "SyntaxError"
#     must classify as assertion (exit 0), NOT be swallowed as a build red (exit 4). ---
F1="$WS/assert_mentions_build"; mkdir -p "$F1"
cat > "$F1/impl.js" <<'JS'
function errorLabel() { return 'SyntaxError'; }
module.exports = { errorLabel };
JS
cat > "$F1/label.test.js" <<'JS'
const test = require('node:test');
const assert = require('node:assert');
const { errorLabel } = require('./impl.js');
test('errorLabel is SyntaxError', () => {
  assert.strictEqual(errorLabel(), 'SyntaxError');
});
JS
case_run "Fix1: assertion message mentions SyntaxError -> exit 0 (not 4)" "$F1" 0 \
  --verify 'node --test label.test.js' --target impl.js --mutate 's/SyntaxError/OTHERWORD/'

# --- Fix 2: a discriminating red whose runner emits TAP `not ok` (outside the
#     build/collection allowlist) is a VALID control (exit 0), not parked (exit 4). ---
F2="$WS/tap_red"; mkdir -p "$F2"
cat > "$F2/impl.sh" <<'SH'
answer() { echo 42; }
SH
case_run "Fix2: TAP not-ok discriminating red -> exit 0 (not 4)" "$F2" 0 \
  --verify 'source ./impl.sh; if [ "$(answer)" = 42 ]; then echo "ok 1 - answer"; else echo "not ok 1 - answer $(answer)"; exit 1; fi' \
  --target impl.sh --mutate 's/echo 42/echo 7/'

# --- Fix 2: a plain `exit 1` with a diff and no recognized marker (-> unknown)
#     is still a valid discriminating red (exit 0), not parked (exit 4). ---
F3="$WS/plain_red"; mkdir -p "$F3"
cat > "$F3/impl.sh" <<'SH'
greet() { echo hello; }
SH
case_run "Fix2: plain exit-1 diff (unknown) discriminating red -> exit 0 (not 4)" "$F3" 0 \
  --verify 'source ./impl.sh; got=$(greet); [ "$got" = hello ] || { printf "want hello got %s\n" "$got"; exit 1; }' \
  --target impl.sh --mutate 's/echo hello/echo goodbye/'

# ===================== halt / usage guards =====================

# --- no-op mutation is not a control -> exit 5 ---
case_run "no-op mutation (sed matches nothing) -> halt 5" "$D" 5 \
  --verify 'node --test add.test.js' --target impl.js --mutate 's/__ABSENT_TOKEN__/x/'

# --- baseline that is not green on the unmutated copy -> exit 5 ---
B="$WS/badbase"; mkdir -p "$B"
cat > "$B/impl.js" <<'JS'
function add(a, b) { return a + b; }
module.exports = { add };
JS
cat > "$B/bad.test.js" <<'JS'
const test = require('node:test');
const assert = require('node:assert');
const { add } = require('./impl.js');
test('bad', () => { assert.strictEqual(add(1, 1), 999); }); // fails even unmutated
JS
case_run "baseline not green on unmutated copy -> halt 5" "$B" 5 \
  --verify 'node --test bad.test.js' --target impl.js --mutate 's/a + b/a - b/'

# --- usage: required flag missing -> exit 3 ---
before=$(git_snap)
set +e; ( "$NC" --verify 'true' ) >/dev/null 2>&1; rc=$?; set -e
after=$(git_snap)
if [ "$rc" = 3 ] && [ "$before" = "$after" ]; then
  printf 'PASS: usage: missing --target -> rc=3 (tree-untouched)\n'; pass=$((pass+1))
else
  printf 'FAIL: usage missing --target (rc=%s want=3)\n' "$rc"; fail=$((fail+1))
fi

# ===================== pytest fixtures (if available) =====================
if command -v pytest >/dev/null 2>&1; then
  P="$WS/py"; mkdir -p "$P"
  cat > "$P/impl.py" <<'PY'
def add(a, b):
    return a + b
PY
  cat > "$P/test_add.py" <<'PY'
from impl import add
def test_add():
    assert add(1, 1) == 2
PY
  case_run "pytest discriminating: assertion red" "$P" 0 \
    --verify 'pytest -q test_add.py' --target impl.py --mutate 's/a + b/a - b/'
  case_run "pytest invalid-control: mutation -> collection error" "$P" 4 \
    --verify 'pytest -q test_add.py' --target impl.py --mutate 's/def add(a, b):/def add(a, b)/'
else
  printf 'SKIP: pytest unavailable - pytest collection classification covered by stub cases\n'
fi

# ===================== classifier signature stubs (deterministic) =====================
# Exercises the {assertion|build|collection} classifier across node/pytest/jest/go
# using canned stderr signatures, so the classifier is proven even where a runtime
# is absent.

case_classify "node assertion" assertion \
'✖ add
  AssertionError [ERR_ASSERTION]: Expected values to be strictly equal:
  -1 !== 5
    code: '"'"'ERR_ASSERTION'"'"','

case_classify "node syntax" build \
'add.test.js:1
foo(() => { ; ) }
        ^
SyntaxError: Unexpected token '"'"')'"'"''

case_classify "node missing-module" collection \
"Error: Cannot find module './impl.js'
  code: 'MODULE_NOT_FOUND',"

case_classify "pytest assertion" assertion \
'>       assert add(1,1) == 2
E       assert 0 == 2
test_a.py:3: AssertionError
FAILED test_a.py::test_add - assert 0 == 2'

case_classify "pytest collection" collection \
'==================================== ERRORS ====================================
__________________________ ERROR collecting test_a.py __________________________
E   SyntaxError: expected '"'"':'"'"'
!!!!!!!!! Interrupted: 1 error during collection !!!!!!!!!'

case_classify "pytest import" collection \
"ImportError while importing test module 'test_a.py'.
ModuleNotFoundError: No module named 'impl'"

case_classify "go build-failed" build \
'# example/pkg
./impl.go:5:10: undefined: helper
FAIL	example/pkg [build failed]'

case_classify "go test-fail" assertion \
'--- FAIL: TestAdd (0.00s)
    impl_test.go:10: add(2,3)=4, want 5
FAIL
exit status 1'

case_classify "jest assertion" assertion \
'  ● adds
    expect(received).toBe(expected)
    Expected: 5
    Received: -1'

# --- Fix 1: an assertion whose message merely CONTAINS "SyntaxError" must
#     classify as assertion, not build (the build substring must not win). ---
case_classify "assertion message mentions SyntaxError -> assertion" assertion \
'✖ errorLabel is SyntaxError
  AssertionError [ERR_ASSERTION]: Expected values to be strictly equal:
  '"'"'OTHERWORD'"'"' !== '"'"'SyntaxError'"'"''

# --- Fix 1: TAP `not ok` is a hard assertion marker. ---
case_classify "TAP not-ok -> assertion" assertion \
'TAP version 13
1..1
not ok 1 - answer should be 42
  ---
  operator: equal'

# --- Fix 1: a bare per-test fail glyph, no build/collection signature -> assertion. ---
case_classify "bare fail glyph -> assertion" assertion \
'✗ widget renders the header
    rendered output differs from the golden file'

printf -- '---- %s passed, %s failed ----\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
