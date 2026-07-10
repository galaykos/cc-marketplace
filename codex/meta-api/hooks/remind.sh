#!/usr/bin/env bash
# Fail open: never block the prompt. Print a reminder only on Meta-platform keywords.
{
  input=$(cat)
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  case "$prompt" in "/"*) exit 0 ;; esac # slash commands manage their own flow
  if printf '%s' "$prompt" | grep -qiE '\b(facebook|instagram|whatsapp|messenger|graph api|marketing api|meta (api|app|login|pixel|ads?))\b'; then
    echo "meta-api: this prompt touches a Meta platform. API versions and permissions change quarterly — run /meta-api:check <task> to pin the current version and required permissions before writing integration code (see meta-api skill)."
  fi
} 2>/dev/null
exit 0
