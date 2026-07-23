#!/usr/bin/env bash
# Fail open: never block the prompt. Inject the boost directive when the prompt asks.
# One hook, two tokens: ultra-task (boost) / ultra-goal (boost + hands-off).
# No suffix grammar — bare tokens only, fixed tier model=auto effort=xhigh
# (auto = session model or opus, whichever is higher on haiku<sonnet<opus<fable).
{
  input=$(cat)
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  case "$prompt" in "/"*) exit 0 ;; esac # slash commands own their flag path
  if printf '%s' "$prompt" | grep -qiE '\bultra-?goal\b'; then
    echo "ULTRA-GOAL ACTIVE (model=auto, effort=xhigh) — hands-off Extreme Boost for this taskmaster run. Apply the taskmaster 'ultra' skill (skills/ultra/SKILL.md) in Goal mode: full boost contract (reasoning subagents model:auto — session model or opus, whichever is higher, escalate never downgrade; effort xhigh on the Workflow path, inline dispatch escalates model only; scouts and opinion-lens stay NATIVE), mandatory red-team + coverage, auto-take every recommendation per the skill's Goal rules with every auto-take audited to the goal ledger, stamp 'Goal: true (model=auto, effort=xhigh)' into 00-INDEX.md, never suppress safety halts, print the ⚡ banner first. Fan-out only when the Workflow tool is present; else inline fallback labeled 'inline heuristic pass — single model, uncorroborated'."
  elif printf '%s' "$prompt" | grep -qiE '\bultra-?task\b'; then
    echo "ULTRA-TASK ACTIVE (model=auto, effort=xhigh) — Extreme Boost for this taskmaster run. Apply the taskmaster 'ultra' skill (skills/ultra/SKILL.md): reasoning subagents (red-team, coverage, card-verify, synthesis) model:auto (session model or opus, whichever is higher, escalate never downgrade; effort xhigh on the Workflow path, inline dispatch escalates model only), scouts and opinion-lens stay NATIVE, mandatory red-team + coverage, bounded fan-outs whose counts are CEILINGS sized to blast radius (references/dispatch-tiers.md), print the ⚡ banner first, write 'Ultra: true (model=auto, effort=xhigh)' verbatim into the card index. Fan-out only when the Workflow tool is present; else inline fallback labeled 'inline heuristic pass — single model, uncorroborated'."
  fi
} 2>/dev/null
exit 0
