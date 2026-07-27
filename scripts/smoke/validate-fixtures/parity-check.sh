#!/usr/bin/env bash
# Parity harness: proves validate.sh — now sourcing scripts/lib/plugin-checks.sh —
# still fires the SKILL-budget and doc-location FAIL paths with its exact messages.
# Plants throwaway violations in a listed plugin, runs validate, asserts, cleans up.
# Runnable in CI on every lib change (guards the shared-lib refactor against drift).
set -u
cd "$(dirname "$0")/../../.." || exit 2   # repo root
P=plugins/debugging
SK="$P/skills/_parity_scratch"
DOC="$P/_parity_scratch.md"
cleanup() { rm -rf "$SK" "$DOC"; }
trap cleanup EXIT
mkdir -p "$SK"
{
  echo '---'; echo 'name: _parity_scratch'
  echo 'description: Use when proving the budget check fires on an over-length body.'
  echo '---'; echo
  for i in $(seq 1 170); do echo "line $i"; done
} > "$SK/SKILL.md"
echo "# stray" > "$DOC"

out=$(bash scripts/validate.sh 2>&1)
rc=0
printf '%s\n' "$out" | grep -qF "$SK/SKILL.md: body is 171 lines, over the 150-line ceiling" \
  && echo "PASS: budget FAIL fires" || { echo "FAIL: budget check did not fire"; rc=1; }
printf '%s\n' "$out" | grep -qF "$DOC: non-functional doc inside a plugin" \
  && echo "PASS: doc-location FAIL fires" || { echo "FAIL: doc-location check did not fire"; rc=1; }

# ---------------------------------------------------------------------------
# Jargon gate: both directions, plus the escape hatch.
#
# Before this block the jargon check had ZERO fixture coverage, its rescue list
# did not exist, and <!-- jargon-ok --> was used zero times in the repo — an
# untested escape from a gate that rejected ordinary English.
#
# Exercises pc_jargon directly — the SAME function validate.sh calls, so there is
# no second copy of the patterns to drift. Direct calls also keep this harness
# fast; routing each case through a full validate.sh run took ~2min.
# ---------------------------------------------------------------------------
. scripts/lib/plugin-checks.sh
JTMP=$(mktemp)
cleanup_j() { rm -f "$JTMP"; }
trap 'cleanup; cleanup_j' EXIT

jrun() { printf '%s\n' "$1" > "$JTMP"; pc_jargon "$JTMP"; }

# TRUE POSITIVE — the internal vocabulary must still be caught.
[ -n "$(jrun 'Resolve card 07 before continuing.')" ] \
  && echo "PASS: jargon fires on 'card 07'" || { echo "FAIL: jargon missed 'card 07'"; rc=1; }

# FALSE POSITIVES — ordinary English a plugin has every right to write.
for s in \
  'Use a credit card 16 digits long.' \
  'The backlog of user stories is groomed weekly.' \
  'See finding #2 in the OWASP report for the remediation.' \
  'Run smoke test 3 in the regression suite.'
do
  if [ -n "$(jrun "$s")" ]; then
    echo "FAIL: jargon false-positive on: $s"; rc=1
  else
    echo "PASS: jargon allows: $s"
  fi
done

# ESCAPE HATCH — an author legitimately quoting the vocabulary.
[ -z "$(jrun 'Resolve card 07 before continuing. <!-- jargon-ok -->')" ] \
  && echo "PASS: <!-- jargon-ok --> suppresses" || { echo "FAIL: jargon-ok marker ignored"; rc=1; }

exit $rc
