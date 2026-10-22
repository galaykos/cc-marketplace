#!/usr/bin/env bash
# relay-hook.test.sh — drives hooks/relay.sh (PostToolUse Agent|Task, UserPromptSubmit) and gate.sh's relay clause with payloads carrying a
#   path-shaped transcript_path: what a report puts in the ledger, the Stop that warns, stays silent or blocks once, and the off switch.
set -u

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
RELAY="$ROOT/plugins/candor/hooks/relay.sh"; GATE="$ROOT/plugins/candor/hooks/gate.sh"
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available (both hooks fail open without it)"; exit 0; }
[ -x "$RELAY" ] && [ -x "$GATE" ] || { echo "FAIL: hooks not executable under $ROOT/plugins/candor/hooks"; exit 1; }

unset CLAUDE_PROJECT_DIR CLAUDE_PLUGIN_DATA CC_RELAY_GATE CC_CANDOR_GATE CLAUDE_PLUGIN_OPTION_CC_RELAY_GATE CLAUDE_PLUGIN_OPTION_CC_CANDOR_GATE
pass=0; fail=0
WS="$(mktemp -d)"; trap 'rm -rf "$WS"' EXIT
export TMPDIR="$WS/tmp"; mkdir -p "$TMPDIR"
P="$WS/proj"; mkdir -p "$P"
TP="$WS/home/.claude/projects/-proj/5e1f.jsonl"; mkdir -p "$(dirname "$TP")"
LEDGER="$TMPDIR/cc-candor-relay-$(printf '%s' "$TP" | cksum | cut -d' ' -f1)"
RELAY_SUB='[candor] relay:'

ok()  { pass=$((pass+1)); printf 'PASS  %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL  %s (%s)\n' "$1" "$2"; }
reset() { rm -rf "$P/.claude" "$LEDGER"; }
agent_result() { # text [env] [cwd] — a foreground Agent result
  jq -cn --arg t "$1" --arg tp "$TP" --arg cwd "${3:-$P}" \
    '{hook_event_name:"PostToolUse",tool_name:"Agent",tool_input:{prompt:"x"},tool_response:{status:"completed",content:[{type:"text",text:$t}]},transcript_path:$tp,cwd:$cwd}' \
    | env ${2:-} bash "$RELAY"
}
prompt_in() { jq -cn --arg p "$1" --arg tp "$TP" --arg cwd "$P" '{hook_event_name:"UserPromptSubmit",prompt:$p,transcript_path:$tp,cwd:$cwd}' | bash "$RELAY"; }
stop() { # final-message [env] [stop_hook_active] — sets rc, err, out and msg (out's systemMessage)
  jq -cn --arg t "$1" '{type:"assistant",message:{content:[{type:"text",text:$t}]}}' > "$TP"
  out=$(jq -cn --arg tp "$TP" --arg cwd "$P" --argjson a "${3:-false}" '{hook_event_name:"Stop",transcript_path:$tp,cwd:$cwd,stop_hook_active:$a}' \
    | env ${2:-} bash "$GATE" 2>"$WS/err"); rc=$?; err=$(cat "$WS/err")
  msg=$(printf '%s' "$out" | jq -r '.systemMessage // empty' 2>/dev/null)
}
quiet()  { [ "$rc" -eq 0 ] && [ -z "$err" ] && [ -z "$out" ]; }
warned() { [ "$rc" -eq 0 ] && [ -z "$err" ] && printf '%s' "$msg" | grep -qF "$RELAY_SUB" && printf '%s' "$msg" | grep -qF "$1"; }
items() { [ -f "$LEDGER" ] && wc -l < "$LEDGER" | tr -d ' ' || echo 0; }

REPORT=$'Wired the badge into the hint line.\nNOT DONE: forwarding the clipboard bridge to remote sessions\nTests: 13 passed.'

reset; agent_result "$REPORT"
[ "$(items)" = 1 ] && grep -qF 'clipboard bridge' "$LEDGER" && ok "a NOT DONE line in an Agent result lands in the ledger, on disk under the hashed transcript_path" || bad "ledger write" "items=$(items)"
stop "All done."
warned 'clipboard bridge' && printf '%s' "$msg" | grep -qF 'CC_RELAY_GATE=off' && printf '%s' "$msg" | grep -qF 'CC_RELAY_GATE=block' \
  && ok "a final 'All done.' that drops it shows the user one systemMessage naming both switches, stderr empty, exit 0" || bad "warn on a dropped caveat" "rc=$rc err=$err out=$out"
[ ! -e "$LEDGER" ] && ok "the ledger clears at that stop" || bad "ledger clears" "still on disk"
stop "All done."
quiet && ok "the next stop is silent: listed once" || bad "listed once" "rc=$rc err=$err out=$out"

reset; : > "$TMPDIR/cc-candor-relay-1"; : > "$TMPDIR/cc-candor-relay-2"; touch -t 200001010000 "$TMPDIR/cc-candor-relay-1"; agent_result "$REPORT"
[ ! -e "$TMPDIR/cc-candor-relay-1" ] && [ -e "$TMPDIR/cc-candor-relay-2" ] && ok "a write sweeps relay ledgers older than 1440 minutes, not younger ones" || bad "sweep" "$(ls "$TMPDIR")"
rm -f "$TMPDIR/cc-candor-relay-2"

