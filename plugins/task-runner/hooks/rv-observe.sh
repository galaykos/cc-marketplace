#!/bin/bash
# Absolute-path shebang: fail-open must hold under a stripped PATH.
#
# PostToolUse observer — records that a reviewer pass was actually DISPATCHED for a
# card. Writes nothing else, blocks nothing, and is silent on every path.
#
# WHY A HOOK AND NOT A RECORD THE RUN WRITES. The per-card negative control is
# enforceable because a SCRIPT's exit writes nc-pass-<card>.json — the model cannot
# author it. The reviewer pass had no such artifact: it is mandated in prose
# (`skills/task-execution/SKILL.md` § Reviewer pass, "every task's diff, no
# condition") and nothing observed it, so under context pressure a real run reviewed
# card 01, skipped cards 02-08, reported "all 8 done, none parked", and passed every
# gate. Closing that gap afterwards found a real bug and six over-claims.
#
# A model-written rv-pass-<card>.json would not have helped: the same run wrote
# cards_done:8 into gate-pass.json while skipping the reviews, and would have written
# pass records with the same conviction. What has teeth is evidence the ORCHESTRATOR
# could not fabricate without lying in a tool call: this hook sees the dispatch itself.
#
# WHAT IT PROVES, EXACTLY: that an Agent/Task dispatch carrying one of the markers below
# was made while a run was registered. Not that the reviewer or refuter read anything,
# not that its findings were acted on, not that the right one was chosen. DEPTH stays
# unenforceable — a subagent's transcript is a separate file the parent hook cannot
# see. This closes "the pass never happened", which is the failure that occurred.
#
# STATE ROOT: the sentinel is read and records are written at the project root (the block
# below), not under the payload cwd — a dispatch made after a `cd app/Models` used to look
# for app/Models/.claude/task-runner/active-run.json, find none, and record nothing, which
# the completion gate then reads as a review that never ran.
#
# FAIL-OPEN: missing jq, no registered run, unwritable dir, any error → exit 0 silently.
# --- state root ----------------------------------------------------------------
# Canonical copy: templates/blocks/state-root.md. Every hook defining cc_state_root must
# carry this block byte-for-byte (pc_shared_blocks); generated hooks include it.
# The payload's `cwd` is the SHELL's cwd and follows the model's `cd` — measured
# 2026-09-25: app/Enums, then app/Models, then the repo root in one session, each leaving
# its own `.claude/` state dir and each re-firing a "once per session" nudge. State lives
# at the project root instead (pc_state_root refuses a raw `$cwd/.claude` path in a hook):
# the git toplevel reached by walking UP from cwd (`--show-cdup`, so a symlinked /tmp keeps
# the caller's spelling and path-prefix comparisons still hold); outside git,
# CLAUDE_PROJECT_DIR when cwd sits under it; else cwd. A cwd that no longer exists yields
# nothing and status 1 — the caller exits rather than resurrect a deleted project.
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

{
  command -v jq >/dev/null 2>&1 || exit 0

  input=$(cat)
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  [ -n "$cwd" ] || exit 0
  root=$(cc_state_root "$cwd") || exit 0

  # Only inside a registered run. Outside one there is nothing to be complete about,
  # and the completion gate is fail-open there for the same reason.
  [ -r "$root/.claude/task-runner/active-run.json" ] || exit 0

  # Markers ride in the dispatch prompt. Read the whole tool_input rather than a single
  # field: the Agent tool names it `prompt`, and a future dispatch shape carrying it
  # elsewhere should still count.
  #
  #   RV-CARD: <card>   a card's reviewer pass      (reviewer-routing.md § Coverage marker)
  #   RT-LENS: <lens>   one red-team refuter        (code-redteam § The N=3 refuter panel)
  #   RT-CRITIC: <id>   the completeness critic     (same)
  #
  # One observer, several kinds: a second hook per mandated dispatch would be four
  # copies of this file, and the marketplace's admission law forbids that.
  blob=$(printf '%s' "$input" | jq -r '.tool_input // {} | tostring' 2>/dev/null)

  record() { # record <subdir> <prefix> <id>
    case "$3" in '' | *[!a-zA-Z0-9._-]*) return 0 ;; esac
    d="$root/.claude/task-runner/$1"
    mkdir -p "$d" 2>/dev/null || return 0
    [ -w "$d" ] || return 0
    # Idempotent by id: several reviewers dispatch per card (code-reviewer plus the tag
    # route) and one record per card is what the gate counts.
    printf '{"id":"%s","dispatched":true}\n' "$3" > "$d/$2-$3.json" 2>/dev/null
  }

  m=$(printf '%s' "$blob" | grep -oE 'RV-CARD: ?[a-zA-Z0-9._-]{1,64}' | head -1)
  [ -n "$m" ] && { v=${m#RV-CARD:}; record rv rv-seen "${v# }"; }

  m=$(printf '%s' "$blob" | grep -oE 'RT-LENS: ?[a-zA-Z0-9._-]{1,64}' | head -1)
  [ -n "$m" ] && { v=${m#RT-LENS:}; record rt rt-lens "${v# }"; }

  m=$(printf '%s' "$blob" | grep -oE 'RT-CRITIC: ?[a-zA-Z0-9._-]{1,64}' | head -1)
  [ -n "$m" ] && { v=${m#RT-CRITIC:}; record rt rt-critic "${v# }"; }
} 2>/dev/null
exit 0
