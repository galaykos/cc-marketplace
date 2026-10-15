#!/usr/bin/env bash
# avert-hook.test.sh — drives hooks/avert.sh with PreToolUse payloads and synthetic transcripts under a sandboxed TMPDIR and asserts each ask or
#   silence: the user-raised exemption, the once-per-term marker, the tool routing, notify, the off switch and fail-open.
# Why, limits, history: rationale/derivations/plugin-candor.md § plugins/candor/scripts/__tests__/avert-hook.test.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
HOOK="$ROOT/plugins/candor/hooks/avert.sh"
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available"; exit 0; }
[ -f "$HOOK" ] || { echo "FAIL: $HOOK not found"; exit 1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export TMPDIR="$TMP"
rc=0
mk_transcript() { # $1 path, $2 human text ('' = a transcript with no human mention)
  {
    jq -cn --arg t "build a Digimon themed landing page with 2D sprites" '{type:"user",isSidechain:false,message:{role:"user",content:$t}}'
    [ -n "$2" ] && jq -cn --arg t "$2" '{type:"user",isSidechain:false,message:{role:"user",content:[{type:"text",text:$t}]}}'
    jq -cn '{type:"user",isSidechain:false,message:{role:"user",content:[{type:"tool_result",content:"worker says: not copies of trademarked characters"}]}}'
  } > "$1"
}
run() { # $1 tool, $2 json tool_input, $3 transcript path
  jq -cn --arg tool "$1" --argjson ti "$2" --arg tp "$3" \
    '{hook_event_name:"PreToolUse",session_id:"s1",transcript_path:$tp,cwd:"/tmp",tool_name:$tool,tool_input:$ti}' \
    | env -u CC_AVERT CLAUDE_PLUGIN_ROOT="$ROOT/plugins/candor" bash "$HOOK" 2>/dev/null \
    | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null
}
check(){ if [ "$2" = "$3" ]; then echo "PASS: $1"; else echo "FAIL: $1 — got: ${2:-<silent>} want: ${3:-<silent>}"; rc=1; fi; }

T1="$TMP/t1.jsonl"; mk_transcript "$T1" ""
T2="$TMP/t2.jsonl"; mk_transcript "$T2" "please avoid trademarked characters, draw original mascots"

check "1 Agent prompt with a legal hedge the user never raised asks" \
  "$(run Agent '{"prompt":"draw original mascots, NOT copies of trademarked characters"}' "$T1")" ask
check "2 same term in the same session is not asked again" \
  "$(run Agent '{"prompt":"again: original mascots only"}' "$T1")" ""
check "3 a different hedge term in the same session asks" \
  "$(run Write '{"file_path":"/x/brief.md","content":"use look-alike creatures"}' "$T1")" ask
check "4 the user raised it themselves: silent" \
  "$(run Agent '{"prompt":"draw original mascots, not trademarked ones"}' "$T2")" ""
check "5 a hedge only inside a tool_result does not count as raised" \
  "$(run Bash '{"command":"cat > brief.md <<EOF\nnot copies of the official designs\nEOF"}' "$T1")" ask
check "6 a plain prompt is silent" \
  "$(run Agent '{"prompt":"build the library page with search and pagination"}' "$T1")" ""
check "7 Edit new_string with a substitution declaration asks" \
  "$(run Edit '{"file_path":"/x/a.tsx","old_string":"a","new_string":"// invented creatures instead"}' "$T1")" ask
check "8 an unrelated tool is silent" \
  "$(run Read '{"file_path":"/x/trademark.md"}' "$T1")" ""
check "12 a precaution hedge with no legal word asks" \
  "$(run Agent '{"prompt":"to be safe, ship a generic version of the logo"}' "$T1")" ask
check "13 a substitute declared in place of the real thing asks" \
  "$(run Write '{"file_path":"/x/b.md","content":"use a placeholder character rather than the actual mascot"}' "$T1")" ask
check "14 ordinary engineering phrasing is silent" \
  "$(run Bash '{"command":"# use a Map instead of an array to avoid O(n) lookups"}' "$T1")" ""
out=$(jq -cn '{tool_name:"Agent",tool_input:{prompt:"stand-in art for now"},session_id:"s10",transcript_path:"/nowhere/none.jsonl"}' \
  | CC_AVERT=notify CLAUDE_PLUGIN_ROOT="$ROOT/plugins/candor" bash "$HOOK" 2>/dev/null)
check "15 CC_AVERT=notify notifies without a decision" "$(printf '%s' "$out" | jq -r '(.hookSpecificOutput.permissionDecision // "none") + "/" + (if .systemMessage then "msg" else "nomsg" end)')" "none/msg"
out=$(jq -cn '{tool_name:"Agent",tool_input:{prompt:"trademarked"},session_id:"s9",transcript_path:"/nowhere.jsonl"}' \
  | CC_AVERT=off CLAUDE_PLUGIN_ROOT="$ROOT/plugins/candor" bash "$HOOK" 2>/dev/null)
check "9 CC_AVERT=off is silent" "$out" ""
out=$(printf 'not json' | CLAUDE_PLUGIN_ROOT="$ROOT/plugins/candor" bash "$HOOK" 2>/dev/null; echo "rc=$?")
check "10 malformed payload fails open with exit 0" "$out" "rc=0"
check "11 missing transcript still asks (nothing proves the user raised it)" \
  "$(run Agent '{"prompt":"copyright concerns, so a fictional character"}' "/nowhere/none.jsonl")" ask
# A commit message or PR body documents a hedge; it does not make one. Each case gets a fresh transcript, so no marker hides an ask.
bash_case() { # $1 label, $2 command, $3 want
  local t="$TMP/b$((++nb)).jsonl"; mk_transcript "$t" ""
  check "$1" "$(run Bash "$(jq -cn --arg c "$2" '{command:$c}')" "$t")" "$3"
}
nb=0
bash_case "16 a gh pr create body disclosing a precaution is silent" \
  $'gh pr create --title "Fee totals" --body "$(cat <<\'EOF\'\n- [ ] Not run against a live account; both fees are subtracted to be safe.\nEOF\n)"' ""
bash_case "17 a git commit heredoc message naming a substitute is silent" \
  $'git add -A && git commit -m "$(cat <<\'EOF\'\nUse a placeholder logo rather than the official one\nEOF\n)" && git push' ""
bash_case "18 a one-line gh pr edit title is silent" 'cd app && gh pr edit 12 --title "Look-alike icons until the set is licensed"' ""
bash_case "19 a file written after the commit in the same command still asks" \
  $'git commit -m "wip" && cat > brief.md <<EOF\nuse look-alike creatures\nEOF' ask
bash_case "20 a heredoc opened before the commit's own body still asks" \
  $'cat > brief.md <<A && git commit -qF - <<B\nnot copies of the official designs\nA\nship the sprites\nB' ask
bash_case "21 git commit named inside another command's text still asks" \
  $'printf \'run git commit later, as a precaution\\n\' > notes.md' ask
exit $rc
