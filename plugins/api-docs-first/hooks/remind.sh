#!/usr/bin/env bash
# generated from templates/reminder-hook.sh.tmpl by scripts/generate.sh — edit the template or .chassis.json, not this file
# Fail open: never block the prompt. Print a reminder only on a keyword match.
command -v jq >/dev/null 2>&1 || exit 0
{
  input=$(cat)
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  case "$prompt" in "" | "/"*) exit 0 ;; esac # empty, or slash commands manage their own flow
  if printf '%s' "$prompt" | grep -qiE '\b(sdk|endpoint|integrat\w*|webhook|oauth|graphql)\b'; then
    printf '%s (%s).\n' 'api-docs-first: this prompt mentions an API/SDK integration — verify current official docs before writing integration code, and if none are accessible ask the user for a URL or file' '/api-docs-first:check'
  fi
} 2>/dev/null
exit 0
