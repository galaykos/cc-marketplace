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

# ---- php / rust / ruby / java stubs (SW 1, 2026-09-22). Same deterministic shape as
# the `go` stub above: each prints the fixture's ./<name>.out and exits ./<name>.rc.
# The .out bodies below are VERBATIM output captured from real runs on 2026-09-22 —
# PHPUnit 13.3, cargo 1.98.1, rspec 3.13.6, Gradle 9.7.1 — because CI has none of those
# four toolchains and a stub that invents its runner's wording proves nothing. The
# real-runner probes are recorded in the plugin CHANGELOG entry for 0.38.0.
LANGBIN="$WS/langbin"; mkdir -p "$LANGBIN"
mk_stub() { # mk_stub <path> <out-file> <rc-file>
  cat > "$1" <<STUB
#!/usr/bin/env bash
[ -f ./$2 ] && cat ./$2
if [ -f ./$3 ]; then exit "\$(cat ./$3)"; fi
exit 0
STUB
  chmod +x "$1"
}
mk_stub "$LANGBIN/cargo" .cargostub.out .cargostub.rc
mk_stub "$LANGBIN/rspec" .rspecstub.out .rspecstub.rc
export PATH="$LANGBIN:$PATH"

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

# ---- SW 1 (2026-09-22): php / rust / ruby / java + the --runner escape -------------
# Every case below EXITED 2 with "no test runner resolves for the touched types" before
# 0.38.0 — the classifier knew py/js/go and nothing else, so a PHP/Rust/Java/Ruby run
# could not close and there was no flag to escape with. Each is therefore non-vacuous
# against the old logic by construction.

# ---- P1. php green suite -> covered(0)
PH1="$WS/php-green"; mkdir -p "$PH1/vendor/bin" "$PH1/tests" "$PH1/src"
printf '<?php class Calc {}\n' > "$PH1/src/Calc.php"
printf '<?php final class CalcTest {}\n' > "$PH1/tests/CalcTest.php"
mk_stub "$PH1/vendor/bin/phpunit" .phpstub.out .phpstub.rc
printf 'PHPUnit 13.3.1 by Sebastian Bergmann and contributors.\n\n.  1 / 1 (100%%)\n\nOK (1 test, 1 assertion)\n' > "$PH1/.phpstub.out"
printf '0\n' > "$PH1/.phpstub.rc"
case_run "php green suite (phpunit OK (1 test)) -> covered(0)" "$PH1" 0 --label 'covered' -- --changed src/Calc.php

# ---- P2. php suite that collects nothing -> empty-suite(2)
PH2="$WS/php-empty"; mkdir -p "$PH2/vendor/bin" "$PH2/tests" "$PH2/src"
printf '<?php class Calc {}\n' > "$PH2/src/Calc.php"
printf '<?php // no test class\n' > "$PH2/tests/CalcTest.php"
mk_stub "$PH2/vendor/bin/phpunit" .phpstub.out .phpstub.rc
printf 'PHPUnit 13.3.1 by Sebastian Bergmann and contributors.\n\nNo tests executed!\n' > "$PH2/.phpstub.out"
printf '1\n' > "$PH2/.phpstub.rc"
case_run "php runner that executes zero tests -> empty-suite(2)" "$PH2" 2 --label 'empty-suite' -- --changed src/Calc.php

# ---- P3. php changed, no test file anywhere -> no-behavioral-coverage(2)
PH3="$WS/php-nocov"; mkdir -p "$PH3/src"
printf '<?php class Calc {}\n' > "$PH3/src/Calc.php"
case_run "php changed, no test file -> no-behavioral-coverage(2)" "$PH3" 2 --label 'no-behavioral-coverage' -- --changed src/Calc.php

# ---- R1. cargo multi-target: lib target passes, doc-tests report 0 -> covered(0).
# This is the real shape of a green crate (captured verbatim), and it is why COVERED is
# checked before EMPTY: an empty-first reader calls a healthy crate empty.
RS1="$WS/rs-green"; mkdir -p "$RS1/src"
printf 'pub fn add(a: i32, b: i32) -> i32 { a + b }\n#[cfg(test)]\nmod tests { #[test] fn adds() {} }\n' > "$RS1/src/lib.rs"
cat > "$RS1/.cargostub.out" <<'OUT'
   Compiling bgprobe-rs v0.1.0 (/tmp/bgprobe-rs)
    Finished `test` profile [unoptimized + debuginfo] target(s) in 0.31s
     Running unittests src/lib.rs (target/debug/deps/bgprobe_rs-10a368df25a6d13e)

