#!/bin/bash
# Absolute-path shebang: fail-open must hold under a stripped PATH.
# PostToolUse scope-lock tripwire. When an active run has declared its allowed files
# in $cwd/.claude/task-runner/scope.json, this warns (non-blocking) if an Edit/Write
# landed OUTSIDE that set — the "touch only files the task lists" discipline made
# mechanical. The warning is emitted as the PostToolUse stdout JSON envelope
# ({"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":...}},
# exit 0) — the one non-blocking channel the executing model actually receives;
# plain stdout text with exit 0 never reaches it (same channel reasoning as
# completion-gate.sh, whose Stop event reaches the model only through exit 2).
# No scope file → no-op (the discipline is opt-in per run). Fail-open.
#
# COVERAGE LIMIT (honest scope): this hook reads only the INLINE path's scope.json.
# Delegated workers get per-card scope-<cardId>.json files (routing.md) which this
# hook does NOT read — their scope is enforced by the prose diff-vs-declared check
# on return, not mechanically here. A subagent's edits also fire in ITS session,
# not this one. Inline-only tripwire by design.
#
# fd 3 = the caller's real stderr, saved before the block so the two fail-open
# warnings below (D7: missing jq / malformed scope.json) reach stderr — the block's
# `2>/dev/null` is there only to silence incidental jq/grep noise and would eat a
# plain `>&2` warning. (Honest limitation law: .claude/skills/authoring-skills/SKILL.md (in the marketplace repository) "The four laws".)
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

  # Allowed if the edited path equals an allow entry, or sits under it as a
  # DIRECTORY. The boundary matters: a raw startswith made every entry a prefix of
  # unrelated siblings — "src/util.ts" admitted "src/util.tsx", "app/Models"
  # admitted "app/ModelsBackup/X.php" — so the lock leaked silently on the exact
  # near-miss paths a drifting edit produces.
  allowed=$(jq -r --arg f "$rel" \
    'if ((.allow // []) | any(. as $a | $a == $f or ($f | startswith(if ($a | endswith("/")) then $a else $a + "/" end)))) then "y" else "n" end' \
    "$scope" 2>/dev/null)
  [ "$allowed" = "n" ] || exit 0

  task=$(jq -r '.task // "the current task"' "$scope" 2>/dev/null)
  warn=$(printf '[task-runner] scope-lock: %s was edited but is NOT among the files %s declared. If intentional, add it to the task definition; otherwise this is scope creep — record it as a follow-up and revert this edit.' "$rel" "$task")
  # jq builds the envelope so the message stays valid JSON whatever $rel contains.
  # jq presence is guaranteed here by the guard at the top of the block.
  jq -cn --arg ctx "$warn" \
    '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$ctx}}'
} 2>/dev/null
exit 0
