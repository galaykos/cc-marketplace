#!/usr/bin/env bash
# generated from templates/reminder-hook.sh.tmpl by scripts/generate.sh — edit the template or .chassis.json, not this file
# Fail open: never block the prompt. Print a reminder only on a keyword match.
command -v jq >/dev/null 2>&1 || exit 0
{
  input=$(cat)
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  case "$prompt" in "" | "/"*) exit 0 ;; esac # empty, or slash commands manage their own flow
  if printf '%s' "$prompt" | grep -qiE '\b(kameleo|kameleo-local-api|localhost:5050|fingerprint profile)\b'; then
    printf '%s (%s).\n' 'kameleo: this prompt touches the Kameleo Local API — endpoints and SDK usage change between releases, so resolve current endpoints/SDK and the fingerprint → profile → start → connect flow from live docs before writing automation code' '/kameleo:check'
  fi
} 2>/dev/null
exit 0
