#!/usr/bin/env bash
# Fixture tests for hooks/collect.sh — the session row, one row per subagent
# transcript tagged kind:"agent" with its agentType, dedup on a second
# SessionEnd for the same session, and fail-silent exit 0 on every bad input.
# Drives the hook with a real-shaped SessionEnd payload over a synthetic HOME.
set -u
HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/collect.sh"
export HOME="$(mktemp -d)"; trap 'rm -rf "$HOME"' EXIT
pass=0; fail=0
ok()   { pass=$((pass+1)); }
bad()  { echo "FAIL $1"; fail=$((fail+1)); }
check(){ if eval "$2"; then ok; else bad "$1"; fi; }

proj="/tmp/proj-collect"
slug=$(printf '%s' "$proj" | tr -c '[:alnum:]' '-')
ledger="$HOME/.claude/hindsight/$slug/ledger.jsonl"
tdir="$HOME/.claude/projects/$slug"; mkdir -p "$tdir"
sid="11111111-2222-3333-4444-555555555555"
transcript="$tdir/$sid.jsonl"

# Session transcript: 2 assistant turns, 1 user text message, 1 error line.
cat > "$transcript" <<'J'
{"type":"user","timestamp":"2026-09-14T10:00:00Z","message":{"content":"do the thing"}}
{"type":"assistant","timestamp":"2026-09-14T10:00:05Z","message":{"content":[{"type":"text","text":"ok"}]}}
{"type":"user","timestamp":"2026-09-14T10:00:10Z","message":{"content":[{"type":"tool_result","is_error":true,"content":"boom"}]}}
{"type":"assistant","timestamp":"2026-09-14T10:00:15Z","message":{"content":[{"type":"text","text":"fixed"}]}}
J

# Two subagents: one with a meta file, one without (agent_type falls back to "unknown").
adir="$tdir/$sid/subagents"; mkdir -p "$adir"
cat > "$adir/agent-aaaa.jsonl" <<'J'
{"type":"user","timestamp":"2026-09-14T10:01:00Z","message":{"content":"review this"}}
{"type":"assistant","timestamp":"2026-09-14T10:01:05Z","message":{"content":[{"type":"text","text":"found 2"}]}}
{"type":"user","timestamp":"2026-09-14T10:01:06Z","message":{"content":[{"type":"tool_result","is_error":true,"content":"denied"}]}}
{"type":"user","timestamp":"2026-09-14T10:01:07Z","message":{"content":[{"type":"tool_result","is_error":true,"content":"rejected by user"}]}}
J
printf '{"agentType":"code-review:code-reviewer","spawnDepth":1}\n' > "$adir/agent-aaaa.meta.json"
cat > "$adir/agent-bbbb.jsonl" <<'J'
{"type":"assistant","timestamp":"2026-09-14T10:02:00Z","message":{"content":[{"type":"text","text":"done"}]}}
J

payload() { printf '{"session_id":"%s","transcript_path":"%s","cwd":"%s","reason":"exit","hook_event_name":"SessionEnd"}' "$sid" "$transcript" "$proj"; }

payload | bash "$HOOK"; rc=$?
check "exit 0"            '[ "$rc" -eq 0 ]'
check "ledger exists"     '[ -f "$ledger" ]'
check "three rows"        '[ "$(wc -l <"$ledger")" -eq 3 ]'
check "session row first" 'head -1 "$ledger" | jq -e "(.kind // \"session\") == \"session\" and .turns == 2 and .user_msgs == 1 and .errors == 1" >/dev/null'
check "agent row typed"   'grep -F "\"agent_id\":\"agent-aaaa\"" "$ledger" | jq -e ".kind == \"agent\" and .agent_type == \"code-review:code-reviewer\" and .session_id == \"$sid\"" >/dev/null'
check "agent friction"    'grep -F "\"agent_id\":\"agent-aaaa\"" "$ledger" | jq -e ".errors == 2 and .friction_events == 2 and .mined == false" >/dev/null'
check "agent path"        'grep -F "\"agent_id\":\"agent-aaaa\"" "$ledger" | jq -e ".transcript_path == \"$adir/agent-aaaa.jsonl\"" >/dev/null'
check "meta-less agent"   'grep -F "\"agent_id\":\"agent-bbbb\"" "$ledger" | jq -e ".agent_type == \"unknown\" and .turns == 1" >/dev/null'

# Second SessionEnd for the same session (a resume): the session row appends
# again (pre-existing behaviour, unchanged), the agents do NOT.
payload | bash "$HOOK"
check "agents deduped"    '[ "$(grep -c "\"kind\":\"agent\"" "$ledger")" -eq 2 ]'
check "session re-added"  '[ "$(wc -l <"$ledger")" -eq 4 ]'

# No subagents dir → just the session row, exit 0.
sid2="22222222-2222-3333-4444-555555555555"; cp "$transcript" "$tdir/$sid2.jsonl"
printf '{"session_id":"%s","transcript_path":"%s","cwd":"%s","reason":"exit"}' "$sid2" "$tdir/$sid2.jsonl" "$proj" | bash "$HOOK"; rc=$?
check "no-agents exit 0"  '[ "$rc" -eq 0 ]'
check "no-agents one row" '[ "$(grep -c "\"session_id\":\"$sid2\"" "$ledger")" -eq 1 ]'

# Fail-silent: garbage payload, missing transcript, no jq on PATH.
out=$(printf 'not json' | bash "$HOOK" 2>&1); rc=$?
check "garbage exit 0"    '[ "$rc" -eq 0 ] && [ -z "$out" ]'
out=$(printf '{"session_id":"x","transcript_path":"/nonexistent","cwd":"%s","reason":"exit"}' "$proj" | bash "$HOOK" 2>&1); rc=$?
check "missing transcript exit 0" '[ "$rc" -eq 0 ] && [ -z "$out" ]'
out=$(payload | PATH=/nonexistent /bin/bash "$HOOK" 2>&1); rc=$?
check "no jq exit 0"      '[ "$rc" -eq 0 ] && [ -z "$out" ]'

echo "collect tests: $pass passed, $fail failed"
exit $((fail > 0))
