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

# ---- tally ----
printf '\nbehavioral-gate.test: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
