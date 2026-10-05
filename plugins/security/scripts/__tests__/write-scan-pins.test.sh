#!/usr/bin/env bash
# write-scan-pins.test.sh — pins both sides of hooks/write-scan.sh's one-shot marker sweep age and of its per-call Bash target cap.
set -u
HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/write-scan.sh"
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq is required (the hook fails open without it)"; exit 0; }
unset CC_SECURITY_SCAN CC_REMIND CLAUDE_PLUGIN_OPTION_CC_SECURITY_SCAN CLAUDE_PLUGIN_OPTION_CC_REMIND
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
sweep_scan() {
  jq -cn --arg f "$T/clean.js" \
    '{tool_name:"Write", session_id:"sweep", transcript_path:"/tmp/sweep.jsonl", tool_input:{file_path:$f, content:"const a = 1;"}}' \
    | bash "$HOOK" >/dev/null 2>&1
}

# Half-minute ages: BSD find rounds an -mmin age up to the next whole minute, so a whole-minute fixture flips with the run's first second.
L="$TMPDIR/cc-security-scan"
mkdir -p "$L/ctx-1439m30s/marker" "$L/ctx-1440m30s/marker"
age_seconds "$L/ctx-1439m30s" $((1439 * 60 + 30))
age_seconds "$L/ctx-1440m30s" $((1440 * 60 + 30))
sweep_scan
[ -d "$L/ctx-1439m30s" ]; verdict "marker sweep: a context's markers 1439.5 minutes old survive a scan" $?
[ ! -e "$L/ctx-1440m30s" ]; verdict "marker sweep: a context's markers 1440.5 minutes old are swept by a scan" $?

O="$T/aged-root"
mkdir -p "$O/cc-security-scan/ctx-fresh/marker"
age_seconds "$O/cc-security-scan" $((2880 * 60))
TMPDIR="$O" sweep_scan
[ -d "$O/cc-security-scan/ctx-fresh/marker" ]
verdict "marker sweep: a fresh marker survives a scan when the lock root itself is past the sweep age" $?

W="$T/w"; mkdir -p "$W"
printf '%s\n' 'el.innerHTML = user.bio' > "$W/hit.js"
writes() { # count -> a command writing count-1 clean files, then hit.js
  local i cmd=""
  for ((i = 1; i < $1; i++)); do printf 'const a = 1;\n' > "$W/c$i.js"; cmd="${cmd}echo x > c$i.js; "; done
  printf '%secho x > hit.js' "$cmd"
}
bashfire() { # command session
  jq -cn --arg c "$1" --arg d "$W" --arg s "$2" \
    '{tool_name:"Bash", session_id:$s, transcript_path:("/tmp/"+$s+".jsonl"), cwd:$d, tool_input:{command:$c}}' | bash "$HOOK" 2>/dev/null
}
out=$(bashfire "$(writes 8)" eighth)
case "$out" in *raw-html-sink*hit.js*) true ;; *) false ;; esac
verdict "target cap: the 8th file one Bash call writes is scanned" $?
out=$(bashfire "$(writes 9)" ninth)
[ -z "$out" ]; verdict "target cap: the 9th file one Bash call writes is not scanned" $?

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
