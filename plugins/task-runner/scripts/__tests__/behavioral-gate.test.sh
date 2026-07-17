#!/usr/bin/env bash
# Tests behavioral-gate.sh (B1: classify + own-tests + empty-detect + zero-check).
#
# Asserts the FIVE acceptance outcomes across BOTH node --test and pytest:
#   1. empty-suite      (node describe-with-no-it  AND pytest file w/ no test_ fn) -> 2
#   2. proper-suite     (node & pytest, >=1 real assertion)                        -> 0
#   3. docs-only        (no runner resolvable)                                     -> 0 no-executable-surface
#   4. no-behavioral    (runner resolves, no test file at all; node & pytest)      -> 2
#   5. fail-closed      (package.json script emits no parseable test count)        -> 2
#
# SAFETY: every fixture is built under a mktemp -d workspace and the gate is always
# invoked with CWD set to a throwaway fixture dir — it only ever runs tests inside
# disposable temp trees, never the live repo. Each case snapshots
# `git status --porcelain` (from the repo root) before/after and asserts it is
# byte-identical, proving the gate left the caller's tree untouched.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
BG="$here/../behavioral-gate.sh"
repo_root=$(cd "$here" && git rev-parse --show-toplevel)

[ -x "$BG" ] || { printf 'FAIL: behavioral-gate.sh not executable at %s\n' "$BG"; exit 1; }
command -v node >/dev/null 2>&1 || { printf 'FAIL: node is required to run these tests\n'; exit 1; }

WS=$(mktemp -d)
trap 'rm -rf "$WS"' EXIT
pass=0; fail=0

git_snap() { ( cd "$repo_root" && git status --porcelain ); }

# ---- pytest: use the real binary if present, else a deterministic collection
# stub (card: "if pytest absent, use a stub emitting pytest's exit 5"). The stub
# mimics pytest collection: exit 5 when no `def test_` exists, else exit 0.
PYBIN="$WS/bin"; mkdir -p "$PYBIN"
if command -v pytest >/dev/null 2>&1; then
  PYTEST_MODE="real"
else
  PYTEST_MODE="stub"
  cat > "$PYBIN/pytest" <<'STUB'
#!/usr/bin/env bash
if grep -rEq --include='test_*.py' --include='*_test.py' '^[[:space:]]*def[[:space:]]+test_' . 2>/dev/null; then
  echo "1 passed (stub)"; exit 0
else
  echo "no tests ran (stub)"; exit 5
fi
STUB
  chmod +x "$PYBIN/pytest"
fi
export PATH="$PYBIN:$PATH"
printf 'pytest mode: %s\n' "$PYTEST_MODE"

# ---- go: a deterministic `go` stub so verdict_go's multi-package and build-failed
# branches are reproducible with no real toolchain. Invoked as `go test ./...`, it
# prints the fixture's ./.gostub.out and exits ./.gostub.rc (both in the gate's CWD).
GOBIN="$WS/gobin"; mkdir -p "$GOBIN"
cat > "$GOBIN/go" <<'STUB'
#!/usr/bin/env bash
[ -f ./.gostub.out ] && cat ./.gostub.out
if [ -f ./.gostub.rc ]; then exit "$(cat ./.gostub.rc)"; fi
exit 0
STUB
chmod +x "$GOBIN/go"
export PATH="$GOBIN:$PATH"

# ---- case harness: exit code + optional stderr label + live-tree-untouched ----
# usage: case_run <desc> <workdir> <expected_rc> [--label <substr>] -- <gate args...>
case_run() {
  local desc="$1" wd="$2" exp="$3"; shift 3
  local want_label=""
  if [ "${1:-}" = "--label" ]; then want_label="$2"; shift 2; fi
  [ "${1:-}" = "--" ] && shift
  local before after out rc ok reason
  before=$(git_snap)
  set +e
  out=$( cd "$wd" && "$BG" "$@" 2>&1 )
  rc=$?
  set -e
  after=$(git_snap)
  ok=1; reason=""
  [ "$rc" = "$exp" ] || { ok=0; reason="rc=$rc want=$exp"; }
  if [ -n "$want_label" ] && ! printf '%s\n' "$out" | grep -q "$want_label"; then
    ok=0; reason="${reason:+$reason; }missing verdict label '$want_label'"
  fi
  if [ "$before" != "$after" ]; then
    ok=0; reason="${reason:+$reason; }git-status CHANGED (live tree mutated!)"
  fi
  if [ "$ok" = 1 ]; then
    printf 'PASS: %s (rc=%s, tree-untouched)\n' "$desc" "$rc"; pass=$((pass+1))
  else
    printf 'FAIL: %s (%s)\n' "$desc" "$reason"; fail=$((fail+1))
    printf '%s\n' "$out" | sed 's/^/    | /'
  fi
}

