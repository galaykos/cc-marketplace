#!/bin/bash
# Absolute-path shebang, as mode.sh: fail-open must hold under a stripped PATH.
#
# UserPromptSubmit, one job: on the FIRST work-shaped prompt of a session, inject the
# five working moves that reach the model BEFORE its first edit. Once per session,
# ~640 chars, silent on every other prompt.
#
# WHY A PROMPT-TIME HOOK AND NOT A SKILL. Three passes (PR #105, #114, #132) shipped
# working discipline into this marketplace, and every clause of it lives where a plain
# session never reads it: the delegation preamble and the worker template are
# worker-only by design, the skill-router nudges AFTER a file is edited, and the
# discipline skills are command-gated or absent from core-suite. Measured 2026-09-17
# on the prompt "fix this bug in the checkout total": zero discipline rules reached the
# main session (rationale/fable-distillation-2026-09-17.md §3). The Stop gate is the
# after-half; this is the before-half.
#
# WHY THESE FIVE AND WHY SHORT. Nine Opus 5 runs of one build task, 2026-08: a 535-char
# five-move preamble moved three observable process moves from 0/3 (bare prompt) to
# 6/6, and a 4,362-char catalogue added nothing over the short one (same rationale, §2).
# The five lines below are the moves the paired Fable/Opus transcript diff supported,
# not the original five verbatim (§4). Vote counts on nine runs, unreplicated — this
# is the best-evidenced prompt-time text the repo has, not a proven delta.
#
# LIMITATION (honest scope):
#   - Advisory. `additionalContext` cannot block; standing is `recorded`. The
#     after-half with teeth is gate.sh clause 3.
#   - Fires on the trigger taskmaster's remind.sh uses (a making verb in an imperative
#     clause of the prompt head); a work session opened with a question never sees it
#     until the first imperative prompt. Silence is the cheaper error.
#   - Once per session by marker; after a compaction the text is gone and not re-sent.
#   - CC_PREAMBLE=off is the off switch. It does not answer to CC_REMIND: this is not a
#     tool-routing nudge and claims no rank marker, so on the first work prompt it can
#     print alongside one reminder line — bounded, once.
{
  command -v jq >/dev/null 2>&1 || exit 0
  [ "${CC_PREAMBLE:-}" = "off" ] && exit 0

  input=$(cat)
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  [ -n "$prompt" ] || exit 0
  case "$prompt" in /*) exit 0 ;; esac # a slash command carries its own procedure

  scrub=$(printf '%s' "$prompt" | awk '/^```/{f=!f; next} !f' | sed 's/`[^`]*`//g')
  head=$(printf '%s' "$scrub" | tr '\n' ' ' | cut -c1-400 | tr 'A-Z' 'a-z')
  verbs='\b(build|create|add|implement|develop|rewrite|refactor|fix|update|change|write)\b'
  clauses=$(printf '%s' "$head" | awk '{gsub(/\?/," __Q__\n"); gsub(/\. /,"\n"); print}')
  printf '%s\n' "$clauses" | grep -qiE "$verbs" || exit 0
  printf '%s\n' "$clauses" | grep -iE "$verbs" \
    | grep -qvE '(__Q__|^[[:space:]]*(can|could|should|would|shall|is|are|was|were|do|does|did|am|will|what|why|how|when|where|which|who|whether)[^a-z])' \
    || exit 0

  # One-shot per context. UserPromptSubmit never reaches a subagent, so session_id
  # would do; transcript_path is preferred for the same reason the gate exists.
  ctx=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // empty' 2>/dev/null)
  [ -n "$ctx" ] || exit 0
  key=$(printf '%s' "$ctx" | cksum | cut -d' ' -f1)
  find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'cc-preamble-*' -type d -mmin +1440 -exec rmdir {} + 2>/dev/null
  mkdir "${TMPDIR:-/tmp}/cc-preamble-$key" 2>/dev/null || exit 0

  jq -cn --arg m 'candor: five moves before the first edit, this session. (1) Make the smallest change that satisfies the ask; name the trigger for anything more. (2) Prove it through the surface the user will use — the browser, the live endpoint, the real host — never only a double you wrote: it encodes your own guess and cannot disagree with you. (3) A green run that predates your last edit, or ran under your own background load, is not evidence; run it again. (4) Before stating a limitation (a tool missing, a host unreachable), run the command that checks it. (5) The final message names what is untested, what you cut, and what the user must configure.' \
    '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$m}}' 2>/dev/null
} 2>/dev/null
exit 0
