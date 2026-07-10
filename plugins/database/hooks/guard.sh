#!/bin/bash
# Absolute-path shebang: the fail-open guarantee must hold under a stripped PATH.
# PreToolUse destructive-SQL guard. On a Write/Edit that introduces a destructive
# statement (DROP TABLE/DATABASE/SCHEMA, TRUNCATE, or an unqualified DELETE/UPDATE),
# returns permissionDecision "ask" so the user confirms a backup/rollback exists first
# — it does NOT hard-deny, because down-migrations legitimately drop. Fail-open: any
# error or missing jq allows the write.
{
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0
  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  case "$tool" in Write|Edit|MultiEdit) ;; *) exit 0 ;; esac

  text=$(printf '%s' "$input" | jq -r '
    [ .tool_input.content // empty,
      .tool_input.new_string // empty,
      ( .tool_input.edits // [] | map(.new_string // empty) | join("\n") )
    ] | join("\n")' 2>/dev/null) || exit 0
  [ -n "$text" ] || exit 0
  file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

  hit=""
  [ -z "$hit" ] && printf '%s' "$text" | grep -qiE '\bdrop[[:space:]]+(table|database|schema)\b' && hit="DROP TABLE/DATABASE/SCHEMA"
  [ -z "$hit" ] && printf '%s' "$text" | grep -qiE '\btruncate[[:space:]]+(table[[:space:]]+)?[^;]' && hit="TRUNCATE"
  # unqualified DELETE/UPDATE: a line with DELETE FROM or UPDATE … SET and no WHERE on it
  if [ -z "$hit" ]; then
    if printf '%s' "$text" | grep -iE '\b(delete[[:space:]]+from|update[[:space:]]+[^;]+[[:space:]]set)\b' \
         | grep -ivE '\bwhere\b' | grep -qiE '(delete[[:space:]]+from|update)'; then
      hit="an unqualified DELETE/UPDATE (no WHERE)"
    fi
  fi
  [ -n "$hit" ] || exit 0

  reason="destructive-SQL guard: this change introduces ${hit}. Confirm a backup or a tested rollback path exists before applying it, and that the statement is scoped as intended (an unqualified DELETE/UPDATE rewrites every row). Proceed only if that is verified."
  [ -n "$file" ] && reason="$reason (file: $file)"

  jq -cn --arg r "$reason" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}' 2>/dev/null
  exit 0
} 2>/dev/null
exit 0
