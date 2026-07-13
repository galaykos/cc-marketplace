#!/bin/bash
# UserPromptSubmit: count user turns per session and, on a repeating interval, print one
# advisory line suggesting /compact once the session is long enough that an early chunk may
# be stale. The model judges relevance from the nudge text — this hook only measures length.
# Warn-only, fail-open: any error exits 0 with no output; a corrupt or foreign-session state
# file re-seeds (never a permanent silent no-op).
{
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0
  sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null) || exit 0
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
  [ -n "$sid" ] || exit 0
  [ -n "$cwd" ] || exit 0

  interval=50
  dir="$cwd/.claude/compaction-advisor"
  mkdir -p "$dir" 2>/dev/null || exit 0
  state="$dir/state"

  turns=0
  last=0
  if [ -r "$state" ]; then
    read -r f_sid f_turns f_last _ < "$state" 2>/dev/null
    # Keep prior counts only when the file is well-formed AND for the current session;
    # anything else (missing, garbage, non-integer, a different session_id) re-seeds to 0.
    if [ "$f_sid" = "$sid" ] && [[ "$f_turns" =~ ^[0-9]+$ ]] && [[ "$f_last" =~ ^[0-9]+$ ]]; then
      turns=$f_turns
      last=$f_last
    fi
  fi

  turns=$((turns + 1))

  if [ $((turns - last)) -ge "$interval" ]; then
    printf '⚠ compaction-advisor: ~%s turns in this session — if early context is now stale, a guided /compact sharpens output: e.g. /compact keep the current task, key decisions, and file paths; drop resolved tangents.\n' "$turns"
    last=$turns
  fi

  printf '%s %s %s\n' "$sid" "$turns" "$last" > "$state" 2>/dev/null || exit 0
} || exit 0
exit 0
