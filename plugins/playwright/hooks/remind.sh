#!/usr/bin/env bash
# Fail open: never block the prompt. Print a reminder only on Playwright keywords.
{
  input=$(cat)
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  case "$prompt" in "/"*) exit 0 ;; esac # slash commands manage their own flow
  if printf '%s' "$prompt" | grep -qiE '\b(playwright|page\.locator|getbyrole|connectovercdp|browsercontext)\b'; then
    echo "playwright: run /playwright:check <goal> to pin the current API and patterns before writing automation (see playwright skill)."
  fi
} 2>/dev/null
exit 0
