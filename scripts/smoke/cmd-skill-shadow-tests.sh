#!/usr/bin/env bash
# Smoke tests for pc_cmd_skill_shadow (scripts/lib/plugin-checks.sh), plus its
# validate.sh wiring.
#
# The live repo passes this check by construction — its six pairs were resolved before
# the check existed — so a clean run proves nothing. These fixtures are the record that it
# has been watched fail, and that a reasonless marker does not silence it.
#
# WHAT IS PINNED IS THE ASSERTION LIST BELOW. pc_cmd_skill_shadow's own header says what
# the check does and does not catch; if the two disagree, the assertions win.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/scripts/lib/plugin-checks.sh" 2>/dev/null || { echo "FAIL: cannot source plugin-checks.sh"; exit 1; }

WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT
trap 'exit 130' INT TERM HUP
pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'PASS  %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL  %s\n      %s\n' "$1" "$2"; }

mkroot() { rm -rf "$WORK/plugins"; mkdir -p "$WORK/plugins"; }
cmd()    { mkdir -p "$WORK/plugins/$1/commands"; printf '%s\n' "---" "description: c" "---" "${3:-body}" > "$WORK/plugins/$1/commands/$2.md"; }
skill()  { mkdir -p "$WORK/plugins/$1/skills/$2"; printf '%s\n' "---" "name: $2" "description: s" "---" > "$WORK/plugins/$1/skills/$2/SKILL.md"; }

mkroot; cmd alpha build; skill alpha build; skill alpha other
out=$(pc_cmd_skill_shadow "$WORK/plugins"); rc=$?
[ "$rc" = 1 ] && [ "$out" = "shadow alpha:build" ] \
  && ok "unmarked same-name command and skill fails" \
  || bad "unmarked same-name command and skill fails" "want rc=1 'shadow alpha:build', got rc=$rc '$out'"

mkroot; cmd alpha build '<!-- shadow-ok: the command pins argument-hint the skill cannot carry -->'; skill alpha build
out=$(pc_cmd_skill_shadow "$WORK/plugins"); rc=$?
[ "$rc" = 0 ] && [ -z "$out" ] \
  && ok "shadow-ok marker with a reason passes" \
  || bad "shadow-ok marker with a reason passes" "want rc=0 and no output, got rc=$rc '$out'"

leaked=""
for marker in '<!-- shadow-ok -->' '<!-- shadow-ok: -->' '<!-- shadow-ok:-->' '<!-- shadow-ok:    -->' "$(printf '<!-- shadow-ok:\t-->')"; do
  mkroot; cmd alpha build "$marker"; skill alpha build
  out=$(pc_cmd_skill_shadow "$WORK/plugins"); rc=$?
  [ "$rc" = 1 ] && [ "$out" = "shadow alpha:build" ] || leaked="$leaked [$marker rc=$rc]"
done
[ -z "$leaked" ] \
  && ok "shadow-ok marker without a reason still fails" \
  || bad "shadow-ok marker without a reason still fails" "silenced by:$leaked"

mkroot; cmd alpha build; skill alpha built
out=$(pc_cmd_skill_shadow "$WORK/plugins"); rc=$?
[ "$rc" = 0 ] && [ -z "$out" ] \
  && ok "different names pass" \
  || bad "different names pass" "want rc=0 and no output, got rc=$rc '$out'"

mkroot; skill alpha build
out=$(pc_cmd_skill_shadow "$WORK/plugins"); rc=$?
[ "$rc" = 0 ] && [ -z "$out" ] \
  && ok "a plugin with skills and no commands dir passes" \
  || bad "a plugin with skills and no commands dir passes" "want rc=0 and no output, got rc=$rc '$out'"

out=$(pc_cmd_skill_shadow "$ROOT/plugins"); rc=$?
[ "$rc" = 0 ] && [ -z "$out" ] \
  && ok "live repo has no unmarked pair" \
  || bad "live repo has no unmarked pair" "rc=$rc: $out"

HINT="a plugin ships commands/<name>.md and skills/<name>/SKILL.md — the command's description shadows the skill's in the listing; fold one into the other, or mark the command '<!-- shadow-ok: <why> -->'"
if grep -v '^[[:space:]]*#' "$ROOT/scripts/validate.sh" | grep -A1 -F 'shadow_gap=$(pc_cmd_skill_shadow plugins) || true' \
   | grep -qF "[ -n \"\$shadow_gap\" ] && lane_err \"\$shadow_gap\" \"$HINT\""; then
  ok "validate.sh feeds pc_cmd_skill_shadow output to lane_err with its hint"
else
  bad "validate.sh feeds pc_cmd_skill_shadow output to lane_err with its hint" "the call is missing, commented out, or no longer feeds lane_err its hint"
fi

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
