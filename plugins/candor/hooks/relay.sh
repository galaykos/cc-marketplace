#!/bin/bash
# relay.sh (PostToolUse Agent|Task, UserPromptSubmit) — records the caveat lines (not done, untested, residual…, or the lines under such a heading) of a
#   foreground result, hand-back or task-notification <result> for gate.sh's relay clause, 40 at most. Off: CC_RELAY_GATE=off|CC_CANDOR_GATE=off. Prints nothing.
# Misses: a caveat phrased otherwise or mid-line; a nested worker's caveats; payload shapes read from transcripts, not probed live.
# Why, limits, history: rationale/derivations/plugin-candor.md § plugins/candor/hooks/relay.sh

# Shared block templates/blocks/option-resolver.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/option-resolver.md
# cc_option <ENV_NAME> <default> [<level-file>] prints, status 0, the first non-empty of: variable ENV_NAME,
# <level-file>'s first word, option CLAUDE_PLUGIN_OPTION_<ENV_NAME> (true/false as on/off), <default>.
# The host exports only SAVED options, so <default> must equal the manifest's default.
# A non-empty variable beats the option: the environment is shared, so one export before launch
# switches every plugin that reads it.
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

RELAY_MAX_ITEMS=40
LEDGER_TTL_MIN=1440

# Caveat lines of a report on stdin: at a line or bullet start, or after a **label**; a heading ("Residuals:") yields the lines under it.
relay_extract() {
  awk '
    function strip(s) { sub(/^[ \t>]+/, "", s); sub(/^#+[ \t]+/, "", s); sub(/^([-*+]|•|[0-9]+[.)]|\([a-z0-9]\))[ \t]+/, "", s); return s }
    function emit(s,   id, t) {
      t = tolower(s); sub(/^[*_ ]+/, "", t); sub(CAV "[a-z]*[*_ ]*[:.)—–-]*[*_ ]*", "", t)
      if (t ~ /^(none|n\/a|nothing)[.!]?[*_ ]*$/) return
      id = "-"; t = " " s " "
      if (match(t, "[^A-Za-z0-9_-]" ID "[^A-Za-z0-9_]")) id = substr(t, RSTART + 1, RLENGTH - 2)
      gsub(/\t/, " ", s)
      print id "\t" substr(s, 1, 100)
    }
    BEGIN {
      CAV = "^(not done|partial|not tested|untested|not checked|not run|residual|known miss|blocked|could not|did not|unverified|not verified)"
      ID = "[A-Z][A-Z]?[A-Z]?[A-Z]?-?[0-9][0-9]?[0-9]?(-[A-Z0-9][A-Z0-9]?[A-Z0-9]?)?"
    }
    /<\/agent-message>|<\/result>/ { exit }
    {
      hd = ($0 ~ /^[ \t>]*#+[ \t]/)
      body = strip($0)
      rest = body; lab = ""
      if (match(rest, /^\*\*[^*]+\*\*/)) {
        lab = substr(rest, 3, RLENGTH - 4); rest = substr(rest, RLENGTH + 1)
        sub(/^([ \t:.-]|—|–)+/, "", rest)
      }
      b = tolower(body); sub(/^(\*\*|__)/, "", b)
      cav = (b ~ CAV || (lab != "" && (tolower(lab) ~ CAV || tolower(rest) ~ CAV)))
      t = body; sub(/[ \t*_]+$/, "", t)
      if (under) {
        if (body ~ /^[ \t]*$/) { if (!took) next; under = 0 }
        else if (hd || lab != "" || (t ~ /:$/ && !cav) || ++under > 11) { under = 0; if (!took) emit(head) }
        else if (t ~ /:$/) next
        else { x = tolower(t); sub(/^[*_ ]+/, "", x)
               if (!took && x ~ /^(none|n\/a|nothing)[.!]?$/) { under = 0; next }
               emit(body); took = 1; next }
      }
      if (!cav) next
      t = body; sub(/[ \t]+$/, "", t)
      if (hd || t ~ /^\*\*[^*:]+:?\*\*[.:]?$/ || t ~ /:[*_]*$/) { under = 1; took = 0; head = body; next }
      emit(body)
    }
    END { if (under && !took) emit(head) }'
}

{
  command -v jq >/dev/null 2>&1 || exit 0
  input=$(cat)
  [ "$(cc_option CC_CANDOR_GATE block)" = off ] && exit 0
  [ "$(cc_option CC_RELAY_GATE warn)" = off ] && exit 0
  # A worker's own dispatches: no clause reads a subagent's ledger.
  [ -z "$(printf '%s' "$input" | jq -r '.agent_id // empty')" ] || exit 0
  case "$(printf '%s' "$input" | jq -r '.hook_event_name // empty')" in
    PostToolUse)
      # A foreground result; from CLI 2.1.295 its content points at the hand-back and the report sits in handbackReport.
      text=$(printf '%s' "$input" | jq -r '.tool_response
        | if type == "string" then .
          elif type == "array" then [.[]? | select(.type? == "text") | .text] | join("\n")
          elif type == "object" then ([.content[]? | select(.type? == "text") | .text] + [.handbackReport.text?, .result?]
                                      | map(select(type == "string")) | join("\n"))
          else empty end') ;;
    UserPromptSubmit)
      prompt=$(printf '%s' "$input" | jq -r '.prompt // empty')
      case "$prompt" in
        '<task-notification'*) text=$(printf '%s\n' "$prompt" | awk '/<result>/ { f = 1; sub(/.*<result>/, "") } f')
          [ -n "$text" ] || exit 0 ;;
        'Another Claude session sent a message:'* | '<agent-message'*) text=$prompt ;;
        *'[Subagent hand-back]'*) printf '%s\n' "$prompt" | grep -qE '^[*_[:space:]]*\[Subagent hand-back\]' || exit 0; text=$prompt ;;
        *) exit 0 ;;
      esac ;;
    *) exit 0 ;;
  esac
  items=$(printf '%s\n' "$text" | relay_extract)
  [ -n "$items" ] || exit 0

  ctx=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // empty')
  [ -n "$ctx" ] || exit 0
  # Under TMPDIR, not the state root: the payload cwd follows a cd, and the gate's would not; private, as /tmp is shared.
  umask 077
  find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'cc-candor-relay-*' -type f -mmin +"$LEDGER_TTL_MIN" -delete
  f="${TMPDIR:-/tmp}/cc-candor-relay-$(printf '%s' "$ctx" | cksum | cut -d' ' -f1)"
  have=0; [ -f "$f" ] && have=$(wc -l < "$f" | tr -d ' ')
  # Appends, not a rewrite: parallel workers' results can land at once; gate.sh drops repeats.
  [ "$have" -lt "$RELAY_MAX_ITEMS" ] && printf '%s\n' "$items" | head -n "$((RELAY_MAX_ITEMS - have))" >> "$f"
} 2>/dev/null
exit 0
