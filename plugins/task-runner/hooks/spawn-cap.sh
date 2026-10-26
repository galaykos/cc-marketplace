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
# INSIDE A REGISTERED RUN (.claude/task-runner/active-run.json at the state root, naming
# the checked-out branch or none) it NOTIFIES instead (2026-10-14), and its first threshold is
# max(cap, cards x 3), cards counted from the run's index_path (a worker plus reviewers
# per card). The run was already authorized, and the ask at #20 left one run idle for 67
# minutes, then 25 at #40, while its sibling agents finished; neither approval changed
# the plan. The notice goes to the user (systemMessage) and the model
# (additionalContext), and names the plan.
# Residual: a run that dispatches past its plan is told, not stopped. The branch is read with
# `symbolic-ref`: a tag with the branch's name made --abbrev-ref print `heads/<branch>`, so the
# run read as another branch's and the cap asked. A detached HEAD (exit 1) reads `HEAD`; any other
# failure leaves the branch unknown, which matches the run.
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
# CC_SPAWN_CAP unset: the /config option cc_spawn_cap decides.
# Fail-open on every error path.

# Shared block templates/blocks/state-root.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/state-root.md
# cc_state_root <cwd> prints the root that holds hook state: the git toplevel above <cwd>, else
# CLAUDE_PROJECT_DIR when <cwd> is under it, else <cwd>. A <cwd> that no longer exists: no output, status 1.
# --show-cdup, not --show-toplevel: git resolves a symlinked /tmp there, breaking the caller's path-prefix compares.
cc_state_root() {
  [ -n "$1" ] && [ -d "$1" ] || return 1
  local up pd="${CLAUDE_PROJECT_DIR:-}"; pd="${pd%/}"
  if up=$(git -C "$1" rev-parse --show-cdup 2>/dev/null); then
    [ -n "$up" ] || { printf '%s\n' "$1"; return 0; }
    (CDPATH= cd -- "$1/$up" 2>/dev/null && pwd) && return 0
  fi
  if [ -n "$pd" ] && [ -d "$pd" ]; then
    case "$1/" in "$pd"/*) printf '%s\n' "$pd"; return 0 ;; esac
  fi
  printf '%s\n' "$1"
}

# Shared block templates/blocks/option-resolver.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/option-resolver.md
# cc_option <ENV_NAME> <default> [<level-file>] prints, status 0, the first non-empty of: variable ENV_NAME,
# <level-file>'s first word, option CLAUDE_PLUGIN_OPTION_<ENV_NAME> (true/false as on/off), <default>.
# The host exports only SAVED options, so <default> must equal the manifest's default.
# A non-empty variable beats the option: the environment is shared, so one export before launch
# switches every plugin that reads it.
# Misses: a malformed name, which yields <default>; a variable passed instead of a literal name; a value outside the vocabulary.
cc_option() {
  local v="" opt
  case "${1:-}" in '' | [0-9]* | *[!A-Za-z0-9_]*) printf '%s\n' "${2:-}"; return 0 ;; esac
  v="${!1:-}"
  if [ -z "$v" ] && [ -n "${3:-}" ] && [ -f "$3" ] && [ -r "$3" ]; then
    read -r v _ 2>/dev/null < "$3" || :
  fi
  if [ -z "$v" ]; then
    opt="CLAUDE_PLUGIN_OPTION_$1"; v="${!opt:-}"
    case "$v" in true) v=on ;; false) v=off ;; esac
  fi
  [ -n "$v" ] || v="${2:-}"
  printf '%s\n' "$v"
  return 0
}

{
  cap=$(cc_option CC_SPAWN_CAP 20)
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

  # One marker per dispatch, created with mkdir — atomic, no read-modify-write, so two
  # dispatches racing cannot lose a count. `$$-$(date +%s)-$RANDOM` alone can collide:
  # same PID, same second, and $RANDOM repeats within a seeded shell, which silently
  # undercounts. mkdir FAILS on collision, so the loop retries instead of losing the
  # count; ten attempts then give up (fail-open) rather than spin.
  n_try=0
  while :; do
    mkdir "$dir/d-$$-$(date +%s)-$RANDOM-$n_try" 2>/dev/null && break
    n_try=$((n_try + 1))
    [ "$n_try" -ge 10 ] && exit 0
  done
  n=$(ls -1 "$dir" 2>/dev/null | grep -c '^d-' || true)
  case "$n" in ''|*[!0-9]*) exit 0 ;; esac

  # Sweep sessions older than a day so /tmp does not accumulate one dir per session.
  find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'cc-spawn-*' -type d -mtime +1 -exec rm -rf {} + 2>/dev/null

  # No threshold sits below the cap, so the run lookup waits until the count reaches it.
  [ "$n" -ge "$cap" ] || exit 0
  first="$cap"; run=""; plan=""
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  root=$(cc_state_root "$cwd") || root=""
  sent="$root/.claude/task-runner/active-run.json"
  # A sentinel names the branch it was registered on; one left behind on another branch
  # turned this ask into a notice for unrelated work. Read as candor's clause 4 reads it: a
  # run differs only when both names are known and differ.
  if [ -n "$root" ] && [ -r "$sent" ] && sb=$(jq -r '.branch // empty' "$sent" 2>/dev/null) &&
     { cb=$(git -C "$root" symbolic-ref -q HEAD 2>/dev/null); [ $? -ne 1 ] || cb=HEAD; cb=${cb#refs/heads/}; [ -z "$sb" ] || [ -z "$cb" ] || [ "$sb" = "$cb" ]; }; then
    run=$(jq -r '.slug // empty' "$sent" 2>/dev/null); [ -n "$run" ] || run=run
    idx=$(jq -r '.index_path // empty' "$sent" 2>/dev/null)
    idxp="$idx"; case "$idx" in '' | /*) ;; *) idxp="$root/$idx" ;; esac
    cards=0
    [ -n "$idx" ] && [ -r "$idxp" ] &&
      cards=$(grep -cE '^[[:space:]]*\|[[:space:]]*[0-9][0-9][[:space:]]*\|' "$idxp" 2>/dev/null)
    case "$cards" in '' | *[!0-9]*) cards=0 ;; esac
    if [ "$cards" -gt 0 ]; then
      plan="$cards cards in $idx, about $((cards * 3)) dispatches at 3 per card"
      [ $((cards * 3)) -gt "$first" ] && first=$((cards * 3))
    else
      plan="no card index to plan from, so the session threshold of $cap applies"
    fi
  fi

  # Threshold at the first one, then every doubling: 20, 40, 80, 160…
  t="$first"
  while [ "$t" -lt "$n" ]; do t=$((t * 2)); done
  [ "$n" -eq "$t" ] || exit 0

  if [ -n "$run" ]; then
    msg="task-runner: subagent dispatch #$n in this session (each is billed), inside the registered run $run ($plan); next notice at #$((n * 2)). Continue if this matches the plan; otherwise stop re-dispatching and read the last report."
    jq -cn --arg r "$msg" '{systemMessage:$r,hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$r}}' 2>/dev/null
    exit 0
  fi

  reason="task-runner: this is subagent dispatch #$n in this session; each is billed and none shows in the transcript. Approve if this many was planned (next prompt at #$((n * 2))); if not, decline and stop re-dispatching. CC_SPAWN_CAP=<n> moves the threshold (off disables it)."

  jq -cn --arg r "$reason" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}' 2>/dev/null
  exit 0
} 2>/dev/null
exit 0
