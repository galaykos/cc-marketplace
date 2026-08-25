#!/usr/bin/env bash
# Smoke tests for pc_source_of_truth (scripts/lib/plugin-checks.sh).
#
# WHY THIS FILE EXISTS. The check's behavioural claims were verified by planting
# fixtures by hand, twice, while its header said "a planted fixture reproduces it"
# and `scripts/gate-coverage.sh` reported its harness coverage as NONE. A
# behavioural claim with no harness is a recorded claim wearing a gate's clothes —
# the tier confusion this repo's has-teeth convention exists to name.
#
# WHAT IS PINNED IS THE ASSERTION LIST BELOW, and nothing else. This header
# deliberately does NOT enumerate the check's claims: it used to, the enumeration
# drifted out of step with the check's own header within one commit, and the pair
# then contradicted each other. Two copies of one claim is the defect this whole
# branch keeps re-finding. Read `pc_source_of_truth`'s header for what the check
# does and does not catch; read the `printf '== ...'` section names below for what
# is actually enforced. If those two ever disagree, the assertions win — they run.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/scripts/lib/plugin-checks.sh" 2>/dev/null || { echo "FAIL: cannot source plugin-checks.sh"; exit 1; }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'PASS  %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL  %s\n      %s\n' "$1" "$2"; }

mk() { # $1 skill-figure  $2 reference-figure
  local d="$WORK/plugins/t/skills/s"
  rm -rf "$WORK/plugins"; mkdir -p "$d/references"
  printf -- '---\nname: s\ndescription: d\n---\n\nSee `references/r.md` — SOURCE OF TRUTH for every figure below.\n\n- budget %s\n' "$1" > "$d/SKILL.md"
  printf '# r\n\n- budget %s\n' "$2" > "$d/references/r.md"
}
expect() { # want-rc  skill  ref  desc
  mk "$2" "$3"
  pc_source_of_truth "$WORK/plugins" >/dev/null 2>&1; local got=$?
  [ "$got" = "$1" ] && ok "$4" || bad "$4" "want rc=$1, got rc=$got (skill=$2 ref=$3)"
}

printf '== catches: adjacent unit, figure absent from the reference\n'
expect 1 "77KB"  "34KB"  "KB mismatch caught"
expect 1 "5MB"   "2MB"   "MB mismatch caught"
expect 1 "500ms" "200ms" "ms mismatch caught"
expect 1 "60fps" "30fps" "fps mismatch caught"

printf '== passes: the figure agrees\n'
expect 0 "34KB"  "34KB"  "matching figure passes"

printf '== misses, by construction and by declaration in the header\n'
expect 0 "24px"  "12px"  "px is not covered"
expect 0 "77 KB" "34KB"  "spaced unit on the SKILL side is invisible"
expect 0 "99"    "34KB"  "bare integer is not covered"

printf '== the declared FALSE-fail direction\n'
expect 1 "34KB"  "34 KB" "reference-side spacing falsely fails (documented brittleness)"

printf '== SCOPE: a SKILL that does not declare the marker is untouched\n'
# What this pins: the marker gating as a WHOLE. The check has two guards — the
# `SOURCE OF TRUTH` grep and the reference-path extraction, which greps the same
# line — so removing either alone is a no-op and correctly flips nothing. Remove
# BOTH and the gate starts firing on every skill in the repo; without this
# assertion that blast passed green. Verified both directions: single break → 10/10
# pass (nothing to catch), double break → this assertion reds.
mk_unmarked() { # $1 skill-figure  $2 reference-figure
  local d="$WORK/plugins/t/skills/s"
  rm -rf "$WORK/plugins"; mkdir -p "$d/references"
  printf -- '---\nname: s\ndescription: d\n---\n\nSee `references/r.md` for the budgets.\n\n- budget %s\n' "$1" > "$d/SKILL.md"
  printf '# r\n\n- budget %s\n' "$2" > "$d/references/r.md"
}
mk_unmarked "77KB" "34KB"
pc_source_of_truth "$WORK/plugins" >/dev/null 2>&1
[ "$?" = "0" ] && ok "no SOURCE OF TRUTH marker: skill ignored despite a mismatch" \
  || bad "no SOURCE OF TRUTH marker: skill ignored despite a mismatch" "gate fired on an undeclared skill"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
