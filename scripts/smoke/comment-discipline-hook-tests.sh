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
  local desc="$1" out ctx
  out="$(run "$2")"
  if [ -z "$out" ]; then fail "$desc" "wanted a warning, got silence"; return; fi
  # The warning travels in the PostToolUse envelope — plain stdout never reaches the
  # model. Unwrap it before matching, the same way scope-hook.test.sh does.
  if ! printf '%s' "$out" | jq -e '.hookSpecificOutput.hookEventName == "PostToolUse"' >/dev/null 2>&1; then
    fail "$desc" "stdout is not a PostToolUse envelope: $out"; return
  fi
  ctx="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext // empty')"
  if [ -z "$ctx" ]; then fail "$desc" "envelope carries no additionalContext: $out"; return; fi
  out="$ctx"
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

# ---- 4. the PostToolUse lane never blocks --------------------------------------------
# `hookSpecificOutput`/`additionalContext` is the non-blocking context channel, not a
# veto. `decision` (Stop) is a blocking key this hook must never emit on any lane.
# `permissionDecision` used to be in this list too; it is now emitted, but ONLY on the
# PreToolUse lane and ONLY for the two blockable categories — asserted behaviorally in
# section 5 rather than by grepping the file, because the file-level assertion can no
# longer tell an emission from an emission on the correct lane.
# Comment lines are stripped first: the header *names* keys to describe them.
if grep -vE '^[[:space:]]*#' "$HOOK" | grep -qE '"decision"'; then
  fail "hook emits no Stop-blocking JSON" "found a Stop decision key in $HOOK"
else
  pass "hook emits no Stop-blocking JSON"
fi

