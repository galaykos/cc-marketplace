#!/bin/bash
# Absolute-path shebang (not `env bash`): the fail-open guarantee must hold even
# under a stripped or broken PATH, where `env bash` itself exits 127.
#
# PostToolUse on the first Edit/Write/MultiEdit of a CONTEXT. Emits one short
# additionalContext line stating the cost doctrine: everything written is a debit,
# the default is the smallest change that satisfies the stated requirement, more
# needs a named trigger, and the excess says what it cut.
#
# KEYED ON transcript_path, NOT session_id, and that is the whole delivery design.
# A subagent shares its parent's session id but gets its own transcript, so a
# session-keyed one-shot fires in the main thread and never again — while the
# writing actually happens inside the fan-out. Keying on the transcript gives every
# subagent exactly one copy, and PostToolUse is the ONLY hook channel that reaches
# subagents at all (SessionStart and UserPromptSubmit do not run for them).
#
# THE MESSAGE IS A SELF-IMPOSED BUDGET: 263 bytes, ceiling 300. The emitted JSON
# measures 85 tokens against the dynamic channel of `scripts/context-budget.sh`. Be
# honest about the standing: the 300-byte line is a rule this file keeps on itself and
# nothing checks it, while the 2900-token channel ceiling IS a gate — one this change
# raised from 2800 in the same commit, so "growing the message turns the build red" is
# true only at the channel level, not per byte. A doctrine about minimum output that
# shipped a paragraph here would refute itself; that is the actual reason for the 300.
#
# LIMITATION (honest scope — the four laws, see
# claude-authoring/skills/authoring-skills/SKILL.md "The four laws"):
#   - WARN-ONLY, PostToolUse. `additionalContext` is not a blocking key. The file is
#     already on disk; this informs the NEXT write, never the one that fired it.
#   - It fires on the first write of a context, so the first file of every context
#     is written without it. That is the cost of the only channel that reaches
#     subagents, and it is the reason this is a reminder and not a gate.
#   - It cannot see the AGGREGATE across a fan-out. Each subagent gets its own line
#     in its own context; nothing sums 30 agents' output and reports the total —
#     which is exactly the number that went unmeasured in the run recorded at
#     testing/skills/testing-best-practices/references/proportionality.md.
#   - It measures NOTHING. There is deliberately no line-count or test-count
#     threshold: a mechanical ratio would be the ratio-chasing the cost-model skill
#     rejects, and would fire on legitimately dense work. This states the bar; a
#     human or a reviewer applies it.
#
# Off switches: CC_REMIND=off silences every advisory nudge in this marketplace;
# CC_LEAN=off silences only this one.
#
# FAIL-OPEN: missing jq, unreadable or unwritable state dir, or any error exits 0.
{
  command -v jq >/dev/null 2>&1 || exit 0
  case "${CC_REMIND:-on}" in off) exit 0 ;; esac
  case "${CC_LEAN:-on}" in off) exit 0 ;; esac

  input=$(cat)
  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  case "$tool" in Edit|Write|MultiEdit) ;; *) exit 0 ;; esac

  # Falls back to session_id when transcript_path is absent, and the fallback is not
  # defensive padding — `scripts/context-budget.sh` measures the dynamic channel with
  # a synthetic Edit payload that carries a session_id and no transcript_path. Exiting
  # on a missing transcript would have scored this hook's real per-context cost as
  # zero on the one meter that exists for it. An unmeasurable cost is the failure this
  # plugin is about. With neither key the one-shot cannot be bounded at all, and a
  # bound that cannot be recorded is not a bound, so say nothing.
  tp=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // empty' 2>/dev/null) || exit 0
  [ -n "$tp" ] || exit 0

  key=$(printf '%s' "$tp" | cksum 2>/dev/null | cut -d' ' -f1)
  [ -n "$key" ] || exit 0
  seen="${TMPDIR:-/tmp}/cc-lean-$key"
  mkdir "$seen" 2>/dev/null || exit 0   # already fired for this context, or unwritable
  find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'cc-lean-*' -type d -mmin +1440 -exec rmdir {} + 2>/dev/null

  msg='lean: every line, test, comment, file, action is a debit. Ship the smallest change that satisfies the stated requirement. More needs a trigger named in place: blast radius, observed defect, stated criterion, user asked. Say what you cut. See the cost-model skill.'

  jq -cn --arg m "$msg" \
    '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$m}}' 2>/dev/null
  exit 0
} 2>/dev/null
exit 0
