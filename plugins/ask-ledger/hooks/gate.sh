#!/bin/bash
# gate.sh — Stop: sends the turn back (JSON block on stdout) when a name ledger.sh ledgered has no line in the final reply naming it with `as named`, `substituted` or `omitted`; twice a session at most, then warns; accounted names leave the ledger. Off: CC_ASK_LEDGER=off (unset: /config option cc_ask_ledger). Fails open.
# Misses: whether "as named" is true (the model's word, agent-graded), and a later turn quietly undoing an accounted name it does not name again. Silent with no ledger or no final message.
# Why, limits, history: rationale/derivations/plugin-ask-ledger.md § plugins/ask-ledger/hooks/gate.sh

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

  missing=""; owed=""
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    esc=$(printf '%s' "$name" | sed 's/[][\.*^$/|+?(){}]/\\&/g')
    printf '%s\n' "$final" | grep -iE "$esc.*\b(as named|substituted|omitted)\b" >/dev/null 2>&1 && continue
    missing="${missing}${missing:+, }$name"
    owed="${owed}${name}
"
  done < "$dir/entries"
  printf '%s' "$owed" > "$dir/entries"
  [ -n "$missing" ] || exit 0

  n=$(cat "$dir/blocks" 2>/dev/null || echo 0)
  if [ "$n" -ge 2 ]; then
    printf 'ask-ledger: after two tries the final reply still does not say what happened to %s; ending the turn anyway, so treat those as unverified.\n' "$missing" >&3
    : > "$dir/entries"
    exit 0
  fi
  echo $((n+1)) > "$dir/blocks"
  # The verdict leads the retry: it is the last thing the user reads, and name lines alone made users re-ask.
  reason=$(printf 'ask-ledger: your final reply does not say what happened to %s, which the request named. Restate the answer'"'"'s one-line verdict first, then one line per name, then stop again:\n  `<name>: as named` | `<name>: substituted → what, why` | `<name>: omitted → why`\n  A substitution you never raised is "substituted", not "as named".\n' "$missing"
    printf 'ask-ledger: CC_ASK_LEDGER=off turns this check off.\n')
  jq -cn --arg r "$reason" --arg m "ask-ledger sent the turn back: the reply does not say what happened to $missing." \
    '{decision:"block",reason:$r,systemMessage:$m}'
  exit 0
} 2>/dev/null
exit 0
