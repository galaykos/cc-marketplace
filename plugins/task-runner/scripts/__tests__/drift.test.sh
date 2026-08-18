#!/usr/bin/env bash
# Fixture tests for hooks/drift.sh — the ad-hoc complement to scope.sh.
#
# THE POSITIVE CASE IS NOT OPTIONAL, and this harness exists because of that. An earlier
# draft piped transcript lines through jq's `fromjson` — which wants a JSON-encoded
# STRING, while transcript lines are JSON OBJECTS — so every line was discarded and the
# hook was silent on every input. All three silence fixtures passed. Only the fixture that
# demands it FIRE caught it. A suite of silence assertions cannot tell correct suppression
# from a dead hook.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$ROOT/hooks/drift.sh"
[ -f "$HOOK" ] || { echo "FAIL: hook not found at $HOOK"; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq unavailable"; exit 0; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
rc=0
pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n      %s\n' "$1" "$2"; rc=1; }

# $1 ask, $2 file count -> transcript path
# A COUNTER, not mktemp: `mktemp "$TMP/t.XXXXXX.jsonl"` needs its X's at the END of the
# template, so on macOS the first call created a file named literally t.XXXXXX.jsonl and
# every later call failed with "File exists", returning an empty path. Every silence
# assertion then passed because the hook exited early on a missing transcript — green
# because the fixture was broken. Exactly the vacuous-assertion failure this suite exists
# to catch elsewhere.
_n=0
mk() {
  _n=$((_n + 1))
  local tp="$TMP/t$_n.jsonl"
  printf '{"type":"user","message":{"role":"user","content":%s}}\n' "$(jq -Rn --arg a "$1" '$a')" > "$tp"
  local i; for i in $(seq 1 "$2"); do
    printf '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Edit","input":{"file_path":"/p/mod%s.ts"}}]}}\n' "$i" >> "$tp"
  done
  printf '%s' "$tp"
}
fire() { # $1 transcript, $2 cwd
  python3 -c 'import json,sys
print(json.dumps({"hook_event_name":"PostToolUse","tool_name":"Edit","cwd":sys.argv[2],
 "session_id":"11111111-2222-3333-4444-555555555555","transcript_path":sys.argv[1],
 "tool_input":{"file_path":"/p/x.ts"}}))' "$1" "$2" \
    | bash "$HOOK" 2>/dev/null | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null
}

# ---- 1. FIRES: many files, none named, narrow ask ---------------------------------------
c="$TMP/cwd$_n"; mkdir -p "$c"
out="$(fire "$(mk 'fix the login page title' 20)" "$c")"
case "$out" in *"20 files edited"*"20 of them not named"*) pass "fires on wide drift from a narrow ask" ;;
  *) fail "fires on wide drift from a narrow ask" "got: ${out:-<silent>}" ;; esac
case "$out" in *"Breadth is not wrongness"*) pass "asks a question rather than rendering a verdict" ;;
  *) fail "asks a question rather than rendering a verdict" "got: ${out:-<silent>}" ;; esac

# ---- 2. SILENT below the measured floor -------------------------------------------------
# p90 of 169 real edit-turns is 12. 8 is ordinary work, not drift.
c="$TMP/cwd$_n"; mkdir -p "$c"
out="$(fire "$(mk 'fix the login page title' 8)" "$c")"
[ -z "$out" ] && pass "silent below the measured p90 floor" || fail "silent below the measured p90 floor" "$out"

# ---- 3. SILENT when the request ASKED for breadth ---------------------------------------
for ask in 'rename User to Account everywhere' 'migrate the whole codebase to strict mode' 'update all the files'; do
  c="$TMP/cwd$_n"; mkdir -p "$c"
  out="$(fire "$(mk "$ask" 20)" "$c")"
  [ -z "$out" ] && pass "silent when the ask requests breadth: ${ask:0:28}" \
    || fail "silent when the ask requests breadth: ${ask:0:28}" "$out"
