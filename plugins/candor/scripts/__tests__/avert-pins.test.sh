#!/usr/bin/env bash
# avert-pins.test.sh — pins both sides of the once-per-term marker sweep age in hooks/avert.sh.
set -u
HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/avert.sh"
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available (the hook fails open without it)"; exit 0; }
unset CC_AVERT CLAUDE_PLUGIN_OPTION_CC_AVERT
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
export TMPDIR="$T/tmp"; mkdir -p "$TMPDIR"
pass=0; fail=0
verdict() { # label status
  if [ "$2" -eq 0 ]; then pass=$((pass+1)); printf 'PASS  %s\n' "$1"
  else fail=$((fail+1)); printf 'FAIL  %s\n' "$1"; fi
}

age_seconds() { # path seconds
  local e s
  e=$(( $(date +%s) - $2 ))
  s=$(date -r "$e" +%Y%m%d%H%M.%S 2>/dev/null) || s=$(date -d "@$e" +%Y%m%d%H%M.%S)
  touch -t "$s" "$1"
}

# GNU find compares the exact -mmin age, BSD rounds it up to whole minutes: 30 s off each side, 1439, 1440 and 1441 all answer differently.
mkdir "$TMPDIR/cc-avert-1439m30s" "$TMPDIR/cc-avert-1440m30s"
age_seconds "$TMPDIR/cc-avert-1439m30s" $(( 1439 * 60 + 30 ))
age_seconds "$TMPDIR/cc-avert-1440m30s" $(( 1440 * 60 + 30 ))
jq -cn '{hook_event_name:"PreToolUse", session_id:"sweep", transcript_path:"/nowhere/sweep.jsonl", tool_name:"Agent", tool_input:{prompt:"draw original mascots"}}' \
  | bash "$HOOK" >/dev/null 2>&1
[ -d "$TMPDIR/cc-avert-1439m30s" ]; verdict "marker sweep: an avert marker 1439m30s old survives the next ask" $?
[ ! -e "$TMPDIR/cc-avert-1440m30s" ]; verdict "marker sweep: an avert marker 1440m30s old is swept by the next ask" $?

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
