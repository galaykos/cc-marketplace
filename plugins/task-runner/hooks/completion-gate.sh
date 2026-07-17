#!/bin/bash
# Absolute-path shebang: fail-open must hold under a stripped PATH.
# Stop hook — completion-gate enforcement for a task-runner run.
#
# WHAT IT DOES: on every Stop, if a run has REGISTERED itself (the run wrote
# $cwd/.claude/task-runner/active-run.json at start), this checks whether the
# behavioral-gate recorded a PASS for the current HEAD in gate-pass.json. If not,
# it surfaces a reminder that the produced code was never run through the gate — a
# green repo suite alone is NOT the gate. With TASK_RUNNER_STOP_GATE=block it exits
# 2 to BLOCK the stop and feed the reason back to the model.
#
# WHY A RECORDS CHECK, NOT A TEST RUN: this hook fires on EVERY yield, so it must be
# cheap and never mutate the tree. It never executes the produced tests — the
# completion protocol runs behavioral-gate.sh in the proper isolated way and records
# the pass here. This hook only verifies that record exists for the final commit.
#
# HONEST LIMIT (documented, not hidden): enforcement is keyed off the run REGISTERING
# itself. A run that never writes active-run.json is not enforced (fail-open) — the
# same residual the behavioral-gate skill names. What this closes is the honest-but-
# forgetful path: a registered run cannot stop "done" without a recorded gate pass.
#
# Default is WARN (safe on every yield). Opt into hard blocking with
# TASK_RUNNER_STOP_GATE=block. Fail-open on missing jq/git or a malformed sentinel.

input=$(cat)

command -v jq >/dev/null 2>&1 || { echo "[task-runner] completion-gate: jq not found — gate not enforced" >&2; exit 0; }

cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$cwd" ] || exit 0

# Never re-trigger from our own continuation.
[ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)" = "true" ] && exit 0

sentinel="$cwd/.claude/task-runner/active-run.json"
[ -r "$sentinel" ] || exit 0                     # no registered run → nothing to enforce
jq empty "$sentinel" 2>/dev/null || { echo "[task-runner] completion-gate: active-run.json malformed — not enforced" >&2; exit 0; }

command -v git >/dev/null 2>&1 || { echo "[task-runner] completion-gate: git not found — not enforced" >&2; exit 0; }
head=$(git -C "$cwd" rev-parse HEAD 2>/dev/null) || { echo "[task-runner] completion-gate: not a git repo — not enforced" >&2; exit 0; }

gatepass="$cwd/.claude/task-runner/gate-pass.json"
if [ -r "$gatepass" ] && [ "$(jq -r '.head // empty' "$gatepass" 2>/dev/null)" = "$head" ]; then
  # Gate pass recorded for THIS commit. For an index run, run.md also records card
  # counts in gate-pass.json; when those numeric fields are present, refuse a clean
  # stop while any card is neither done nor parked (cards_done + cards_parked <
  # cards_total). ALL fields absent → legacy behavior (allow). Partially present,
  # non-numeric, or inconsistent (done+parked > total) counts are MALFORMED — warned,
  # never silently allowed, so a bookkeeping slip cannot disarm the gate. Same
  # warn-by-default / block semantics as the no-pass path below.
  verdict=$(jq -r '
    if ((.cards_total|type)=="number" and (.cards_done|type)=="number" and (.cards_parked|type)=="number")
    then (if (.cards_done + .cards_parked) < .cards_total then "incomplete"
          elif (.cards_done + .cards_parked) > .cards_total then "malformed"
          else "complete" end)
    elif ((has("cards_total") or has("cards_done") or has("cards_parked")) | not) then "absent"
    else "malformed" end' "$gatepass" 2>/dev/null)
  # A run REGISTERED as an index run (active-run.json carries index_path) must record
  # counts: counts-absent for it is a bookkeeping failure, not legacy — warn, never a
  # silent allow (an unregistered/plain run keeps the legacy absent→allow behavior).
  if [ "$verdict" = "absent" ] && [ "$(jq -r 'has("index_path")' "$sentinel" 2>/dev/null)" = "true" ]; then
    verdict="malformed"
  fi
  if [ "$verdict" = "incomplete" ] || [ "$verdict" = "malformed" ]; then
    slug=$(jq -r '.slug // "the active run"' "$sentinel" 2>/dev/null)
    ct=$(jq -r '.cards_total' "$gatepass" 2>/dev/null)
    cdone=$(jq -r '.cards_done' "$gatepass" 2>/dev/null)
    cpark=$(jq -r '.cards_parked' "$gatepass" 2>/dev/null)
    printf '[task-runner] completion-gate: %s recorded a gate pass but its card counts are %s: done=%s parked=%s total=%s.\n' "$slug" "$verdict" "$cdone" "$cpark" "$ct" >&2
    printf '  A run may not report complete while any card is neither done nor parked.\n' >&2
    [ "${TASK_RUNNER_STOP_GATE:-warn}" = "block" ] && exit 2
  fi
  exit 0                                          # gate pass for THIS commit (cards complete or legacy) → allow
fi

slug=$(jq -r '.slug // "the active run"' "$sentinel" 2>/dev/null)
printf '[task-runner] completion-gate: %s has recorded no passing behavioral-gate for HEAD %s.\n' "$slug" "${head:0:12}" >&2
printf '  Run behavioral-gate.sh on the produced code (isolated), then record the pass to\n' >&2
printf '  .claude/task-runner/gate-pass.json as {"head":"%s"}, and clear active-run.json on\n' "$head" >&2
printf '  a clean completion. A green repo suite alone is NOT this gate.\n' >&2

[ "${TASK_RUNNER_STOP_GATE:-warn}" = "block" ] && exit 2
exit 0
