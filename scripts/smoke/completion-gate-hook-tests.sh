#!/usr/bin/env bash
# Smoke tests for the task-runner completion-gate Stop hook.
#
# The hook is a cheap RECORDS check (no test execution): given a throwaway git repo
# as .cwd, it enforces that a run which registered itself (active-run.json) has a
# gate-pass.json recorded for the current HEAD before it stops clean. These cases
# drive the hook with canned Stop-hook stdin JSON and assert rc + stderr.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$ROOT/plugins/task-runner/hooks/completion-gate.sh"

command -v jq  >/dev/null 2>&1 || { echo "SKIP: jq not available (hook fails open without it)"; exit 0; }
command -v git >/dev/null 2>&1 || { echo "SKIP: git not available"; exit 0; }
[ -x "$HOOK" ] || { echo "FAIL: hook not executable at $HOOK"; exit 1; }

pass=0; fail=0
WS="$(mktemp -d)"; trap 'rm -rf "$WS"' EXIT

REPO="$WS/repo"; mkdir -p "$REPO/.claude/task-runner"
git -C "$REPO" init -q
git -C "$REPO" config user.email t@t.t; git -C "$REPO" config user.name t
echo hi > "$REPO/f.txt"; git -C "$REPO" add -A; git -C "$REPO" commit -qm init
HEAD="$(git -C "$REPO" rev-parse HEAD)"

SENT="$REPO/.claude/task-runner/active-run.json"
GP="$REPO/.claude/task-runner/gate-pass.json"

# check <desc> <env> <json> <exp_rc> <exp_substr|__NONE__>
check() {
  local desc="$1" envv="$2" json="$3" exp_rc="$4" exp_sub="$5" err rc ok=1
  set +e
  err=$(printf '%s' "$json" | env $envv bash "$HOOK" 2>&1 1>/dev/null); rc=$?
  set -e
  [ "$rc" = "$exp_rc" ] || ok=0
  if [ "$exp_sub" = "__NONE__" ]; then
    [ -z "$err" ] || ok=0
  else
    printf '%s' "$err" | grep -q -- "$exp_sub" || ok=0
  fi
  if [ "$ok" = 1 ]; then printf 'PASS: %s (rc=%s)\n' "$desc" "$rc"; pass=$((pass+1))
  else printf 'FAIL: %s (rc=%s want=%s; err=<%s>)\n' "$desc" "$rc" "$exp_rc" "$err"; fail=$((fail+1)); fi
}

J='{"cwd":"'"$REPO"'","stop_hook_active":false}'
JACTIVE='{"cwd":"'"$REPO"'","stop_hook_active":true}'

# 1) no registered run -> no-op, silent
rm -f "$SENT" "$GP"
check "no active-run sentinel -> silent no-op" "" "$J" 0 __NONE__

# 2) registered, no gate-pass, default -> WARN (exit 0) with a reminder
printf '{"slug":"demo-run","base":"HEAD"}' > "$SENT"; rm -f "$GP"
check "registered + no gate-pass (default) -> warn exit 0" "" "$J" 0 "completion-gate"

# 3) registered, no gate-pass, block mode -> BLOCK (exit 2)
check "registered + no gate-pass (block) -> exit 2" "TASK_RUNNER_STOP_GATE=block" "$J" 2 "completion-gate"

# 4) registered + gate-pass matching HEAD -> allow, silent (even under block)
printf '{"head":"%s"}' "$HEAD" > "$GP"
check "gate-pass matches HEAD (block) -> allow, silent" "TASK_RUNNER_STOP_GATE=block" "$J" 0 __NONE__

# 5) registered + STALE gate-pass (wrong head), block -> BLOCK
printf '{"head":"deadbeefdeadbeef"}' > "$GP"
check "stale gate-pass head (block) -> exit 2" "TASK_RUNNER_STOP_GATE=block" "$J" 2 "completion-gate"

# 6) stop_hook_active=true -> never re-trigger, silent (even registered + block)
rm -f "$GP"
check "stop_hook_active guards against loop" "TASK_RUNNER_STOP_GATE=block" "$JACTIVE" 0 __NONE__

# 7) malformed sentinel -> fail-open exit 0 with a warning
printf '{not valid json' > "$SENT"
check "malformed active-run.json -> fail-open exit 0" "TASK_RUNNER_STOP_GATE=block" "$J" 0 "malformed"

printf -- '---- %s passed, %s failed ----\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
