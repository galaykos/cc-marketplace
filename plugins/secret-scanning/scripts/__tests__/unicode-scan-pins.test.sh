#!/usr/bin/env bash
# unicode-scan-pins.test.sh — pins both sides of hooks/unicode-scan.sh's one-shot marker sweep age and of its per-call Bash target cap.
set -u
HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/unicode-scan.sh"
command -v jq >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1 \
  || { echo "SKIP: jq and python3 are required (the hook fails open without them)"; exit 0; }
unset CLAUDE_PROJECT_DIR CC_UNICODE_SCAN CC_REMIND CLAUDE_PLUGIN_OPTION_CC_UNICODE_SCAN CLAUDE_PLUGIN_OPTION_CC_REMIND
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
export TMPDIR="$T/tmp"; mkdir -p "$TMPDIR"
pass=0; fail=0
verdict() { # label status
  if [ "$2" -eq 0 ]; then pass=$((pass+1)); printf 'PASS  %s\n' "$1"
  else fail=$((fail+1)); printf 'FAIL  %s\n' "$1"; fi
}

age_minutes() { # path minutes [seconds]
  local e s
  e=$(( $(date +%s) - $2 * 60 - ${3:-0} ))
  s=$(date -r "$e" +%Y%m%d%H%M.%S 2>/dev/null) || s=$(date -d "@$e" +%Y%m%d%H%M.%S)
  touch -t "$s" "$1"
}

# BSD find rounds a -mmin age up to whole minutes, GNU find compares it exactly: only a marker 30 s off a minute separates ±1 under both.
mkdir "$TMPDIR/cc-unicode-1439" "$TMPDIR/cc-unicode-1439m30s" "$TMPDIR/cc-unicode-1440m30s" "$TMPDIR/cc-unicode-1441"
age_minutes "$TMPDIR/cc-unicode-1439" 1439
age_minutes "$TMPDIR/cc-unicode-1439m30s" 1439 30
age_minutes "$TMPDIR/cc-unicode-1440m30s" 1440 30
age_minutes "$TMPDIR/cc-unicode-1441" 1441
printf 'const a = 1;\n' > "$T/clean.ts"
printf '{"session_id":"sweep","transcript_path":"/tmp/sweep","tool_name":"Read","tool_input":{"file_path":"%s"}}' "$T/clean.ts" \
  | bash "$HOOK" >/dev/null 2>&1
[ -d "$TMPDIR/cc-unicode-1439" ]; verdict "marker sweep: a marker 1439 minutes old survives a scan" $?
[ -d "$TMPDIR/cc-unicode-1439m30s" ]; verdict "marker sweep: a marker 1439m30s old survives a scan" $?
[ ! -e "$TMPDIR/cc-unicode-1440m30s" ]; verdict "marker sweep: a marker 1440m30s old is swept by a scan" $?
[ ! -e "$TMPDIR/cc-unicode-1441" ]; verdict "marker sweep: a marker 1441 minutes old is swept by a scan" $?

R="$T/repo"; mkdir -p "$R"; git -C "$R" init -q 2>/dev/null
printf 'const b\xe2\x80\x8b = 2;\n' > "$R/hit.ts"   # U+200B
writes() { # count -> a command writing count-1 clean files, then hit.ts
  local i cmd=""
  for ((i = 1; i < $1; i++)); do : > "$R/c$i.ts"; cmd="${cmd}echo x > c$i.ts; "; done
  printf '%secho x > hit.ts' "$cmd"
}
bashfire() { # command session
  jq -cn --arg c "$1" --arg d "$R" --arg s "$2" \
    '{session_id:$s, transcript_path:("/tmp/"+$s), tool_name:"Bash", cwd:$d, tool_input:{command:$c}}' | bash "$HOOK" 2>/dev/null
}
out=$(bashfire "$(writes 8)" eighth)
case "$out" in *ZERO-WIDTH*hit.ts*|*hit.ts*ZERO-WIDTH*) true ;; *) false ;; esac
verdict "target cap: the 8th file one Bash call writes is scanned" $?
out=$(bashfire "$(writes 9)" ninth)
[ -z "$out" ]; verdict "target cap: the 9th file one Bash call writes is not scanned" $?

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
