#!/usr/bin/env bash
# generated from templates/reminder-hook.sh.tmpl by scripts/generate.sh — edit the template or .chassis.json, not this file
# Fail open: never block the prompt. Print a reminder only on a keyword match.
command -v jq >/dev/null 2>&1 || exit 0
{
  input=$(cat)
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  case "$prompt" in "" | "/"*) exit 0 ;; esac # empty, or slash commands manage their own flow
  if printf '%s' "$prompt" | grep -qiE '\b(camoufox|humanize|geoip|anti-?detect|fingerprint)\b'; then
    printf '%s (%s).\n' 'camoufox: this prompt touches Camoufox anti-detect automation — Camoufox is young and its Python launch options change, so pin current usage and launch options from live docs before writing automation code' '/camoufox:check'
  fi
} 2>/dev/null
exit 0
