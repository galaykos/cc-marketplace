#!/usr/bin/env bash
# Mod-plugin gate harness: proves each FAIL string pc_mod_modules
# (scripts/lib/plugin-checks.sh) emits fires on a planted fixture, and that a well-formed
# mod plugin draws none — mod-good (nested, `export const`), mod-good-fn and mod-good-async
# cover the three accepted register forms, one module each. The fixture
# plugins in scripts/smoke/validate-fixtures/mods/ are copied into plugins/ of a mirror,
# so they sit beside the real tree exactly as validate.sh's `pc_mod_modules plugins` sees
# them. Assert by EXACT STRING PRESENCE, never by count: a real plugin that ships a
# module adds lines of its own.
#
# RESIDUAL: validate.sh is not run. The wiring check greps the live validate.sh for the
# err() loop over `pc_mod_modules plugins`; a grep proves the line exists, not that it runs.
set -u
LIVE="$(cd "$(dirname "$0")/../../.." && pwd)" || exit 2

MIRROR="$(mktemp -d)" || exit 2
trap 'cd /; rm -rf "$MIRROR"' EXIT
trap 'exit 130' INT TERM HUP
for _d in plugins scripts; do
  cp -R "$LIVE/$_d" "$MIRROR/" || exit 2
done
cd "$MIRROR" || exit 2
. scripts/lib/plugin-checks.sh || exit 2
cp -R scripts/smoke/validate-fixtures/mods/. plugins/ || exit 2

npass=0 nfail=0
pass() { echo "PASS $1"; npass=$((npass + 1)); }
fail() { echo "FAIL $1 — $2"; nfail=$((nfail + 1)); }
want() { # want <name> <exact output line>
  if printf '%s\n' "$out" | grep -qxF "$2"; then pass "$1"
  else fail "$1" "no line '$2' in: ${out:-<empty>}"; fi
}

out=$(pc_mod_modules plugins 2>&1)
want "mod-module-missing fires"     "mod-module-missing mod-missing ./absent.ts"
want "mod-module-ext fires"         "mod-module-ext mod-badext ./register.jsx"
want "mod-module-no-register fires" "mod-module-no-register mod-noregister ./register.ts"
want "mod-module-count fires"       "mod-module-count mod-twomod 2"
if printf '%s\n' "$out" | awk '{print $2}' | grep -qxE 'mod-good(-fn|-async)?'; then
  fail "well-formed mod draws nothing" "$(printf '%s\n' "$out" | grep -E ' mod-good(-fn|-async)? ')"
else
  pass "well-formed mod draws nothing"
fi

if grep -qxF 'while IFS= read -r m; do err "$m"; done < <(pc_mod_modules plugins)' "$LIVE/scripts/validate.sh"; then
  pass "wiring — validate.sh err()s every pc_mod_modules line"
else
  fail "wiring — validate.sh err()s every pc_mod_modules line" "no err() loop over 'pc_mod_modules plugins' in scripts/validate.sh"
fi

echo "mod-checks: $npass passed, $nfail failed"
[ "$nfail" -eq 0 ]