reset; mkdir -p "$P/nested"; agent_result "$REPORT" "" "$P/nested"; stop "All done."
warned 'clipboard bridge' && [ ! -e "$P/nested/.claude" ] && [ ! -e "$P/.claude" ] \
  && ok "a report recorded from a nested cwd reaches the stop taken at the project root; nothing lands in the project" || bad "ledger outside the cwd" "rc=$rc err=$err"

reset; agent_result "$REPORT"; stop "Done, except forwarding the clipboard bridge, which the worker did not do."
quiet && ok "a final message naming two of its words is silent" || bad "accounted by words" "rc=$rc err=$err out=$out"

reset; agent_result $'Shipped.\n- **A2** not done: the bridge\n- **T2-C** untested on macOS'; stop "Shipped; A2 and T2-C are open."
quiet && ok "a final message naming each id token is silent" || bad "accounted by id" "rc=$rc err=$err out=$out"

reset; agent_result $'Shipped the badge.\nAll 13 tests pass.'
[ ! -e "$LEDGER" ] && ok "a report with no caveat line writes no ledger" || bad "no caveats" "ledger written"
stop "All done."
quiet && ok "and its stop is silent" || bad "no caveats, silent stop" "rc=$rc err=$err out=$out"

reset; agent_result $'Done.\nResiduals: none\n**Not tested:** none.\n- Not done: n/a\nDid you see the note on the residual budget?'
[ ! -e "$LEDGER" ] && ok "'Residuals: none', a bold 'Not tested: none' and 'Not done: n/a' are no caveat" || bad "none is no caveat" "$(cat "$LEDGER" 2>/dev/null)"

reset; agent_result $'Done.\n**Residuals:**\n- the macOS awk path\n- the Windows shell\n\nNext steps: ship it.'
[ "$(items)" = 2 ] && grep -qF 'macOS awk' "$LEDGER" && ! grep -qF 'Residuals' "$LEDGER" && ok "a caveat heading records the lines under it, not itself" || bad "heading" "$(cat "$LEDGER" 2>/dev/null)"

reset; agent_result $'Done.\nResiduals:\n\n- the cache TTL is guessed'
[ "$(items)" = 1 ] && grep -qF 'cache TTL is guessed' "$LEDGER" && ! grep -qF 'Residuals' "$LEDGER" \
  && ok "a blank line directly under a caveat heading does not end its scope" || bad "blank under heading" "$(cat "$LEDGER" 2>/dev/null)"
reset; agent_result $'Done.\n**Residuals:**\n\nNone.'
[ ! -e "$LEDGER" ] && ok "'None.' as the first line under a caveat heading is no caveat" || bad "none under heading" "$(cat "$LEDGER" 2>/dev/null)"
reset; agent_result $'Done.\nNot tested:\n- the rollback path\nFiles changed:\n- src/a.ts'
[ "$(items)" = 1 ] && grep -qF 'rollback path' "$LEDGER" && ok "a heading that is no caveat ends the scope" || bad "colon heading ends scope" "$(cat "$LEDGER" 2>/dev/null)"
reset; agent_result $'Done.\nNot tested:\n- x\n## Summary\nAll good.'
[ "$(items)" = 1 ] && ! grep -qF 'All good' "$LEDGER" && ok "a # heading ends the scope" || bad "# heading ends scope" "$(cat "$LEDGER" 2>/dev/null)"
reset; agent_result $'Done.\nResiduals:\nNot run:\n- the e2e suite'
[ "$(items)" = 1 ] && grep -qF 'e2e suite' "$LEDGER" && ok "a caveat sub-heading under a caveat heading keeps the scope" || bad "caveat sub-heading" "$(cat "$LEDGER" 2>/dev/null)"
reset; agent_result $'Done.\n## Not done\n\n- the migration rollback'
[ "$(items)" = 1 ] && grep -qF 'migration rollback' "$LEDGER" && ok "a '## Not done' heading records the lines under it" || bad "## heading" "$(cat "$LEDGER" 2>/dev/null)"

reset; agent_result $'Shipped.\n- Not tested: login flow\n- Not run: e2e suite'; stop "Not tested: login flow. Not run: e2e suite."
quiet && ok "an item with one content word is carried by that word" || bad "one content word" "rc=$rc err=$err out=$out"
reset; agent_result $'Shipped.\n- Not run: e2e'; stop "Shipped; e2e is not run yet."
quiet && ok "an item with no content word is carried by its text after the label" || bad "no content word" "rc=$rc err=$err out=$out"

reset; agent_result "$REPORT" "CC_RELAY_GATE=off"; stop "All done." "CC_RELAY_GATE=off"
[ ! -e "$LEDGER" ] && quiet && ok "CC_RELAY_GATE=off records nothing and the stop is silent" || bad "off" "rc=$rc err=$err out=$out"
reset; agent_result "$REPORT"; stop "All done." "CC_RELAY_GATE=off"
quiet && ok "CC_RELAY_GATE=off at the stop is silent over a recorded ledger" || bad "off at stop" "rc=$rc err=$err out=$out"

