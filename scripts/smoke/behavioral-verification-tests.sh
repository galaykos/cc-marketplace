#!/usr/bin/env bash
# Dogfood smoke test — the ultimate proof for the behavioral-verification gates.
#
# Reproduces the deterministic defect classes that motivated the work and asserts the
# SHIPPED gate scripts flip each one RED:
#   1. empty-suite       — a suite that collects zero tests
#   2. dead-flag         — a documented, parsed-but-unwired flag (identical output)
#   3. fail-open-guard   — a guard whose verify only exercises the allow path
#   4. passWithNoTests   — jest masks a zero-test suite green via --passWithNoTests
#
# It CALLS THE SHIPPED SCRIPTS BY REPO-RELATIVE PATH and never reimplements gate
# logic. Each fixture is copied into a fresh temp dir before the gate runs there, so
# the live repo tree is never mutated — asserted via `git status --porcelain` before
# and after. The script exits 0 ONLY if every gate correctly went RED.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GATE="$ROOT/plugins/task-runner/scripts/behavioral-gate.sh"
NC="$ROOT/plugins/task-runner/scripts/negative-control.sh"
FIX="$ROOT/scripts/smoke/validate-fixtures/behavioral-verification"

command -v node >/dev/null 2>&1 || { echo "SKIP: node not available (behavioral fixtures need node --test)"; exit 0; }

rc=0
GIT_BEFORE="$(git -C "$ROOT" status --porcelain 2>/dev/null || true)"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

stage() { # $1 fixture-subdir -> prints a fresh isolated temp copy of it
  local name="$1"
  local dst="$WORK/$name.$$.$RANDOM"
  mkdir -p "$dst"
  cp -R "$FIX/$name/." "$dst/"
  printf '%s' "$dst"
}

assert_red() { # $1 class  $2 gate-name  $3 want-label  $4 exit-code  $5 errfile
  local class="$1" gate="$2" label="$3" ec="$4" errf="$5"
  if [ "$ec" -eq 2 ] && grep -q "$label" "$errf"; then
    echo "PASS[$class]: $gate exit=$ec label=$label"
  else
    echo "FAIL[$class]: $gate exit=$ec (want exit 2 + stderr label '$label')"
    sed 's/^/    /' "$errf"
    rc=1
  fi
}

# --- class 1: empty-suite ---------------------------------------------------
# A JS test file exists but its describe() block has no it() cases -> `tests 0`.
d="$(stage empty-suite)"
ec=0
( cd "$d" && bash "$GATE" --changed app.js ) >/dev/null 2>"$WORK/1.err" || ec=$?
assert_red empty-suite behavioral-gate.sh empty-suite "$ec" "$WORK/1.err"

# --- class 2: dead-flag -----------------------------------------------------
# demo-tool documents & parses --verbose but never consumes it -> identical output.
d="$(stage dead-flag)"
chmod +x "$d/demo-tool"
ec=0
( cd "$d" && bash "$GATE" --changed app.js --entrypoint ./demo-tool \
    --differential '--verbose::VERBOSE-OUTPUT::QUIET-OUTPUT' ) >/dev/null 2>"$WORK/2.err" || ec=$?
assert_red dead-flag behavioral-gate.sh dead-affordance "$ec" "$WORK/2.err"

# --- class 3: fail-open-guard ----------------------------------------------
# The verify only checks the allow path; disabling the deny path leaves it green.
d="$(stage fail-open-guard)"
chmod +x "$d/guard.sh"
ec=0
( cd "$d" && bash "$NC" --verify 'bash guard.sh good | grep -q ALLOW' \
    --target guard.sh --auto ) >/dev/null 2>"$WORK/3.err" || ec=$?
assert_red fail-open-guard negative-control.sh vacuous "$ec" "$WORK/3.err"

# --- class 4: jest empty suite masked by --passWithNoTests ------------------
# A jest run with --passWithNoTests over a zero-test suite prints a GREEN
# "Test Suites: 1 passed" line while "Tests: 0 total" shows nothing ran, and exits 0.
# This is the mechanism most likely to mask green; the shipped gate must flip it RED.
d="$(stage jest-passwithnotests)"
ec=0
( cd "$d" && bash "$GATE" --changed app.js ) >/dev/null 2>"$WORK/4.err" || ec=$?
assert_red passWithNoTests behavioral-gate.sh unverifiable-suite "$ec" "$WORK/4.err"

# --- repo-tree invariant ----------------------------------------------------
GIT_AFTER="$(git -C "$ROOT" status --porcelain 2>/dev/null || true)"
if [ "$GIT_BEFORE" = "$GIT_AFTER" ]; then
  echo "PASS[git-status]: repo tree unchanged before/after"
else
  echo "FAIL[git-status]: repo tree changed during run"
  rc=1
fi

if [ "$rc" -eq 0 ]; then
  echo "All behavioral-verification defect classes caught (shipped gates flipped RED)."
else
  echo "One or more defect classes were NOT caught — see FAIL lines above."
fi
exit "$rc"
