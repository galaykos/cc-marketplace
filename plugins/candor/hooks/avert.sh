#!/bin/bash
# Absolute-path shebang, as the other candor hooks: fail-open must hold under a stripped PATH.
#
# PreToolUse on Agent, Write, Edit, MultiEdit and Bash: the text the model is about to
# hand a worker or write to disk is scanned for a HEDGE the user never raised — a legal
# or substitution reason for doing less than what was named. On a hit, the call is
# turned into a permission question ("ask"), once per hedge term per session.
#
# WHY THIS EXISTS (2026-09-18). Asked for "a landing page with 2D Sprites … Digimon
# themed", the orchestrating session wrote into its sprite worker's brief: "original
# mascots in a Digimon-like style, NOT copies of trademarked characters". No prompt of
# the user's had said trademark, copyright or original; the project's own library page
# already showed the real artwork. The swap surfaced once, in the final message, under
# "cut". The user's read: "there was intent for aversion, is it possible to assist with
# it?" There was, and it is: the intent left its reason in text the model wrote, and the
# reason's vocabulary is small. The preamble's move 1 (0.4.4) says the rule; this is the
# one place a script can see the act before a worker starts on it.
#
# WHAT IT CATCHES. A dispatch prompt, file content, edit text or shell command that
# names a legal hedge (trademark, copyright, infringe, licensing concern, legal risk) or
# declares a substitute (original/invented/made-up mascots|characters|designs,
# "not copies of", "look-alike", "inspired by"), when NO human turn in this session's
# transcript contains that term. If the user said "trademark" themselves, the hedge is
# theirs and the hook is silent.
#
# WHAT IT DOES NOT CATCH (honest scope). An avert that never names its reason — a
# quietly smaller target with no hedge word — passes; that half is agent-graded
# (drift-review clauses c and e, the preamble's move 1). A hedge phrased outside this
# vocabulary passes. Inside a subagent the "user" turn is the orchestrator's dispatch,
# so a hedge the orchestrator already wrote reads as raised and the hook is silent
# there — by design: the guard sits at the dispatch, which is where the avert is made.
#
# STANDING: gate on the CALL — `ask` hands the decision to the user; in a
# non-interactive session it is a deny. CC_AVERT=notify downgrades it to a notification
# (the call proceeds, the user and the model both see the line). Vocabulary-bound, so a
# guard, not a proof. Off switch: CC_AVERT=off. Fail-open on missing jq, missing
# transcript, bad payload.
{
  command -v jq >/dev/null 2>&1 || exit 0
  [ "${CC_AVERT:-}" = "off" ] && exit 0

  input=$(cat)
  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  case "$tool" in
    Agent|Task) text=$(printf '%s' "$input" | jq -r '.tool_input.prompt // empty' 2>/dev/null); what="dispatch prompt" ;;
    Write)      text=$(printf '%s' "$input" | jq -r '.tool_input.content // empty' 2>/dev/null); what="file" ;;
    Edit)       text=$(printf '%s' "$input" | jq -r '.tool_input.new_string // empty' 2>/dev/null); what="edit" ;;
    MultiEdit)  text=$(printf '%s' "$input" | jq -r '[.tool_input.edits[]?.new_string // empty] | join(" ")' 2>/dev/null); what="edit" ;;
    Bash)       text=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null); what="command" ;;
    *) exit 0 ;;
  esac
  [ -n "$text" ] || exit 0

  # Three clusters, one act — doing less than what was named for a reason the user did
  # not give: (a) the reason is legal/IP; (b) a substitute is declared (original, invented,
  # generic, placeholder, stand-in, look-alike, inspired-by) in place of the real/named
  # thing; (c) precaution language ("to be safe", "as a precaution", "to avoid any …").
  # Common engineering phrases ("instead of X use Y", "avoid N+1") are deliberately NOT
  # matched: the substitute cluster needs a substitute noun, the precaution cluster a
  # safety/rights object.
  hedge='trademark|copyright|infring|licen[cs](e|ing) (concern|risk|issue|reason)|legal(ly)? (risk|reason|concern|safe|issue)|(original|invented|made-up|fictional|generic|placeholder|stand-in) (mascot|character|creature|design|version|substitute|logo|brand|name|asset|art)s?|not (a )?cop(y|ies) of|look-?alike|inspired[- ]by|(instead of|rather than|in place of) (the |any )?(real|actual|official|licensed|branded|named) |(to (be|stay|play it) safe|as a precaution|to (avoid|sidestep|steer clear of) (any |the )?(legal|licen|copyright|trademark|ip |brand|rights|infring))'
  term=$(printf '%s' "$text" | grep -oiE "$hedge" | head -1)
  [ -n "$term" ] || exit 0
  stem=$(printf '%s' "$term" | tr 'A-Z' 'a-z' | cut -c1-8)

  transcript=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
  if [ -n "$transcript" ] && [ -f "$transcript" ]; then
    # Human turns only: string content, or the text items of a content array (tool
    # results are `tool_result` items and are skipped, so a worker's report cannot
    # launder a hedge into "the user said it").
    jq -r 'select(.type=="user" and (.isSidechain|not)) | .message.content
           | if type=="string" then . else ([.[]? | select(.type=="text") | .text] | join(" ")) end' \
       "$transcript" 2>/dev/null | grep -qiF "$stem" && exit 0
  fi

  ctx="${transcript:-$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)}"
  [ -n "$ctx" ] || exit 0
  key=$(printf '%s|%s' "$ctx" "$stem" | cksum | cut -d' ' -f1)
  find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'cc-avert-*' -type d -mmin +1440 -exec rmdir {} + 2>/dev/null
  mkdir "${TMPDIR:-/tmp}/cc-avert-$key" 2>/dev/null || exit 0

  reason="candor: this $what adds a hedge the user never raised (\"$term\") — doing less than what they named is their call, not yours. Ask them first, or proceed only if they already decided it; the next call with this term is not asked again. CC_AVERT=off disables this guard for the session; CC_AVERT=notify downgrades it to a notification."
  if [ "${CC_AVERT:-}" = "notify" ]; then
    jq -cn --arg r "$reason" '{systemMessage:$r,hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$r}}' 2>/dev/null
  else
    jq -cn --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}' 2>/dev/null
  fi
} 2>/dev/null
exit 0
