#!/usr/bin/env bash
# Fail open: never block the prompt. Activate a boosted assessment run when asked.
{
  input=$(cat)
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  case "$prompt" in "/"*) exit 0 ;; esac # slash commands own their flag path
  if printf '%s' "$prompt" | grep -qiE '\bultra-?assess(ment)?\b'; then
    # Fixed tier, matching ultra-task: model=auto (session model or opus, whichever
    # is higher) + effort=xhigh. No suffix grammar — bare token only.
    model=auto; effort=xhigh
    echo "ULTRA-ASSESS ACTIVE (model=$model, effort=$effort) — Extreme Boost for this assessment run. Apply the orchestration 'ultra-assess' skill (skills/ultra-assess/SKILL.md): TIER subagents by role, not per-run: analytical/judgment lenses + the red-team + the completeness-critic get model:$model (model=auto resolves at dispatch to the session model or opus, whichever is higher on haiku<sonnet<opus<fable — escalate, never downgrade; on the Workflow agent() path also effort:$effort; inline Agent dispatch escalates model only), while enumerate/locate readers and opinion-lens stay NATIVE (no override), run the fan-out → synthesize → red-team → completeness-critic recipe from the verification-panels + delegation-contracts skills with fan-out counts as CEILINGS sized to blast radius (2-voter panel small / N=3 default), print the ⚡ banner first. Output findings/backlog, NOT task cards, and write no execution marker. Fan-out only when the Workflow tool is present; else inline fallback labeled 'inline heuristic pass — single model, uncorroborated' (never reported as a panel)."
  fi
} 2>/dev/null
exit 0
