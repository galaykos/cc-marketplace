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
# FAIL-OPEN: missing jq, no registered run, unwritable dir, any error → exit 0 silently.
{
  command -v jq >/dev/null 2>&1 || exit 0

  input=$(cat)
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  [ -n "$cwd" ] || exit 0

  # Only inside a registered run. Outside one there is nothing to be complete about,
  # and the completion gate is fail-open there for the same reason.
  [ -r "$cwd/.claude/task-runner/active-run.json" ] || exit 0

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
    d="$cwd/.claude/task-runner/$1"
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
