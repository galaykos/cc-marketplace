#!/usr/bin/env bash
# Fail open: never block the prompt. Nudge only on refactor-/rewrite-shaped prompts.
{
  input=$(cat)
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  case "$prompt" in "" | "/"*) exit 0 ;; esac # empty, or slash commands manage their own flow
  if printf '%s' "$prompt" | grep -qiE '\b(refactor|rewrite|migrate|redesign|restructure|overhaul|modernize)\b'; then
    echo "approaches: task-shaped prompt. Consider a second-opinions round (Standards Purist / Quality-over-Speed / Skeptic-Investigator) before picking an approach — /approaches:opinions (see second-opinions skill)."
  fi
} 2>/dev/null
exit 0
