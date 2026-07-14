#!/bin/bash
# SessionStart: when the session starts from a compaction or a context clear, zero this
# session's turn counter so the advisor never nudges immediately after /compact. Other
# sources (startup, resume) are left alone — remind.sh's session-id rotation handles a
# resumed session that mints a new id. Fail-open: any error exits 0.
{
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0
  sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null) || exit 0
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
  src=$(printf '%s' "$input" | jq -r '.source // empty' 2>/dev/null)
  [ -n "$sid" ] || exit 0
  [ -n "$cwd" ] || exit 0

  dir="$cwd/.claude/compaction-advisor"
  mkdir -p "$dir" 2>/dev/null || exit 0

  case "$src" in
    compact|clear)
      printf '%s 0 0\n' "$sid" > "$dir/state" 2>/dev/null || exit 0
      ;;
  esac
} || exit 0
exit 0
