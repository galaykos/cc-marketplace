#!/bin/bash
# Absolute-path shebang: fail-open must hold under a stripped PATH.
# PostToolUse scope-lock tripwire. When an active run has declared its allowed files
# in $cwd/.claude/task-runner/scope*.json, this warns (non-blocking) if an Edit/Write
# landed OUTSIDE the union of those sets — the "touch only files the task lists" discipline made
# mechanical. The warning is emitted as the PostToolUse stdout JSON envelope
# ({"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":...}},
# exit 0) — the one non-blocking channel the executing model actually receives;
# plain stdout text with exit 0 never reaches it (same channel reasoning as
# candor's gate.sh clause 4, whose Stop event reaches the model only through exit 2).
# No scope file → no-op (the discipline is opt-in per run). Fail-open.
#
# COVERAGE: every scope file in the run's state dir — the inline path's scope.json AND
# the per-card scope-<cardId>.json files routing.md writes for delegated and tracked
# cards — read as ONE UNION. An edit outside the union warns; an edit any live card
# declared does not. Union, not per-file, because this hook cannot tell WHICH card an
# Edit belongs to: the payload carries a path, not a card id, and charging an edit
# against the wrong card's list would warn on correct work.
#
# WHAT IT STILL DOES NOT CATCH (SW 8 of the 2026-09-22 panel closed the first half):
#   - A WORKER IN ANOTHER WORKTREE. A subagent's Edit fires in ITS session with ITS
#     cwd; a track worktree is a different tree entirely, so its edits never reach this
#     hook at all. That path is enforced by the prose diff-vs-declared check on return.
#   - Scope-file drift. A card whose scope file is never written is unbounded here, and
#     a stale scope-<cardId>.json from a finished card WIDENS the union rather than
#     narrowing it — the union fails toward silence, which is the right failure for an
#     advisory tripwire and the wrong one for a gate. This is not a gate.
#   - Any malformed scope file disarms the whole call, not just its own card: a partial
#     union would warn about paths a card it could not parse had actually allowed.
#
# fd 3 = the caller's real stderr, saved before the block so the two fail-open
# warnings below (D7: missing jq / a malformed scope file) reach stderr — the block's
# `2>/dev/null` is there only to silence incidental jq/grep noise and would eat a
# plain `>&2` warning. (Honest limitation law: .claude/skills/authoring-skills/SKILL.md (in the marketplace repository) "The four laws".)
exec 3>&2
{
  input=$(cat)
  command -v jq >/dev/null 2>&1 || { echo "task-runner scope-lock: jq not found — scope not enforced this call" >&3; exit 0; }
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
  file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
  [ -n "$cwd" ] && [ -n "$file" ] || exit 0

  # STATE HYGIENE (0.34.4). .claude/task-runner/ is written by the run itself
  # (active-run.json, rv/, bg/, gate-pass.json) and by this plugin's scripts; none of
  # it belongs in a commit, and it showed up as untracked in every repo a run touched
  # (overseer's acceptance protocol names it as "other plugins' scratch"). A directory
  # can ignore itself, so the first hook to see it drops a `.gitignore` holding `*`.
  tr_dir="$cwd/.claude/task-runner"
  if [ -d "$tr_dir" ] && [ ! -e "$tr_dir/.gitignore" ]; then printf '*\n' > "$tr_dir/.gitignore" 2>/dev/null; fi

  scopes=()
  for s in "$cwd"/.claude/task-runner/scope.json "$cwd"/.claude/task-runner/scope-*.json; do
    [ -r "$s" ] && scopes+=("$s")
  done
  [ "${#scopes[@]}" -gt 0 ] || exit 0
  for s in "${scopes[@]}"; do
    jq empty "$s" 2>/dev/null || { echo "task-runner scope-lock: $(basename "$s") is malformed — scope not enforced this call" >&3; exit 0; }
  done

  # Normalize the edited path to repo-relative for comparison.
  rel="$file"; case "$file" in "$cwd"/*) rel="${file#"$cwd"/}" ;; esac

  # A scope file is never itself in scope; ignore edits to any of them.
  case "$rel" in .claude/task-runner/scope.json|.claude/task-runner/scope-*.json) exit 0 ;; esac

  # Allowed if the edited path equals an allow entry, or sits under it as a
  # DIRECTORY. The boundary matters: a raw startswith made every entry a prefix of
  # unrelated siblings — "src/util.ts" admitted "src/util.tsx", "app/Models"
  # admitted "app/ModelsBackup/X.php" — so the lock leaked silently on the exact
  # near-miss paths a drifting edit produces.
  # -s slurps every scope file into one array, so `allow` is the UNION of all of them.
  allowed=$(jq -rs --arg f "$rel" \
    'if ((map(.allow // []) | add // []) | any(. as $a | $a == $f or ($f | startswith(if ($a | endswith("/")) then $a else $a + "/" end)))) then "y" else "n" end' \
    "${scopes[@]}" 2>/dev/null)
  [ "$allowed" = "n" ] || exit 0

  task=$(jq -rs '[.[] | .task // empty] | unique | join(", ")' "${scopes[@]}" 2>/dev/null)
  [ -n "$task" ] || task="the current task"
  warn=$(printf '[task-runner] scope-lock: %s was edited but is NOT among the files %s declared. If intentional, add it to the task definition; otherwise this is scope creep — record it as a follow-up and revert this edit.' "$rel" "$task")
  # jq builds the envelope so the message stays valid JSON whatever $rel contains.
  # jq presence is guaranteed here by the guard at the top of the block.
  jq -cn --arg ctx "$warn" \
    '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$ctx}}'
} 2>/dev/null
exit 0
