#!/usr/bin/env bash
# compact-capsule.test.sh — runs hooks/compact-capsule.sh on host-shaped SessionStart payloads; each numbered case names what it asserts.
# Why, limits, history: rationale/derivations/plugin-skill-router.md § plugins/skill-router/scripts/__tests__/compact-capsule.test.sh
set -u
# A live session exports it; cc_state_root takes it as the root of any non-git cwd beneath it.
unset CLAUDE_PROJECT_DIR
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

reset() { rm -rf "$CWD/.claude" "$CWD/.cc-artifacts"; mkdir -p "$CWD/.cc-artifacts/cc-phase"; }

# 1. no ledgers → silent on every source, including compact
reset
for s in startup resume clear fork compact; do check "no ledgers, source=$s" "$s" S1 silent; done

# 2. phase sentinel written by THIS session, under its own key; another session's is not this one's state
reset
printf '{"phase":"build","owner":"task-runner:run","session_id":"S1","started_at":"2026-09-10T10:00:00Z"}' > "$CWD/.cc-artifacts/cc-phase/S1.json"
check "phase: startup stays silent"        startup S1 silent
check "phase: compact names the phase"     compact S1 "has:arc phase \`build\`"
check "phase: names the owner"             compact S1 "has:owned by task-runner:run"
check "phase: names the file"              compact S1 "has:.cc-artifacts/cc-phase/S1.json"
check "phase: same session wording"        compact S1 "has:declared by this session"
check "phase: another session's phase is not reported" compact S2 "absent:arc phase"
mkdir -p "$CWD/.claude"; printf '{"phase":"build","owner":"x:y"}' > "$CWD/.claude/cc-phase.json"
check "phase: a legacy repo-wide sentinel is not reported" compact S2 "absent:arc phase"
rm -f "$CWD/.claude/cc-phase.json"
check "phase: approaches marker not mentioned" compact S1 "absent:deliberated.json"

# 3. measurement rider: one line per firing, match recorded truthfully
reset
printf '{"phase":"shape","owner":"taskmaster:task","session_id":"S1"}' > "$CWD/.cc-artifacts/cc-phase/S1.json"
run compact S1 >/dev/null; run compact S9 >/dev/null
log="$CWD/.cc-artifacts/skill-router/compact-log.jsonl"
if [ -f "$log" ] && [ "$(wc -l < "$log" | tr -d ' ')" = 2 ] \
   && sed -n 1p "$log" | jq -e '.sentinel_session_matches_payload == true'  >/dev/null \
   && sed -n 2p "$log" | jq -e '.sentinel_session_matches_payload == false' >/dev/null; then pass=$((pass+1))
else echo "FAIL measurement log: $(cat "$log" 2>/dev/null)"; fail=$((fail+1)); fi

# 4. task-runner run + scope lock + taskmaster ledgers
reset
mkdir -p "$CWD/.cc-artifacts/task-runner" "$CWD/.cc-artifacts/taskmaster"
printf '{"slug":"2026-09-10-orders","base":"abc","branch":"feat/orders","index_path":".cc-artifacts/taskmaster/tasks/2026-09-10-orders/00-INDEX.md"}' > "$CWD/.cc-artifacts/task-runner/active-run.json"
printf '{"files":["src/a.ts"]}' > "$CWD/.cc-artifacts/task-runner/scope.json"
: > "$CWD/.cc-artifacts/taskmaster/ledger-orders.md"
: > "$CWD/.cc-artifacts/taskmaster/goal-ledger-orders.md"
check "run: slug named"        compact S1 "has:registered task-runner run \`2026-09-10-orders\`"
check "run: branch named"      compact S1 "has:on branch feat/orders"
check "run: index path named"  compact S1 "has:cards at .cc-artifacts/taskmaster/tasks/2026-09-10-orders/00-INDEX.md"
check "run: gate reminder"     compact S1 "has:completion gate"
check "run: file named"        compact S1 "has:— .cc-artifacts/task-runner/active-run.json"
check "scope: named"           compact S1 "has:.cc-artifacts/task-runner/scope.json"
check "ledger: named"          compact S1 "has:ledger-orders.md"
check "goal ledger: named"     compact S1 "has:goal-ledger-orders.md"
check "ledger: dir named"      compact S1 "has:ledger-orders.md — .cc-artifacts/taskmaster/ (grill"
check "no phase → no measurement line" compact S1 "absent:cc-phase/"
[ -f "$CWD/.cc-artifacts/skill-router/compact-log.jsonl" ] && { echo "FAIL: measurement line written without a sentinel"; fail=$((fail+1)); } || pass=$((pass+1))

# 5. malformed sentinel → fail open (silent, exit 0), other ledgers still reported
reset
mkdir -p "$CWD/.cc-artifacts/task-runner"
printf 'not json' > "$CWD/.cc-artifacts/cc-phase/S1.json"
printf '{"slug":"x"}' > "$CWD/.cc-artifacts/task-runner/active-run.json"
check "malformed sentinel: run still named" compact S1 "has:registered task-runner run \`x\`"
check "malformed sentinel: phase absent"    compact S1 "absent:arc phase"

