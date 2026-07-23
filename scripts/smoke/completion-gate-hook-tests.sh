#!/usr/bin/env bash
# Smoke tests for the task-runner completion-gate Stop hook.
#
# The hook is a cheap RECORDS check (no test execution): given a throwaway git repo
# as .cwd, it enforces that a run which registered itself (active-run.json) has a
# gate-pass.json recorded for the current HEAD before it stops clean. These cases
# drive the hook with canned Stop-hook stdin JSON and assert rc + stderr.
#
# DEFAULT IS BLOCK (exit 2) — a Stop hook reaches the model only through exit 2, so the
# cases below assert the default blocks and that TASK_RUNNER_STOP_GATE=warn downgrades
# each blocking path to print-only. Both modes are covered on every branch that can block.
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
NUDGE="$REPO/.claude/task-runner/gate-nudge"

# check <desc> <env> <json> <exp_rc> <exp_substr|__NONE__>
# The hook blocks at most ONCE per HEAD, so each case starts from a cleared nudge marker
# and is judged on its own. check_keep() preserves the marker — that is how the
# one-block-per-HEAD bound itself is tested.
check() { rm -f "$NUDGE"; check_keep "$@"; }
check_keep() {
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

# 2) registered, no gate-pass, DEFAULT -> BLOCK (exit 2). This is the stalled-run case:
#    a run that registered itself and then yielded in prose with no card started.
printf '{"slug":"demo-run","base":"HEAD"}' > "$SENT"; rm -f "$GP"
check "registered + no gate-pass (default) -> exit 2" "" "$J" 2 "completion-gate"

# 2b) the blocked stop must carry the mid-run branch, not only the completion branch —
#     naming just "run behavioral-gate.sh" is useless to a run that is on card 1 of 17.
check "block message names the mid-run continue path" "" "$J" 2 "AskUserQuestion"

# 2c) opt-out: warn mode downgrades the same case to print-only
check "registered + no gate-pass (warn) -> print-only exit 0" "TASK_RUNNER_STOP_GATE=warn" "$J" 0 "completion-gate"

# 3) registered, no gate-pass, explicit block mode -> BLOCK (exit 2)
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

# 8-11) card-count completeness for index runs: a gate pass for HEAD is present, and
# run.md also recorded {cards_total,cards_done,cards_parked}. The hook refuses a clean
# stop while cards_done + cards_parked < cards_total; absent fields = legacy pass.
printf '{"slug":"demo-run","base":"HEAD"}' > "$SENT"    # restore valid sentinel (case 7 left it malformed)

# 8) complete counts (done+parked == total) -> allow, silent (even under block)
printf '{"head":"%s","cards_total":3,"cards_done":2,"cards_parked":1}' "$HEAD" > "$GP"
check "complete card counts (block) -> allow, silent" "TASK_RUNNER_STOP_GATE=block" "$J" 0 __NONE__

# 9) incomplete counts (done+parked < total), default -> BLOCK exit 2; warn downgrades
printf '{"head":"%s","cards_total":13,"cards_done":10,"cards_parked":0}' "$HEAD" > "$GP"
check "incomplete card counts (default) -> exit 2" "" "$J" 2 "incomplete"
check "incomplete card counts (warn) -> print-only exit 0" "TASK_RUNNER_STOP_GATE=warn" "$J" 0 "incomplete"

# 10) incomplete counts, block mode -> BLOCK exit 2
check "incomplete card counts (block) -> exit 2" "TASK_RUNNER_STOP_GATE=block" "$J" 2 "incomplete"

# 11) card-count fields absent (legacy gate-pass) -> allow, silent (backward compatible)
printf '{"head":"%s"}' "$HEAD" > "$GP"
check "card-count fields absent (block) -> legacy allow, silent" "TASK_RUNNER_STOP_GATE=block" "$J" 0 __NONE__

# 12) non-numeric count (a quoted "13") -> MALFORMED, never a silent disarm
printf '{"head":"%s","cards_total":"13","cards_done":10,"cards_parked":0}' "$HEAD" > "$GP"
check "string card count (default) -> malformed exit 2" "" "$J" 2 "malformed"
check "string card count (warn) -> malformed print-only exit 0" "TASK_RUNNER_STOP_GATE=warn" "$J" 0 "malformed"

# 13) partially present fields (one count missing) -> MALFORMED, blocks under block mode
printf '{"head":"%s","cards_total":13,"cards_done":10}' "$HEAD" > "$GP"
check "missing one count field (block) -> malformed exit 2" "TASK_RUNNER_STOP_GATE=block" "$J" 2 "malformed"

# 14) inconsistent bookkeeping (done+parked > total) -> MALFORMED
printf '{"head":"%s","cards_total":3,"cards_done":3,"cards_parked":1}' "$HEAD" > "$GP"
check "done+parked > total (default) -> malformed exit 2" "" "$J" 2 "malformed"
check "done+parked > total (warn) -> malformed print-only exit 0" "TASK_RUNNER_STOP_GATE=warn" "$J" 0 "malformed"

# 15) zero-card index (total=0, nothing done) -> complete, allow silent
printf '{"head":"%s","cards_total":0,"cards_done":0,"cards_parked":0}' "$HEAD" > "$GP"
check "cards_total=0 (block) -> complete allow, silent" "TASK_RUNNER_STOP_GATE=block" "$J" 0 __NONE__

# 16) run REGISTERED as an index run (sentinel carries index_path) but gate-pass has no
#     counts -> malformed warn, never a silent legacy allow
printf '{"slug":"demo-run","base":"HEAD","index_path":"taskmaster-docs/tasks/x/00-INDEX.md"}' > "$SENT"
printf '{"head":"%s"}' "$HEAD" > "$GP"
check "index-registered run, counts absent (default) -> exit 2" "" "$J" 2 "malformed"
check "index-registered run, counts absent (warn) -> print-only exit 0" "TASK_RUNNER_STOP_GATE=warn" "$J" 0 "malformed"

# 17) same but block mode -> exit 2
check "index-registered run, counts absent (block) -> exit 2" "TASK_RUNNER_STOP_GATE=block" "$J" 2 "malformed"
printf '{"slug":"demo-run","base":"HEAD"}' > "$SENT"    # restore plain sentinel

# 18-20) BRANCH GUARD — a sentinel is cleared only on clean completion, so an abandoned
# run leaves one behind. It must not block unrelated work on another branch.
rm -f "$GP"
git -C "$REPO" checkout -q -b other-branch
printf '{"slug":"demo-run","base":"HEAD","branch":"%s"}' "$(git -C "$REPO" rev-parse --abbrev-ref HEAD)" > "$SENT"
check "sentinel branch == current branch -> enforced" "" "$J" 2 "completion-gate"

printf '{"slug":"demo-run","base":"HEAD","branch":"a-dead-run-branch"}' > "$SENT"
check "sentinel from another branch -> not enforced" "" "$J" 0 "not enforced here"

printf '{"slug":"demo-run","base":"HEAD"}' > "$SENT"   # pre-0.17 sentinel, no branch field
check "sentinel without branch field -> enforced (back-compat)" "" "$J" 2 "completion-gate"

# 21-25) ONE BLOCK PER HEAD — the bound that keeps a stale sentinel from nagging every
# stop. Independent of stop_hook_active: the hook records the HEAD it blocked on.
# mtimes are set explicitly: the marker counts only while it is newer than the sentinel
# it was written under, and a same-tick write would otherwise make these cases racy.
touch -t 200001010000 "$SENT"          # registration precedes the block it provoked
check_keep "second stop at the same HEAD -> print-only exit 0" "" "$J" 0 "completion-gate"
if [ "$(cat "$NUDGE" 2>/dev/null)" = "$HEAD" ]; then
  echo "PASS: nudge marker records the blocked HEAD"; pass=$((pass+1))
else
  echo "FAIL: nudge marker missing or wrong"; fail=$((fail+1))
fi

# a marker left by an EARLIER run must not eat this run's first block: same HEAD, no
# commit in between, but a fresh registration — the case a per-repo marker gets wrong.
touch "$SENT"                          # re-register at the same HEAD, after the marker
check_keep "marker predating this registration -> block still fires" "" "$J" 2 "completion-gate"
touch -t 200001010000 "$SENT"          # back to within-run ordering for the cases below

# a new commit re-arms the gate — enforcement rides on progress, so a real run is held
# at every card boundary, not nudged once for the whole run
echo more >> "$REPO/f.txt"; git -C "$REPO" add -A; git -C "$REPO" commit -qm second
HEAD="$(git -C "$REPO" rev-parse HEAD)"
check "new commit re-arms the gate -> exit 2 again" "" "$J" 2 "completion-gate"

# warn mode never writes a marker, so it cannot disarm a later block
check "warn mode -> print-only" "TASK_RUNNER_STOP_GATE=warn" "$J" 0 "completion-gate"
if [ -e "$NUDGE" ]; then
  echo "FAIL: warn mode wrote a nudge marker"; fail=$((fail+1))
else
  echo "PASS: warn mode leaves no marker"; pass=$((pass+1))
fi
check "block still fires after a warn-mode stop" "" "$J" 2 "completion-gate"

# ---- per-card negative-control coverage (opt-in by nc/ dir presence) ----
NC="$ROOT/plugins/task-runner/scripts/negative-control.sh"
NCDIR="$REPO/.claude/task-runner/nc"
printf '{"slug":"t","branch":"%s","index_path":"x/00-INDEX.md"}' "$(git -C "$REPO" rev-parse --abbrev-ref HEAD)" > "$SENT"
printf '{"head":"%s","cards_total":3,"cards_done":3,"cards_parked":0}' "$HEAD" > "$GP"

# no nc/ dir at all -> legacy allow (run did not opt into the convention)
rm -rf "$NCDIR"
check "complete counts, no nc dir -> legacy allow" "" "$J" 0 __NONE__

# nc/ dir with fewer records than cards_done -> block (a done card had no control)
mkdir -p "$NCDIR"
printf '{"card":"01"}' > "$NCDIR/nc-pass-01.json"
check "nc records 1 < done 3 -> block" "" "$J" 2 "negative-control records"
check "nc records short + warn mode -> print-only" "TASK_RUNNER_STOP_GATE=warn" "$J" 0 "negative-control records"

# records covering done count (mix of mechanical pass + documented skip) -> allow
out=$("$NC" --skip "visual-only card" --record-dir "$NCDIR" --card 02 2>&1)
printf '%s' "$out" | grep -q skip-recorded \
  && { echo "PASS: --skip writes a skip record"; pass=$((pass+1)); } \
  || { echo "FAIL: --skip writes a skip record (out=<$out>)"; fail=$((fail+1)); }
[ -f "$NCDIR/nc-skip-02.json" ] \
  && { echo "PASS: nc-skip-02.json exists with reason"; pass=$((pass+1)); } \
  || { echo "FAIL: nc-skip-02.json missing"; fail=$((fail+1)); }
printf '{"card":"03"}' > "$NCDIR/nc-pass-03.json"
check "nc records 3 == done 3 -> allow" "" "$J" 0 __NONE__

# mechanical pass-record path: a discriminating control writes nc-pass-<card>.json itself
FIX="$WS/ncfix"; mkdir -p "$FIX"
printf 'echo OK\n' > "$FIX/impl.sh"
( cd "$FIX" && bash "$NC" --verify 'bash impl.sh | grep -q OK' --target impl.sh \
    --mutate 's/OK/NO/' --record-dir "$NCDIR" --card 04 >/dev/null 2>&1 )
rc=$?
if [ "$rc" = 0 ] && [ -f "$NCDIR/nc-pass-04.json" ] \
   && jq -e '.card=="04"' "$NCDIR/nc-pass-04.json" >/dev/null 2>&1; then
  echo "PASS: discriminating control writes nc-pass record mechanically"; pass=$((pass+1))
else
  echo "FAIL: discriminating control writes nc-pass record (rc=$rc)"; fail=$((fail+1))
fi

printf -- '---- %s passed, %s failed ----\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
