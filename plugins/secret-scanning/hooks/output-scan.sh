#!/bin/bash
# PostToolUse and PostToolUseFailure on every tool: adds one context line naming the label of each hooks/patterns.tsv row with a non-placeholder match in the tool's output (its string fields, or the failure's error), never the value. Never blocks, never masks.
# Misses: output past 1 MiB, base64 fields, JSON keys, an assigned value whose directory part exists under the call's cwd (read as a path), what patterns.tsv misses; repeats on every call that shows a value. Fail-open, a malformed patterns.tsv included. Off: CC_SECRET_OUTPUT_SCAN=off; unset, /config decides.
# Why, limits, history: rationale/derivations/plugin-secret-scanning.md § plugins/secret-scanning/hooks/output-scan.sh

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

MAX_OUTPUT_BYTES=1048576
{
  [ "$(cc_option CC_SECRET_OUTPUT_SCAN on)" = off ] && exit 0
  command -v jq >/dev/null 2>&1 || exit 0
  input=$(cat)
  tool=""; event=""; cwd=""
  { IFS= read -r tool; IFS= read -r event; IFS= read -r cwd; } < <(printf '%s' "$input" | jq -r '.tool_name // "", .hook_event_name // "", .cwd // ""' 2>/dev/null)
  case "$event" in PostToolUse | PostToolUseFailure) ;; *) exit 0 ;; esac
  # Every string leaf, so a JSON-escaped quote never hides an assigned value; base64 media bytes stay out.
  text=$(printf '%s' "$input" | jq -r '[(.tool_response // .error // empty) | walk(if type == "object" then del(.base64) else . end) | .. | strings] | join("\n")' 2>/dev/null | head -c "$MAX_OUTPUT_BYTES")
  [ -n "$text" ] || exit 0

  pat_file="$(dirname "$0")/patterns.tsv"
  # Cheap exit before the validating load: most output matches no row. One alternation per flag, read as scan.sh's detect reads it.
  any_row() { awk -F'\t' -v f="$1" '/^#/ || NF != 4 || $1 == "placeholder" || $3 != f { next } { printf "%s(%s)", (n++ ? "|" : ""), $4 }' "$pat_file" 2>/dev/null; }
  cs=$(any_row -); ci=$(any_row i)
  { [ -n "$cs" ] && printf '%s' "$text" | grep -qE -- "$cs"; } || { [ -n "$ci" ] && printf '%s' "$text" | grep -qiE -- "$ci"; } || exit 0

  . "$(dirname "$0")/patterns.sh" && load_patterns "$pat_file" || exit 0
  # An assigned value is a path, not a secret, when the part before its last / is a directory: an echoed `secret-…: <path>` line.
  is_path() {
    local dir=${1%/*}
    [ "$dir" != "$1" ] && [ -n "$dir" ] || return 1
    case "$dir" in
      /*) [ -d "$dir" ] ;;
      '~/'*) [ -n "${HOME:-}" ] && [ -d "$HOME/${dir#\~/}" ] ;;
      *) [ -n "$cwd" ] && [ -d "$cwd/$dir" ] ;;
    esac
  }
  labels=""
  for k in "${!pat_re[@]}"; do
    opts=-oE; [ "${pat_flags[$k]}" = i ] && opts=-oiE
    while IFS= read -r m; do
      [ -n "$m" ] || continue
      pat_value "${pat_kind[$k]}" "$m"
      placeholder "$pat_v" && continue
      [ "${pat_kind[$k]}" = assigned ] && is_path "$pat_v" && continue
      labels="$labels${labels:+, }${pat_label[$k]}"
      break
    done < <(printf '%s' "$text" | grep "$opts" -- "${pat_re[$k]}" 2>/dev/null)
  done
  [ -n "$labels" ] || exit 0
  jq -cn --arg c "secret-scanning: this ${tool:-tool} output holds what looks like ${labels}. It reached you unmasked: never repeat, log, commit or write the value; refer to it by its variable or file name. If it is real and was not meant to be read, tell the user so they can rotate it. CC_SECRET_OUTPUT_SCAN=off turns this off." \
    --arg ev "$event" '{hookSpecificOutput:{hookEventName:$ev,additionalContext:$c}}' 2>/dev/null
  exit 0
} 2>/dev/null
exit 0
