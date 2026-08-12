#!/bin/bash
# Absolute-path shebang, same reasoning as secret-scanning's guard: the fail-open
# guarantee must hold even under a stripped PATH.
#
# PostToolUse WARN (never deny) on the mechanically detectable subset of the
# security-review skill — the four shapes with near-zero false-positive cost that
# used to be review-time only. Warn, not deny, on purpose: each has a legitimate
# form (a fixture, an admin-only Blade page, an already-sanitized sink), and a
# deny that fires on ambiguous cases is a deny that gets turned off.
#
# One warning per (session, file, finding) — repeat edits stay quiet. Fail-open:
# any error, or missing jq, exits 0 silently. CC_SECURITY_SCAN=off disables.
#
# Residual (stated, per the has-teeth convention): shape-only matching on the
# text being written. Cross-file flows, authz logic, injection via query builders
# other than whereRaw — still review-time judgment (/security:review).
{
  [ "${CC_SECURITY_SCAN:-on}" = "off" ] && exit 0
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0

  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  case "$tool" in Write|Edit|MultiEdit) ;; *) exit 0 ;; esac

  text=$(printf '%s' "$input" | jq -r '
    [ .tool_input.content // empty,
      .tool_input.new_string // empty,
      ( .tool_input.edits // [] | map(.new_string // empty) | join("\n") )
    ] | join("\n")' 2>/dev/null) || exit 0
  [ -n "$text" ] || exit 0
  file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // "unknown"' 2>/dev/null)
  sid=$(printf '%s' "$input" | jq -r '.session_id // "nosession"' 2>/dev/null)

  hits=""
  detect() { # detect <slug> <ERE> <one-line advice>
    printf '%s' "$text" | grep -qE "$2" || return 0
    lock="${TMPDIR:-/tmp}/cc-security-scan/${sid}/$(printf '%s%s' "$file" "$1" | cksum | tr ' ' '_')"
    mkdir -p "$(dirname "$lock")" 2>/dev/null || return 0
    mkdir "$lock" 2>/dev/null || return 0   # already warned for this file+finding
    hits="${hits}[security] ${1}: ${3}
"
  }

  detect "mass-assignment-open" \
    '\$guarded[[:space:]]*=[[:space:]]*\[[[:space:]]*\]' \
    "empty \$guarded disables mass-assignment protection — list guarded fields or use \$fillable"
  detect "blade-unescaped" \
    '\{!![[:space:]]*\$' \
    "{!! \$var !!} skips Blade escaping — use {{ }} unless this exact value is sanitized HTML"
  detect "vite-client-secret" \
    'VITE_[A-Z0-9_]*(SECRET|TOKEN|PASSWORD|PRIVATE|API_?KEY)' \
    "VITE_-prefixed vars are compiled into the public client bundle — server secrets must not carry the prefix"
  detect "raw-sql-interpolation" \
    'whereRaw\((["'"'"'][^"'"'"')]*\{\$|[^,)]*\.[[:space:]]*\$)' \
    "variable inside whereRaw SQL — use ? placeholders with the bindings array"
  detect "raw-html-sink" \
    'dangerouslySetInnerHTML|v-html[[:space:]]*=' \
    "raw HTML sink — sanitize upstream or render as text; XSS if any user data reaches it"

  [ -n "$hits" ] || exit 0
  ctx="${hits}[security] warn-tier only (file: ${file}) — judgment cases stay with /security:review; CC_SECURITY_SCAN=off disables."
  jq -cn --arg c "$ctx" \
    '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$c}}' 2>/dev/null
  exit 0
} 2>/dev/null
exit 0
