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
  echo "Resolve card 07 before continuing."
  for i in $(seq 2 170); do echo "line $i"; done
} > "$SK/SKILL.md"
echo "# stray" > "$DOC"

out=$(bash scripts/validate.sh 2>&1)
rc=0
printf '%s\n' "$out" | grep -qF "$SK/SKILL.md: body is 171 lines, over the 150-line ceiling" \
  && echo "PASS: budget FAIL fires" || { echo "FAIL: budget check did not fire"; rc=1; }
printf '%s\n' "$out" | grep -qF "$DOC: non-functional doc inside a plugin" \
  && echo "PASS: doc-location FAIL fires" || { echo "FAIL: doc-location check did not fire"; rc=1; }
# validate.sh's own jargon wiring: the find path set, the taskmaster/task-runner
# skip arm, and the "[$hit]" interpolation. Calling pc_jargon directly (below)
# cannot catch an empty bracket or a broken call site.
printf '%s\n' "$out" | grep -qF "$SK/SKILL.md: leaked internal taskmaster jargon [card 07]" \
  && echo "PASS: jargon wiring fires with populated hit" \
  || { echo "FAIL: validate.sh jargon wiring did not fire with [card 07]"; rc=1; }

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

jseed() { printf '%s\n' "$1" > "$JTMP"; }

# Both channels are asserted on every case. validate.sh branches on pc_jargon's
# EXIT STATUS and interpolates its STDOUT; a regression that prints matches while
# returning 0 (gate silently dead) or returns 1 with an empty hit (an empty
# bracket in the error) is invisible to a stdout-only assertion.
jassert_hit() { # $1 desc  $2 line
  jseed "$2"; out_j=$(pc_jargon "$JTMP"); st=$?
  if [ "$st" -eq 1 ] && [ -n "$out_j" ]; then echo "PASS: $1"
  else echo "FAIL: $1 (status=$st hit='$out_j'; want status 1 + non-empty)"; rc=1; fi
}
jassert_clean() { # $1 desc  $2 line
  jseed "$2"; out_j=$(pc_jargon "$JTMP"); st=$?
  if [ "$st" -eq 0 ] && [ -z "$out_j" ]; then echo "PASS: $1"
  else echo "FAIL: $1 (status=$st hit='$out_j'; want status 0 + empty)"; rc=1; fi
}

# TRUE POSITIVE — the internal vocabulary must still be caught.
jassert_hit "jargon fires on 'card 07'" 'Resolve card 07 before continuing.'

# FALSE POSITIVES — ordinary English a plugin has every right to write.
jassert_clean "jargon allows: credit card 16 digits"   'Use a credit card 16 digits long.'
jassert_clean "jargon allows: the backlog of stories"  'The backlog of user stories is groomed weekly.'
jassert_clean "jargon allows: finding #2 in a report"  'See finding #2 in the OWASP report for the remediation.'
jassert_clean "jargon allows: smoke test 3 in a suite" 'Run smoke test 3 in the regression suite.'

# ESCAPE HATCH — an author legitimately quoting the vocabulary.
jassert_clean "<!-- jargon-ok --> suppresses" 'Resolve card 07 here. <!-- jargon-ok -->'

exit $rc
