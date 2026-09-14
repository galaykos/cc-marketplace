#!/bin/bash
# Absolute-path shebang not `/usr/bin/env bash`: the fail-open guarantee must hold
# even under a stripped PATH where `env bash` exits 127.
#
# PreToolUse spawn budget. Counts subagent dispatches per session and returns `ask`
# once the count crosses a soft cap (default 20), then again at every doubling.
#
# WHY THIS EXISTS. `scripts/turn-cost.sh` in the marketplace repo states the fact this
# guard acts on: subagent turns are invisible in the transcript and they are billed.
# A fan-out that was planned as three agents and became thirty is not visible anywhere
# until the bill — not in the transcript, not in a summary, not in `parallel-planning`'s
# estimate, which is prose the dispatcher reads once at the start and not again at
# dispatch number twenty-six. Nothing in this marketplace counts.
#
# WHY `ask` AND NOT `deny`. A large fan-out is sometimes right — a tracks run over a
# dependency wave, a review panel over a big diff. The cap is not a claim that thirty is
# wrong; it is a claim that thirty should be a decision someone made. A deny would make
# the plugin wrong about the legitimate case; an ask makes the count visible exactly
# once per threshold and costs one keystroke.
#
# WHY IT DOUBLES RATHER THAN ASKING EVERY TIME. Asking at 21, 22, 23… trains the user to
# approve reflexively, which is the same as not asking. Thresholds at 20, 40, 80 keep the
# signal rare enough to read.
#
# WHAT IT DOES NOT CATCH, stated because the README tiers this:
#   - Agents a SUBAGENT spawns. The count is keyed on the session, and a nested dispatch
#     carries the parent's session id, so nesting inflates the same counter rather than
#     escaping it — but a subagent that spawns through a different mechanism is invisible.
#   - Cost. It counts dispatches, not tokens or dollars; a cap of 20 haiku calls and 20
#     opus calls are the same number here and are not the same bill.
#   - Anything about whether the fan-out was a good idea. That is
#     `task-runner:parallel-planning`, which is prose and stays prose.
#
# CC_SPAWN_CAP=<n> moves the first threshold; CC_SPAWN_CAP=off disables it.
# Fail-open on every error path.
{
  cap="${CC_SPAWN_CAP:-20}"
  case "$cap" in off) exit 0 ;; ''|*[!0-9]*) cap=20 ;; esac
  [ "$cap" -lt 1 ] && exit 0

  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0

  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  case "$tool" in Agent|Task) ;; *) exit 0 ;; esac

  sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
  [ -n "$sid" ] || exit 0
  # context-key-ok: the counter is per SESSION by design — a spawn budget that reset on
  # every prompt would never reach a threshold, which is the whole mechanism.
  key=$(printf '%s' "$sid" | cksum 2>/dev/null | cut -d' ' -f1)
  [ -n "$key" ] || exit 0

  dir="${TMPDIR:-/tmp}/cc-spawn-$key"
  mkdir -p "$dir" 2>/dev/null || exit 0

  # One marker file per dispatch: an atomic create with no read-modify-write, so two
  # dispatches racing cannot lose a count. The file name is the nanosecond-ish unique
  # part; its content is never read.
  : > "$dir/$$-$(date +%s)-$RANDOM" 2>/dev/null || exit 0
  n=$(ls -1 "$dir" 2>/dev/null | grep -c . || true)
  case "$n" in ''|*[!0-9]*) exit 0 ;; esac

  # Sweep sessions older than a day so /tmp does not accumulate one dir per session.
  find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'cc-spawn-*' -type d -mtime +1 -exec rm -rf {} + 2>/dev/null

  # Threshold at cap, then every doubling: 20, 40, 80, 160…
  t="$cap"
  while [ "$t" -lt "$n" ]; do t=$((t * 2)); done
  [ "$n" -eq "$t" ] || exit 0

  reason="task-runner: this is subagent dispatch #$n in this session. Subagent turns do not appear in the transcript and they are billed, so a fan-out that grew past its plan is invisible until the invoice — this is the only place it gets counted. If the work genuinely needs this many, approve and carry on; the next prompt is at #$((n * 2)). If it does not, the usual causes are a retry loop that re-dispatches instead of reading the last report, or a fan-out sized per file rather than per independent unit — task-runner's parallel-planning skill sizes it per dependency level. CC_SPAWN_CAP=<n> moves the threshold, CC_SPAWN_CAP=off disables it."

  jq -cn --arg r "$reason" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}' 2>/dev/null
  exit 0
} 2>/dev/null
exit 0
