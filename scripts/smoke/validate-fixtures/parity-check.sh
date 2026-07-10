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
printf '%s\n' "$out" | grep -qF "$SK/SKILL.md: body is 171 lines, outside 100-150 budget" \
  && echo "PASS: budget FAIL fires" || { echo "FAIL: budget check did not fire"; rc=1; }
printf '%s\n' "$out" | grep -qF "$DOC: non-functional doc inside a plugin" \
  && echo "PASS: doc-location FAIL fires" || { echo "FAIL: doc-location check did not fire"; rc=1; }
exit $rc
