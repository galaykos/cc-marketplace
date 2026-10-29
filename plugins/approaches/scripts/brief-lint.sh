#!/usr/bin/env bash
# brief-lint.sh [file] (stdin when none) — leaning detector for a consult brief, the mechanical part of the blind rule (skills/consult/SKILL.md: facts, not the session's conclusion). Exit 0 no leaning phrasing, 1 offending lines listed.
# Misses: smuggled conclusions — "The cache layer, which is broken, is at path X" passes and still leans; a clean lint is necessary, never sufficient: reread the brief for framing before dispatch.
# Why, limits, history: rationale/derivations/plugin-approaches.md § plugins/approaches/scripts/brief-lint.sh
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
