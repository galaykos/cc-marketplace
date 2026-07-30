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
# WHAT IT PROVES, EXACTLY: that an Agent/Task dispatch carrying `RV-CARD: <id>` was
# made while a run was registered. Not that the reviewer read anything, not that its
# findings were acted on, not that the right reviewer was chosen. Review DEPTH stays
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

  # The marker rides in the dispatch prompt (reviewer-routing.md § Priming). Read the
  # whole tool_input rather than a single field: the Agent tool names it `prompt`,
  # and a future dispatch shape that carries it elsewhere should still count.
  marker=$(printf '%s' "$input" | jq -r '.tool_input // {} | tostring' 2>/dev/null |
    grep -oE 'RV-CARD: ?[a-zA-Z0-9._-]{1,64}' | head -1)
  [ -n "$marker" ] || exit 0

  card=${marker#RV-CARD:}
  card=${card# }
  case "$card" in '' | *[!a-zA-Z0-9._-]*) exit 0 ;; esac

  dir="$cwd/.claude/task-runner/rv"
  mkdir -p "$dir" 2>/dev/null || exit 0
  [ -w "$dir" ] || exit 0

  # Idempotent: several reviewers dispatch per card (code-reviewer plus the tag route),
  # and one record per card is what the gate counts.
  printf '{"card":"%s","dispatched":true}\n' "$card" > "$dir/rv-seen-$card.json" 2>/dev/null
} 2>/dev/null
exit 0
