#!/usr/bin/env bash
# Repo-level PostToolUse authoring guard. Advisory (post-write) and fail-open:
# any error, missing jq, or out-of-scope path exits 0 silently and never blocks.
# On an over-budget SKILL.md or a stray non-functional .md inside this repo's own
# plugins/, emits a model-visible additionalContext warning so the author (human
# or Claude) fixes it in-session instead of at CI. Shares check logic with
# validate.sh via scripts/lib/plugin-checks.sh — no drift.
{
  command -v jq >/dev/null 2>&1 || exit 0
  input=$(cat)
  file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
  [ -n "$file_path" ] || exit 0

  root=$(cd "$(dirname "$0")/.." && pwd) || exit 0
  case "$file_path" in
    /*) abs="$file_path" ;;
    *)  abs="$root/$file_path" ;;
  esac

  # Only this repo's own top-level plugins/. Reject worktrees and out-of-repo paths.
  case "$abs" in
    "$root"/.claude/worktrees/*) exit 0 ;;
    "$root"/plugins/*) rel="${abs#"$root"/}" ;;
    *) exit 0 ;;
  esac

  . "$root/scripts/lib/plugin-checks.sh" 2>/dev/null || exit 0

  warns=""
  case "$rel" in
    plugins/*/skills/*/SKILL.md)
      v=$(pc_skill_budget "$abs" 2>/dev/null) || \
        warns="SKILL body ${v##* } lines — outside the 100-150 budget ($rel)"
      ;;
  esac
  case "$rel" in
    *.md)
      allow_md='^(README|CHANGELOG|ROADMAP)\.md$|^skills/[^/]+/SKILL\.md$|^skills/[^/]+/references/.+\.md$|^commands/[^/]+\.md$|^agents/[^/]+\.md$'
      pc_doc_location "$rel" "$allow_md" >/dev/null 2>&1 || \
        warns="${warns:+$warns\n}Non-functional .md inside a plugin ($rel) — docs belong in taskmaster-docs/, not plugins/"
      ;;
  esac

  [ -n "$warns" ] || exit 0
  msg=$(printf '[authoring-guard] %b' "$warns")
  jq -cn --arg c "$msg" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$c}}'
} 2>/dev/null
exit 0