running 1 test
test tests::adds ... ok

test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s

   Doc-tests bgprobe_rs

running 0 tests

test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s
OUT
printf '0\n' > "$RS1/.cargostub.rc"
case_run "cargo multi-target (1 passed + doc-tests 0 passed) -> covered(0)" "$RS1" 0 --label 'covered' -- --changed src/lib.rs

# ---- R2. every cargo target reports 0 passed -> empty-suite(2)
RS2="$WS/rs-empty"; mkdir -p "$RS2/src" "$RS2/tests"
printf 'pub fn add(a: i32, b: i32) -> i32 { a + b }\n' > "$RS2/src/lib.rs"
printf '// an integration test file with zero #[test] fns\n' > "$RS2/tests/it.rs"
cat > "$RS2/.cargostub.out" <<'OUT'
    Finished `test` profile [unoptimized + debuginfo] target(s) in 0.00s
     Running tests/it.rs (target/debug/deps/it-6a1b2c3d)

running 0 tests

test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s
OUT
printf '0\n' > "$RS2/.cargostub.rc"
case_run "cargo runner that executes zero tests -> empty-suite(2)" "$RS2" 2 --label 'empty-suite' -- --changed src/lib.rs

# ---- R3. cargo compile error: zero tests ran, must not read green -> unverifiable(2)
RS3="$WS/rs-buildfail"; mkdir -p "$RS3/src"
printf 'pub fn add(a: i32, b: i32) -> i32 { a + b }\n#[cfg(test)]\nmod tests { #[test] fn adds() {} }\n' > "$RS3/src/lib.rs"
cat > "$RS3/.cargostub.out" <<'OUT'
error[E0425]: cannot find value `c` in this scope
 --> src/lib.rs:1:45
error: could not compile `bgprobe-rs` (lib test) due to 1 previous error
OUT
printf '101\n' > "$RS3/.cargostub.rc"
case_run "cargo compile error (zero tests ran) -> unverifiable-suite(2)" "$RS3" 2 --label 'unverifiable-suite' -- --changed src/lib.rs

# ---- B1. rspec green -> covered(0)
RB1="$WS/rb-green"; mkdir -p "$RB1/lib" "$RB1/spec"
printf 'module Calc\nend\n' > "$RB1/lib/calc.rb"
printf 'RSpec.describe Calc do\n  it("adds") { }\nend\n' > "$RB1/spec/calc_spec.rb"
printf '.\n\nFinished in 0.00108 seconds (files took 0.03 seconds to load)\n1 example, 0 failures\n' > "$RB1/.rspecstub.out"
printf '0\n' > "$RB1/.rspecstub.rc"
case_run "rspec green (1 example) -> covered(0)" "$RB1" 0 --label 'covered' -- --changed lib/calc.rb

# ---- B2. rspec runs zero examples -> empty-suite(2)
RB2="$WS/rb-empty"; mkdir -p "$RB2/lib" "$RB2/spec"
printf 'module Calc\nend\n' > "$RB2/lib/calc.rb"
printf 'RSpec.describe Calc do\nend\n' > "$RB2/spec/calc_spec.rb"
printf 'No examples found.\n\nFinished in 0.00008 seconds (files took 0.02 seconds to load)\n0 examples, 0 failures\n' > "$RB2/.rspecstub.out"
printf '0\n' > "$RB2/.rspecstub.rc"
case_run "rspec runner that executes zero examples -> empty-suite(2)" "$RB2" 2 --label 'empty-suite' -- --changed lib/calc.rb

