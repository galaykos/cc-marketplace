#!/usr/bin/env bash
# Mod-plugin gate harness: proves each FAIL string pc_mod_modules
# (scripts/lib/plugin-checks.sh) emits fires on a planted fixture, and that a well-formed
# mod plugin draws none — mod-good (nested, `export const`), mod-good-fn and mod-good-async
# cover the three accepted register forms, one module each. The `mod` lane kind is proven
# the same way: mod-uncovered (no row), mod-unguarded (phase row, sentinel only in its
# cc-kit.ts), mod-declared (declared and guarded) and mod-ghost (rows naming no module) for
# pc_lanes_coverage, pc_phase_guard, pc_lanes_schema and pc_lanes_resolve. The fixture
# plugins in scripts/smoke/validate-fixtures/mods/ are copied into plugins/ of a mirror,
# so they sit beside the real tree exactly as validate.sh's `pc_mod_modules plugins` sees
# them. Assert by EXACT STRING PRESENCE, never by count: a real plugin that ships a
# module adds lines of its own.
#
# RESIDUAL: validate.sh is not run. The wiring checks grep the live validate.sh for the
# lines that route each gate's output to err(); a grep proves the line exists, not that it runs.
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
lacks() { # lacks <name> <fixed string no output line may contain>
  if printf '%s\n' "$out" | grep -qF "$2"; then fail "$1" "$(printf '%s\n' "$out" | grep -F "$2")"
  else pass "$1"; fi
}
wired() { # wired <name> <exact validate.sh line>
  if grep -qxF "$2" "$LIVE/scripts/validate.sh"; then pass "$1"
  else fail "$1" "no line '$2' in scripts/validate.sh"; fi
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

out=$(pc_lanes_coverage plugins 2>&1)
want  "lane-uncovered-mod fires"                   "lane-missing lane-uncovered-mod mod-uncovered:redaction"
lacks "an entry that only dispatches needs no row" "lane-uncovered-mod mod-uncovered:mods"
lacks "the shared kit needs no row"                "lane-uncovered-mod mod-uncovered:cc-kit"
lacks "a declared mod is covered"                  "lane-uncovered-mod mod-declared:"
lacks "a file the entry never imports needs no row" "lane-uncovered-mod mod-uncovered:stray"

out=$(pc_phase_guard plugins 2>&1)
want  "phase-guard-mod fires"                       "phase-guard-mod mod-unguarded:watch"
want  "the shared kit never satisfies the guard"    "phase-guard-mod mod-unguarded:cc-kit"
lacks "a guarded mod passes the phase guard"        "phase-guard-mod mod-declared:"

out=$( { pc_lanes_schema plugins/mod-declared/lane.tsv; pc_lanes_resolve plugins/mod-declared/lane.tsv; } 2>&1)
if [ -z "$out" ]; then pass "declared mod resolves"; else fail "declared mod resolves" "$out"; fi
out=$(pc_lanes_resolve plugins/mod-unguarded/lane.tsv 2>&1)
if [ -z "$out" ]; then pass "a mod named in yields_to resolves"; else fail "a mod named in yields_to resolves" "$out"; fi
out=$(pc_lanes_resolve plugins/mod-ghost/lane.tsv 2>&1)
want  "a mod row naming no module fails resolve" \
      "lane-resolve plugins/mod-ghost/lane.tsv:1 mod-ghost:absent names no mod in the tree"
want  "a mod row naming a file the entry never imports fails resolve" \
      "lane-resolve plugins/mod-ghost/lane.tsv:2 mod-ghost:orphan names no mod in the tree"

mkdir -p vocab-fixture/v || exit 2
printf 'v:a\tmod\tany\t%s\ta checkable condition\t-\n' secret-output-redaction subagent-model-floor \
  next-step-suggestion run-board program-status-line undeclared-control-noun > vocab-fixture/v/lane.tsv
out=$(pc_lanes_vocabulary vocab-fixture scripts/lane-vocabulary.txt 2>&1)
if [ "$out" = "lane-vocab vocab-fixture/v/lane.tsv undeclared-control-noun" ]; then
  pass "the five mod owns nouns pass the vocabulary check"
else
  fail "the five mod owns nouns pass the vocabulary check" "want only the control noun, got: ${out:-<empty>}"
fi

if grep -qxF 'while IFS= read -r m; do err "$m"; done < <(pc_mod_modules plugins)' "$LIVE/scripts/validate.sh"; then
  pass "wiring — validate.sh err()s every pc_mod_modules line"
else
  fail "wiring — validate.sh err()s every pc_mod_modules line" "no err() loop over 'pc_mod_modules plugins' in scripts/validate.sh"
fi
wired "wiring — validate.sh err()s pc_lanes_coverage's lane-missing lines" \
      "lane_gap=\$(printf '%s\n' \"\$lane_cov\" | grep '^lane-missing ' || true)"
wired "wiring — validate.sh err()s every pc_phase_guard line" \
      'phase_gap=$(pc_phase_guard plugins) || true'

echo "mod-checks: $npass passed, $nfail failed"
[ "$nfail" -eq 0 ]
