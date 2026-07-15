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

[ "$rc" -eq 0 ] && echo "All rules-overlap smoke tests passed."
exit "$rc"