# ---- 1a. node --test empty suite (declared, zero tests) -> empty-suite (2) ----
N1="$WS/node-empty"; mkdir -p "$N1"
cat > "$N1/impl.js" <<'JS'
module.exports = function () { return 42; };
JS
cat > "$N1/feature.test.js" <<'JS'
const { describe } = require('node:test');
// suite declared but ZERO tests inside -> node reports "tests 0"
describe('feature', () => {});
JS
case_run "node --test empty suite -> empty-suite(2)" "$N1" 2 --label 'empty-suite' -- --changed impl.js

# ---- 1b. pytest empty suite (no test_ fn) -> empty-suite (2) ----
P1="$WS/py-empty"; mkdir -p "$P1"
cat > "$P1/impl.py" <<'PY'
def feature():
    return 42
PY
cat > "$P1/test_feature.py" <<'PY'
# present but defines ZERO test_ functions -> pytest exit 5 (no tests collected)
x = 1 + 1
PY
case_run "pytest empty suite -> empty-suite(2)" "$P1" 2 --label 'empty-suite' -- --changed impl.py

# ---- 2a. node --test real assertion -> covered (0) ----
N2="$WS/node-proper"; mkdir -p "$N2"
cat > "$N2/impl.js" <<'JS'
module.exports = function add(a, b) { return a + b; };
JS
cat > "$N2/add.test.js" <<'JS'
const test = require('node:test');
const assert = require('node:assert');
const add = require('./impl.js');
test('adds', () => { assert.strictEqual(add(2, 3), 5); });
JS
case_run "node --test real assertion -> covered(0)" "$N2" 0 --label 'covered' -- --changed impl.js

# ---- 2b. pytest real assertion -> covered (0) ----
P2="$WS/py-proper"; mkdir -p "$P2"
cat > "$P2/impl.py" <<'PY'
def add(a, b):
    return a + b
PY
cat > "$P2/test_add.py" <<'PY'
def test_add():
    assert 2 + 3 == 5
PY
case_run "pytest real assertion -> covered(0)" "$P2" 0 --label 'covered' -- --changed impl.py

# ---- 3. docs-only changed-list (no runner) -> no-executable-surface (0) ----
D3="$WS/docs"; mkdir -p "$D3"
printf '# readme\n' > "$D3/README.md"
printf '{"a":1}\n'  > "$D3/data.json"
case_run "docs-only -> no-executable-surface(0)" "$D3" 0 --label 'no-executable-surface' -- --changed 'README.md data.json'

# ---- 3b. prose template (.tmpl) classifies doc, not opaque -> no-executable-surface (0) ----
printf '# tmpl\n' > "$D3/agent.md.tmpl"
case_run "tmpl-is-doc -> no-executable-surface(0)" "$D3" 0 --label 'no-executable-surface' -- --changed 'README.md agent.md.tmpl'

# ---- 4a. js changed, NO test file -> no-behavioral-coverage (2) ----
N4="$WS/node-nocov"; mkdir -p "$N4"
cat > "$N4/impl.js" <<'JS'
module.exports = function () { return 1; };
JS
case_run "js changed, no test file -> no-behavioral-coverage(2)" "$N4" 2 --label 'no-behavioral-coverage' -- --changed impl.js

# ---- 4b. py changed, NO test file -> no-behavioral-coverage (2) ----
P4="$WS/py-nocov"; mkdir -p "$P4"
cat > "$P4/impl.py" <<'PY'
def f():
    return 1
PY
case_run "py changed, no test file -> no-behavioral-coverage(2)" "$P4" 2 --label 'no-behavioral-coverage' -- --changed impl.py

# ---- 5. package.json script w/ no parseable count -> fail-closed (2) ----
F5="$WS/pkg-failclosed"; mkdir -p "$F5"
cat > "$F5/impl.js" <<'JS'
module.exports = function () { return 1; };
JS
cat > "$F5/package.json" <<'JSON'
{
  "name": "fixture",
  "version": "1.0.0",
  "scripts": { "test": "echo ran-something-with-no-test-count" }
}
JSON
case_run "runner w/ no empty-signal (unparseable count) -> fail-closed(2)" "$F5" 2 --label 'unverifiable-suite' -- --changed impl.js

