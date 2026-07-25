#!/usr/bin/env bash
# scripts/smoke/comment-discipline-hook-tests.sh
#
# Pins the contract of plugins/comment-discipline/hooks/scan.sh — a warn-only PostToolUse
# guard. Three properties, each of which fails silently in production if it regresses:
#   1. FIRES  on the five high-confidence noise patterns, across all three tool shapes
#   2. SILENT on every keep-case, on exempt paths/extensions, and on unknown tools
#   3. FAIL-OPEN — malformed stdin, empty stdin, and a jq-free PATH exit 0 with no output
# The jq-free case uses a clean bin of coreutils symlinks so it exercises genuine absence.
# Companion to scripts/smoke/hook-guard-tests.sh, which covers the remind.sh guards.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${CHASSIS_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
HOOK="$ROOT/plugins/comment-discipline/hooks/scan.sh"
BASH_BIN="$(command -v bash)"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
rc=0
pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n      %s\n' "$1" "${2:-}"; rc=1; }

[ -f "$HOOK" ] || { printf 'comment-discipline-hook-tests: %s missing\n' "$HOOK" >&2; exit 2; }
[ -x "$HOOK" ] || fail "hook is executable" "not +x"

NOJQ="$WORK/nojq-bin"; mkdir -p "$NOJQ"
for u in cat grep sed awk tr head cut env sh expr dirname basename printf; do
  p="$(command -v "$u" 2>/dev/null)" && ln -s "$p" "$NOJQ/$u" 2>/dev/null
done
if PATH="$NOJQ" command -v jq >/dev/null 2>&1; then
  printf 'comment-discipline-hook-tests: could not build a jq-free PATH; aborting\n' >&2; exit 2
fi

# Build a PostToolUse envelope without depending on the shape of the caller's quoting.
envelope() { # tool  file_path  added-text  [shape: content|new_string|edits]
  python3 - "$@" <<'PY'
import json, sys
tool, path, added = sys.argv[1], sys.argv[2], sys.argv[3]
shape = sys.argv[4] if len(sys.argv) > 4 else "content"
ti = {"file_path": path}
if shape == "edits":
    ti["edits"] = [{"new_string": part} for part in added.split("\x00")]
else:
    ti[shape] = added
print(json.dumps({"cwd": "/tmp/proj", "tool_name": tool, "tool_input": ti}))
PY
}

run() { printf '%s' "$1" | "$BASH_BIN" "$HOOK" 2>/dev/null; }

assert_fires() { # desc  json  expected-category-substring
  local desc="$1" out
  out="$(run "$2")"
  if [ -z "$out" ]; then fail "$desc" "wanted a warning, got silence"; return; fi
  case "$out" in
    comment-discipline:*) ;;
    *) fail "$desc" "warning not prefixed 'comment-discipline:': $out"; return ;;
  esac
  case "$out" in
    *"$3"*) pass "$desc" ;;
    *) fail "$desc" "wanted category '$3', got: $out" ;;
  esac
}

assert_silent() { # desc  json
  local desc="$1" out rc_
  out="$(printf '%s' "$2" | "$BASH_BIN" "$HOOK" 2>/dev/null)"; rc_=$?
  if [ "$rc_" -ne 0 ]; then fail "$desc" "exit $rc_ (want 0)"; return; fi
  if [ -n "$out" ]; then fail "$desc" "wanted silence, spoke: $out"; return; fi
  pass "$desc"
}

# ---- 1. fires on the five patterns, across all three tool shapes --------------------
assert_fires "fires: comment restating the next line (Write/content)" \
  "$(envelope Write /tmp/proj/a.js '// increment the counter
counter++;')" "restating the next line"

assert_fires "fires: section banner (Edit/new_string)" \
  "$(envelope Edit /tmp/proj/a.php '// ==== HELPERS ====
$x = 1;' new_string)" "section banner"

assert_fires "fires: commented-out code (MultiEdit/edits)" \
  "$(envelope MultiEdit /tmp/proj/a.py 'def f():
    pass
# doThing();' edits)" "commented-out code"

