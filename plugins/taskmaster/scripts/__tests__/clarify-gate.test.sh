#!/usr/bin/env bash
# Cases for hooks/clarify-gate.sh with its real producer, hooks/remind.sh: a work-shaped prompt arms the gate, and the first
# Edit/Write after it is refused unless an AskUserQuestion call or a line opening `Assuming:` landed in the transcript since.
# Not covered: the host's real transcript writer; the entries below copy the shapes of a 2026-10 transcript, not a live run.
set -u
cd "$(dirname "$0")/../../../.." || exit 1
PR="$PWD/plugins/taskmaster"
RM="$PR/hooks/remind.sh"
GT="$PR/hooks/clarify-gate.sh"
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not found"; exit 0; }
FX=$(mktemp -d); trap 'chmod -R u+w "$FX" 2>/dev/null; rm -rf "$FX"' EXIT
unset CC_CLARIFY_GATE CC_REMIND CLAUDE_PLUGIN_OPTION_CC_CLARIFY_GATE CLAUDE_PLUGIN_OPTION_CC_REMIND CLAUDE_PROJECT_DIR
export TMPDIR="$FX/tmp" CLAUDE_PLUGIN_ROOT="$PR"
mkdir -p "$TMPDIR" "$FX/cwd" "$FX/projects/-x/sess-1/subagents"
SUB="$FX/projects/-x/sess-1/subagents/agent-a1.jsonl"; : > "$SUB"
n=0
fresh() { n=$((n+1)); TX="$FX/projects/-x/sess-$n.jsonl"; : > "$TX"; } # one transcript per case: entries share a second
MK="$TMPDIR/cc-workprompt-$(printf '%s' sid-1 | cksum | cut -d' ' -f1)"
rc=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 — $2"; rc=1; }

now() { date -u +%Y-%m-%dT%H:%M:%S.000Z; }
prompt() { # text — the user entry, then the producer
  jq -nc --arg p "$1" --arg t "$(now)" '{type:"user",timestamp:$t,message:{role:"user",content:$p}}' >> "$TX"
  jq -nc --arg p "$1" --arg tp "$TX" --arg c "$FX/cwd" \
    '{hook_event_name:"UserPromptSubmit",session_id:"sid-1",transcript_path:$tp,cwd:$c,prompt:$p}' | bash "$RM" >/dev/null 2>&1
}
said() { # text [timestamp] [file] — an assistant text block
  jq -nc --arg x "$1" --arg t "${2:-$(now)}" '{type:"assistant",timestamp:$t,message:{role:"assistant",content:[{type:"text",text:$x}]}}' >> "${3:-$TX}"
}
asked() { # [timestamp] — an AskUserQuestion tool call
  jq -nc --arg t "${1:-$(now)}" '{type:"assistant",timestamp:$t,message:{role:"assistant",content:[{type:"tool_use",id:"tu1",name:"AskUserQuestion",
    input:{questions:[{question:"Which cache?",header:"Cache",options:[{label:"Redis"},{label:"In-process"}],multiSelect:false}]}}]}}' >> "$TX"
}
write() { # [transcript] [agent_id] — prints the gate's stdout
  jq -nc --arg tp "${1:-$TX}" --arg c "$FX/cwd" --arg a "${2:-}" \
    '{hook_event_name:"PreToolUse",session_id:"sid-1",transcript_path:$tp,cwd:$c,tool_name:"Write",
      tool_input:{file_path:"src/Cache.php",content:"<?php\n"}}
     + (if $a == "" then {} else {agent_id:$a,agent_type:"task-runner:task-executor"} end)' | bash "$GT" 2>/dev/null
}
denied() { # label output
  if [ "$(printf '%s' "$2" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null)" = deny ]; then
    pass "$1"
    printf '%s' "$2" | jq -r '.hookSpecificOutput.permissionDecisionReason' | grep -qF 'CC_CLARIFY_GATE=off' \
      && pass "$1: the reason names CC_CLARIFY_GATE=off" || fail "$1" "the reason does not name the off switch"
  else fail "$1" "not denied: [$2]"; fi
}
allowed() { # label output
  [ -z "$2" ] && pass "$1" || fail "$1" "spoke: $2"
}
WORK='add a caching layer to the user repository'

# ---- the reminder names both accepted forms and offers no other way out ------------------------
line=$(jq -nc --arg p "$WORK" --arg c "$FX/cwd" '{hook_event_name:"UserPromptSubmit",session_id:"sid-0",cwd:$c,prompt:$p}' \
  | TMPDIR="$FX/tmp0" bash -c 'mkdir -p "$TMPDIR"; bash "$0"' "$RM" 2>/dev/null)
