#!/usr/bin/env bash
# Fail open: never block the prompt. Print a reminder only on Kameleo keywords.
{
  input=$(cat)
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  case "$prompt" in "/"*) exit 0 ;; esac # slash commands manage their own flow
  if printf '%s' "$prompt" | grep -qiE '\b(kameleo|kameleo-local-api|localhost:5050|anti-?detect|fingerprint profile)\b'; then
    echo "kameleo: this prompt touches the Kameleo Local API. Endpoints and SDK usage change between releases — run /kameleo:check <goal> to resolve the current endpoints/SDK and the fingerprint → profile → start → connect flow from live docs before writing automation code (see kameleo-docs skill)."
  fi
} 2>/dev/null
exit 0
