#!/bin/bash
# Absolute-path shebang not `/usr/bin/env bash`: the fail-open guarantee must hold
# even under a stripped PATH where `env bash` exits 127.
# PreToolUse secret guard. DENIES a Write/Edit/MultiEdit that introduces a
# high-confidence secret, before it reaches disk. Fail-open: any error, or a missing
# jq, exits 0 (allow) and never blocks legitimate work. Only high-confidence provider
# patterns deny — placeholder/fixture values with obviously-fake content pass.
{
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0

  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  case "$tool" in Write|Edit|MultiEdit) ;; *) exit 0 ;; esac

  # Collect the text being written across the three tool shapes.
  text=$(printf '%s' "$input" | jq -r '
    [ .tool_input.content // empty,
      .tool_input.new_string // empty,
      ( .tool_input.edits // [] | map(.new_string // empty) | join("\n") )
    ] | join("\n")' 2>/dev/null) || exit 0
  [ -n "$text" ] || exit 0
  file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

  hit=""
  detect() { [ -z "$hit" ] && printf '%s' "$text" | grep -qE "$2" && hit="$1"; }
  detect "AWS access key ID"       'AKIA[0-9A-Z]{16}'
  detect "private key block"       '-----BEGIN ([A-Z]+ )?PRIVATE KEY-----'
  detect "GitHub token"            'gh[pousr]_[A-Za-z0-9]{36,}'
  detect "Slack token"             'xox[baprs]-[A-Za-z0-9-]{10,}'
  detect "Google API key"          'AIza[0-9A-Za-z_-]{35}'
  detect "Stripe live secret key"  'sk_live_[0-9a-zA-Z]{24,}'
  detect "assigned secret literal" '(api[_-]?key|secret|token|passwd|password)["'"'"' ]*[:=]["'"'"' ]*[A-Za-z0-9/+=_-]{24,}'
  [ -n "$hit" ] || exit 0

  reason="secret-scanning: this write appears to contain a ${hit}. Blocked before it reaches disk. Move the value to an environment variable or a secret store and reference it by name; if this is a deliberate test fixture, use an obviously-fake value or a path outside version control."
  [ -n "$file" ] && reason="$reason (file: $file)"

  jq -cn --arg r "$reason" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}' 2>/dev/null
  exit 0
} 2>/dev/null
exit 0