# ---- J1. gradle green prints NO counts, only BUILD SUCCESSFUL -> covered(0) via the
# weak fallback. The weakness is documented in runners.md; the case pins the behaviour
# so a future tightening is a deliberate change, not a surprise.
JV1="$WS/java-green"; mkdir -p "$JV1/src/main/java" "$JV1/src/test/java"
printf 'public class Calc {}\n' > "$JV1/src/main/java/Calc.java"
printf 'public class CalcTest {}\n' > "$JV1/src/test/java/CalcTest.java"
mk_stub "$JV1/gradlew" .gradlestub.out .gradlestub.rc
printf '> Task :compileJava\n> Task :test\n\nBUILD SUCCESSFUL in 572ms\n3 actionable tasks: 3 executed\n' > "$JV1/.gradlestub.out"
printf '0\n' > "$JV1/.gradlestub.rc"
case_run "gradle green (no counts printed) -> covered(0) via the weak fallback" "$JV1" 0 --label 'covered' -- --changed src/main/java/Calc.java

# ---- J2. gradle discovers nothing (Gradle 9 failOnNoDiscoveredTests) -> empty-suite(2)
JV2="$WS/java-nodiscovery"; mkdir -p "$JV2/src/main/java" "$JV2/src/test/java"
printf 'public class Calc {}\n' > "$JV2/src/main/java/Calc.java"
printf 'public class CalcTest {}\n' > "$JV2/src/test/java/CalcTest.java"
mk_stub "$JV2/gradlew" .gradlestub.out .gradlestub.rc
cat > "$JV2/.gradlestub.out" <<'OUT'
FAILURE: Build failed with an exception.

* What went wrong:
Execution failed for task ':test'.
> There are test sources present and no filters are applied, but the test task did not discover any tests to execute. This is likely due to a misconfiguration.

BUILD FAILED in 570ms
OUT
printf '1\n' > "$JV2/.gradlestub.rc"
case_run "gradle discovered zero tests -> empty-suite(2)" "$JV2" 2 --label 'empty-suite' -- --changed src/main/java/Calc.java

# ---- J3. gradle test task UP-TO-DATE: nothing executed this invocation -> unverifiable(2)
JV3="$WS/java-uptodate"; mkdir -p "$JV3/src/main/java" "$JV3/src/test/java"
printf 'public class Calc {}\n' > "$JV3/src/main/java/Calc.java"
printf 'public class CalcTest {}\n' > "$JV3/src/test/java/CalcTest.java"
mk_stub "$JV3/gradlew" .gradlestub.out .gradlestub.rc
printf '> Task :compileTestJava UP-TO-DATE\n> Task :test UP-TO-DATE\n\nBUILD SUCCESSFUL in 618ms\n' > "$JV3/.gradlestub.out"
printf '0\n' > "$JV3/.gradlestub.rc"
case_run "gradle test task UP-TO-DATE (nothing ran) -> unverifiable-suite(2)" "$JV3" 2 --label 'unverifiable-suite' -- --changed src/main/java/Calc.java

# ---- J4. maven surefire 'Tests run: 0' -> empty-suite(2); .kt classifies as java too
JV4="$WS/java-surefire-zero"; mkdir -p "$JV4/src/main/kotlin" "$JV4/src/test/kotlin"
printf 'class Calc\n' > "$JV4/src/main/kotlin/Calc.kt"
printf 'class CalcTest\n' > "$JV4/src/test/kotlin/CalcTest.kt"
mk_stub "$JV4/mvnw" .mvnstub.out .mvnstub.rc
printf '[INFO] Tests run: 0, Failures: 0, Errors: 0, Skipped: 0\n[INFO] BUILD SUCCESS\n' > "$JV4/.mvnstub.out"
printf '0\n' > "$JV4/.mvnstub.rc"
case_run "kotlin + maven 'Tests run: 0' -> empty-suite(2)" "$JV4" 2 --label 'empty-suite' -- --changed src/main/kotlin/Calc.kt

# ---- C1. --runner escape on a language the classifier still calls opaque -> covered(0)
CR1="$WS/custom-green"; mkdir -p "$CR1"
printf 'defmodule Calc do\nend\n' > "$CR1/calc.ex"
printf '#!/bin/sh\necho "Finished in 0.02 seconds"\necho "3 tests, 0 failures"\n' > "$CR1/suite.sh"; chmod +x "$CR1/suite.sh"
case_run "--runner escape, declared suite runs 3 tests -> covered(0)" "$CR1" 0 --label 'covered' -- \
  --changed calc.ex --runner './suite.sh::^0 tests'

