#!/usr/bin/env bash
# Mod-plugin gate harness: proves each FAIL string pc_mod_modules
# (scripts/lib/plugin-checks.sh) emits fires on a planted fixture, and that a well-formed
# mod plugin draws none — mod-good (nested, `export const`), mod-good-fn and mod-good-async
# cover the three accepted register forms, one module each. The `mod` lane kind is proven
# the same way: mod-uncovered (no row), mod-unguarded (phase row, sentinel only in its
# cc-kit.ts), mod-declared (declared and guarded) and mod-ghost (rows naming no module) for
# pc_lanes_coverage, pc_phase_guard, pc_lanes_schema and pc_lanes_resolve; mod-hostof and
# a planted mod-drifted for pc_mod_kit. The fixture
# plugins in scripts/smoke/validate-fixtures/mods/ are copied into plugins/ of a mirror,
# so they sit beside the real tree exactly as validate.sh's `pc_mod_modules plugins` sees
# them. A fixture that must equal a live template — each cc-kit.ts and mod-hostof's
# pasted.ts — is planted from templates/mods/ at run time, so editing the kit or the host
# block cannot leave a committed copy stale. Assert by EXACT STRING PRESENCE, never by
# count: a real plugin that ships a module adds lines of its own.
#
# RESIDUAL: validate.sh is not run. The wiring checks grep the live validate.sh for the
# lines that route each gate's output to err(); a grep proves the line exists, not that it runs.
set -u
LIVE="$(cd "$(dirname "$0")/../../.." && pwd)" || exit 2

MIRROR="$(mktemp -d)" || exit 2
trap 'cd /; rm -rf "$MIRROR"' EXIT
trap 'exit 130' INT TERM HUP
for _d in plugins scripts templates; do
  cp -R "$LIVE/$_d" "$MIRROR/" || exit 2
done
cd "$MIRROR" || exit 2
. scripts/lib/plugin-checks.sh || exit 2
cp -R scripts/smoke/validate-fixtures/mods/. plugins/ || exit 2
KIT=templates/mods/cc-kit.ts
for _p in mod-uncovered mod-unguarded; do cp "$KIT" "plugins/$_p/hooks/cc-kit.ts" || exit 2; done

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

mkdir -p plugins/mod-drifted/hooks && cp "$KIT" plugins/mod-drifted/hooks/cc-kit.ts || exit 2
printf 'X' | dd of=plugins/mod-drifted/hooks/cc-kit.ts bs=1 count=1 conv=notrunc 2>/dev/null || exit 2
{ cat templates/mods/host-block.ts; printf '\nexport const cwdOf = $ => hostOf($).cwd()\n'; } \
  > plugins/mod-hostof/hooks/pasted.ts || exit 2
out=$(pc_mod_kit plugins "$KIT" 2>&1)
want  "mod-kit-drift fires"                        "mod-kit-drift plugins/mod-drifted/hooks/cc-kit.ts"
want  "mod-host-block-drift fires"                 "mod-host-block-drift plugins/mod-hostof/hooks/mods.ts"
want  "a feature file's hostOf( is gated too"      "mod-host-block-drift plugins/mod-hostof/hooks/drifted.ts"
lacks "the host block pasted verbatim passes"      "plugins/mod-hostof/hooks/pasted.ts"
lacks "a kit importer without hostOf( draws nothing" "plugins/mod-unguarded/hooks/watch.ts"
_same=$(printf '%s\n' "$out" | grep -xF -e 'mod-kit-drift plugins/mod-uncovered/hooks/cc-kit.ts' \
  -e 'mod-kit-drift plugins/mod-unguarded/hooks/cc-kit.ts' -e "mod-kit-drift templates/mods/kit-harness/hooks/cc-kit.ts")
if [ -z "$_same" ]; then pass "identical kit copy draws nothing"; else fail "identical kit copy draws nothing" "$_same"; fi

mkdir -p kitfix/plugins kitfix/kit-harness/hooks || exit 2
printf 'export const kit = 1\n' > kitfix/cc-kit.ts
cp templates/mods/host-block.ts kitfix/ && cp "$KIT" kitfix/kit-harness/hooks/cc-kit.ts || exit 2
out=$(pc_mod_kit kitfix/plugins kitfix/cc-kit.ts 2>&1)
want  "a canonical kit without the host block fires" "mod-host-block-drift kitfix/cc-kit.ts"
want  "the kit-harness copy is compared"             "mod-kit-drift kitfix/kit-harness/hooks/cc-kit.ts"

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
wired "wiring — validate.sh err()s every pc_mod_kit line" \
      'while IFS= read -r m; do err "$m"; done < <(pc_mod_kit plugins templates/mods/cc-kit.ts)'

echo "mod-checks: $npass passed, $nfail failed"
[ "$nfail" -eq 0 ]
