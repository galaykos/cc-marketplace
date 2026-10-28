#!/bin/bash
# skill-use.sh — PostToolUse on Skill: appends one row per skill invocation to $HOME/.claude/hindsight/<slug>/skills.jsonl, machine-local, same slug rule and fail-silent contract as collect.sh; only /hindsight:harvest reads it, on request. Off: CC_SKILL_LOG=off (unset: /config option cc_skill_log).
# Misses: usefulness (it proves invocation only); every call once the harness stops naming the tool `Skill`, leaving an empty file that reads like "nothing was used".
# Why, limits, history: rationale/derivations/plugin-hindsight.md § plugins/hindsight/hooks/skill-use.sh

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

{
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0
  case "$(cc_option CC_SKILL_LOG on)" in off) exit 0 ;; esac

  # context-key-ok: session_id is RECORDED as a ledger field, never used to key a
  # one-shot marker. The harvest reads these rows to group what a session invoked, so
  # session scope is the correct scope here — rewriting it to transcript_path would
  # split one session's ledger across every subagent that ran in it.
  session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null) || exit 0
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
  [ -n "$cwd" ] || exit 0
  [ -n "${HOME:-}" ] || exit 0

  skill=$(printf '%s' "$input" \
    | jq -r '.tool_input.skill // .tool_input.name // .tool_input.skill_name // empty' 2>/dev/null) || exit 0
  [ -n "$skill" ] || exit 0

  # Same slug rule as collect.sh: one directory per project, shared with the ledger.
  slug=$(printf '%s' "$cwd" | tr -c '[:alnum:]' '-') || exit 0
  [ -n "$slug" ] || exit 0
  dir="$HOME/.claude/hindsight/$slug"
  mkdir -p "$dir" 2>/dev/null || exit 0

  jq -c -n --arg s "$skill" --arg sid "$session_id" \
    '{v: 1, ts: (now | todate), skill: $s, session_id: $sid}' \
    >> "$dir/skills.jsonl" 2>/dev/null
} 2>/dev/null
exit 0
