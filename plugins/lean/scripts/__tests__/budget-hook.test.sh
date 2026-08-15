#!/usr/bin/env bash
# Fixtures for plugins/lean/hooks/budget.sh.
#
# WHY THIS EXISTS. The plugin's entire delivery claim is one sentence: the budget
# reaches SUBAGENTS, because PostToolUse is the only hook event that runs inside them
# and that is where a fan-out actually writes code. If the one-shot were keyed on the
# session id, a subagent sharing its parent's session would be silenced and the claim
# would be false while every other gate in this repo stayed green — the failure is
# invisible by construction. The load-bearing assertion below is therefore that TWO
# DIFFERENT transcripts under ONE session id each get the message exactly once.
#
# The second load-bearing assertion is fail-open. This hook runs on every Edit in every
# context; a non-zero exit or a stray stderr line on malformed input would wedge real
# runs for a reminder nobody asked to be blocked by.
set -u
cd "$(dirname "$0")/../../../.." || exit 1
H=plugins/lean/hooks/budget.sh
rc=0
FX=$(mktemp -d); trap 'rm -rf "$FX"' EXIT

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not found"; exit 0; }

# Isolate the once-per-context marker: the hook records "already fired" as a directory
# under $TMPDIR. Without a scratch TMPDIR these fixtures pass once and fail on re-run.
mkdir -p "$FX/tmp"
export TMPDIR="$FX/tmp"

fire() { # tool transcript session -> additionalContext (empty when silent)
  jq -nc --arg t "$1" --arg p "$2" --arg s "$3" \
    '{tool_name:$t,transcript_path:$p,session_id:$s}' \
  | bash "$H" 2>/dev/null | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null
}

# --- 1. fires on the first Edit of a context -------------------------------------
out=$(fire Edit /t/main.jsonl s1)
if [ -n "$out" ]; then echo "PASS: fires on first Edit"
else echo "FAIL: silent on first Edit"; rc=1; fi

# --- 2. the message carries the contract, not just a pointer ----------------------
for want in "debit" "smallest change" "trigger"; do
  if printf '%s' "$out" | grep -qF "$want"; then echo "PASS: message carries '$want'"
  else echo "FAIL: message missing '$want'"; rc=1; fi
done

# --- 3. one-shot per context ------------------------------------------------------
if [ -z "$(fire Edit /t/main.jsonl s1)" ]; then echo "PASS: silent on second Edit"
else echo "FAIL: repeated within one context"; rc=1; fi

# --- 4. THE DELIVERY CLAIM: a subagent sharing the parent's session still gets it --
if [ -n "$(fire Edit /t/subagents/a1.jsonl s1)" ]; then echo "PASS: subagent transcript fires under the parent session"
else echo "FAIL: subagent silenced by the parent's marker — the delivery claim is false"; rc=1; fi

# --- 5. scoped to writes ----------------------------------------------------------
if [ -z "$(fire Bash /t/other.jsonl s2)" ]; then echo "PASS: silent on a non-write tool"
else echo "FAIL: fired on Bash"; rc=1; fi

# --- 6. both off switches ---------------------------------------------------------
if [ -z "$(CC_LEAN=off fire Edit /t/off1.jsonl s3)" ]; then echo "PASS: CC_LEAN=off silences"
else echo "FAIL: CC_LEAN=off ignored"; rc=1; fi
if [ -z "$(CC_REMIND=off fire Edit /t/off2.jsonl s4)" ]; then echo "PASS: CC_REMIND=off silences"
else echo "FAIL: CC_REMIND=off ignored"; rc=1; fi

# --- 7. fail-open: malformed input exits 0 and says nothing on stderr -------------
for bad in 'not json' '' '{}' '{"tool_name":"Edit"}'; do
  err=$(printf '%s' "$bad" | bash "$H" 2>&1 >/dev/null); st=$?
  if [ "$st" -eq 0 ] && [ -z "$err" ]; then echo "PASS: fail-open on [${bad:-<empty>}]"
  else echo "FAIL: exit=$st stderr=[$err] on [${bad:-<empty>}]"; rc=1; fi
done

# --- 8. emits a well-formed PostToolUse envelope ----------------------------------
if jq -nc '{tool_name:"Edit",transcript_path:"/t/shape.jsonl"}' | bash "$H" 2>/dev/null \
   | jq -e '.hookSpecificOutput.hookEventName=="PostToolUse"' >/dev/null 2>&1; then
  echo "PASS: PostToolUse envelope"
else echo "FAIL: bad envelope"; rc=1; fi

# --- 9. the self-imposed message budget -------------------------------------------
# 300 bytes. Standing: this fixture is the only thing enforcing it — the repo's
# context-budget gate meters the whole dynamic CHANNEL, never this one line.
bytes=$(grep -o "lean: every line.*cost-model skill\." "$H" | tr -d '\n' | wc -c | tr -d ' ')
if [ "$bytes" -le 300 ] && [ "$bytes" -gt 0 ]; then echo "PASS: message $bytes bytes (<= 300)"
else echo "FAIL: message $bytes bytes, over the 300-byte budget"; rc=1; fi

exit $rc
