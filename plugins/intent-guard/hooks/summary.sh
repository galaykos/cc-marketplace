#!/bin/bash
# Absolute-path shebang: fail-open must hold under a stripped PATH.
# Stop: emit ONE passive, user-facing line summarizing what this turn touched vs the declared
# intent, then truncate the ephemeral turn.log so "this turn" resets for the next turn. This is
# a summary, not a gate — it NEVER holds the turn and emits no decision field of any kind.
# Fail-open: any error or a missing jq exits 0.
{
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
  [ -n "$cwd" ] || exit 0

  dir="$cwd/.claude/intent-guard"
  intent="$dir/intent.json"
  turnlog="$dir/turn.log"

  [ -f "$intent" ] || exit 0        # guard not engaged this session (benign, silent)
  [ -s "$turnlog" ] || exit 0       # nothing touched this turn — nothing to summarize

  # Disabled-visible: engaged but state corrupt — say so, still never hold the turn.
  if ! jq empty "$intent" 2>/dev/null; then
    printf 'intent-guard: DISABLED (intent.json unreadable) — turn summary is OFF.\n'
    : > "$turnlog" 2>/dev/null
    exit 0
  fi

  x=$(jq -r '.intent // "the declared task"' "$intent" 2>/dev/null)
  n=$(grep -c '' "$turnlog" 2>/dev/null || echo 0)

  printf 'intent-guard: this turn touched %s target(s) vs intent «%s» — if any strayed or cut a corner, fix before done.\n' "$n" "$x"

  # Truncate so the next turn starts from empty.
  : > "$turnlog" 2>/dev/null
} 2>/dev/null
exit 0
