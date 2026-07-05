#!/bin/bash
# Absolute-path shebang (not `env bash`): the fail-silent guarantee must hold
# even with a stripped/broken PATH, where `/usr/bin/env bash` itself exits 127
# with stderr noise before this script ever runs.
# Fail silent: never block or noise SessionEnd (D14). Appends one cheap-stats
# row per ended session to <cwd>/.claude/hindsight/ledger.jsonl (D2, D4-D6).
# Transcript JSONL format is officially unstable (D13) — every parse is
# defensive and prefers undercounting over crashing.
{
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0

  session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null) || exit 0
  transcript_path=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null) || exit 0
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
  reason=$(printf '%s' "$input" | jq -r '.reason // empty' 2>/dev/null) || exit 0

  [ -n "$session_id" ] || exit 0
  [ -n "$cwd" ] || exit 0
  [ -f "$transcript_path" ] || exit 0
  [ -r "$transcript_path" ] || exit 0

  # One pass over the transcript: keep raw lines for marker greps and
  # parsed lines (malformed ones silently dropped) for structural counts.
  stats=$(jq -c -n -R '
    [inputs] as $raw
    | [$raw[] | fromjson? // empty] as $lines
    | [$lines[] | .timestamp? | select(type == "string")] as $ts
    | {
        ts_start: ($ts[0] // ""),
        ts_end: ($ts[-1] // ""),
        turns: ([$lines[] | select(.type? == "assistant")] | length),
        user_msgs: ([$lines[]
          | select(.type? == "user")
          | .message.content?
          | select(
              (type == "string" and length > 0)
              or (type == "array"
                  and any(.[]?; .type? == "text" and ((.text? // "") | length) > 0))
            )] | length),
        errors: ([$raw[] | select(test("\"is_error\"\\s*:\\s*true"))] | length),
        friction_events: ([$raw[]
          | select(
              test("\"is_error\"\\s*:\\s*true")
              or test("rejected"; "i")
            )] | length)
      }' <"$transcript_path" 2>/dev/null) || exit 0
  [ -n "$stats" ] || exit 0

  row=$(jq -c -n \
    --arg session_id "$session_id" \
    --arg reason "$reason" \
    --arg transcript_path "$transcript_path" \
    --argjson stats "$stats" \
    '{
      v: 1,
      session_id: $session_id,
      ts_start: $stats.ts_start,
      ts_end: $stats.ts_end,
      turns: $stats.turns,
      friction_events: $stats.friction_events,
      errors: $stats.errors,
      user_msgs: $stats.user_msgs,
      reason: $reason,
      transcript_path: $transcript_path,
      mined: false
    }' 2>/dev/null) || exit 0
  [ -n "$row" ] || exit 0

  mkdir -p "$cwd/.claude/hindsight" 2>/dev/null || exit 0
  printf '%s\n' "$row" >>"$cwd/.claude/hindsight/ledger.jsonl" 2>/dev/null || exit 0
} 2>/dev/null
exit 0
