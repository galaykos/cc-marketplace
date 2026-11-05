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
bash_case "22 a <<WORD quoted in the commit message opens no heredoc" \
  $'git commit -m "handle <<EOF in parser" && cat > brief.md <<EOF\nuse look-alike creatures\nEOF' ask
bash_case "23 a <<< here-string in the commit span opens no heredoc" \
  $'git commit -qF - <<<EOF && cat > brief.md <<EOF\nuse look-alike creatures\nEOF' ask
# Retro 2026-11-05 issue 13: a topic term (legal, generic, look-alike, inspired-by) asks only beside a cut cue in its clause, and never in a memory note.
fresh() { # $1 label, $2 tool, $3 json tool_input, $4 want
  local t="$TMP/f$((++nf)).jsonl"; mk_transcript "$t" ""
  check "$1" "$(run "$2" "$3" "$t")" "$4"
}
nf=0
MEM=/home/u/.claude/projects/-g-little-sprito/memory/little-sprito-direction.md
KOS='Story will reuse public-domain Koschei the Deathless folklore (write original text; avoid copyrighted modern retellings/translations).'
fresh "24 a launch plan's to-do row naming a trademark check is silent" Write \
  "$(jq -cn '{file_path:"/x/design/reviews/launch-plan.md",content:"| Nov | Check \"Hoardling\" on both stores and as a trademark before store art uses it | Free |"}')" ""
fresh "25 a trademark reason beside a cut in the same clause asks" Write \
  "$(jq -cn '{file_path:"/x/design/reviews/launch-plan.md",content:"| Nov | Leave out the Hoardling name from store art over trademark doubts | Free |"}')" ask
fresh "26 a memory note recording the user's public-domain plan is silent" Edit \
  "$(jq -cn --arg f "$MEM" --arg s "$KOS" '{file_path:$f,old_string:"x",new_string:$s}')" ""
fresh "27 the same avoid-copyrighted clause in a project doc asks" Edit \
  "$(jq -cn --arg s "$KOS" '{file_path:"/x/docs/story-plan.md",old_string:"x",new_string:$s}')" ask
fresh "28 a substitute declared in a memory note still asks" Write \
  "$(jq -cn --arg f "$MEM" '{file_path:$f,content:"Original 2.5D beat-em-up in the genre of Little Fighter (not a recreation: original characters/data only)."}')" ask
bash_case "29 a heredoc of story credits saying inspired by is silent" \
  $'cat > Assets/Editor/CampaignStory.cs <<\'EOF\'\ncampaign.credits = string.Join("\\n", new[] {\n    "Story inspired by the public-domain Russian folk tales of",\n    "Koschei the Deathless, Marya Morevna, Baba Yaga and the Isle of Buyan.",\n});\nEOF' ""
bash_case "30 inspired by beside instead of in one clause asks" \
  $'cat > brief.md <<\'EOF\'\nWrite a story inspired by the folk tales instead of the user\'s draft.\nEOF' ask
fresh "31 a security probe for unicode look-alikes is silent" Agent \
  "$(jq -cn '{prompt:"Probe `app/Services/ArtDirection/SourceBlock.php` (delimiter defusing — try forged openers/closers, unicode look-alikes, nested runs, newlines inside url)."}')" ""
fresh "32 look-alike glyphs instead of the licensed font asks" Agent \
  "$(jq -cn '{prompt:"Use look-alike glyphs instead of the licensed font in the logo."}')" ask
bash_case "33 a React page finding about generic names is silent" \
  $'python3 - <<\'EOF\'\np = "src/admin/ReorderControls.tsx"\n# [26] low: row actions repeat generic names ("Move up", "Edit", "Delete") with no row name\nEOF' ""
fresh "34 generic design advice in a research brief, SKIP in another clause, is silent" Agent \
  "$(jq -cn '{prompt:"Mark each ADMIT (meets the bar above) or SKIP-model-knows (base model already does this unprompted; generic design advice usually fails the bar). Be honest."}')" ""
fresh "35 skip generic design advice in one clause asks" Agent \
  "$(jq -cn '{prompt:"Skip generic design advice and ship only the layout."}')" ask
bash_case "36 a chess test note on a legal safe reply is silent" \
  $'cat > acc-tests.txt <<\'EOF\'\n- Skip click pressed on a shop card: skip consumed at frame 204\n- No legal safe reply before a Fury turn: the two-move danger fired\nEOF' ""
# review of 0.12.1: the common "don't include" / "without the" cuts must still ask; a check that merely says doesn't stays silent
fresh "37 don't include beside trademarked in one clause asks" Agent \
  "$(jq -cn '{prompt:"Build the title screen. Don'"'"'t include the Zelda logo, it'"'"'s trademarked."}')" ask
fresh "38 without the logo since it is trademarked asks" Agent \
  "$(jq -cn '{prompt:"Ship the title screen without the Zelda logo since it is trademarked."}')" ask
fresh "39 a check that the name doesn't clash with a trademark is silent" Write \
  "$(jq -cn '{file_path:"/x/design/reviews/launch-plan.md",content:"Check the name doesn'"'"'t clash with a registered trademark."}')" ""
exit $rc
