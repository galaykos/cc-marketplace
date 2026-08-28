#!/usr/bin/env bash
# Tests scripts/authoring-guard.sh against PostToolUse-shaped stdin JSON. Asserts
# the additionalContext envelope appears (or not) per case AND exit 0 in every case
# (fail-open). Local harness; run from anywhere.
set -u
cd "$(dirname "$0")/../.." || exit 2
GUARD=scripts/authoring-guard.sh
ROOT=$(pwd)
rc=0

json() { jq -cn --arg p "$1" '{tool_input:{file_path:$p}}'; }

check() { # $1 desc  $2 file_path  $3 want: ceiling|doc-location|none
  local out ex body
  out=$(printf '%s' "$(json "$2")" | bash "$GUARD"; printf 'EXIT:%s' "$?")
  ex=${out##*EXIT:}; body=${out%EXIT:*}
  if [ "$ex" != 0 ]; then echo "FAIL[$1]: exit $ex (want 0)"; rc=1; return; fi
  if [ "$3" = none ]; then
    [ -z "$body" ] && echo "PASS[$1]: silent, exit 0" || { echo "FAIL[$1]: wanted silence, got: $body"; rc=1; }
  else
    if printf '%s' "$body" | grep -q additionalContext && printf '%s' "$body" | grep -qi "$3"; then
      echo "PASS[$1]: warned ($3), exit 0"
    else echo "FAIL[$1]: wanted $3 warning, got: $body"; rc=1; fi
  fi
}

TMPSK="plugins/debugging/skills/_guardtest"; mkdir -p "$TMPSK"
{ echo '---'; echo 'name: _guardtest'; echo 'description: Use when testing the guard budget path with an over-length body.'; echo '---'; echo; for i in $(seq 1 220); do echo "l$i"; done; } > "$TMPSK/SKILL.md"
CLEANSK="plugins/debugging/skills/_guardclean"; mkdir -p "$CLEANSK"
# 40 lines, DELIBERATELY: this fixture is the regression guard for the removed
# 100-line floor. At its old 110 lines it sat above the floor, so re-adding
# `-lt 100` to pc_skill_budget would have kept every smoke test green.
{ echo '---'; echo 'name: _guardclean'; echo 'description: Use when testing the guard with a short body that stays clean.'; echo '---'; echo; for i in $(seq 1 40); do echo "l$i"; done; } > "$CLEANSK/SKILL.md"
# Byte-ceiling fixture: 160 lines, comfortably under the 200-line ceiling, ~16 kB —
# the exact shape the line count stopped measuring (task-execution sat at a frozen
# 154 lines while its bytes grew 31%). Both numbers were raised with the caps on
# 2026-08-27: at the old 120 lines / ~12 kB the fixture no longer exceeded the
# 14,000-byte ceiling. It failed LOUDLY when it stopped ("wanted bytes warning,
# got:"), which is the property worth keeping — every cap-sized fixture in this
# repo asserts the check FIRES, so moving a cap breaks the suite rather than
# silently retiring the test. Keep it that way: a fixture that merely runs the
# check without asserting on its output would go quiet instead.
BYTESK="plugins/debugging/skills/_guardbytes"; mkdir -p "$BYTESK"
{ echo '---'; echo 'name: _guardbytes'; echo 'description: Use when testing the guard byte path with a fat but short body.'; echo '---'; echo
  for i in $(seq 1 160); do printf 'l%s %s\n' "$i" "$(head -c 95 < /dev/zero | tr '\0' 'x')"; done; } > "$BYTESK/SKILL.md"
# Line-length fixture: 20 short lines and one 400-character prose line.
LONGSK="plugins/debugging/skills/_guardlong"; mkdir -p "$LONGSK"
{ echo '---'; echo 'name: _guardlong'; echo 'description: Use when testing the guard line-length path with one jammed line.'; echo '---'; echo
  for i in $(seq 1 20); do echo "l$i"; done; head -c 400 < /dev/zero | tr '\0' 'y'; echo; } > "$LONGSK/SKILL.md"
# Exemption fixture: the same 400 characters as a TABLE ROW, which cannot wrap and
# must NOT fail — the residual this check declares rather than pretends away.
TABLESK="plugins/debugging/skills/_guardtable"; mkdir -p "$TABLESK"
{ echo '---'; echo 'name: _guardtable'; echo 'description: Use when testing that a long table row is exempt from the line check.'; echo '---'; echo
  echo '| a | b |'; echo '|---|---|'; printf '| %s |\n' "$(head -c 400 < /dev/zero | tr '\0' 'z')"; } > "$TABLESK/SKILL.md"
STRAY="plugins/debugging/_guardstray.md"; echo "# stray" > "$STRAY"
cleanup() { rm -rf "$TMPSK" "$CLEANSK" "$BYTESK" "$LONGSK" "$TABLESK" "$STRAY"; }
trap cleanup EXIT

check "over-lines SKILL"  "$ROOT/$TMPSK/SKILL.md"                                   lines
check "stray plugin .md"  "$ROOT/$STRAY"                                            Non-functional
check "clean SKILL"       "$ROOT/$CLEANSK/SKILL.md"                                 none
check "over-bytes SKILL"  "$ROOT/$BYTESK/SKILL.md"                                  bytes
check "jammed line SKILL" "$ROOT/$LONGSK/SKILL.md"                                  line-length
check "long table row"    "$ROOT/$TABLESK/SKILL.md"                                 none
check "non-plugin edit"   "$ROOT/src/app.ts"                                        none
check "absolute README"   "$ROOT/plugins/debugging/README.md"                       none
check "worktree path"     "$ROOT/.claude/worktrees/foo/plugins/x/skills/y/SKILL.md" none

badex=$(printf 'not json' | bash "$GUARD" >/dev/null 2>&1; echo $?)
[ "$badex" = 0 ] && echo "PASS[bad JSON]: exit 0" || { echo "FAIL[bad JSON]: exit $badex"; rc=1; }

[ "$rc" = 0 ] && echo "ALL GUARD TESTS PASS" || echo "GUARD TESTS FAILED"
exit $rc
