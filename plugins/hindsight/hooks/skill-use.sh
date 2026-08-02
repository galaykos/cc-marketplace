#!/bin/bash
# Absolute-path shebang (not `env bash`): the fail-silent guarantee must hold
# even with a stripped/broken PATH, where `/usr/bin/env bash` itself exits 127
# with stderr noise before this script ever runs.
#
# PostToolUse on Skill. Appends one row per skill INVOCATION to
# $HOME/.claude/hindsight/<slug>/skills.jsonl — machine-local, never inside the
# project tree, same slug rule and same fail-silent contract as collect.sh.
#
# WHY. This marketplace ships 126 skills against roughly four real gates, and
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
#   - It depends on the harness naming this tool `Skill`. If that changes, the
#     matcher silently records nothing — the failure mode is an empty file, which
#     reads identically to "nothing was used". Check the file exists before
#     concluding a skill is unused.
#   - Nothing reads it automatically. /hindsight:harvest reports it on request,
#     which keeps hindsight's collect → harvest → apply-on-approval contract
#     intact: no file in a user's repo is ever written from this data.
{
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0
  case "${CC_SKILL_LOG:-on}" in off) exit 0 ;; esac

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
