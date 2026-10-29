#!/usr/bin/env bash
# gate-coverage.sh — maintainer path, exits 0: for each pc_* check, the harnesses (scripts/smoke/, plugins/*/scripts/__tests__/) that mention it (NONE = never watched fail) and its WIRED line count in validate.sh, context-budget.sh and official-validate.sh.
# Misses: a hit is a mention, not proof of exercise, so it over-reports (NONE is certain, a hit probable); a check exercised through validate.sh without its name; calls from done-gate.sh and authoring-guard.sh.
# Why, limits, history: rationale/derivations/scripts.md § scripts/gate-coverage.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 0

LIB=scripts/lib/plugin-checks.sh
[ -r "$LIB" ] || exit 0

covered=0; uncovered=0; unwired=0
printf '%-26s %-6s %s\n' CHECK WIRED HARNESS
printf '%-26s %-6s %s\n' '-----' '-----' '-------'
for fn in $(grep -oE '^pc_[a-z_]+\(\)' "$LIB" | tr -d '()' | sort); do
  # -w: `_` is a word character, so pc_x is not credited with pc_x_tail's mentions.
  h=$(grep -rlw "$fn" scripts/smoke/ plugins/*/scripts/__tests__/ 2>/dev/null \
      | sed 's|scripts/smoke/||; s|plugins/||; s|/scripts/__tests__/|:|' | tr '\n' ' ')
  w=$(cat scripts/validate.sh scripts/context-budget.sh scripts/official-validate.sh 2>/dev/null | grep -cw "$fn")
  [ "$w" -eq 0 ] && { unwired=$((unwired + 1)); w="NOT-WIRED"; }
  if [ -n "$h" ]; then covered=$((covered + 1)); else uncovered=$((uncovered + 1)); h='NONE'; fi
  printf '%-26s %-6s %s\n' "$fn" "$w" "$h"
done

printf '\n%s checks: %s with a harness, %s with NONE' "$((covered + uncovered))" "$covered" "$uncovered"
[ "$unwired" -gt 0 ] && printf ', %s never called from validate.sh, context-budget.sh or official-validate.sh' "$unwired"
printf '\n'
[ "$uncovered" -gt 0 ] && printf 'A check with NONE has never been watched fail. That is a decision to make, not a bug.\n'
exit 0
