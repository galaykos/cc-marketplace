#!/bin/bash
# Absolute-path shebang: fail-open must hold under a stripped PATH.
# Stop hook — completion-gate enforcement for a task-runner run.
#
# WHAT IT DOES: on every Stop, if a run has REGISTERED itself (the run wrote
# $cwd/.claude/task-runner/active-run.json at start), this checks whether the
# behavioral-gate recorded a PASS for the current HEAD in gate-pass.json. If not, it
# exits 2 to BLOCK the stop and feed the reason back to the model — the produced code
# was never run through the gate, and a green repo suite alone is NOT the gate.
#
# WHY BLOCK IS THE DEFAULT: a Stop hook reaches the model ONLY through exit 2. Exit 0
# prints to a turn that has already ended, so warn mode cannot prevent the failure it
# describes — a run that narrates its next step ("starting card 01 now") and yields in
# plain text stalls, with no card started and the user waiting on a dead turn. Blocking
# is bounded to ONE BLOCK PER COMMIT (the nudge marker below), on the run's own branch
# only, so a genuine stop costs at most one extra turn and an abandoned run cannot become
# a repo-wide trap. Opt out with TASK_RUNNER_STOP_GATE=warn (print only, never block).
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
# Default is BLOCK (one-shot, only inside a registered run). Downgrade to print-only
# with TASK_RUNNER_STOP_GATE=warn. Fail-open on missing jq/git or a malformed sentinel.

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

# BRANCH GUARD: a sentinel is cleared only on clean completion, so an abandoned run leaves
# one behind indefinitely. Enforcing it from a different branch would turn a dead run into
# a repo-wide trap on unrelated work, with no way out but deleting a file the user does not
# know exists. A run registered with a "branch" is enforced only on that branch; a sentinel
# without one (pre-0.17 registration) keeps the old unconditional behavior.
run_branch=$(jq -r '.branch // empty' "$sentinel" 2>/dev/null)
cur_branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ -n "$run_branch" ] && [ -n "$cur_branch" ] && [ "$run_branch" != "$cur_branch" ]; then
  printf '[task-runner] completion-gate: run registered on branch %s, now on %s — not enforced here.\n' "$run_branch" "$cur_branch" >&2
  printf '  If that run is finished or abandoned, delete .claude/task-runner/active-run.json.\n' >&2
  exit 0
fi

# ONE BLOCK PER HEAD. The stop_hook_active check above assumes Claude Code sets that flag
# on the continuation it triggers; this guard does not assume it. The last HEAD blocked on
# is recorded, and a second stop at the SAME commit prints without blocking. Enforcement
# therefore rides on progress — every commit re-arms the gate, so a real run is held to
# every card — while a stale sentinel costs at most one extra turn per commit, not one per
# stop. The marker lives beside the sentinel in .claude/task-runner/ (the run's own state
# dir); it is the only thing this hook ever writes, and never touches the working tree.
#
# The marker is honored only while it is NEWER than the sentinel it was written under.
# Nothing clears it (the run clears active-run.json, not this), so without that test a
# marker left by run A would eat run B's first block whenever no commit landed between
# them — the same HEAD, a different run, and the protection silently gone on the turn it
# matters most. Comparing mtimes makes a new registration re-arm the gate by itself; if
# the two land in the same clock tick the comparison fails toward blocking, never toward
# silence.
nudge="$cwd/.claude/task-runner/gate-nudge"
gate_exit() {
  [ "${TASK_RUNNER_STOP_GATE:-block}" = "block" ] || exit 0
  if [ -r "$nudge" ] && [ "$nudge" -nt "$sentinel" ] && [ "$(cat "$nudge" 2>/dev/null)" = "$head" ]; then
    exit 0
  fi
  printf '%s' "$head" > "$nudge" 2>/dev/null
  exit 2
}

gatepass="$cwd/.claude/task-runner/gate-pass.json"
if [ -r "$gatepass" ] && [ "$(jq -r '.head // empty' "$gatepass" 2>/dev/null)" = "$head" ]; then
  # Gate pass recorded for THIS commit. For an index run, run.md also records card
  # counts in gate-pass.json; when those numeric fields are present, refuse a clean
  # stop while any card is neither done nor parked (cards_done + cards_parked <
  # cards_total). ALL fields absent → legacy behavior (allow). Partially present,
  # non-numeric, or inconsistent (done+parked > total) counts are MALFORMED — warned,
  # never silently allowed, so a bookkeeping slip cannot disarm the gate. Same
  # block-by-default semantics (via gate_exit) as the no-pass path below.
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
    gate_exit
  fi
  exit 0                                          # gate pass for THIS commit (cards complete or legacy) → allow
fi

# No gate pass for HEAD → the run is not complete. Two very different moments land here:
# mid-run (cards still to execute) and end-of-run (all cards done, gate not yet run). The
# hook cannot tell them apart cheaply — index status formats vary and parsing them here
# would trade fail-open cheapness for guesswork — so it names BOTH branches and lets the
# model pick the one it is in. Naming only the completion branch is what made the earlier
# message useless mid-run: it answered a question the model was not yet asking.
slug=$(jq -r '.slug // "the active run"' "$sentinel" 2>/dev/null)
printf '[task-runner] completion-gate: %s is a registered run with no behavioral-gate pass for HEAD %s.\n' "$slug" "${head:0:12}" >&2
printf '  The run is not complete, so this turn must not end here.\n' >&2
printf '  Cards still to execute -> continue NOW with a tool call. Do not name the next card in prose\n' >&2
printf '    and yield: that binds nothing, and the user waits on a turn that already ended. Need a\n' >&2
printf '    decision -> ask it with AskUserQuestion (not a stop). Blocked -> park the card with a reason.\n' >&2
printf '  Every card done or parked -> run behavioral-gate.sh on the produced code (isolated), record\n' >&2
printf '    the pass to .claude/task-runner/gate-pass.json as {"head":"%s"} plus the card counts,\n' "$head" >&2
printf '    then clear active-run.json. A green repo suite alone is NOT this gate.\n' >&2
printf '  Not running this task list at all? The sentinel outlived its run — delete\n' >&2
printf '    .claude/task-runner/active-run.json.\n' >&2

gate_exit                                          # blocks (exit 2) or, when already
                                                   # nudged at this HEAD / under warn, exits 0
