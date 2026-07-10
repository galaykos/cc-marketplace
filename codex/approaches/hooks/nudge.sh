#!/usr/bin/env bash
# Fail open: never block the prompt. Nudge only on refactor-/rewrite-shaped prompts.
{
  input=$(cat)
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  case "$prompt" in "" | "/"*) exit 0 ;; esac # empty, or slash commands manage their own flow
  if printf '%s' "$prompt" | grep -qiE '\b(refactor|re-?write|restructure|re-?architect|migrate|redesign|rework|overhaul|moderni[sz]e|consolidate|decouple)\b'; then
    echo "approaches: task-shaped prompt. Consider an opinion round (Standards Purist / Quality-over-Speed / Pragmatist-Minimalist / Skeptic-Investigator, blind takes) before picking an approach — /approaches:opinions (see opinion-round skill)."
  fi
} 2>/dev/null
exit 0