for want in 'AskUserQuestion round' 'one line starting `Assuming:`' 'at a later fork the user has not answered, ask — do not default'; do
  printf '%s' "$line" | grep -qF -- "$want" && pass "the reminder says: $want" || fail "reminder" "missing '$want' in: $line"
done
printf '%s' "$line" | grep -qiE 'trivial|skip' && fail "reminder" "still offers a skip: $line" || pass "the reminder offers no trivial skip"

# ---- the default refuses: no evidence since the work prompt --------------------------------
fresh; prompt "$WORK"
[ -d "$MK" ] && pass "a work-shaped prompt arms the gate (marker on disk)" || fail "producer" "no marker at $MK"
out=$(write); denied "work prompt, Write with neither AskUserQuestion nor Assuming:, default settings" "$out"
[ -d "$MK" ] && fail "bound" "the marker survived the block" || pass "the block spent the marker"
allowed "second write after a block (bounded)" "$(write)"

# ---- the two accepted forms ------------------------------------------------------------------
fresh; prompt "$WORK"
said "Assuming: a per-request cache in the repository, no Redis."
allowed "an Assuming: line since the prompt" "$(write)"
[ -d "$MK" ] && fail "allow" "the marker survived an allowed write" || pass "an allowed write spends the marker too"

fresh; prompt "$WORK"
asked
allowed "an AskUserQuestion call since the prompt" "$(write)"

fresh; prompt "$WORK"
said "Plan, then code.
**Assuming:** the cache key is the user id."
allowed "an Assuming: line under markdown emphasis, not the first line" "$(write)"

# ---- what does not count ---------------------------------------------------------------------
fresh
asked "2020-01-01T00:00:00.000Z"
said "Assuming: from an older turn." "2020-01-01T00:00:01.000Z"
prompt "$WORK"
denied "evidence older than the work prompt does not count" "$(write)"

fresh; prompt "$WORK"
said "Assuming the cache is per-request, I will start with the repository."
denied "Assuming without the colon is not the line" "$(write)"

fresh; prompt "$WORK"
said "Note that I am Assuming: nothing yet."
denied "Assuming: mid-line is not a line starting Assuming:" "$(write)"

# ---- prompts after the work prompt -----------------------------------------------------------
fresh; prompt "$WORK"
prompt "what does the repository return on a miss?"
allowed "a later human prompt that is not work-shaped disarms the gate" "$(write)"
[ -d "$MK" ] && fail "disarm" "the marker survived a later human prompt" || pass "the later prompt removed the marker"

fresh; prompt "$WORK"
prompt "<task-notification><task-id>a1</task-id><status>completed</status></task-notification>"
denied "a harness frame after the work prompt leaves the gate armed" "$(write)"

# ---- a subagent's write is not judged and does not spend the marker ----------------------------
fresh; prompt "$WORK"
allowed "a subagent's write" "$(write "$SUB")"
[ -d "$MK" ] && pass "the subagent's write left the marker" || fail "subagent" "the marker was spent by a worker"
denied "the main thread's first write after the worker's" "$(write)"

fresh; prompt "$WORK"
allowed "a subagent's write on the parent's transcript_path (agent_id set)" "$(write "$TX" agent-b1)"
[ -d "$MK" ] && pass "the agent_id write left the marker" || fail "agent_id" "the marker was spent by a worker"
denied "the main thread's first write after the agent_id write" "$(write)"

# ---- off switches ----------------------------------------------------------------------------
fresh; prompt "$WORK"
allowed "CC_CLARIFY_GATE=off" "$(CC_CLARIFY_GATE=off write)"
allowed "option cc_clarify_gate off" "$(CLAUDE_PLUGIN_OPTION_CC_CLARIFY_GATE=off write)"
allowed "CC_REMIND=off" "$(CC_REMIND=off write)"
[ -d "$MK" ] && pass "an off switch leaves the marker untouched" || fail "off" "an off switch spent the marker"
rmdir "$MK" 2>/dev/null

# ---- fail-open -------------------------------------------------------------------------------
fresh; prompt "$WORK"
chmod a-w "$TMPDIR"
allowed "a marker that cannot be spent means no block" "$(write)"
chmod u+w "$TMPDIR"; rmdir "$MK" 2>/dev/null
fresh; prompt "$WORK"
allowed "an unreadable transcript means no block" "$(write "$FX/projects/-x/missing.jsonl")"
rmdir "$MK" 2>/dev/null
o=$(printf 'not json' | bash "$GT" 2>/dev/null); s=$?
[ "$s" -eq 0 ] && [ -z "$o" ] && pass "garbage input exits 0 with no output" || fail "garbage" "rc=$s out=$o"

[ "$rc" -eq 0 ] && echo "clarify-gate.test: all cases passed" || echo "clarify-gate.test: FAILURES above"
exit "$rc"
