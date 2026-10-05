#!/usr/bin/env bash
# route-prompt-pins.test.sh — pins both sides of the catalog-marker sweep age in hooks/route-prompt.sh.
set -u
unset CLAUDE_PROJECT_DIR CLAUDE_PLUGIN_DATA CC_REMIND CC_ROUTE CLAUDE_PLUGIN_OPTION_CC_REMIND CLAUDE_PLUGIN_OPTION_CC_ROUTE
SR="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$SR/hooks/route-prompt.sh"
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available (the hook fails open without it)"; exit 0; }
[ -x "$HOOK" ] || { echo "FAIL: hook not executable at $HOOK"; exit 1; }

pass=0; fail=0
WS="$(mktemp -d)"; trap 'rm -rf "$WS"' EXIT
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

# Half a minute either side of 1440: BSD find rounds an age up to whole minutes once a second has passed, GNU compares it exactly.
T="$WS/tmp"; mkdir -p "$T/cc-route-catalog-1439m30s" "$T/cc-route-catalog-1440m30s" "$WS/cwd"
age_seconds "$T/cc-route-catalog-1439m30s" 86370
age_seconds "$T/cc-route-catalog-1440m30s" 86430
out=$(jq -cn --arg c "$WS/cwd" --arg tp "$WS/transcript.jsonl" \
    '{hook_event_name:"UserPromptSubmit",prompt:"build a landing page",session_id:"pins",transcript_path:$tp,cwd:$c}' \
  | TMPDIR="$T" CLAUDE_PLUGIN_ROOT="$SR" bash "$HOOK" 2>/dev/null); rc=$?
[ "$rc" -eq 0 ] && [ -n "$out" ] && [ -d "$T/cc-route-catalog-1439m30s" ]
verdict "a catalog marker 1439.5 minutes old survives the first work-shaped prompt's sweep" $?
[ ! -e "$T/cc-route-catalog-1440m30s" ]
verdict "a catalog marker 1440.5 minutes old is swept by the first work-shaped prompt" $?

printf '\nroute-prompt-pins: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
