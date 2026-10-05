#!/bin/bash
# preamble.sh (UserPromptSubmit, SubagentStart; payload on stdin) — adds candor's five working moves as context: once per session, on the
#   first prompt whose head has a making verb in an imperative clause; once per agent_id on SubagentStart, after recording the worker in flight.
# Off: CC_PREAMBLE=off silences the text, never the in-flight record; it does not answer to CC_REMIND. Unset, the /config option cc_preamble decides.
#   Advisory: context cannot block. Fails open: without jq it does nothing; it always exits 0.
# Misses: a work session opened with a question, until its first imperative prompt; a compaction drops the text and it is not re-sent.
# Why, limits, history: rationale/derivations/plugin-candor.md § plugins/candor/hooks/preamble.sh

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

MARKER_TTL_MIN=1440

{
  command -v jq >/dev/null 2>&1 || exit 0

  input=$(cat)
  event=$(printf '%s' "$input" | jq -r '.hook_event_name // "UserPromptSubmit"' 2>/dev/null) || exit 0
  if [ "$event" = "SubagentStart" ]; then
    aid=$(printf '%s' "$input" | jq -r '.agent_id // empty' 2>/dev/null)
    sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
    # 180 minutes is gate.sh's INFLIGHT_TTL_MIN; a worker killed without a SubagentStop is only ever swept by age.
    for d in "${TMPDIR:-/tmp}"/cc-candor-inflight-*; do
      [ -d "$d" ] && [ -O "$d" ] || continue
      find "$d" -type f -mmin +180 -delete 2>/dev/null
      rmdir "$d" 2>/dev/null
    done
    if [ -n "$aid" ] && [ -n "$sid" ]; then
      d="${TMPDIR:-/tmp}/cc-candor-inflight-$(printf '%s' "$sid" | cksum | cut -d' ' -f1)"
      mkdir -p -m 700 "$d" 2>/dev/null \
        && printf '%s\n' "$aid" > "$d/$(printf '%s' "$aid" | cksum | cut -d' ' -f1)" 2>/dev/null
    fi
  fi

  [ "$(cc_option CC_PREAMBLE on)" = "off" ] && exit 0
  if [ "$event" = "SubagentStart" ]; then
    ctx="$aid"
  else
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  [ -n "$prompt" ] || exit 0
  case "$prompt" in /*) exit 0 ;; esac # a slash command carries its own procedure

  scrub=$(printf '%s' "$prompt" | awk '/^```/{f=!f; next} !f' | sed 's/`[^`]*`//g')
  head=$(printf '%s' "$scrub" | tr '\n' ' ' | cut -c1-400 | tr 'A-Z' 'a-z')
  verbs='\b(build|create|add|implement|develop|rewrite|refactor|fix|update|change|write)\b'
  clauses=$(printf '%s' "$head" | awk '{gsub(/\?/," __Q__\n"); gsub(/\. /,"\n"); print}')
  printf '%s\n' "$clauses" | grep -qiE "$verbs" || exit 0
  printf '%s\n' "$clauses" | grep -iE "$verbs" \
    | grep -qvE '(__Q__|^[[:space:]]*(can|could|should|would|shall|is|are|was|were|do|does|did|am|will|what|why|how|when|where|which|who|whether)[^a-z])' \
    || exit 0

  ctx=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // empty' 2>/dev/null)
  fi
  [ -n "$ctx" ] || exit 0
  key=$(printf '%s' "$ctx" | cksum | cut -d' ' -f1)
  find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'cc-preamble-*' -type d -mmin +"$MARKER_TTL_MIN" -exec rmdir {} + 2>/dev/null
  mkdir "${TMPDIR:-/tmp}/cc-preamble-$key" 2>/dev/null || exit 0

  jq -cn --arg m 'candor: five moves before the first edit, this session. (1) Make the smallest change that satisfies the ask; anything more needs a trigger named in place — the user asked, a stated criterion, an observed defect — or is left out; an unasked feature or file admitted afterwards is not a trigger. Add no code comment unless it states what the code cannot; a CLAUDE.md house style wins. (2) Prove it through the surface the user will use — the browser, the live endpoint, the real host — never only a double you wrote: it encodes your guess and cannot disagree with you. (3) A green run that predates your last edit, or ran under your own background load, is not evidence; run it again. (4) Before stating a limitation (a tool missing, a host unreachable), run the command that checks it. (5) The final message names what is untested, what you cut, and what the user must configure.' \
    --arg e "$event" '{hookSpecificOutput:{hookEventName:$e,additionalContext:$m}}' 2>/dev/null
} 2>/dev/null
exit 0
