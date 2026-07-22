#!/usr/bin/env bash
# Fail open: never block the prompt. Activate Extreme Boost when the prompt asks.
{
  input=$(cat)
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  case "$prompt" in "/"*) exit 0 ;; esac # slash commands own their flag path
  if printf '%s' "$prompt" | grep -qiE '\bultra-?task\b'; then
    # Defaults: auto model (session model or opus, whichever is higher) + effort xhigh.
    # An explicit model suffix pins absolutely; max is opt-in, e.g. ultra-task-max.
    model=auto; effort=xhigh
    # Optional suffix: ultra-task-<model>[-<effort>] or ultra-task-<effort>.
    lc=$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]')
    if [[ "$lc" =~ ultra-?task-(auto|opus|sonnet|haiku|fable)(-(low|medium|high|xhigh|max))?([^a-z0-9-]|$) ]]; then
      model="${BASH_REMATCH[1]}"
      [ -n "${BASH_REMATCH[3]}" ] && effort="${BASH_REMATCH[3]}"
    elif [[ "$lc" =~ ultra-?task-(low|medium|high|xhigh|max)([^a-z0-9-]|$) ]]; then
      effort="${BASH_REMATCH[1]}"
    fi
    echo "ULTRA-TASK ACTIVE (model=$model, effort=$effort) — Extreme Boost engaged for this taskmaster run. Apply the taskmaster 'ultra' skill (skills/ultra/SKILL.md): dispatch reachable subagents model:$model (model=auto resolves at dispatch to the session model or opus, whichever is higher on haiku<sonnet<opus<fable — escalate, never downgrade; on the Workflow agent() path also effort:$effort; inline Agent dispatch escalates model only), mandatory red-team + coverage, bounded Workflow fan-outs, print the ⚡ banner first, and write the 'Ultra: true (model=$model, effort=$effort)' marker verbatim into the card index (auto re-resolves in the executing session). Fan-out only when the Workflow tool is present; else inline fallback."
  fi
} 2>/dev/null
exit 0
