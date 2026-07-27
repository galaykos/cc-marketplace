#!/usr/bin/env bash
# Smoke tests for pc_rules_overlap (scripts/lib/plugin-checks.sh): the rules.tsv
# overlap gate must flag same-pattern high-confidence glob pairs that are neither
# marker-discriminated nor co-fire-ok-allowlisted — and nothing else.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
. "$ROOT/scripts/lib/plugin-checks.sh"
FIX="$ROOT/scripts/smoke/validate-fixtures/rules-collision.tsv"
rc=0

out=$(pc_rules_overlap "$FIX") && gate_rc=0 || gate_rc=$?

if [ "$gate_rc" -ne 0 ]; then
  echo "PASS: fixture collision makes the gate fail (rc=$gate_rc)"
else
  echo "FAIL: gate passed a fixture containing an unresolved collision"; rc=1
fi

if printf '%s\n' "$out" | grep -qx 'overlap \*\.bad alpha-skill beta-skill'; then
  echo "PASS: unresolved pair flagged (*.bad alpha-skill beta-skill)"
else
  echo "FAIL: unresolved pair not flagged; output: $out"; rc=1
fi

if [ "$(printf '%s\n' "$out" | grep -c '^overlap ')" -eq 1 ]; then
  echo "PASS: exactly one violation reported"
else
  echo "FAIL: expected exactly 1 violation, got: $out"; rc=1
fi

case "$out" in
  *'*.vue'*) echo "FAIL: marker-discriminated pair (*.vue) wrongly flagged"; rc=1 ;;
  *) echo "PASS: marker-discriminated pair allowed" ;;
esac
case "$out" in
  *'*.tsx'*) echo "FAIL: co-fire-ok pair (*.tsx) wrongly flagged"; rc=1 ;;
  *) echo "PASS: co-fire-ok pair allowed" ;;
esac
case "$out" in
  *'*.low'*|*gamma*|*epsilon*) echo "FAIL: low-confidence/content rows wrongly flagged"; rc=1 ;;
  *) echo "PASS: low-confidence and content rows ignored" ;;
esac

if pc_rules_overlap "$ROOT/plugins/skill-router/rules.tsv" >/dev/null; then
  echo "PASS: live rules.tsv is overlap-clean"
else
  echo "FAIL: live rules.tsv has unresolved co-fires"; rc=1
fi

if pc_rules_overlap "$ROOT/scripts/smoke/validate-fixtures/__absent__.tsv"; then
  echo "PASS: missing file returns clean (fail-open for optional consumers)"
else
  echo "FAIL: missing file should return 0"; rc=1
fi


# --- content-row co-firing (pc_rules_cofire) ---------------------------------
# The glob-axis test above flags rows sharing an IDENTICAL pattern. Content rows
# never do, so that algorithm is vacuous for them; these cases prove the corpus
# gate catches what pattern equality structurally cannot.
. scripts/lib/plugin-checks.sh
CORPUS=scripts/smoke/router-corpus
RT=$(mktemp); trap 'rm -f "$RT"' EXIT

# 1. the shipped file is clean (every real pair is blessed)
if pc_rules_cofire plugins/skill-router/rules.tsv "$CORPUS" >/dev/null; then
  echo "PASS[cofire]: shipped rules.tsv has no unblessed content co-fire"
else
  echo "FAIL[cofire]: shipped rules.tsv has an unblessed content co-fire"; rc=1
fi

# 2. an unblessed row with a DISTINCT regex that overlaps on real code must fail
cp plugins/skill-router/rules.tsv "$RT"
printf 'content\t\\b(catch|rescue)\\b\tzz-probe\tzz\tlow\n' >> "$RT"
if pc_rules_cofire "$RT" "$CORPUS" >/dev/null; then
  echo "FAIL[cofire]: distinct-regex overlap went undetected"; rc=1
else
  echo "PASS[cofire]: distinct-regex overlap detected"
fi

# 3. the glob-axis gate must NOT see it — proving the two checks are not redundant
if pc_rules_overlap "$RT" >/dev/null; then
  echo "PASS[cofire]: pattern-equality gate is blind to it, as expected"
else
  echo "FAIL[cofire]: pattern-equality gate unexpectedly flagged a content row"; rc=1
fi

[ "$rc" -eq 0 ] && echo "All rules-overlap smoke tests passed."
exit "$rc"