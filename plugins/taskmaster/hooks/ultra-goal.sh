#!/usr/bin/env bash
# Fail open: never block the prompt. Activate hands-off Extreme Boost when the prompt asks.
{
  input=$(cat)
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  case "$prompt" in "/"*) exit 0 ;; esac # slash commands own their flag path
  if printf '%s' "$prompt" | grep -qiE '\bultra-?goal\b'; then
    # Defaults: opus model + effort xhigh. max is opt-in via a suffix, e.g. ultra-goal-max.
    model=opus; effort=xhigh
    # Optional suffix: ultra-goal-<model>[-<effort>] or ultra-goal-<effort>.
    lc=$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]')
    if [[ "$lc" =~ ultra-?goal-(opus|sonnet|haiku|fable)(-(low|medium|high|xhigh|max))?([^a-z0-9-]|$) ]]; then
      model="${BASH_REMATCH[1]}"
      [ -n "${BASH_REMATCH[3]}" ] && effort="${BASH_REMATCH[3]}"
    elif [[ "$lc" =~ ultra-?goal-(low|medium|high|xhigh|max)([^a-z0-9-]|$) ]]; then
      effort="${BASH_REMATCH[1]}"
    fi
    cat <<EOF
ULTRA-GOAL ACTIVE (model=$model, effort=$effort) — hands-off Extreme Boost for this taskmaster run. Canonical owner: the taskmaster 'ultra-goal' skill (skills/ultra-goal/SKILL.md).
- Implies the full ULTRA-TASK escalation contract (skills/ultra/SKILL.md): $model subagents,
  mandatory red-team + coverage, bounded Workflow fan-outs, ⚡ banner. If an explicit ultra-task
  token is also present, ITS tier wins (precedence: ultra-task > ultra-goal suffix).
- Auto-take every pipeline recommendation instead of asking: AskUserQuestion gates resolve to the
  "(Recommended)" option; unmarked choices (variant picks, erd forks, hole resolutions) resolve by
  deriving a recommendation first, then taking it — never blind-first.
- Binding contracts (erd Data Model, Visual contract, brainstorm design doc) self-approve; log.
- Visual decisions: consent auto-answers "Full mockups"; build variants, self-pick, keep files +
  gallery saves as audit artifacts. experience-walkthrough: self-drive, fold gaps as ASSUMED.
- Audit every auto-take: append to .claude/taskmaster/goal-ledger-<slug>.md (decision, options,
  pick, rationale); write spec appendix "## Auto-decisions"; stamp "Goal: true (model=…, effort=…)"
  into 00-INDEX.md so execution inherits hands-off.
- Run THROUGH execution: auto-answer "Run now", execute cards, stop after the green full suite —
  never auto-run branch merge/PR.
- NEVER suppress: halt-with-evidence, the full-suite completion gate, the **behavioral-gate**
  (produced code is run, not just linted) + negative-control, mis-specified-task halts,
  security-hole flagging. These surface; they are not consent prompts. Confirmed **code-redteam**
  findings feed the bounded auto-retry like reviewer findings; on exhaustion, park.
- EXEMPT from take-Recommended: the green branch-finish handoff gate ALWAYS resolves to "Stop
  here" under goal, regardless of which option is labeled Recommended. Post-run "Retry parked":
  at most ONE auto-retry, and only if the prior run made forward progress (a task moved
  parked→done); otherwise auto-take "Stop here" and surface the parked list.
- Escape hatch (surface-and-stop, not a prompt): when no defensible recommendation can be
  derived — contradictory requirements, an option fork with no dominant choice after analysis,
  a brainstorm idea too vague to self-shape — halt with evidence instead of coin-flipping.
- Security/auth/data-loss AND statement-fidelity holes (the upgraded statement adds, drops, or swaps
  capability vs the raw prompt) are never auto-accepted as known risk: amend the spec/statement, or halt with evidence if unamendable.
- Audit precondition: create/verify the goal ledger at activation; if an append ever fails,
  halt with evidence rather than proceeding unaudited.
- Optional side-offers (ADR capture, skill-suggester) auto-skip and log. Fan-out only when the
  Workflow tool is present; else inline fallback.
EOF
  fi
} 2>/dev/null
exit 0
