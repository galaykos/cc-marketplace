#!/usr/bin/env bash
# dispatch-lint.sh [file] (stdin when none) — checks one drafted subagent prompt for the four string-checkable parts of delegation-contracts' prompt contract: an absolute path, a scope lock, a return shape, the closing data instruction. Exit 0 all four, 1 each missing one printed.
# Misses: quality of contract, only the phrase — a scope lock on the wrong scope passes; constraints and the done-when are judgment's.
# Why, limits, history: rationale/derivations/plugin-task-runner.md § plugins/task-runner/scripts/dispatch-lint.sh
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