done

# ---- 4. SILENT when the files were named in the ask -------------------------------------
named="update"; for i in $(seq 1 20); do named="$named mod$i.ts"; done
c="$TMP/cwd$_n"; mkdir -p "$c"
out="$(fire "$(mk "$named" 20)" "$c")"
[ -z "$out" ] && pass "silent when the ask names the files" || fail "silent when the ask names the files" "$out"

# ---- 5. SILENT when a declared scope exists — scope.sh owns that turn --------------------
c="$TMP/cwd$_n"; mkdir -p "$c"; mkdir -p "$c/.claude/task-runner"
echo '{"allow":[]}' > "$c/.claude/task-runner/scope.json"
out="$(fire "$(mk 'fix the login page title' 20)" "$c")"
[ -z "$out" ] && pass "silent when scope.json exists (no two voices on one lane)" \
  || fail "silent when scope.json exists (no two voices on one lane)" "$out"

# ---- 6. bounded per REQUEST, and a new request may speak again --------------------------
c="$TMP/cwd-bound"; mkdir -p "$c"; tp="$(mk 'fix the login page title' 20)"
a="$(fire "$tp" "$c")"; b="$(fire "$tp" "$c")"
if [ -n "$a" ] && [ -z "$b" ]; then pass "one question per request, not per edit"
else fail "one question per request, not per edit" "first='${a:0:30}' second='${b:0:30}'"; fi
if [ -n "$(find "$c/.claude/task-runner" -name 'drift-*' -type f 2>/dev/null)" ]
then pass "the marker lands on disk (key hashed, not a raw path)"
else fail "the marker lands on disk (key hashed, not a raw path)" "none under $c"; fi
printf '{"type":"user","message":{"role":"user","content":"now fix the footer"}}\n' >> "$tp"
for i in $(seq 21 40); do
  printf '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Edit","input":{"file_path":"/p/mod%s.ts"}}]}}\n' "$i" >> "$tp"
done
[ -n "$(fire "$tp" "$c")" ] && pass "a NEW request in the same session may speak again" \
  || fail "a NEW request in the same session may speak again" "stayed silent"

# ---- 7. FAIL-OPEN and off switches -------------------------------------------------------
printf '' | bash "$HOOK" >/dev/null 2>&1 && pass "empty stdin exits 0" || fail "empty stdin exits 0" "non-zero"
printf 'not json' | bash "$HOOK" >/dev/null 2>&1 && pass "malformed stdin exits 0" || fail "malformed stdin exits 0" "non-zero"
c="$TMP/cwd$_n"; mkdir -p "$c"
out="$(CC_DRIFT=off bash -c 'python3 -c "import json,sys
print(json.dumps({\"hook_event_name\":\"PostToolUse\",\"tool_name\":\"Edit\",\"cwd\":sys.argv[2],\"transcript_path\":sys.argv[1],\"tool_input\":{\"file_path\":\"/p/x.ts\"}}))" "$1" "$2" | bash "$0"' "$HOOK" "$(mk 'fix the login page title' 20)" "$c")"
[ -z "$out" ] && pass "CC_DRIFT=off silences it" || fail "CC_DRIFT=off silences it" "$out"
# No transcript at all: nothing to compare the work against, so say nothing.
out="$(python3 -c 'import json;print(json.dumps({"hook_event_name":"PostToolUse","tool_name":"Edit","cwd":"/tmp","session_id":"s","tool_input":{"file_path":"/p/x.ts"}}))' | bash "$HOOK" 2>/dev/null)"
[ -z "$out" ] && pass "no transcript: silent rather than guessing" || fail "no transcript: silent rather than guessing" "$out"

printf '\n'
[ "$rc" -eq 0 ] && printf 'drift.test: all cases passed\n' || printf 'drift.test: FAILURES above\n'
exit "$rc"
