#!/usr/bin/env bash
# generated from templates/reminder-hook.sh.tmpl by scripts/generate.sh — edit the template or .chassis.json, not this file
# Fail open: never block the prompt. Print a reminder only on a keyword match.
command -v jq >/dev/null 2>&1 || exit 0
{
  input=$(cat)
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  case "$prompt" in "" | "/"*) exit 0 ;; esac # empty, or slash commands manage their own flow
  if printf '%s' "$prompt" | grep -qiE '\b(refactor|re-?write|restructure|re-?architect|migrate|redesign|rework|overhaul|moderni[sz]e|consolidate|decouple)\b'; then
    printf '%s (%s).\n' 'approaches: task-shaped prompt — consider a blind opinion round (Standards Purist / Quality-over-Speed / Pragmatist-Minimalist / Skeptic-Investigator) before picking an approach' '/approaches:opinions'
  fi
} 2>/dev/null
exit 0
