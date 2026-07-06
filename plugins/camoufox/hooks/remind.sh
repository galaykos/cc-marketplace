#!/usr/bin/env bash
# Fail open: never block the prompt. Print a reminder only on Camoufox keywords.
{
  input=$(cat)
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  case "$prompt" in "/"*) exit 0 ;; esac # slash commands manage their own flow
  if printf '%s' "$prompt" | grep -qiE '\b(camoufox|humanize|geoip|anti-?detect|fingerprint)\b'; then
    echo "camoufox: this prompt touches Camoufox anti-detect automation. Camoufox is young and its Python launch options change — run /camoufox:check <goal> to pin the current usage and launch options from the live docs before writing automation code (see camoufox-docs skill)."
  fi
} 2>/dev/null
exit 0
