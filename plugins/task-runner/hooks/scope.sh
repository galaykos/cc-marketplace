#!/bin/bash
# Absolute-path shebang: fail-open must hold under a stripped PATH.
# PostToolUse scope-lock tripwire. When an active run has declared its allowed files
# in $cwd/.claude/task-runner/scope.json, this warns (non-blocking) if an Edit/Write
# landed OUTSIDE that set — the "touch only files the task lists" discipline made
# mechanical. No scope file → no-op (the discipline is opt-in per run). Fail-open.
#
# fd 3 = the caller's real stderr, saved before the block so the two fail-open
# warnings below (D7: missing jq / malformed scope.json) reach stderr — the block's
# `2>/dev/null` is there only to silence incidental jq/grep noise and would eat a
# plain `>&2` warning.
exec 3>&2
{
  input=$(cat)
  command -v jq >/dev/null 2>&1 || { echo "task-runner scope-lock: jq not found — scope not enforced this call" >&3; exit 0; }
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
  file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
  [ -n "$cwd" ] && [ -n "$file" ] || exit 0

  scope="$cwd/.claude/task-runner/scope.json"
  [ -r "$scope" ] || exit 0
  jq empty "$scope" 2>/dev/null || { echo "task-runner scope-lock: scope.json is malformed — scope not enforced this call" >&3; exit 0; }

  # Normalize the edited path to repo-relative for comparison.
  rel="$file"; case "$file" in "$cwd"/*) rel="${file#"$cwd"/}" ;; esac

  # The scope.json is never itself in scope; ignore edits to it.
  case "$rel" in .claude/task-runner/scope.json) exit 0 ;; esac

  # Allowed if the edited path equals or sits under any allow entry (prefix match).
  allowed=$(jq -r --arg f "$rel" \
    'if ((.allow // []) | any(. as $a | ($f | startswith($a)) or ($a == $f))) then "y" else "n" end' \
    "$scope" 2>/dev/null)
  [ "$allowed" = "n" ] || exit 0

  task=$(jq -r '.task // "the current task"' "$scope" 2>/dev/null)
  printf '[task-runner] scope-lock: %s was edited but is NOT among the files %s declared. If intentional, add it to the task definition; otherwise this is scope creep — record it as a follow-up and revert this edit.\n' "$rel" "$task"
} 2>/dev/null
exit 0
