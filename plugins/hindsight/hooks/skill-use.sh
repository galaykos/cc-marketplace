#!/bin/bash
# Absolute-path shebang (not `env bash`): the fail-silent guarantee must hold
# even with a stripped/broken PATH, where `/usr/bin/env bash` itself exits 127
# with stderr noise before this script ever runs.
#
# PostToolUse on Skill. Appends one row per skill INVOCATION to
# $HOME/.claude/hindsight/<slug>/skills.jsonl — machine-local, never inside the
# project tree, same slug rule and same fail-silent contract as collect.sh.
#
# WHY. This marketplace ships ~100 skills against roughly four real gates, and
# every removal it has ever made was argued from description tokens and trigger
# overlap because nothing recorded which skills a session actually used. The
# skill-router's own state file (route.sh's fired-<sid>.json) knows what was
# OFFERED and is deleted at SessionEnd; nothing knew what was INVOKED. The
# sentence "this skill was invoked zero times in 200 sessions and costs 60
# always-on tokens forever" is the only sentence that can shrink a marketplace,
# and it needs this row to be writeable.
#
# HONEST LIMITATIONS, stated because the four laws require it:
#   - It proves INVOCATION, never usefulness. A skill invoked 200 times may still
#     be restating what the model already knew; only a control/treatment run
#     settles that. This is the denominator, not the verdict.
#   - Machine-local and single-user. It is not telemetry about anyone else, it
#     never leaves the machine, and CC_SKILL_LOG=off disables it outright.
#     CC_SKILL_LOG unset: the /config option cc_skill_log decides.
#   - It depends on the harness naming this tool `Skill`. If that changes, the
#     matcher silently records nothing — the failure mode is an empty file, which
#     reads identically to "nothing was used". Check the file exists before
#     concluding a skill is unused.
#   - Nothing reads it automatically. /hindsight:harvest reports it on request,
#     which keeps hindsight's collect → harvest → apply-on-approval contract
#     intact: no file in a user's repo is ever written from this data.

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

  # The skill name lives in the tool input; accept both the documented field and
  # the plugin-qualified form without caring which, since either identifies it.
  skill=$(printf '%s' "$input" \
    | jq -r '.tool_input.skill // .tool_input.name // .tool_input.skill_name // empty' 2>/dev/null) || exit 0
  [ -n "$skill" ] || exit 0

  # slug: the same rule Claude Code uses for its projects dir, and the same rule
  # hooks/collect.sh uses — one directory per project, shared with the ledger.
  slug=$(printf '%s' "$cwd" | tr -c '[:alnum:]' '-') || exit 0
  [ -n "$slug" ] || exit 0
  dir="$HOME/.claude/hindsight/$slug"
  mkdir -p "$dir" 2>/dev/null || exit 0

  jq -c -n --arg s "$skill" --arg sid "$session_id" \
    '{v: 1, ts: (now | todate), skill: $s, session_id: $sid}' \
    >> "$dir/skills.jsonl" 2>/dev/null
} 2>/dev/null
exit 0
