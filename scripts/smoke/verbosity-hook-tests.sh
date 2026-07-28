#!/usr/bin/env bash
# Smoke tests for the comment-discipline verbosity PostToolUse hook.
#
# The hook measures assistant-text characters per tool call over the session
# transcript and emits ONE additionalContext warning when the session is an
# outlier (threshold 600 chars/call; see the hook header for the calibration).
# These cases drive it with synthetic transcripts + canned PostToolUse stdin and
# assert the emitted envelope, the exemptions, and the once-per-session bound.
#
# It must NEVER block: every case asserts rc 0.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$ROOT/plugins/comment-discipline/hooks/verbosity.sh"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available (hook fails open without it)"; exit 0; }
[ -f "$HOOK" ] || { echo "FAIL: hook missing at $HOOK"; exit 1; }

pass=0; fail=0
WS="$(mktemp -d)"; trap 'rm -rf "$WS"' EXIT
CWD="$WS/proj"; mkdir -p "$CWD" "$WS/subagents"

# build <file> <tool-calls> <chars-per-text> <text-blocks> [total-lines]
# Pads with user rows so the transcript clears the hook's 60-line cheap gate.
build() {
  local f="$1" calls="$2" chars="$3" texts="$4" pad="${5:-70}"
  jq -cn --argjson calls "$calls" --argjson chars "$chars" \
        --argjson texts "$texts" --argjson pad "$pad" '
    [ range($calls) | {type:"assistant",message:{content:[{type:"tool_use",name:"Read"}]}} ]
    + [ range($texts) | {type:"assistant",message:{content:[{type:"text",text:("x"*$chars)}]}} ]
    | . + [ range([0, $pad - length] | max) | {type:"user",message:{content:"noise"}} ]
    | .[]' > "$f"
}

# check <desc> <transcript> <session-id> <expect: warn|silent>
check() {
  local desc="$1" tf="$2" sid="$3" expect="$4" out rc ok=1
  out=$(jq -cn --arg tp "$tf" --arg cwd "$CWD" --arg sid "$sid" \
          '{transcript_path:$tp,cwd:$cwd,session_id:$sid}' \
        | bash "$HOOK" 2>/dev/null); rc=$?
  [ "$rc" -eq 0 ] || ok=0                       # warn-only: never blocks, ever
  case "$expect" in
    warn)   printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext' >/dev/null 2>&1 || ok=0 ;;
    silent) [ -z "$out" ] || ok=0 ;;
  esac
  if [ "$ok" -eq 1 ]; then pass=$((pass+1)); printf 'PASS  %s\n' "$desc"
  else fail=$((fail+1)); printf 'FAIL  %s (rc=%s out=%s)\n' "$desc" "$rc" "$out"; fi
}

# 1. Terse session: 4000 chars over 20 calls = 200/call, below p90 -> silent.
build "$WS/terse.jsonl" 20 200 20
check "terse session is silent"                  "$WS/terse.jsonl" s1 silent

# 2. At the median (155/call, the measured p50) -> silent.
build "$WS/median.jsonl" 20 155 20
check "median-ratio session is silent"           "$WS/median.jsonl" s2 silent

# 3. Just under the threshold (590/call) -> silent. Guards off-by-one drift.
build "$WS/under.jsonl" 10 590 10
check "just under threshold is silent"           "$WS/under.jsonl" s3 silent

# 4. Outlier: 1000/call, above every observed main-thread session -> warn.
build "$WS/verbose.jsonl" 10 1000 10
check "outlier session warns"                    "$WS/verbose.jsonl" s4 warn

# 5. Once per session: the same session, still an outlier -> silent.
check "second call in warned session is silent"  "$WS/verbose.jsonl" s4 silent

# 6. A DIFFERENT session with the same transcript still warns (state is per-session).
check "fresh session id warns again"             "$WS/verbose.jsonl" s5 warn

# 7. Subagent transcripts are exempt — narration is their return contract.
build "$WS/subagents/a.jsonl" 10 1000 10
check "subagent transcript is exempt"            "$WS/subagents/a.jsonl" s6 silent

# 8. Too few tool calls to judge (3 < 8) -> silent, however wordy.
build "$WS/few.jsonl" 3 5000 10
check "under 8 tool calls is silent"             "$WS/few.jsonl" s7 silent

# 9. Transcript shorter than the 60-line cheap gate -> silent.
build "$WS/short.jsonl" 10 1000 10 0
check "short transcript is silent"               "$WS/short.jsonl" s8 silent

# 10. Missing transcript -> fail open, silent.
check "missing transcript fails open"            "$WS/nope.jsonl" s9 silent

# 11. Malformed (non-JSONL) transcript -> fail open, silent.
head -c 4000 /dev/zero | tr '\0' 'z' > "$WS/junk.jsonl"
printf '\n%.0s' $(seq 1 70) >> "$WS/junk.jsonl"
check "malformed transcript fails open"          "$WS/junk.jsonl" s10 silent

# 12. Missing cwd/session_id in the payload -> fail open, silent.
out=$(jq -cn --arg tp "$WS/verbose.jsonl" '{transcript_path:$tp}' | bash "$HOOK" 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ]; then pass=$((pass+1)); printf 'PASS  payload without cwd/session_id fails open\n'
else fail=$((fail+1)); printf 'FAIL  payload without cwd/session_id (rc=%s out=%s)\n' "$rc" "$out"; fi

# --- ledger (13-15) --------------------------------------------------------
# Every scan is recorded, warned or not — the measurement trail. HOME is redirected
# so these cases never touch the real ledger.
LEDGER_HOME="$WS/home"; LEDGER="$LEDGER_HOME/.claude/comment-discipline/verbosity-ledger.jsonl"
ledger_run() { # transcript  session-id
  jq -cn --arg tp "$1" --arg cwd "$CWD" --arg sid "$2" \
     '{transcript_path:$tp,cwd:$cwd,session_id:$sid}' \
    | env HOME="$LEDGER_HOME" bash "$HOOK" >/dev/null 2>&1
}
ledger_run "$WS/verbose.jsonl" L1
if [ -s "$LEDGER" ] && jq -e '.warned == true and .ratio == 1000' "$LEDGER" >/dev/null 2>&1
then pass=$((pass+1)); printf 'PASS  ledger records a warned scan\n'
else fail=$((fail+1)); printf 'FAIL  ledger records a warned scan (%s)\n' "$(cat "$LEDGER" 2>/dev/null)"; fi

ledger_run "$WS/terse.jsonl" L2
if [ "$(wc -l < "$LEDGER" 2>/dev/null | tr -d ' ')" = "2" ] \
   && jq -se 'last | .warned == false' "$LEDGER" >/dev/null 2>&1
then pass=$((pass+1)); printf 'PASS  ledger also records a silent (below-threshold) scan\n'
else fail=$((fail+1)); printf 'FAIL  ledger also records a silent scan (%s)\n' "$(cat "$LEDGER" 2>/dev/null)"; fi

# An exempt path must leave no row at all — the ledger records scans, not calls.
ledger_run "$WS/subagents/a.jsonl" L3
if [ "$(wc -l < "$LEDGER" 2>/dev/null | tr -d ' ')" = "2" ]
then pass=$((pass+1)); printf 'PASS  exempt transcript writes no ledger row\n'
else fail=$((fail+1)); printf 'FAIL  exempt transcript writes no ledger row (%s rows)\n' "$(wc -l < "$LEDGER" 2>/dev/null)"; fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