# 6. missing cwd / empty payload → silent, exit 0
out=$(printf '{}' | bash "$HOOK" 2>/dev/null); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && pass=$((pass+1)) || { echo "FAIL empty payload: rc=$rc out=$out"; fail=$((fail+1)); }
out=$(printf '{"source":"compact","cwd":"/nonexistent/x"}' | bash "$HOOK" 2>/dev/null); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && pass=$((pass+1)) || { echo "FAIL missing cwd: rc=$rc out=$out"; fail=$((fail+1)); }

# 7. payload cwd = a subdirectory of a git repo (the model `cd`-ed before compaction):
#    ledgers at the repo root are still named, the measurement line lands at the root,
#    and no `.claude/` or `.cc-artifacts/` appears in the subdirectory.
if command -v git >/dev/null 2>&1; then
  G="$WS/gitproj"; mkdir -p "$G/app/Enums" "$G/.cc-artifacts/task-runner" "$G/.cc-artifacts/cc-phase"; git -C "$G" init -q
  printf '{"phase":"build","owner":"task-runner:run","session_id":"S1"}' > "$G/.cc-artifacts/cc-phase/S1.json"
  printf '{"slug":"sub"}' > "$G/.cc-artifacts/task-runner/active-run.json"
  out=$(jq -cn --arg c "$G/app/Enums" '{hook_event_name:"SessionStart",source:"compact",cwd:$c,session_id:"S1"}' | bash "$HOOK" 2>/dev/null)
  grep -qF 'arc phase `build`' <<<"$out" && grep -qF 'registered task-runner run `sub`' <<<"$out" && pass=$((pass+1)) \
    || { echo "FAIL subdir cwd: root ledgers not named: ${out:0:200}"; fail=$((fail+1)); }
  [ -s "$G/.cc-artifacts/skill-router/compact-log.jsonl" ] && pass=$((pass+1)) \
    || { echo "FAIL subdir cwd: measurement line not at the repo root"; fail=$((fail+1)); }
  [ ! -e "$G/app/Enums/.claude" ] && [ ! -e "$G/app/Enums/.cc-artifacts" ] && pass=$((pass+1)) \
    || { echo "FAIL subdir cwd: stray state dir created in app/Enums"; fail=$((fail+1)); }
else
  echo "SKIP subdir cwd: git not available"
fi

# 8. state written before 2026-11-14 under .claude/ only: each file is named at its old path, the log lands in
#    .cc-artifacts/skill-router/, and the old files are left byte-identical with no new state dir created for them.
reset; rm -rf "$CWD/.cc-artifacts"
mkdir -p "$CWD/.claude/cc-phase" "$CWD/.claude/task-runner" "$CWD/.claude/taskmaster"
printf '{"phase":"build","owner":"task-runner:run","session_id":"S1"}' > "$CWD/.claude/cc-phase/S1.json"
printf '{"slug":"old-run","branch":"feat/old"}' > "$CWD/.claude/task-runner/active-run.json"
printf '{"files":["src/a.ts"]}' > "$CWD/.claude/task-runner/scope.json"
: > "$CWD/.claude/taskmaster/ledger-old.md"
before=$(cd "$CWD/.claude" && find . -type f | sort | xargs cksum)
check "legacy: phase file named"    compact S1 "has:.claude/cc-phase/S1.json (reminder"
check "legacy: run file named"      compact S1 "has:registered task-runner run \`old-run\` on branch feat/old — .claude/task-runner/active-run.json"
check "legacy: scope named"         compact S1 "has:.claude/task-runner/scope.json"
check "legacy: ledger dir named"    compact S1 "has:ledger-old.md — .claude/taskmaster/"
[ "$(cd "$CWD/.claude" && find . -type f | sort | xargs cksum)" = "$before" ] && [ ! -e "$CWD/.claude/skill-router" ] \
  && [ -s "$CWD/.cc-artifacts/skill-router/compact-log.jsonl" ] \
  && [ ! -e "$CWD/.cc-artifacts/task-runner" ] && [ ! -e "$CWD/.cc-artifacts/taskmaster" ] && [ ! -e "$CWD/.cc-artifacts/cc-phase" ] \
  && pass=$((pass+1)) || { echo "FAIL legacy: old files changed or the log missed .cc-artifacts/skill-router/"; fail=$((fail+1)); }
# Once .cc-artifacts/task-runner/ exists it is the run's only home: a stale old active-run.json is not a live run.
mkdir -p "$CWD/.cc-artifacts/task-runner"
check "legacy: old run ignored once the new dir exists" compact S1 "absent:old-run"
# The new sentinel and ledgers win over the old ones.
mkdir -p "$CWD/.cc-artifacts/cc-phase" "$CWD/.cc-artifacts/taskmaster"
printf '{"phase":"review","owner":"x:y","session_id":"S1"}' > "$CWD/.cc-artifacts/cc-phase/S1.json"
: > "$CWD/.cc-artifacts/taskmaster/ledger-new.md"
check "legacy: new phase wins"      compact S1 "has:arc phase \`review\`"
check "legacy: new ledgers win"     compact S1 "absent:ledger-old.md"

echo "compact-capsule: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