# ---- C2. --runner whose suite runs zero tests, per the DECLARED regex -> empty-suite(2)
CR2="$WS/custom-empty"; mkdir -p "$CR2"
printf 'defmodule Calc do\nend\n' > "$CR2/calc.ex"
printf '#!/bin/sh\necho "Finished in 0.01 seconds"\necho "0 tests, 0 failures"\n' > "$CR2/suite.sh"; chmod +x "$CR2/suite.sh"
case_run "--runner escape, declared suite runs zero tests -> empty-suite(2)" "$CR2" 2 --label 'empty-suite' -- \
  --changed calc.ex --runner './suite.sh::^0 tests'

# ---- C3. --runner naming a command that never starts -> unverifiable-suite(2). The one
# failure the caller's declaration cannot paper over.
case_run "--runner naming a missing command -> unverifiable-suite(2)" "$CR2" 2 --label 'unverifiable-suite' -- \
  --changed calc.ex --runner 'no-such-binary-here::^0 tests'

# ---- C4. malformed --runner (no :: separator) -> usage error(3)
case_run "--runner without the :: separator -> usage error(3)" "$CR2" 3 --label 'usage error' -- \
  --changed calc.ex --runner 'justacommand'

# ---- I. isolation modes (2026-09-24). The fixture is its own git repo standing in for a
# LIVE project: a committed .env.example and artisan, an untracked .env holding the
# "credentials", and a test that drops ran.marker in whatever directory it runs in — so
# "was the live tree touched" is a file check, not an inference. The gate's worktrees go
# under a TMPDIR private to this harness, so leftovers are countable.
iso_ok()  { printf 'PASS: %s\n' "$1"; pass=$((pass+1)); }
iso_bad() { printf 'FAIL: %s (%s)\n' "$1" "$2"; fail=$((fail+1)); [ -n "${3:-}" ] && printf '%s\n' "$3" | sed 's/^/    | /'; return 0; }
iso_gate() { # iso_gate <dir> <args...> -> sets IRC, IOUT
  set +e; IOUT=$( cd "$1" && shift && TMPDIR="$ISO_TMP" "$BG" "$@" 2>&1 ); IRC=$?; set -e
}
ISO_TMP="$WS/isotmp"; mkdir -p "$ISO_TMP"
LIVE="$WS/live-app"; mkdir -p "$LIVE/.claude/task-runner/bg"
cat > "$LIVE/impl.js" <<'JS'
module.exports = () => 42;
JS
cat > "$LIVE/impl.test.js" <<'JS'
const test = require('node:test'); const assert = require('node:assert'); const fs = require('node:fs');
test('impl', () => {
  fs.writeFileSync('ran.marker', 'x');
  if (process.env.BG_EXPECT_ISO) {
    assert.strictEqual(fs.readFileSync('.env', 'utf8'), fs.readFileSync('.env.example', 'utf8'));
    assert.match(process.env.APP_KEY || '', /^base64:/);
  }
  assert.strictEqual(require('./impl.js')(), 42);
});
JS
printf 'APP_KEY=\nAPP_URL=http://localhost\n' > "$LIVE/.env.example"
printf '#!/usr/bin/env php\n' > "$LIVE/artisan"
printf '.env\nran.marker\n.claude/\n' > "$LIVE/.gitignore"
( cd "$LIVE" && git init -q && git add -A && git -c user.email=t@t -c user.name=t commit -qm fixture )
printf 'APP_KEY=base64:LIVE-SECRET\nAPP_URL=https://live.example\n' > "$LIVE/.env"
live_env_sum=$(cksum < "$LIVE/.env"); live_status=$(git -C "$LIVE" status --porcelain)
live_head=$(git -C "$LIVE" rev-parse HEAD)

