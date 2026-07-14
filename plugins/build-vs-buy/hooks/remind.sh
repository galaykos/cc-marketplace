#!/usr/bin/env bash
# generated from templates/reminder-hook.sh.tmpl by scripts/generate.sh — edit the template or .chassis.json, not this file
# Fail open: never block the prompt. Print a reminder only on a keyword match.
command -v jq >/dev/null 2>&1 || exit 0
{
  input=$(cat)
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  case "$prompt" in "" | "/"*) exit 0 ;; esac # empty, or slash commands manage their own flow
  if printf '%s' "$prompt" | grep -qiE '(build|implement|write|create|roll[[:space:]-]*(my|our|your)?[[:space:]-]*own|from[[:space:]]scratch|hand[[:space:]-]*roll)' && printf '%s' "$prompt" | grep -qiE '(auth(entication|orization)?|login|session|oauth|jwt|password[[:space:]]hash|parser|tokeni[sz]er|date[[:space:]-]*(lib|library|math|parsing)|time[[:space:]]?zone|queue|job[[:space:]]queue|message[[:space:]]broker|cache|rate[[:space:]-]*limit(er|ing)?|state[[:space:]]machine|pdf|csv[[:space:]]parser|email[[:space:]]sending|smtp|payment|billing|encryption|crypto(graphy)?|hashing|search[[:space:]]engine|full[[:space:]-]*text[[:space:]]search|orm|scheduler|cron|websocket|pub[[:space:]-]*sub|i18n|internationali[sz]ation|feature[[:space:]]flag|markdown[[:space:]]parser|diff(ing)?[[:space:]]algorithm|uuid|slug)'; then
    printf '%s (%s).\n' 'build-vs-buy: this looks like building a capability often already solved by a battle-tested library or service — before writing it, weigh take (adopt) vs wrap vs write via an existing-solution search, health table, and verdict; skip only if you already know no fit exists' '/build-vs-buy:check'
  fi
} 2>/dev/null
exit 0