# ---- card 07: entrypoint smoke + differential dead-flag -----------------------
# Each fixture pairs a covered JS suite (so the gate reaches the entrypoint seam)
# with a temp-dir entrypoint. The gate EXECUTES shell entrypoints, so every bin is
# non-destructive (echo-only) and lives under $WS (never the live repo); case_run
# still snapshots git status before/after and asserts byte-identical.
mk_covered() {
  local d="$1"; mkdir -p "$d"
  cat > "$d/impl.js" <<'JS'
module.exports = function () { return 1; };
JS
  cat > "$d/smoke.test.js" <<'JS'
const test = require('node:test');
const assert = require('node:assert');
test('smoke', () => { assert.strictEqual(1, 1); });
JS
}

# ---- 6. dead-flag entrypoint: --flag parsed but unwired (identical output) -> dead-affordance(2)
E6="$WS/ep-dead"; mk_covered "$E6"
cat > "$E6/dead-bin" <<'BIN'
#!/usr/bin/env bash
# parses --flag but NEVER wires it: output is identical WITH or WITHOUT the flag
for a in "$@"; do case "$a" in --flag) : ;; esac; done
echo "mode=default"
echo "result=constant"
exit 0
BIN
chmod +x "$E6/dead-bin"
case_run "dead-flag entrypoint (parsed, unwired) -> dead-affordance(2)" "$E6" 2 --label 'dead-affordance' -- \
  --changed impl.js --entrypoint ./dead-bin --differential '--flag::mode=flagged::mode=default'

# ---- 7. wired-flag entrypoint: --flag changes output as declared -> covered(0)
E7="$WS/ep-wired"; mk_covered "$E7"
cat > "$E7/wired-bin" <<'BIN'
#!/usr/bin/env bash
seen=0
for a in "$@"; do
  case "$a" in
    --flag) seen=1 ;;
    --help) echo "usage: wired-bin [--flag]"; exit 0 ;;
  esac
done
if [ "$seen" = 1 ]; then echo "mode=flagged"; else echo "mode=default"; fi
exit 0
BIN
chmod +x "$E7/wired-bin"
case_run "wired-flag entrypoint (observable differs) -> covered(0)" "$E7" 0 --label 'covered' -- \
  --changed impl.js --entrypoint ./wired-bin --differential '--flag::mode=flagged::mode=default'

# ---- 8. crash-on-invoke entrypoint -> entrypoint-error(2)
E8="$WS/ep-crash"; mk_covered "$E8"
cat > "$E8/crash-bin" <<'BIN'
#!/usr/bin/env bash
echo "boom: cannot initialize" >&2
exit 1
BIN
chmod +x "$E8/crash-bin"
case_run "crash-on-invoke entrypoint -> entrypoint-error(2)" "$E8" 2 --label 'entrypoint-error' -- \
  --changed impl.js --entrypoint ./crash-bin

# ---- 9. .md command entrypoint (prompt doc) -> not-shell-smokable report, exit(0)
E9="$WS/ep-md"; mk_covered "$E9"
cat > "$E9/command.md" <<'MD'
# /demo:command
Runs the demo with $ARGUMENTS.
MD
case_run ".md command entrypoint -> not-shell-smokable report, exit(0)" "$E9" 0 --label 'not-shell-smokable' -- \
  --changed impl.js --entrypoint ./command.md

# ---- gate-correctness regression cases (each proves a specific false-verdict bug
# ---- is now caught; each fails against the OLD logic, i.e. is non-vacuous) --------

# ---- G1. jest --passWithNoTests false-PASS: the flag disables the empty signal;
# jest prints "Test Suites: 1 passed" + "Tests: 0 total" and exits 0. The gate must
# refuse it (unverifiable-suite), NOT read the suite-count line as covered. (fix a)
GJ1="$WS/pkg-passwithnotests"; mkdir -p "$GJ1"
cat > "$GJ1/impl.js" <<'JS'
module.exports = () => 42;
JS
cat > "$GJ1/jest-stub.sh" <<'STUB'
#!/usr/bin/env bash
# emulate `jest --passWithNoTests` on a zero-test suite: green suite line, 0 tests.
echo "Test Suites: 1 passed, 1 total"
echo "Tests:       0 total"
echo "Snapshots:   0 total"
exit 0
STUB
cat > "$GJ1/package.json" <<'JSON'
{ "name": "fx", "version": "1.0.0", "scripts": { "test": "sh ./jest-stub.sh --passWithNoTests" } }
JSON
case_run "jest --passWithNoTests (empty masked green) -> unverifiable-suite(2)" "$GJ1" 2 --label 'unverifiable-suite' -- --changed impl.js

