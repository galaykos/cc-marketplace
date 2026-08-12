#!/usr/bin/env bash
# dispatch-lint.sh — mechanical contract check over ONE drafted subagent prompt.
# Usage: dispatch-lint.sh [file]   (reads stdin when no file is given)
#
# delegation-contracts § Prompt contract names five elements; four are
# string-checkable and this lint checks exactly those:
#   1. an absolute path            (fresh context — relative paths are coin flips)
#   2. a scope lock                (what NOT to touch, stated)
#   3. a required return shape     (format/cap stated, not hoped for)
#   4. the closing data instruction ("final message is data", no-preamble)
# The fifth (constraints/conventions) is not string-checkable — judgment owns it.
#
# Exit 0: all four present. Exit 1: each missing element printed.
# Residual: presence-of-phrase, not quality-of-contract — a scope lock that
# locks the wrong scope passes. /orchestration:review judges that part.
set -u

input=$(cat "${1:-/dev/stdin}") || exit 2
fail=0

need() { # need <label> <ERE> <hint>
  printf '%s' "$input" | grep -qiE "$2" || {
    printf 'dispatch-lint: missing %s — %s\n' "$1" "$3"; fail=1; }
}

need "absolute path" \
  '(^|[[:space:]"'"'"'`(=])/[[:alnum:]_.-]+/[[:alnum:]_./-]+' \
  "name every file in full; the agent's cwd is not yours"
need "scope lock" \
  'do not (modify|touch|edit)|only (edit|modify|touch)|scope (lock|:)|no other files|allowed files|nothing outside|outside .* (is|are) (blast radius|out of scope)' \
  "state what NOT to touch, not just what to touch"
need "return shape" \
  'return (exactly|at most|only|as )|one line (each|per)|final message must|format:|as json|as a table|length cap|[0-9]+ lines? (max|total|or fewer)' \
  "say exactly what the final message contains: format, per-item shape, cap"
need "closing data instruction" \
  'final message is data|not prose for a human|no preamble' \
  "tell it the return is data for the orchestrator, or you get an essay"

exit $fail
