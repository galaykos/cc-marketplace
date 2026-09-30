#!/bin/bash
# Absolute-path shebang: fail-open must hold under a stripped PATH.
#
# Stop. Reads the session ledger ledger.sh wrote and the final assistant message from the
# transcript; refuses the turn (exit 2, reason on stderr — the channel candor's gate
# measured as the one that reaches the model) when any ledgered name has no accounting
# line: a line naming it and one of `as named`, `substituted`, `omitted`. Blocks at most
# twice per session, so a model that will not comply cannot be held forever; after that
# the missing names are printed as a warning and the turn ends.
#
# STANDING: gate on the SHAPE — the line must exist. Whether "as named" is true is
# agent-graded: the model's word, and the reader's eye on the lines it was made to
# write. That is the whole design: a silent substitution has to be written down as
# "as named" — a lie — or as "substituted" — the confession — and neither is silence.
# No ledger (no work-shaped prompt this session), no final message, or
# CC_ASK_LEDGER=off: silent. Fail-open on missing jq or a bad payload.
# CC_ASK_LEDGER unset: the /config option cc_ask_ledger decides.

# --- option resolver -----------------------------------------------------------
# Canonical copy: templates/blocks/option-resolver.md. Every hook defining cc_option must
# carry this block byte-for-byte (pc_shared_blocks); generated hooks include it.
# cc_option <ENV_NAME> <default> [<level-file>] prints one line, the first non-empty of: the
# variable ENV_NAME; the first word of <level-file>, if given and readable; the userConfig
# option CLAUDE_PLUGIN_OPTION_<ENV_NAME>, true/false read as on/off; <default>. The shell wins
# because the environment is the one state independently installed plugins share (CC_REMIND
# or CC_BOOST there mutes every plugin at once); the option gives one plugin a /config row.
# The host exports only SAVED options, so <default> must equal the manifest's default.
# Status 0, no stderr: a malformed name, an expansion error that exits bash 5, yields <default>.
# WHAT IT DOES NOT CATCH: a caller passing a variable instead of a literal name, or a value
# outside the switch's vocabulary — each hook still validates the value it gets.
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

exec 3>&2
{
  command -v jq >/dev/null 2>&1 || exit 0
  [ "$(cc_option CC_ASK_LEDGER on)" = "off" ] && exit 0
  input=$(cat)
  ctx=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // empty' 2>/dev/null) || exit 0
  [ -n "$ctx" ] || exit 0
  key=$(printf '%s' "$ctx" | cksum | cut -d' ' -f1)
  dir="${TMPDIR:-/tmp}/cc-ask-ledger-$key"
  [ -s "$dir/entries" ] || exit 0

  tp=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
  final=$(printf '%s' "$input" | jq -r '.last_assistant_message // empty' 2>/dev/null)
  if [ -z "$final" ] && [ -f "$tp" ]; then
    final=$(jq -r 'select(.type=="assistant") | .message.content | if type=="string" then . else ([.[]? | select(.type=="text") | .text] | join("\n")) end' "$tp" 2>/dev/null | awk 'BEGIN{RS="\0"} {print}' | tail -c 20000)
    last_uuid=$(jq -r 'select(.type=="assistant") | .uuid' "$tp" 2>/dev/null | tail -1)
    [ -n "$last_uuid" ] && final=$(jq -r --arg u "$last_uuid" 'select(.type=="assistant" and .uuid==$u) | .message.content | if type=="string" then . else ([.[]? | select(.type=="text") | .text] | join("\n")) end' "$tp" 2>/dev/null)
  fi
  [ -n "$final" ] || exit 0

  missing=""
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    esc=$(printf '%s' "$name" | sed 's/[][\.*^$/|+?(){}]/\\&/g')
    printf '%s\n' "$final" | grep -iE "$esc.*\b(as named|substituted|omitted)\b" >/dev/null 2>&1 && continue
    missing="${missing}${missing:+, }$name"
  done < "$dir/entries"
  [ -n "$missing" ] || exit 0

  n=$(cat "$dir/blocks" 2>/dev/null || echo 0)
  if [ "$n" -ge 2 ]; then
    printf 'ask-ledger: still unaccounted after two blocks — %s. Ending the turn anyway; the reader should treat those names as unverified.\n' "$missing" >&3
    exit 0
  fi
  echo $((n+1)) > "$dir/blocks"
  printf 'ask-ledger: the ask named %s and the final message does not account for them. Add one line per name — `<name>: as named` | `<name>: substituted → what, why` | `<name>: omitted → why` — and say so truthfully: a substitution you never raised is a substitution, not "as named". Then stop again.\n' "$missing" >&3
  printf 'ask-ledger: CC_ASK_LEDGER=off disables this gate for the session.\n' >&3
  exit 2
} 2>/dev/null
exit 0
