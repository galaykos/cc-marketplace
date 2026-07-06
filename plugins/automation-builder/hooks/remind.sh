#!/usr/bin/env bash
# Fail open: never block the prompt. Print a reminder only on automation keywords.
{
  input=$(cat)
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  case "$prompt" in "/"*) exit 0 ;; esac # slash commands manage their own flow
  if printf '%s' "$prompt" | grep -qiE '\b(automation|automate|scrape|scraping|headless|web ?bot|fingerprint|anti-?detect|playwright|puppeteer)\b'; then
    echo "automation-builder: run /automation-builder:build <goal> to pick the tool and plan the flow before coding (see automation-planning skill)."
  fi
} 2>/dev/null
exit 0