assert_fires "fires: bare TODO with no ticket" \
  "$(envelope Write /tmp/proj/a.ts '// TODO: fix this
const x = 1;')" "bare TODO"

assert_fires "fires: docblock tag repeating the signature" \
  "$(envelope Write /tmp/proj/a.php '/**
 * @param $id The id
 */
function f($id) {}')" "docblock tag repeating the signature"

assert_fires "fires: getter comment restating the name" \
  "$(envelope Write /tmp/proj/a.js '// get the user by id
function getUserById(id) {}')" "restating the next line"

# ---- 2. silent on every keep-case ---------------------------------------------------
assert_silent "keep: why / rejected alternative" \
  "$(envelope Write /tmp/proj/a.js '// Sequential, not Promise.all: the vendor rate-limits concurrent calls.
for (const id of ids) await fetchOne(id);')"

assert_silent "keep: external constraint with a ticket" \
  "$(envelope Write /tmp/proj/a.js '// Retry twice: upstream 500s on first call after deploy (VENDOR-412).
retry(2);')"

assert_silent "keep: intentional-silence marker on an empty catch" \
  "$(envelope Write /tmp/proj/a.js 'try { warmCache(); } catch (e) {
  // Best-effort only: a cold cache is correct, just slower.
}')"

assert_silent "keep: TODO carrying a ticket ID" \
  "$(envelope Write /tmp/proj/a.js '// TODO(BILL-412): drop once the v2 rollout completes
const x = 1;')"

assert_silent "keep: contract fact a signature cannot state" \
  "$(envelope Write /tmp/proj/a.ts '// Timeout in milliseconds; caller owns the handle and must close it.
function connect(timeout: number) {}')"

assert_silent "exempt: licence / SPDX header" \
  "$(envelope Write /tmp/proj/a.js '// Copyright 2026 Acme. SPDX-License-Identifier: MIT
const x = 1;')"

assert_silent "exempt: shebang" \
  "$(envelope Write /tmp/proj/a.sh '#!/usr/bin/env bash
set -e')"

assert_silent "exempt: tool directive" \
  "$(envelope Write /tmp/proj/a.js '// eslint-disable-next-line no-console
console.log(1);')"

assert_silent "scope: non-code extension is not governed" \
  "$(envelope Write /tmp/proj/notes.md '// increment the counter
counter++;')"

assert_silent "scope: generated/tooling path is exempt" \
  "$(envelope Write /tmp/proj/scripts/build.sh '# increment the counter
counter=$((counter+1))')"

assert_silent "scope: vendored path is exempt" \
  "$(envelope Write /tmp/proj/node_modules/x/a.js '// increment the counter
counter++;')"

assert_silent "unknown tool name is ignored" \
  "$(envelope Read /tmp/proj/a.js '// increment the counter
counter++;')"

assert_silent "empty added text" \
  "$(envelope Write /tmp/proj/a.js '')"

# ---- 3. fail-open -------------------------------------------------------------------
assert_silent "fail-open: malformed JSON" 'not json at all'
assert_silent "fail-open: empty stdin" ''
assert_silent "fail-open: JSON with no tool_input" '{"tool_name":"Write"}'

nojq_out="$(printf '%s' "$(envelope Write /tmp/proj/a.js '// increment the counter
counter++;')" | PATH="$NOJQ" "$BASH_BIN" "$HOOK" 2>/dev/null)"; nojq_rc=$?
if [ "$nojq_rc" -eq 0 ] && [ -z "$nojq_out" ]; then
  pass "fail-open: no jq on PATH"
else
  fail "fail-open: no jq on PATH" "exit $nojq_rc, output: $nojq_out"
fi

# ---- 4. never blocks ----------------------------------------------------------------
if grep -qE 'permissionDecision|"decision"|hookSpecificOutput' "$HOOK"; then
  fail "hook emits no blocking JSON" "found a blocking key in $HOOK"
else
  pass "hook emits no blocking JSON"
fi

printf '\n'
[ "$rc" -eq 0 ] && printf 'comment-discipline-hook-tests: all cases passed\n' \
               || printf 'comment-discipline-hook-tests: FAILURES above\n'
exit "$rc"
