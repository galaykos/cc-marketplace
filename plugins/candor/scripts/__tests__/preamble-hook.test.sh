#!/usr/bin/env bash
# preamble-hook.test.sh — drives hooks/preamble.sh with UserPromptSubmit and SubagentStart payloads under a sandboxed TMPDIR and asserts when it
#   speaks (the first imperative work prompt, each new agent_id) and when it stays silent, its size bound, the off switch and fail-open.
# Why, limits, history: rationale/derivations/plugin-candor.md § plugins/candor/scripts/__tests__/preamble-hook.test.sh
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
clause='is not a trigger. Add no code comment unless it states what the code cannot; a CLAUDE.md house style wins. (2) '
check "19 the comment clause ends move (1) on UserPromptSubmit" "$(run 'build the importer' s10)" "$clause"
runsub() { # $1 agent_id, $2 agent_type — the SubagentStart payload the host sends (no prompt)
  jq -n --arg a "$1" --arg t "$2" \
    '{hook_event_name:"SubagentStart",session_id:"s-sub",transcript_path:"/nowhere/s-sub.jsonl",cwd:"/tmp",prompt_id:"p1",agent_id:$a,agent_type:$t}' \
    | env -u CC_PREAMBLE CLAUDE_PLUGIN_ROOT="$ROOT/plugins/candor" bash "$HOOK" 2>/dev/null
}
out=$(runsub ag1 general-purpose)
check "14 SubagentStart speaks with no prompt field" "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext // empty')" 'five moves'
check "15 SubagentStart names its own event" "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.hookEventName // empty')" 'SubagentStart'
check "20 the comment clause ends move (1) on SubagentStart" "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext // empty')" "$clause"
check "16 same agent_id is silent the second time" "$(runsub ag1 general-purpose)" ''
check "17 a second agent in the same session speaks" "$(runsub ag2 laravel:backend-engineer | jq -r '.hookSpecificOutput.additionalContext // empty')" 'five moves'
out=$(jq -n '{hook_event_name:"SubagentStart",session_id:"s-sub"}' | CLAUDE_PLUGIN_ROOT="$ROOT/plugins/candor" bash "$HOOK" 2>/dev/null; echo "rc=$?")
check "18 SubagentStart without agent_id fails open, silent" "$out" 'rc=0'
out=$(jq -n '{hook_event_name:"SubagentStart",session_id:"s-sub",transcript_path:"/nowhere/s-sub.jsonl",cwd:"/tmp",prompt_id:"p1",agent_id:"ag3",agent_type:"general-purpose"}' \
  | CC_PREAMBLE=off CLAUDE_PLUGIN_ROOT="$ROOT/plugins/candor" bash "$HOOK" 2>/dev/null)
check "21 CC_PREAMBLE=off is silent on SubagentStart" "$out" ''
# The read-only set is derived, not listed: an agent whose tools: hold neither Write nor Edit gets no text.
writable() { # agents/*.md -> status 0 when it can edit: no tools: key (it inherits every tool), or Write or Edit inline or as a YAML list
  local t
  t=$(awk '/^---/ { k++; next } k != 1 { next } l && /^[[:space:]]*-/ { printf " %s", $0; next } l { exit }
    /^tools:/ { l = 1; sub(/^tools:[[:space:]]*/, ""); printf "tools:%s", $0 }' "$1")
  case "$t" in '' | tools: | *Write* | *Edit*) return 0 ;; esac
  return 1
}
loud=""; quiet=""; n=0
for f in "$ROOT"/plugins/*/agents/*.md; do
  p=${f#"$ROOT"/plugins/}; t="${p%%/*}:$(basename "$f" .md)"; n=$((n + 1))
  got=$(runsub "ro$n" "$t" | jq -r '.hookSpecificOutput.additionalContext // empty')
  if writable "$f"; then [ -n "$got" ] || quiet="$quiet $t"
  else [ -z "$got" ] || loud="$loud $t"; fi
done
check "22 every marketplace agent with no Write or Edit gets no text ($n agents read)" "${loud:-none}" 'none'
check "23 every marketplace agent with Write or Edit still gets the five moves" "${quiet:-none}" 'none'
check "24 the built-in Explore gets no text" "$(runsub ro-ex Explore)" ''
check "25 the built-in Plan gets no text" "$(runsub ro-pl Plan)" ''
rec=$(cat "$TMP"/cc-candor-inflight-*/* 2>/dev/null | grep -cx 'ro-ex')
check "26 a read-only agent still gets its in-flight record" "rec=$rec" 'rec=1'
loud=""
for t in verifier code-reviewer acme:security-reviewer acme:schema-expert other-plugin:researcher acme:Explore; do
  [ -n "$(runsub "other-$t" "$t" | jq -r '.hookSpecificOutput.additionalContext // empty')" ] || loud="$loud $t"
done
check "27 another source's agent sharing a skipped bare name still gets the five moves" "${loud:-none}" 'none'
A="$TMP/agents"; mkdir -p "$A"
printf -- '---\nname: bare\ndescription: x\n---\nbody\n' > "$A/bare.md"
printf -- '---\nname: listw\ndescription: x\ntools:\n  - Read\n  - Write\nmodel: inherit\n---\nbody\n' > "$A/listw.md"
printf -- '---\nname: listr\ndescription: x\ntools:\n- Read\n- Grep\nmodel: inherit\n---\nbody\n' > "$A/listr.md"
check "28 an agent with no tools: line counts as writable (it inherits Write and Edit)" "$(writable "$A/bare.md" && echo w)" 'w'
check "29 a YAML-list tools: naming Write counts as writable" "$(writable "$A/listw.md" && echo w)" 'w'
check "30 a YAML-list tools: of Read and Grep counts as read-only" "$(writable "$A/listr.md" || echo r)" 'r'
move2='cannot disagree with you. If the user said they will test it themselves, name what is untested and stop. (3) '
check "31 move (2) yields to a user who will test it themselves, on UserPromptSubmit" "$(run 'build the exporter' s11)" "$move2"
check "32 the same on SubagentStart" "$(runsub ag-m2 general-purpose | jq -r '.hookSpecificOutput.additionalContext // empty')" "$move2"
check "33 a hand-back frame with a making verb is silent" "$(run $'[Subagent hand-back]\nFixed the parser; update the docs next.' s12)" ''
check "34 the frame did not spend the session's one-shot" "$(run 'fix the login redirect bug' s12)" 'five moves'
check "35 a task notification is silent" "$(run '<task-notification><summary>fix applied</summary></task-notification>' s13)" ''
check "36 a making verb only inside a paste is silent" \
  "$(run $'<pasted_content id="p1">\nnpm WARN: run npm audit fix to update\n</pasted_content id="p1">\nwhat is this warning about' s14)" ''
check "37 an ask beside a paste still speaks" \
  "$(run $'<pasted_content id="p2">\nTypeError: x is undefined\n</pasted_content id="p2">\nfix this error in the importer' s15)" 'five moves'
check "38 the hand-back marker quoted mid-sentence is an ask" "$(run 'fix the parser that drops the [Subagent hand-back] line' s16)" 'five moves'
m=$(ls -d "$TMP"/cc-preamble-* 2>/dev/null | wc -l | tr -d ' ')
[ "$m" -ge 1 ] && echo "PASS: 13 marker is written under TMPDIR ($m)" || { echo "FAIL: 13 no marker written"; rc=1; }

exit $rc
