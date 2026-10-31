#!/bin/bash
# collect.sh — SessionEnd: appends one stats row per ended session, then one `kind:"agent"` row per subagent transcript not yet ledgered (deduped by agent_id), to $HOME/.claude/hindsight/<slug>/ledger.jsonl, never the project tree. Fails silent: never blocks, never prints.
# Misses: what the unstable transcript format hides (every parse undercounts rather than crash); agent rows past the hook timeout (the session row is written first).
# Why, limits, history: rationale/derivations/plugin-hindsight.md § plugins/hindsight/hooks/collect.sh
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

  # Raw lines feed the marker greps, parsed lines (malformed ones dropped) the structural counts.
  stats_prog='
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
      }'
  stats=$(jq -c -n -R "$stats_prog" <"$transcript_path" 2>/dev/null) || exit 0
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

  # $HOME, not `~`, which does not expand under a stripped environment; the slug is Claude Code's projects-dir rule.
  [ -n "${HOME:-}" ] || exit 0
  slug=$(printf '%s' "$cwd" | tr -c '[:alnum:]' '-') || exit 0
  [ -n "$slug" ] || exit 0
  dir="$HOME/.claude/hindsight/$slug"
  mkdir -p "$dir" 2>/dev/null || exit 0
  printf '%s\n' "$row" >>"$dir/ledger.jsonl" 2>/dev/null || exit 0

  agents_dir="${transcript_path%.jsonl}/subagents"
  [ -d "$agents_dir" ] || exit 0
  for agent_file in "$agents_dir"/agent-*.jsonl; do
    [ -f "$agent_file" ] && [ -r "$agent_file" ] || continue
    agent_id=$(basename "$agent_file" .jsonl)
    grep -qF "\"agent_id\":\"$agent_id\"" "$dir/ledger.jsonl" 2>/dev/null && continue
    meta="${agent_file%.jsonl}.meta.json"
    agent_type=""
    [ -r "$meta" ] && agent_type=$(jq -r '.agentType // empty' "$meta" 2>/dev/null)
    stats=$(jq -c -n -R "$stats_prog" <"$agent_file" 2>/dev/null) || continue
    [ -n "$stats" ] || continue
    row=$(jq -c -n \
      --arg session_id "$session_id" \
      --arg agent_id "$agent_id" \
      --arg agent_type "${agent_type:-unknown}" \
      --arg reason "$reason" \
      --arg transcript_path "$agent_file" \
      --argjson stats "$stats" \
      '{
        v: 1,
        kind: "agent",
        session_id: $session_id,
        agent_id: $agent_id,
        agent_type: $agent_type,
        ts_start: $stats.ts_start,
        ts_end: $stats.ts_end,
        turns: $stats.turns,
        friction_events: $stats.friction_events,
        errors: $stats.errors,
        user_msgs: $stats.user_msgs,
        reason: $reason,
        transcript_path: $transcript_path,
        mined: false
      }' 2>/dev/null) || continue
    [ -n "$row" ] || continue
    printf '%s\n' "$row" >>"$dir/ledger.jsonl" 2>/dev/null || exit 0
  done
} 2>/dev/null
exit 0
