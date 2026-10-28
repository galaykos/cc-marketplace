#!/bin/bash
# PreToolUse on Agent, Task, Write, Edit, MultiEdit, Bash: asks the user, once per term per session, before a call whose text names a legal hedge, a declared substitute or precaution language that no human turn contains; a Bash git commit message or gh pr create|edit body is not read.
# Misses a hedge outside its vocabulary, an avert that never names its reason, a hedge a subagent's dispatch already wrote; asks when the transcript is missing, and an ask is a deny in -p. No jq or a bad payload: silent. CC_AVERT=off disables, =notify notifies instead; unset, /config cc_avert.
# Why, limits, history: rationale/derivations/plugin-candor.md § plugins/candor/hooks/avert.sh

# Shared block templates/blocks/option-resolver.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/option-resolver.md
# cc_option <ENV_NAME> <default> [<level-file>] prints, status 0, the first non-empty of: variable ENV_NAME,
# <level-file>'s first word, option CLAUDE_PLUGIN_OPTION_<ENV_NAME> (true/false as on/off), <default>.
# The host exports only SAVED options, so <default> must equal the manifest's default.
# Misses: a malformed name, which yields <default>; a variable passed instead of a literal name; a value outside the vocabulary.
cc_option() {
  local v="" opt
  case "${1:-}" in '' | [0-9]* | *[!A-Za-z0-9_]*) printf '%s\n' "${2:-}"; return 0 ;; esac
  v="${!1:-}"
  if [ -z "$v" ] && [ -n "${3:-}" ] && [ -f "$3" ] && [ -r "$3" ]; then
    read -r v _ 2>/dev/null < "$3" || :
  fi
  if [ -z "$v" ]; then
    opt="CLAUDE_PLUGIN_OPTION_$1"; v="${!opt:-}"
    case "$v" in true) v=on ;; false) v=off ;; esac
  fi
  [ -n "$v" ] || v="${2:-}"
  printf '%s\n' "$v"
  return 0
}

MARKER_TTL_MIN=1440

# A commit message or PR body records a hedge already made: drop a git commit or gh pr create|edit span to the next ; & | or line end, and the heredoc bodies it opens; a ; & | inside the quoted message leaves the rest scanned (it asks).
unbody() {
  LC_ALL=C awk 'BEGIN { qi = 1 }
    # Quoted text as _, length kept, so a << inside a quoted message opens nothing; a "$( reads the rest of the line unquoted.
    function mask(s,   i, c, q, m) {
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (q == "") { if (c == "\"" || c == "\047") q = c }
        else if (c == q || q == "\"" && c == "$" && substr(s, i + 1, 1) == "(") q = ""
        else { if (c == "\\" && q == "\"") { m = m "_"; i++ }; c = "_" }
        m = m c
      }
      return m
    }
    function queue(s, cut,   w, m) {
      m = mask(s)
      while (match(m, /<<<?-?[ \t]*["\047]?[A-Za-z0-9_.-]+/)) {
        w = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH); m = substr(m, RSTART + RLENGTH)
        if (substr(w, 3, 1) == "<") continue
        q[++nq] = w; qd[nq] = (substr(w, 3, 1) == "-"); qx[nq] = cut; sub(/^<<-?[ \t]*["\047]?/, "", q[nq])
      }
    }
    qi <= nq {
      u = $0; if (qd[qi]) sub(/^\t+/, "", u)
      if (u == q[qi]) { held = ""; qi++; next }
      if (qx[qi]) held = held $0 "\n"; else print
      next
    }
    {
      s = $0; out = ""
      while (match(s, /(^|[;&|(])[ \t]*(git([ \t]+-[cC][ \t]+[^ \t;&|]+|[ \t]+-[^ \t;&|]+)*[ \t]+commit|gh[ \t]+pr[ \t]+(create|edit))([ \t;&|)]|$)/)) {
        k = RSTART + index(substr(s, RSTART, RLENGTH), "g") - 1
        out = out substr(s, 1, k - 1) " "; queue(substr(s, 1, k - 1), 0)
        s = substr(s, k); e = match(s, /[;&|]/)
        queue(e ? substr(s, 1, e - 1) : s, 1); s = e ? substr(s, e) : ""
      }
      queue(s, 0); print out s
    }
    END { printf "%s", held }'
}

{
  command -v jq >/dev/null 2>&1 || exit 0
  [ "$(cc_option CC_AVERT on)" = "off" ] && exit 0

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

  # "instead of X use Y" and "avoid N+1" stay silent: "instead of" needs the real or official thing, "to avoid" a legal or rights object.
  hedge='trademark|copyright|infring|licen[cs](e|ing) (concern|risk|issue|reason)|legal(ly)? (risk|reason|concern|safe|issue)|(original|invented|made-up|fictional|generic|placeholder|stand-in) (mascot|character|creature|design|version|substitute|logo|brand|name|asset|art)s?|not (a )?cop(y|ies) of|look-?alike|inspired[- ]by|(instead of|rather than|in place of) (the |any )?(real|actual|official|licensed|branded|named) |(to (be|stay|play it) safe|as a precaution|to (avoid|sidestep|steer clear of) (any |the )?(legal|licen|copyright|trademark|ip |brand|rights|infring))'
  term=$(printf '%s' "$text" | grep -oiE "$hedge" | head -1)
  [ -n "$term" ] || exit 0
  if [ "$tool" = Bash ]; then
    term=$(printf '%s\n' "$text" | unbody | grep -oiE "$hedge" | head -1)
    [ -n "$term" ] || exit 0
  fi
  stem=$(printf '%s' "$term" | tr 'A-Z' 'a-z' | cut -c1-8)

  transcript=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
  if [ -n "$transcript" ] && [ -f "$transcript" ]; then
    # Human turns only: a tool_result is skipped, so a worker's report cannot launder a hedge into "the user said it".
    jq -r 'select(.type=="user" and (.isSidechain|not)) | .message.content
           | if type=="string" then . else ([.[]? | select(.type=="text") | .text] | join(" ")) end' \
       "$transcript" 2>/dev/null | grep -qiF "$stem" && exit 0
  fi

  ctx="${transcript:-$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)}"
  [ -n "$ctx" ] || exit 0
  key=$(printf '%s|%s' "$ctx" "$stem" | cksum | cut -d' ' -f1)
  find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'cc-avert-*' -type d -mmin +"$MARKER_TTL_MIN" -exec rmdir {} + 2>/dev/null
  mkdir "${TMPDIR:-/tmp}/cc-avert-$key" 2>/dev/null || exit 0

  reason="candor: this $what adds a hedge the user never raised (\"$term\") — doing less than what they named is their call, not yours. Ask them first, or proceed only if they already decided it; the next call with this term is not asked again. CC_AVERT=off disables this guard for the session; CC_AVERT=notify downgrades it to a notification."
  if [ "$(cc_option CC_AVERT on)" = "notify" ]; then
    jq -cn --arg r "$reason" '{systemMessage:$r,hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$r}}' 2>/dev/null
  else
    jq -cn --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}' 2>/dev/null
  fi
} 2>/dev/null
exit 0
