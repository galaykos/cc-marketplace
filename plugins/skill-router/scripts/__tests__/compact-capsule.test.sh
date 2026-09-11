#!/usr/bin/env bash
# Author-time tests for hooks/compact-capsule.sh — the SessionStart(compact)
# capsule that re-states on-disk task state after a compaction.
#
# Drives the hook with the payload shape the host sends on SessionStart
# (session_id, cwd, source) and asserts: silent on every non-compact source,
# silent when no ledger exists, names each ledger it knows with its file path,
# says whether the phase sentinel was written by this session, appends one
# measurement line per firing, and fails open on malformed ledgers.
set -u
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
HOOK="$ROOT/plugins/skill-router/hooks/compact-capsule.sh"
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available (hook fails open without it)"; exit 0; }
[ -x "$HOOK" ] || { echo "FAIL: hook not executable at $HOOK"; exit 1; }

pass=0; fail=0
WS="$(mktemp -d)"; trap 'rm -rf "$WS"' EXIT
CWD="$WS/proj"; mkdir -p "$CWD"

payload() { jq -cn --arg s "$1" --arg c "$CWD" --arg sid "$2" '{hook_event_name:"SessionStart",source:$s,cwd:$c,session_id:$sid}'; }
run()     { payload "$1" "$2" | bash "$HOOK" 2>/dev/null; }

check() { # desc  source  sid  expect(silent|has:<substr>|absent:<substr>)
  local desc="$1" src="$2" sid="$3" exp="$4" out rc
  out=$(run "$src" "$sid"); rc=$?
  if [ "$rc" -ne 0 ]; then echo "FAIL $desc: exit $rc (must fail open)"; fail=$((fail+1)); return; fi
  case "$exp" in
    silent)   [ -z "$out" ] && pass=$((pass+1)) || { echo "FAIL $desc: expected silence, got: ${out:0:80}"; fail=$((fail+1)); } ;;
    has:*)    grep -qF -- "${exp#has:}" <<<"$out" && pass=$((pass+1)) || { echo "FAIL $desc: missing [${exp#has:}] in: ${out:0:200}"; fail=$((fail+1)); } ;;
    absent:*) grep -qF -- "${exp#absent:}" <<<"$out" && { echo "FAIL $desc: unexpected [${exp#absent:}]"; fail=$((fail+1)); } || pass=$((pass+1)) ;;
  esac
}

reset() { rm -rf "$CWD/.claude"; mkdir -p "$CWD/.claude"; }

# 1. no ledgers → silent on every source, including compact
reset
for s in startup resume clear fork compact; do check "no ledgers, source=$s" "$s" S1 silent; done

# 2. phase sentinel written by THIS session
reset
printf '{"phase":"build","owner":"task-runner:run","session_id":"S1","started_at":"2026-09-10T10:00:00Z"}' > "$CWD/.claude/cc-phase.json"
check "phase: startup stays silent"        startup S1 silent
check "phase: compact names the phase"     compact S1 "has:arc phase \`build\`"
check "phase: names the owner"             compact S1 "has:owned by task-runner:run"
check "phase: names the file"              compact S1 "has:.claude/cc-phase.json"
check "phase: same session wording"        compact S1 "has:declared by this session"
check "phase: other session wording"       compact S2 "has:declared by another session"
check "phase: approaches marker not mentioned" compact S1 "absent:deliberated.json"

# 3. measurement rider: one line per firing, match recorded truthfully
reset
printf '{"phase":"shape","owner":"taskmaster:task","session_id":"S1"}' > "$CWD/.claude/cc-phase.json"
run compact S1 >/dev/null; run compact S9 >/dev/null
log="$CWD/.claude/skill-router/compact-log.jsonl"
if [ -f "$log" ] && [ "$(wc -l < "$log" | tr -d ' ')" = 2 ] \
   && sed -n 1p "$log" | jq -e '.sentinel_session_matches_payload == true'  >/dev/null \
   && sed -n 2p "$log" | jq -e '.sentinel_session_matches_payload == false' >/dev/null; then pass=$((pass+1))
else echo "FAIL measurement log: $(cat "$log" 2>/dev/null)"; fail=$((fail+1)); fi

# 4. task-runner run + scope lock + taskmaster ledgers
reset
mkdir -p "$CWD/.claude/task-runner" "$CWD/.claude/taskmaster"
printf '{"slug":"2026-09-10-orders","base":"abc","branch":"feat/orders","index_path":"taskmaster-docs/tasks/2026-09-10-orders/00-INDEX.md"}' > "$CWD/.claude/task-runner/active-run.json"
printf '{"files":["src/a.ts"]}' > "$CWD/.claude/task-runner/scope.json"
: > "$CWD/.claude/taskmaster/ledger-orders.md"
: > "$CWD/.claude/taskmaster/goal-ledger-orders.md"
check "run: slug named"        compact S1 "has:registered task-runner run \`2026-09-10-orders\`"
check "run: branch named"      compact S1 "has:on branch feat/orders"
check "run: index path named"  compact S1 "has:cards at taskmaster-docs/tasks/2026-09-10-orders/00-INDEX.md"
check "run: gate reminder"     compact S1 "has:completion gate"
check "scope: named"           compact S1 "has:.claude/task-runner/scope.json"
check "ledger: named"          compact S1 "has:ledger-orders.md"
check "goal ledger: named"     compact S1 "has:goal-ledger-orders.md"
check "no phase → no measurement line" compact S1 "absent:cc-phase.json"
[ -f "$CWD/.claude/skill-router/compact-log.jsonl" ] && { echo "FAIL: measurement line written without a sentinel"; fail=$((fail+1)); } || pass=$((pass+1))

# 5. malformed sentinel → fail open (silent, exit 0), other ledgers still reported
reset
mkdir -p "$CWD/.claude/task-runner"
printf 'not json' > "$CWD/.claude/cc-phase.json"
printf '{"slug":"x"}' > "$CWD/.claude/task-runner/active-run.json"
check "malformed sentinel: run still named" compact S1 "has:registered task-runner run \`x\`"
check "malformed sentinel: phase absent"    compact S1 "absent:arc phase"

# 6. missing cwd / empty payload → silent, exit 0
out=$(printf '{}' | bash "$HOOK" 2>/dev/null); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && pass=$((pass+1)) || { echo "FAIL empty payload: rc=$rc out=$out"; fail=$((fail+1)); }
out=$(printf '{"source":"compact","cwd":"/nonexistent/x"}' | bash "$HOOK" 2>/dev/null); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && pass=$((pass+1)) || { echo "FAIL missing cwd: rc=$rc out=$out"; fail=$((fail+1)); }

echo "compact-capsule: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
