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

check() { # $1 desc  $2 file_path  $3 want: budget|doc-location|none
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
{ echo '---'; echo 'name: _guardtest'; echo 'description: Use when testing the guard budget path with an over-length body.'; echo '---'; echo; for i in $(seq 1 170); do echo "l$i"; done; } > "$TMPSK/SKILL.md"
CLEANSK="plugins/debugging/skills/_guardclean"; mkdir -p "$CLEANSK"
{ echo '---'; echo 'name: _guardclean'; echo 'description: Use when testing the guard with an in-budget body that stays clean.'; echo '---'; echo; for i in $(seq 1 110); do echo "l$i"; done; } > "$CLEANSK/SKILL.md"
STRAY="plugins/debugging/_guardstray.md"; echo "# stray" > "$STRAY"
cleanup() { rm -rf "$TMPSK" "$CLEANSK" "$STRAY"; }
trap cleanup EXIT

check "over-budget SKILL" "$ROOT/$TMPSK/SKILL.md"                                   budget
check "stray plugin .md"  "$ROOT/$STRAY"                                            Non-functional
check "clean SKILL"       "$ROOT/$CLEANSK/SKILL.md"                                 none
check "non-plugin edit"   "$ROOT/src/app.ts"                                        none
check "absolute README"   "$ROOT/plugins/debugging/README.md"                       none
check "worktree path"     "$ROOT/.claude/worktrees/foo/plugins/x/skills/y/SKILL.md" none

badex=$(printf 'not json' | bash "$GUARD" >/dev/null 2>&1; echo $?)
[ "$badex" = 0 ] && echo "PASS[bad JSON]: exit 0" || { echo "FAIL[bad JSON]: exit $badex"; rc=1; }

[ "$rc" = 0 ] && echo "ALL GUARD TESTS PASS" || echo "GUARD TESTS FAILED"
exit $rc
