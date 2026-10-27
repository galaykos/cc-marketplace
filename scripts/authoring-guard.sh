#!/usr/bin/env bash
# authoring-guard.sh — repo PostToolUse hook on Edit/Write/MultiEdit, advisory and fail-open (any error exits 0): warns in-session on an over-budget SKILL.md or a non-functional .md in this repo's plugins/.
# Misses: worktrees and paths outside plugins/, Bash writes, and every other validate.sh check; it never blocks. Both checks come from scripts/lib/plugin-checks.sh, shared with validate.sh.
# Why, limits, history: rationale/derivations/scripts.md § scripts/authoring-guard.sh
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
        warns="SKILL body over budget: $(printf '%s' "$v" | awk '{print $3" "$4}') ($rel) — 200 lines / 14,000 bytes / 300 chars per line"
      ;;
  esac
  case "$rel" in
    *.md)
      allow_md='^(README|CHANGELOG|ROADMAP)\.md$|^skills/[^/]+/SKILL\.md$|^skills/[^/]+/references/.+\.md$|^commands/[^/]+\.md$|^agents/[^/]+\.md$|^evals/.+\.md$'
      pc_doc_location "$rel" "$allow_md" >/dev/null 2>&1 || \
        warns="${warns:+$warns\n}Non-functional .md inside a plugin ($rel) — docs belong in taskmaster-docs/, not plugins/"
      ;;
  esac

  [ -n "$warns" ] || exit 0
  msg=$(printf '[authoring-guard] %b' "$warns")
  jq -cn --arg c "$msg" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$c}}'
} 2>/dev/null
exit 0
