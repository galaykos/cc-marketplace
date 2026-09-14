#!/usr/bin/env bash
# brief-lint.sh — leaning detector for a consult brief.
# Usage: brief-lint.sh [file]   (reads stdin when no file is given)
#
# The blind rule (skills/consult/SKILL.md) says the brief must carry facts, not
# the session's conclusion. The session composing the brief is the party with
# the anchor, so the rule was self-policed; this lint is the mechanical part.
# Exit 0: no leaning phrasing found. Exit 1: offending lines listed.
#
# Residual (honest limitation): this catches conclusion PHRASING, not smuggled
# conclusions. "The cache layer, which is broken, is at path X" passes the lint
# and still leans. A clean lint is necessary, never sufficient — reread the
# brief for framing before dispatch.
set -u

input=$(cat "${1:-/dev/stdin}") || exit 2

patterns=(
  '\bi (think|believe|suspect|assume|bet|am (pretty )?sure)\b'
  '\bwe (think|believe|suspect|assume)\b'
  '\b(my|our) (hypothesis|theory|hunch|guess|suspicion)\b'
  '\b(probably|likely|presumably|obviously|clearly|almost certainly)\b'
  '\broot cause (is|seems|appears|must)\b'
  '\bthe (bug|cause|problem|culprit|issue|fix) (is|must|seems|appears|lies)\b'
  '\bmust be (the|a|an|in|due)\b'
  '\bconfirm (that|this|our|my|it)\b'
  '\b(the right|the correct|the obvious) (fix|answer|approach)\b'
  '\bcheck (the|whether the) [a-z]+ first\b'
)

fail=0
for p in "${patterns[@]}"; do
  hits=$(printf '%s\n' "$input" | grep -inE "$p" || true)
  if [[ -n "$hits" ]]; then
    while IFS= read -r line; do
      printf 'brief-lint: leaning phrasing [%s] at line %s\n' "$p" "${line%%:*}"
    done <<< "$hits"
    fail=1
  fi
done

[[ $fail -eq 0 ]] && echo "brief-lint: clean (phrasing only — reread for smuggled framing)"
exit $fail
