#!/usr/bin/env bash
# Fail open: never block the prompt. The terminal half of the two-surface loop.
# When a theme-design session is RUNNING (state.json names a live pid) and the
# browser has posted events the session has not consumed, inject them into this
# terminal turn and advance <root>/cursor so the long-poll never redelivers them.
# Silent in every other case, which is every case in a project with no session —
# the dynamic budget entry for this plugin is measured against that silence.
# Lane: `any` — a running session is the trigger, not a phase; without one this
# script prints nothing, so the phase sentinel would gate an already-silent path.
# Slash prompts addressed to this plugin exit early: the command reads the same
# queue itself through the server, and a double delivery is worse than a late one.
{
  command -v jq >/dev/null 2>&1 || exit 0
  input=$(cat)
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  case "$prompt" in "/theme-design:"*) exit 0 ;; esac
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  root="${cwd:-$PWD}/.theme-design"
  [ -f "$root/state.json" ] && [ -f "$root/events.jsonl" ] || exit 0
  pid=$(jq -r '.pid // empty' "$root/state.json" 2>/dev/null)
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null || exit 0
  cursor=$(cat "$root/cursor" 2>/dev/null || echo 0)
  case "$cursor" in ''|*[!0-9]*) cursor=0 ;; esac
  pending=$(jq -c --argjson c "$cursor" 'select((.seq // 0) > $c)' "$root/events.jsonl" 2>/dev/null)
  [ -n "$pending" ] || exit 0
  n=$(printf '%s\n' "$pending" | grep -c .)
  # Budget in whole events, never bytes: a line cut mid-JSON is unreadable, and the
  # cursor must only pass events that were printed in full. Whatever does not fit
  # stays behind the cursor for the next poll or the next prompt.
  shown=$(printf '%s\n' "$pending" | awk -v max=3000 '{ if (used + length($0) + 1 > max && shown > 0) exit; print; used += length($0) + 1; shown++ }')
  k=$(printf '%s\n' "$shown" | grep -c .)
  last=$(printf '%s\n' "$shown" | tail -1 | jq -r '.seq')
  mode=$(jq -r '.mode // "html"' "$root/state.json")
  url=$(jq -r '.url // empty' "$root/state.json")
  left=$((n - k))
  echo "theme-design: $n browser event(s) pending from the open $mode design session ($url). Apply them per the design-session skill (skills/design-session/SKILL.md) before answering this prompt, then POST a one-line summary to /__td/reply with reload:true. Events (oldest first, $k of $n shown; $left still queued behind the cursor for the next poll):"
  printf '%s\n' "$shown"
  echo "$last" > "$root/cursor"
} 2>/dev/null
exit 0
