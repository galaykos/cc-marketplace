#!/usr/bin/env bash
# generated from templates/reminder-hook.sh.tmpl by scripts/generate.sh — edit the template or .chassis.json, not this file
# Fail open: never block the prompt. Print a reminder only on a keyword match.
command -v jq >/dev/null 2>&1 || exit 0
{
  input=$(cat)
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  case "$prompt" in "" | "/"*) exit 0 ;; esac # empty, or slash commands manage their own flow
  if printf '%s' "$prompt" | grep -qiE '\b(build|create|add|implement|develop|rewrite|refactor)\b' && [ "${#prompt}" -lt 200 ]; then
    printf '%s (%s).\n' 'taskmaster: feature-shaped prompt with thin detail — pin down scope, edge cases, and success criteria before code' '/taskmaster:task'
  fi
} 2>/dev/null
exit 0
