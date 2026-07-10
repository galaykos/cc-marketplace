#!/usr/bin/env bash
# Fail open: never block the prompt. Activate a boosted assessment run when asked.
{
  input=$(cat)
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  case "$prompt" in "/"*) exit 0 ;; esac # slash commands own their flag path
  if printf '%s' "$prompt" | grep -qiE '\bultra-?assess(ment)?\b'; then
    # Defaults match ultra-task: opus + effort max.
    model=opus; effort=max
    # Optional suffix: ultra-assess-<model>[-<effort>] or ultra-assess-<effort>.
    lc=$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]')
    if [[ "$lc" =~ ultra-?assess(ment)?-(opus|sonnet|haiku|fable)(-(low|medium|high|xhigh|max))?([^a-z0-9-]|$) ]]; then
      model="${BASH_REMATCH[2]}"
      [ -n "${BASH_REMATCH[4]}" ] && effort="${BASH_REMATCH[4]}"
    elif [[ "$lc" =~ ultra-?assess(ment)?-(low|medium|high|xhigh|max)([^a-z0-9-]|$) ]]; then
      effort="${BASH_REMATCH[2]}"
    fi
    echo "ULTRA-ASSESS ACTIVE (model=$model, effort=$effort) — Extreme Boost for this assessment run. Apply the orchestration 'ultra-assess' skill (skills/ultra-assess/SKILL.md): dispatch reachable subagents model:$model (on the Workflow agent() path also effort:$effort; inline Agent dispatch escalates model only), run the fan-out → synthesize → red-team → completeness-critic recipe from the verification-panels + delegation-contracts skills, print the ⚡ banner first. Output findings/backlog, NOT task cards, and write no execution marker. Fan-out only when the Workflow tool is present; else inline fallback."
  fi
} 2>/dev/null
exit 0