# ---- G2. jest empty false-PASS via output anchoring (NO --passWithNoTests flag in
# the script, so this exercises the '^Tests:' anchor independently): a run printing
# "Test Suites: 1 passed" + "Tests: 0 total" must NOT be covered. (fix b)
GJ2="$WS/pkg-suiteline-green"; mkdir -p "$GJ2"
cat > "$GJ2/impl.js" <<'JS'
module.exports = () => 42;
JS
cat > "$GJ2/package.json" <<'JSON'
{ "name": "fx", "version": "1.0.0",
  "scripts": { "test": "printf 'Test Suites: 1 passed, 1 total\\nTests:       0 total\\n'" } }
JSON
case_run "jest 'Test Suites: 1 passed' + 'Tests: 0 total' -> NOT covered (2)" "$GJ2" 2 -- --changed impl.js

# ---- G3. go multi-package: pkg1 has passing tests ('ok'), pkg2 has none
# ('[no test files]'). Empty must NOT win over a real result line -> covered. (fix 2)
GG1="$WS/go-multipkg"; mkdir -p "$GG1"
printf 'package p\n'                > "$GG1/impl.go"
printf 'package p\n'                > "$GG1/impl_test.go"
printf 'ok  \texample/pkg1\t0.012s\n?   \texample/pkg2\t[no test files]\n' > "$GG1/.gostub.out"
printf '0\n'                        > "$GG1/.gostub.rc"
case_run "go multi-package (ok + no test files) -> covered(0)" "$GG1" 0 --label 'covered' -- --changed impl.go

# ---- G4. go build failure: 'FAIL pkg [build failed]' means ZERO tests ran; it must
# route to unverifiable-suite, never be read as covered by the '^FAIL' match. (fix 3)
GG2="$WS/go-buildfail"; mkdir -p "$GG2"
printf 'package p\n'                > "$GG2/impl.go"
printf 'package p\n'                > "$GG2/impl_test.go"
printf '# example/pkg\n./impl.go:3:2: syntax error\nFAIL\texample/pkg [build failed]\n' > "$GG2/.gostub.out"
printf '1\n'                        > "$GG2/.gostub.rc"
case_run "go '[build failed]' (zero tests ran) -> unverifiable-suite(2)" "$GG2" 2 --label 'unverifiable-suite' -- --changed impl.go

# ---- G5. node skip-only suite: node reports 'tests 1' but 'pass 0/fail 0/todo 0'.
# Relying on 'tests N' alone reads covered; cross-checking executed counts (=0) must
# classify it empty-suite. (fix 4)
GN1="$WS/node-skiponly"; mkdir -p "$GN1"
cat > "$GN1/impl.js" <<'JS'
module.exports = () => 1;
JS
cat > "$GN1/skip.test.js" <<'JS'
const { test } = require('node:test');
// the ONLY test is skipped: node prints `tests 1` but `pass 0` -> zero executed.
test('not yet', { skip: true }, () => {});
JS
case_run "node skip-only suite (tests 1 / pass 0) -> empty-suite(2)" "$GN1" 2 --label 'empty-suite' -- --changed impl.js

# ---- G6. entrypoint prints usage and exits NON-ZERO on --help (a common CLI
# convention). That is not a crash: it must NOT be flagged entrypoint-error. (fix 5)
GE1="$WS/ep-usage-nonzero"; mk_covered "$GE1"
cat > "$GE1/helpexit-bin" <<'BIN'
#!/usr/bin/env bash
seen=0
for a in "$@"; do
  case "$a" in
    --help) echo "usage: helpexit-bin [--flag]"; exit 2 ;;  # prints usage, exits NON-ZERO
    --flag) seen=1 ;;
  esac
done
if [ "$seen" = 1 ]; then echo "mode=flagged"; else echo "mode=default"; fi
exit 0
BIN
chmod +x "$GE1/helpexit-bin"
case_run "entrypoint usage+non-zero on --help -> NOT entrypoint-error, covered(0)" "$GE1" 0 --label 'covered' -- \
  --changed impl.js --entrypoint ./helpexit-bin --differential '--flag::mode=flagged::mode=default'

# ---- G7. differential with an EMPTY with-marker: 'grep -qF -- ""' would match
# everything and spuriously read as dead-affordance; it must be a usage error. (fix guard)
GE2="$WS/ep-empty-marker"; mk_covered "$GE2"
cat > "$GE2/okbin" <<'BIN'
#!/usr/bin/env bash
case "${1:-}" in --help) echo "usage: okbin"; exit 0 ;; esac
echo "out"
BIN
chmod +x "$GE2/okbin"
case_run "differential empty with-marker -> usage error(3)" "$GE2" 3 --label 'usage error' -- \
  --changed impl.js --entrypoint ./okbin --differential '--flag::::mode=default'

# ---- tally ----
printf '\nbehavioral-gate.test: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
