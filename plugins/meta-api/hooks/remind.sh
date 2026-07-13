#!/usr/bin/env bash
# generated from templates/reminder-hook.sh.tmpl by scripts/generate.sh — edit the template or .chassis.json, not this file
# Fail open: never block the prompt. Print a reminder only on a keyword match.
command -v jq >/dev/null 2>&1 || exit 0
{
  input=$(cat)
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  case "$prompt" in "" | "/"*) exit 0 ;; esac # empty, or slash commands manage their own flow
  if printf '%s' "$prompt" | grep -qiE '\b(facebook|instagram|whatsapp|messenger|graph api|marketing api|meta (api|app|login|pixel|ads?))\b'; then
    printf '%s (%s).\n' 'meta-api: this prompt touches a Meta platform — API versions and permissions change quarterly, so pin the current version and required permissions before writing integration code' '/meta-api:check'
  fi
} 2>/dev/null
exit 0