# I1. --isolate: runs in its own worktree, builds env there, records to the LIVE bg dir,
#     leaves no worktree and no temp dir behind, and the live tree is byte-identical.
set +e; IOUT=$( cd "$LIVE" && BG_EXPECT_ISO=1 TMPDIR="$ISO_TMP" "$BG" --isolate --changed impl.js 2>&1 ); IRC=$?; set -e
d="--isolate green suite -> covered(0), live tree untouched, worktree removed"
if [ "$IRC" != 0 ] || ! printf '%s' "$IOUT" | grep -q 'covered'; then iso_bad "$d" "rc=$IRC" "$IOUT"
elif [ -e "$LIVE/ran.marker" ]; then iso_bad "$d" "test ran in the LIVE tree"
elif [ "$(cksum < "$LIVE/.env")" != "$live_env_sum" ]; then iso_bad "$d" "live .env CHANGED"
elif [ "$(git -C "$LIVE" status --porcelain)" != "$live_status" ]; then iso_bad "$d" "live git status CHANGED"
elif [ "$(git -C "$LIVE" worktree list | wc -l | tr -d ' ')" != 1 ]; then iso_bad "$d" "worktree left behind" "$(git -C "$LIVE" worktree list)"
elif [ -n "$(ls -A "$ISO_TMP")" ]; then iso_bad "$d" "temp dir left behind" "$(ls -A "$ISO_TMP")"
elif ! grep -q '"verdict":"covered"' "$LIVE/.claude/task-runner/bg/bg-$live_head.json" 2>/dev/null; then iso_bad "$d" "no bg record in the LIVE bg dir"
else iso_ok "$d"; fi

# I2. --isolate when `git worktree add` fails (unborn HEAD) -> refuse(3), nothing ran anywhere.
UNBORN="$WS/unborn"; mkdir -p "$UNBORN"; cp "$LIVE/impl.js" "$LIVE/impl.test.js" "$UNBORN/"
( cd "$UNBORN" && git init -q )
iso_gate "$UNBORN" --isolate --changed impl.js
d="--isolate, worktree add fails -> refuse(3), suite never ran"
if [ "$IRC" != 3 ] || ! printf '%s' "$IOUT" | grep -q 'nothing was run'; then iso_bad "$d" "rc=$IRC" "$IOUT"
elif [ -e "$UNBORN/ran.marker" ]; then iso_bad "$d" "suite ran IN PLACE after the setup failed"
elif [ -n "$(ls -A "$ISO_TMP")" ]; then iso_bad "$d" "temp dir left behind"
else iso_ok "$d"; fi

# I3. --isolate outside any git work tree -> refuse(3).
iso_gate "$N1" --isolate --changed impl.js
d="--isolate outside a git work tree -> refuse(3)"
{ [ "$IRC" = 3 ] && printf '%s' "$IOUT" | grep -q 'not inside a git work tree'; } && iso_ok "$d" || iso_bad "$d" "rc=$IRC" "$IOUT"

# I4. no flag inside a registered run's live tree -> refuse(3), naming --isolate; nothing ran.
printf '{"slug":"t"}\n' > "$LIVE/.claude/task-runner/active-run.json"
iso_gate "$LIVE" --changed impl.js
d="no flag in a registered run's live tree -> refuse(3) naming --isolate"
if [ "$IRC" != 3 ] || ! printf '%s' "$IOUT" | grep -q -- '--isolate'; then iso_bad "$d" "rc=$IRC" "$IOUT"
elif [ -e "$LIVE/ran.marker" ]; then iso_bad "$d" "suite ran in the live tree"
else iso_ok "$d"; fi

# I5. --isolate and --in-place together -> usage(3).
iso_gate "$LIVE" --isolate --in-place --changed impl.js
d="--isolate with --in-place -> usage error(3)"
{ [ "$IRC" = 3 ] && printf '%s' "$IOUT" | grep -q 'mutually exclusive'; } && iso_ok "$d" || iso_bad "$d" "rc=$IRC" "$IOUT"

# I6. --in-place is the explicit escape: runs in cwd even with the sentinel present.
#     (Last on purpose — it writes ran.marker into the fixture.)
iso_gate "$LIVE" --in-place --changed impl.js
d="--in-place escape with the sentinel present -> covered(0) in cwd"
{ [ "$IRC" = 0 ] && [ -e "$LIVE/ran.marker" ]; } && iso_ok "$d" || iso_bad "$d" "rc=$IRC" "$IOUT"

# ---- tally ----
printf '\nbehavioral-gate.test: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
