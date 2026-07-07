#!/bin/bash
# Absolute-path shebang (not `/usr/bin/env bash`): the fail-open guarantee must
# hold even under a stripped/broken PATH.
# SessionEnd digest. Reads route.sh's per-session state, emits the accumulated
# low-confidence signals as one quiet line grouped by skill, then removes the
# state file. Fail-open: any error exits silently.
{
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0
  session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null) || exit 0
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
  [ -n "$session_id" ] || exit 0
  [ -n "$cwd" ] || exit 0

  state_file="$cwd/.claude/skill-router/fired-$session_id.json"
  [ -r "$state_file" ] || exit 0

  line=$(jq -r '
    (.pending_low // [])
    | group_by(.skill)
    | map(.[0].skill + " (" + (length | tostring) + " file" + (if length == 1 then "" else "s" end) + ")")
    | join(", ")
  ' "$state_file" 2>/dev/null) || { rm -f "$state_file" 2>/dev/null; exit 0; }

  [ -n "$line" ] && printf '[skill-router] Low-confidence signals seen this session — consider: %s.\n' "$line"
  rm -f "$state_file" 2>/dev/null
} 2>/dev/null
exit 0
