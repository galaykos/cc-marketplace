#!/usr/bin/env bash
# Fail open: never block the prompt. Print a reminder only on Puppeteer keywords.
{
  input=$(cat)
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  case "$prompt" in "/"*) exit 0 ;; esac # slash commands manage their own flow
  if printf '%s' "$prompt" | grep -qiE '\b(puppeteer|pptr|browserwsendpoint|puppeteer-extra|setrequestinterception)\b'; then
    echo "puppeteer: this prompt touches Puppeteer automation. The API moves fast and is coupled to a bundled Chrome build — run /puppeteer:check <goal> to pin the current API from live docs (pptr.dev) and doc-backed patterns before writing automation code (see puppeteer-docs skill)."
  fi
} 2>/dev/null
exit 0
