#!/usr/bin/env bash
# Smoke tests for candor/hooks/preamble.sh — the UserPromptSubmit (once per session) and
# SubagentStart (once per agent_id) hook that injects the five working moves before the
# first edit.
#
# WHY THIS FILE EXISTS. The hook's whole value is its trigger discipline: speak once
# on the first imperative work prompt, never again, never on a question, a slash
# command, or under CC_PREAMBLE=off. Each of those is a branch a one-character edit
# could remove while the happy path stays green. Picked up by the CI step that globs
# plugins/*/scripts/__tests__/*.test.sh.
set -u
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
HOOK="$ROOT/plugins/candor/hooks/preamble.sh"
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available"; exit 0; }
[ -f "$HOOK" ] || { echo "FAIL: $HOOK not found"; exit 1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export TMPDIR="$TMP" # markers land here, so every case starts clean and nothing leaks
rc=0

run() { # $1 prompt, $2 session — transcript_path supplied, as the host sends it
  jq -n --arg pr "$1" --arg s "$2" \
    '{hook_event_name:"UserPromptSubmit",session_id:$s,transcript_path:("/nowhere/"+$s+".jsonl"),cwd:"/tmp",prompt:$pr}' \
    | env -u CC_PREAMBLE CLAUDE_PLUGIN_ROOT="$ROOT/plugins/candor" bash "$HOOK" 2>/dev/null \
    | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null
}
check(){ # $1 label, $2 out, $3 want-substring ('' = must be silent)
  if [ -n "$3" ]; then case "$2" in *"$3"*) echo "PASS: $1"; return ;; esac
  else [ -z "$2" ] && { echo "PASS: $1"; return; }; fi
  echo "FAIL: $1 — got: ${2:-<silent>}"; rc=1
}

check "1 first imperative work prompt speaks" "$(run 'fix the login redirect bug' s1)" 'five moves before the first edit'
check "2 same session, second work prompt is silent" "$(run 'now add a test for it' s1)" ''
check "3 a new session speaks again" "$(run 'add a test for it' s2)" 'five moves'
check "4 a question with a making verb is silent" "$(run 'how do I add caching?' s3)" ''
check "5 a slash command is silent" "$(run '/code-architecture:coding-task fix the bug' s4)" ''
check "6 a prompt with no making verb is silent" "$(run 'what does this hook do' s5)" ''
check "7 a making verb only inside a fenced block is silent" "$(run $'look at this\n```\nfix me\n```' s6)" ''
check "8 mixed prompt: one imperative clause is enough" "$(run 'that looks wrong? fix the parser.' s7)" 'five moves'
out=$(jq -n '{prompt:"fix it",session_id:"s8",transcript_path:"/nowhere/s8.jsonl"}' \
  | CC_PREAMBLE=off CLAUDE_PLUGIN_ROOT="$ROOT/plugins/candor" bash "$HOOK" 2>/dev/null)
check "9 CC_PREAMBLE=off is silent" "$out" ''
out=$(printf '' | CLAUDE_PLUGIN_ROOT="$ROOT/plugins/candor" bash "$HOOK" 2>/dev/null; echo "rc=$?")
check "10 empty stdin fails open with exit 0" "$out" 'rc=0'
out=$(printf 'not json' | CLAUDE_PLUGIN_ROOT="$ROOT/plugins/candor" bash "$HOOK" 2>/dev/null; echo "rc=$?")
check "11 malformed payload fails open with exit 0" "$out" 'rc=0'
n=$(run 'implement the export' s9 | wc -c | tr -d ' ')
[ "$n" -gt 0 ] && [ "$n" -lt 1000 ] && echo "PASS: 12 payload stays under 1000 chars ($n)" || { echo "FAIL: 12 payload size $n"; rc=1; }
runsub() { # $1 agent_id, $2 agent_type — the SubagentStart payload the host sends (no prompt)
  jq -n --arg a "$1" --arg t "$2" \
    '{hook_event_name:"SubagentStart",session_id:"s-sub",transcript_path:"/nowhere/s-sub.jsonl",cwd:"/tmp",prompt_id:"p1",agent_id:$a,agent_type:$t}' \
    | env -u CC_PREAMBLE CLAUDE_PLUGIN_ROOT="$ROOT/plugins/candor" bash "$HOOK" 2>/dev/null
}
out=$(runsub ag1 general-purpose)
check "14 SubagentStart speaks with no prompt field" "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext // empty')" 'five moves'
check "15 SubagentStart names its own event" "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.hookEventName // empty')" 'SubagentStart'
check "16 same agent_id is silent the second time" "$(runsub ag1 general-purpose)" ''
check "17 a second agent in the same session speaks" "$(runsub ag2 laravel:backend-engineer | jq -r '.hookSpecificOutput.additionalContext // empty')" 'five moves'
out=$(jq -n '{hook_event_name:"SubagentStart",session_id:"s-sub"}' | CLAUDE_PLUGIN_ROOT="$ROOT/plugins/candor" bash "$HOOK" 2>/dev/null; echo "rc=$?")
check "18 SubagentStart without agent_id fails open, silent" "$out" 'rc=0'
m=$(ls -d "$TMP"/cc-preamble-* 2>/dev/null | wc -l | tr -d ' ')
[ "$m" -ge 1 ] && echo "PASS: 13 marker is written under TMPDIR ($m)" || { echo "FAIL: 13 no marker written"; rc=1; }

exit $rc