# and it must still exit 0 on the firing path, not just the silent one
fire_rc_out="$(run "$(envelope Write /tmp/proj/a.js '// increment the counter
counter++;')")"; fire_rc=$?
if [ "$fire_rc" -eq 0 ] && [ -n "$fire_rc_out" ]; then
  pass "exits 0 while warning (never vetoes the edit)"
else
  fail "exits 0 while warning (never vetoes the edit)" "exit $fire_rc, output: $fire_rc_out"
fi
# PostToolUse never carries a permissionDecision, whatever the category.
if printf '%s' "$fire_rc_out" | grep -q 'permissionDecision'; then
  fail "PostToolUse lane carries no permissionDecision" "got: $fire_rc_out"
else
  pass "PostToolUse lane carries no permissionDecision"
fi

# ---- 5. the PreToolUse lane denies the blockable categories, once per file -----------
# Blockable = restatement of the next line, and commented-out code. Banners, bare TODOs
# and dead docblock tags stay warn-only: they are house-style calls.
STATE_DIR="$(mktemp -d)"
pre() { # session-id  file_path  added-text  -> stdout
  envelope Write "$2" "$3" \
    | python3 -c 'import json,sys
d=json.load(sys.stdin); d["hook_event_name"]="PreToolUse"
d["session_id"]=sys.argv[1]; d["cwd"]=sys.argv[2]; print(json.dumps(d))' "$1" "$STATE_DIR" \
    | "$BASH_BIN" "$HOOK" 2>/dev/null
}
assert_denies() { # desc  session  path  text
  local out; out="$(pre "$2" "$3" "$4")"
  if printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1
  then pass "$1"; else fail "$1" "wanted deny, got: $out"; fi
}
assert_allows() { # desc  session  path  text
  local out; out="$(pre "$2" "$3" "$4")"
  if [ -z "$out" ]; then pass "$1"; else fail "$1" "wanted silence, got: $out"; fi
}

assert_denies "PreToolUse denies a restatement comment" s1 /tmp/proj/a.js '// increment the counter
counter++;'
assert_allows "one-shot: same file again is allowed" s1 /tmp/proj/a.js '// increment the counter
counter++;'
assert_denies "one-shot is per FILE: a new file in the same session still denies" s1 /tmp/proj/b.js '// increment the counter
counter++;'
assert_denies "PreToolUse denies commented-out code" s2 /tmp/proj/c.js '// doThing(a, b);
doThing(a, c);'
assert_allows "PreToolUse does NOT deny a bare TODO (warn-only category)" s3 /tmp/proj/d.js '// TODO: revisit
const x = compute();'
assert_allows "PreToolUse does NOT deny a section banner (warn-only category)" s4 /tmp/proj/e.js '// ===== Helpers =====
const y = 2;'
assert_allows "PreToolUse is silent on a keep-case comment" s5 /tmp/proj/f.js '// Sorted before hashing: the vendor compares digests, not sets.
hash(sorted(items));'
assert_allows "generated-file header exempts the edit" s6 /tmp/proj/g.js '// @generated by tool — do not edit
// increment the counter
counter++;'
# The one-shot bound lives in a marker file. If that marker cannot be written, the
# deny is unbounded — it fires on attempt 1, 2, 3, forever, and the model can never
# satisfy or exhaust it. These two cases pin the withhold. Without them the plugin's
# central safety claim ("can never wedge a session") is unasserted prose.
UNWRITABLE="$(mktemp -d)"; mkdir -p "$UNWRITABLE/.claude"; chmod 555 "$UNWRITABLE/.claude"
wedge_out=""
for _ in 1 2 3; do
  wedge_out="$wedge_out$(envelope Write /tmp/proj/w.js '// increment the counter
counter++;' | python3 -c 'import json,sys
d=json.load(sys.stdin); d["hook_event_name"]="PreToolUse"; d["session_id"]="s90"
d["cwd"]=sys.argv[1]; print(json.dumps(d))' "$UNWRITABLE" | "$BASH_BIN" "$HOOK" 2>/dev/null)"
done
if [ -z "$wedge_out" ]; then pass "unwritable marker dir withholds the deny (no wedge)"
else fail "unwritable marker dir withholds the deny (no wedge)" "denied anyway: $wedge_out"; fi
chmod 755 "$UNWRITABLE/.claude"; rm -rf "$UNWRITABLE"

# No cwd at all: the marker path would resolve under / — unwritable on a sealed
# root, and wrong everywhere else. Withhold rather than deny unbounded.
nocwd_out=""
for _ in 1 2; do
  nocwd_out="$nocwd_out$(envelope Write /tmp/proj/x.js '// increment the counter
counter++;' | python3 -c 'import json,sys
d=json.load(sys.stdin); d["hook_event_name"]="PreToolUse"; d["session_id"]="s91"
d.pop("cwd", None)   # envelope() always sets one; this case is about its ABSENCE
print(json.dumps(d))' | "$BASH_BIN" "$HOOK" 2>/dev/null)"
done
if [ -z "$nocwd_out" ]; then pass "missing cwd withholds the deny (no wedge)"
else fail "missing cwd withholds the deny (no wedge)" "denied anyway: $nocwd_out"; fi

# Without a session_id the one-shot cannot be bounded, so the deny is withheld
# entirely rather than risking a loop. Built inline: the helper always sets the field.
nosid_out="$(envelope Write /tmp/proj/h.js '// increment the counter
counter++;' \
  | python3 -c 'import json,sys
d=json.load(sys.stdin); d["hook_event_name"]="PreToolUse"; d["cwd"]=sys.argv[1]; print(json.dumps(d))' "$STATE_DIR" \
  | "$BASH_BIN" "$HOOK" 2>/dev/null)"
if [ -z "$nosid_out" ]; then pass "no session_id: cannot bound the one-shot, so no deny"
else fail "no session_id: cannot bound the one-shot, so no deny" "got: $nosid_out"; fi
rm -rf "$STATE_DIR"

printf '\n'
[ "$rc" -eq 0 ] && printf 'comment-discipline-hook-tests: all cases passed\n' \
               || printf 'comment-discipline-hook-tests: FAILURES above\n'
exit "$rc"
