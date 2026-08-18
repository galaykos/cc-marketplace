#!/usr/bin/env bash
# Which author-time checks has anyone actually watched FAIL?
#
# MAINTAINER PATH, NOT A GATE. Always exits 0 and never fails a build. It reports; the
# judgment about whether an uncovered check deserves a fixture stays with a person,
# because some checks are structural enough that a fixture would be ceremony.
#
# WHY IT EXISTS: a check nobody has seen fail is indistinguishable from `return 0`. That
# is not hypothetical here — `pc_context_key` passed all three hooks that shipped the
# 2026-08-17 marker-key regression, because it tests for a string's presence and every
# offender contained the string.
#
# WHY IT IS A SCRIPT AND NOT A NUMBER IN A DOC: the first version of that day's review
# said "20 checks, 2 have harnesses, so ~14 have never been watched fail" — arrived at by
# counting harness FILES rather than tracing which checks each file exercises. The true
# figure was 3, because one harness covers six checks. A recorded count in prose is a
# measurement someone will trust and nobody will recompute. Run this instead.
#
# HONEST LIMITATION: coverage here means "a harness mentions this function by name". It
# cannot tell an assertion that watches the check fail from one that merely calls it, and
# it cannot see a harness that exercises a check through validate.sh without naming it.
# So this over-reports coverage; treat a NONE as certain and a hit as probable.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 0

LIB=scripts/lib/plugin-checks.sh
[ -r "$LIB" ] || exit 0

covered=0; uncovered=0; unwired=0
printf '%-26s %-6s %s\n' CHECK WIRED HARNESS
printf '%-26s %-6s %s\n' '-----' '-----' '-------'
for fn in $(grep -oE '^pc_[a-z_]+\(\)' "$LIB" | tr -d '()' | sort); do
  h=$(grep -rl "$fn" scripts/smoke/ plugins/*/scripts/__tests__/ 2>/dev/null \
      | sed 's|scripts/smoke/||; s|plugins/||; s|/scripts/__tests__/|:|' | tr '\n' ' ')
  w=$(grep -c "$fn" scripts/validate.sh 2>/dev/null || echo 0)
  [ "$w" -eq 0 ] && { unwired=$((unwired + 1)); w="NOT-WIRED"; }
  if [ -n "$h" ]; then covered=$((covered + 1)); else uncovered=$((uncovered + 1)); h='NONE'; fi
  printf '%-26s %-6s %s\n' "$fn" "$w" "$h"
done

printf '\n%s checks: %s with a harness, %s with NONE' "$((covered + uncovered))" "$covered" "$uncovered"
[ "$unwired" -gt 0 ] && printf ', %s never called from validate.sh' "$unwired"
printf '\n'
[ "$uncovered" -gt 0 ] && printf 'A check with NONE has never been watched fail. That is a decision to make, not a bug.\n'
exit 0
