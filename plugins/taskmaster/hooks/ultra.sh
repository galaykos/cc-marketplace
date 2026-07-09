#!/usr/bin/env bash
# Fail open: never block the prompt. Activate Extreme Boost when the prompt asks.
{
  input=$(cat)
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  case "$prompt" in "/"*) exit 0 ;; esac # slash commands own their flag path
  if printf '%s' "$prompt" | grep -qiE '\bultra-?task\b'; then
    echo "ULTRA-TASK ACTIVE — Extreme Boost engaged for this taskmaster run. Apply the taskmaster 'ultra' skill (skills/ultra/SKILL.md): opus on reachable subagents, mandatory red-team + coverage, bounded Workflow fan-outs, print the ⚡ banner first, and write the 'Ultra: true' marker into the card index. Fan-out only when the Workflow tool is present; else inline fallback."
  fi
} 2>/dev/null
exit 0
