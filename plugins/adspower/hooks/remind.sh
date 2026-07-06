#!/usr/bin/env bash
# Fail open: never block the prompt. Print a reminder only on AdsPower keywords.
{
  input=$(cat)
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  case "$prompt" in "/"*) exit 0 ;; esac # slash commands manage their own flow
  if printf '%s' "$prompt" | grep -qiE '\b(adspower|local\.adspower|50325|anti-?detect|browser profile)\b'; then
    echo "adspower: this prompt touches the AdsPower Local API. Its port and endpoint paths change across AdsPower versions — run /adspower:check <goal> to resolve the current endpoints and the start/stop lifecycle from live docs before writing automation code (see adspower-docs skill)."
  fi
} 2>/dev/null
exit 0