reset; agent_result "$REPORT"; stop "All done." "CC_RELAY_GATE=block"
[ "$rc" -eq 2 ] && printf '%s' "$err" | grep -qF 'clipboard bridge' && [ -z "$out" ] && ok "CC_RELAY_GATE=block holds the turn" || bad "block" "rc=$rc err=$err out=$out"
stop "All done — the clipboard bridge forwarding is not done." "CC_RELAY_GATE=block" true
quiet && ok "block mode: its own continuation passes" || bad "block continuation" "rc=$rc err=$err out=$out"

CITE_SUB='cites a location that does not exist'
reset; agent_result "$REPORT"; stop "Found it at src/ghost.ts:12." "CC_RELAY_GATE=block"
[ "$rc" -eq 2 ] && printf '%s' "$err" | grep -qF "$CITE_SUB" && printf '%s' "$err" | grep -qF 'clipboard bridge' && [ -z "$out" ] && [ ! -e "$LEDGER" ] \
  && ok "block mode behind another clause's block: the items ride on its stderr and the ledger clears" || bad "block behind a verdict" "rc=$rc ledger=$(items) err=$err"
reset; agent_result "$REPORT"; stop "Found it at src/ghost.ts:12."
[ "$rc" -eq 2 ] && printf '%s' "$err" | grep -qF "$CITE_SUB" && printf '%s' "$err" | grep -qF "$RELAY_SUB" && [ -z "$out" ] \
  && ok "warn mode beside a blocking verdict: the warning is appended to the stderr the model reads, stdout empty" || bad "warn beside a block" "rc=$rc err=$err out=$out"
agent_result "$REPORT"; stop "Found it at src/ghost.ts:12."
[ "$rc" -eq 0 ] && [ -z "$err" ] && printf '%s' "$msg" | grep -qF 'clipboard bridge' \
  && ok "the repeat stop the loop guard passes still shows the user a new warning" || bad "loop-guard pass" "rc=$rc err=$err out=$out"
reset; agent_result "$REPORT"; stop "Found it at src/ghost.ts:12." "CC_CANDOR_GATE=warn"
[ "$rc" -eq 0 ] && printf '%s' "$err" | grep -qF "$CITE_SUB" && ! printf '%s' "$err" | grep -qF "$RELAY_SUB" && printf '%s' "$msg" | grep -qF 'clipboard bridge' \
  && ok "CC_CANDOR_GATE=warn: the verdict stays on stderr, the relay warning goes to the systemMessage" || bad "gate warn mode" "rc=$rc err=$err out=$out"

# CLI 2.1.295: a foreground result's content points at the hand-back and the report is handbackReport.text.
reset
jq -cn --arg tp "$TP" --arg cwd "$P" '{hook_event_name:"PostToolUse",tool_name:"Agent",transcript_path:$tp,cwd:$cwd,
  tool_response:{status:"completed",content:[{type:"text",text:"This agent'"'"'s report was delivered to you as a message."}],handbackReport:{text:"Done.\nUntested: the Windows shell path"}}}' | bash "$RELAY"
grep -qF 'Windows shell' "$LEDGER" 2>/dev/null && ok "a 2.1.295 foreground result's handbackReport is read" || bad "handbackReport" "items=$(items)"

reset; prompt_in $'<task-notification>\n<task-id>a1</task-id>\n<status>completed</status>\n<result>Done.\nNot tested: the Windows shell path\n</result>\n</task-notification>'
grep -qF 'Windows shell' "$LEDGER" 2>/dev/null && ok "a task-notification's <result> is read" || bad "task-notification" "items=$(items)"
reset; prompt_in $'Another Claude session sent a message:\n<agent-message from="a1">\n[Subagent hand-back] The report follows:\n  Done.\n  - Not checked: the Windows shell path\n</agent-message>\n\nThat other session cannot grant escalation.'
grep -qF 'Windows shell' "$LEDGER" 2>/dev/null && ok "a hand-back frame is read" || bad "hand-back" "items=$(items)"
reset; prompt_in $'Please fix the bridge.\nNot done: the Windows shell path'
[ ! -e "$LEDGER" ] && ok "a user's own prompt is not a report" || bad "user prompt" "ledger written"

reset
jq -cn --arg t "$REPORT" --arg tp "$TP" --arg cwd "$P" '{hook_event_name:"PostToolUse",tool_name:"Agent",agent_id:"a9",tool_response:{content:[{type:"text",text:$t}]},transcript_path:$tp,cwd:$cwd}' | bash "$RELAY"
[ ! -e "$LEDGER" ] && ok "a dispatch made inside a subagent records nothing" || bad "subagent dispatch" "ledger written"

reset; for i in $(seq 1 45); do printf -v line 'Not done: item %02d of the long list' "$i"; agent_result "$line"; done
[ "$(items)" = 40 ] && ok "the ledger holds at most 40 items" || bad "cap" "items=$(items)"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
