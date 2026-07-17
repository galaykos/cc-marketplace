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
  exit 0                                          # gate recorded a pass for THIS commit → allow
fi

slug=$(jq -r '.slug // "the active run"' "$sentinel" 2>/dev/null)
printf '[task-runner] completion-gate: %s has recorded no passing behavioral-gate for HEAD %s.\n' "$slug" "${head:0:12}" >&2
printf '  Run behavioral-gate.sh on the produced code (isolated), then record the pass to\n' >&2
printf '  .claude/task-runner/gate-pass.json as {"head":"%s"}, and clear active-run.json on\n' "$head" >&2
printf '  a clean completion. A green repo suite alone is NOT this gate.\n' >&2

[ "${TASK_RUNNER_STOP_GATE:-warn}" = "block" ] && exit 2
exit 0
