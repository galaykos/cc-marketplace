#!/usr/bin/env bash
# Fail open: never block the prompt. Print a reminder only on keyword match.
{
  input=$(cat)
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  if printf '%s' "$prompt" | grep -qiE '\b(api|sdk|endpoint|integrat|webhook|oauth|restful|graphql)\b'; then
    echo "api-docs-first: this prompt mentions an API/SDK integration. Verify current official docs before writing integration code; if no docs are accessible, ask the user for a URL or file (see api-docs-first skill)."
  fi
} 2>/dev/null
exit 0
