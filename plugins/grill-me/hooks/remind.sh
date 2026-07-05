#!/usr/bin/env bash
# Fail open: never block the prompt. Remind only on thin feature-shaped prompts.
{
  input=$(cat)
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  case "$prompt" in "/"*) exit 0 ;; esac # slash commands manage their own flow
  len=${#prompt}
  if [ "$len" -gt 0 ] && [ "$len" -lt 200 ] \
    && printf '%s' "$prompt" | grep -qiE '\b(build|create|add|implement|develop|rewrite|refactor)\b'; then
    echo "grill-me: feature-shaped prompt with thin detail. Consider /grill-me:task to pin down scope, edge cases, and success criteria before code (see grill skill)."
  fi
} 2>/dev/null
exit 0
