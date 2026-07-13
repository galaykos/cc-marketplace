#!/usr/bin/env bash
# generated from templates/reminder-hook.sh.tmpl by scripts/generate.sh — edit the template or .chassis.json, not this file
# Fail open: never block the prompt. Print a reminder only on a keyword match.
command -v jq >/dev/null 2>&1 || exit 0
{
  input=$(cat)
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  case "$prompt" in "" | "/"*) exit 0 ;; esac # empty, or slash commands manage their own flow
  if printf '%s' "$prompt" | grep -qiE '\b(puppeteer|pptr|browserwsendpoint|puppeteer-extra|setrequestinterception)\b'; then
    printf '%s (%s).\n' 'puppeteer: this prompt touches Puppeteer automation — the API moves fast and is coupled to a bundled Chrome build, so pin current API and doc-backed patterns from live docs (pptr.dev) before writing automation code' '/puppeteer:check'
  fi
} 2>/dev/null
exit 0
