#!/bin/bash
# Absolute-path shebang (not `/usr/bin/env bash`): the fail-open guarantee must
# hold even under a stripped/broken PATH.
#
# clarify-gate.sh — OPT-IN PreToolUse gate on Edit|Write|MultiEdit. OFF BY
# DEFAULT: does nothing unless CC_CLARIFY_GATE=block is set. When enabled, it
# denies the FIRST code write of a session in which remind.sh saw a work-shaped
# prompt (the cc-workprompt marker), once per session, forcing one turn of
# clarify-or-declare-trivial before code exists. The deny is the reflection
# mechanism itself — the gate does not (cannot) verify a question round
# actually happened; it buys one deliberate turn, nothing more. Standing when
# enabled: gate. Standing when disabled (the default): unenforceable, and this
# header says so on purpose.
#
# Doctrine note: command-guard reserves deny for irreversible loss; a first
# code edit is reversible, which is why this ships OFF and opt-in — the owner
# chooses the stricter contract, it is not imposed. Under hands-off goal runs
# the model should state assumptions instead of asking (see reason text).
# Pattern: comment-discipline/hooks/scan.sh — the once-per-session bound is
# recorded BEFORE the deny; a bound that cannot be recorded means no block.
# Fail-open everywhere; CC_REMIND=off also silences it.
{
  case "${CC_CLARIFY_GATE:-off}" in block) : ;; *) exit 0 ;; esac
  case "${CC_REMIND:-on}" in off) exit 0 ;; esac
  command -v jq >/dev/null 2>&1 || exit 0
  input=$(cat)
  sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null) || exit 0
  [ -n "$sid" ] || exit 0
  sidh=$(printf '%s' "$sid" | cksum | cut -d' ' -f1)

  pending="${TMPDIR:-/tmp}/cc-workprompt-$sidh"
  [ -d "$pending" ] || exit 0

  gated="${TMPDIR:-/tmp}/cc-clarify-gated-$sidh"
  mkdir "$gated" 2>/dev/null || exit 0
  rmdir "$pending" 2>/dev/null
  find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'cc-clarify-gated-*' -type d -mmin +1440 -exec rmdir {} + 2>/dev/null

  jq -cn --arg r '[taskmaster] First code write on a work-shaped prompt with no clarification round. Before re-applying this edit: run one batched AskUserQuestion round on the open unknowns — or, if the task is genuinely trivial or this is a hands-off goal run, state the assumptions you are proceeding on in one line. This gate fires once per session (opt-in via CC_CLARIFY_GATE=block).' \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
} 2>/dev/null
exit 0
