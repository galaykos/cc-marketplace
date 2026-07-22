#!/usr/bin/env bash
# generated from templates/reminder-hook.sh.tmpl by scripts/generate.sh — edit the template or .chassis.json, not this file
# Fail open: never block the prompt. Print a reminder only on a keyword match.
command -v jq >/dev/null 2>&1 || exit 0
{
  input=$(cat)
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  case "$prompt" in "" | "/"*) exit 0 ;; esac # empty, or slash commands manage their own flow
  if printf '%s' "$prompt" | grep -qiE '(still failing|same error|didn.?t work|tried everything|third time|drop table|force.push|rm -rf|reset --hard|migrate:fresh|delete all)'; then
    printf '%s (%s).\n' 'ℹ fresh-take: sounds like a key moment — a fresh opus take is one command away' '/fresh-take:consult'
  fi
} 2>/dev/null
exit 0
