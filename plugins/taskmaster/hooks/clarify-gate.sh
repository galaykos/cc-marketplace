#!/bin/bash
# PreToolUse Edit|Write|MultiEdit: after a work-shaped prompt (remind.sh's cc-workprompt marker), refuses the main thread's first write,
# once, unless an AskUserQuestion call or a line opening `Assuming:` reached the transcript since. Fail-open; off: CC_CLARIFY_GATE=off, CC_REMIND=off.
# Misses: Bash writes; a turn that only delegates; any `Assuming:` line passes, even on an auth prompt; timestamps compare at whole seconds.
# Why, limits, history: rationale/derivations/plugin-taskmaster.md § plugins/taskmaster/hooks/clarify-gate.sh

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

{
  case "$(cc_option CC_CLARIFY_GATE block)" in block) : ;; *) exit 0 ;; esac
  case "$(cc_option CC_REMIND on)" in off) exit 0 ;; esac
  command -v jq >/dev/null 2>&1 || exit 0
  input=$(cat)
  sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null) || exit 0
  [ -n "$sid" ] || exit 0
  pending="${TMPDIR:-/tmp}/cc-workprompt-$(printf '%s' "$sid" | cksum | cut -d' ' -f1)"
  [ -d "$pending" ] || exit 0

  tp=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
  case "$tp" in */subagents/*) exit 0 ;; esac
  aid=$(printf '%s' "$input" | jq -r '.agent_id // empty' 2>/dev/null)
  [ -z "$aid" ] || exit 0
  [ -f "$tp" ] && [ -r "$tp" ] || exit 0
  since=$(stat -c %Y "$pending" 2>/dev/null || stat -f %m "$pending" 2>/dev/null)
  case "$since" in '' | *[!0-9]*) exit 0 ;; esac
  rmdir "$pending" 2>/dev/null || exit 0

  grep -F -e '"AskUserQuestion"' -e 'Assuming:' "$tp" 2>/dev/null | jq -R --argjson since "$since" '
    fromjson? | select(.type == "assistant")
    | select(((.timestamp // "") | sub("\\.[0-9]+"; "") | (try fromdateiso8601 catch 0)) >= $since)
    | .message.content[]?
    | select((.type == "tool_use" and .name == "AskUserQuestion")
        or (.type == "text" and ((.text // "") | test("(^|\n)[ \t>*_-]*Assuming:"))))' 2>/dev/null | grep -q . && exit 0

  jq -cn --arg r '[taskmaster] First code write after a work-shaped prompt, and since that prompt there is no AskUserQuestion call and no line starting `Assuming:`. Before re-applying this edit, ask one batched AskUserQuestion round on the open unknowns, or write one line starting `Assuming:` that names each decision you made for the user (in a hands-off goal run, the Assuming: line). CC_CLARIFY_GATE=off turns this gate off.' \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
} 2>/dev/null
exit 0
