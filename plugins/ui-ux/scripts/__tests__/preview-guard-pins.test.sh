#!/usr/bin/env bash
# preview-guard-pins.test.sh — pins both sides of the weak-marker sweep age in hooks/preview-guard.sh, and in taskmaster's twin when it sits beside this plugin.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available (the hook fails open without it)"; exit 0; }
unset CC_PREVIEW_GUARD CLAUDE_PLUGIN_OPTION_CC_PREVIEW_GUARD

guards=("$ROOT/hooks/preview-guard.sh")
if [ -f "$ROOT/../taskmaster/hooks/preview-guard.sh" ]; then
  guards+=("$(cd "$ROOT/../taskmaster/hooks" && pwd)/preview-guard.sh")
else
  echo "SKIP  taskmaster twin: not beside this plugin"
fi

WS="$(mktemp -d)"; trap 'rm -rf "$WS"' EXIT
mkdir -p "$WS/cwd"
pass=0; fail=0
verdict() { # label status
  if [ "$2" -eq 0 ]; then pass=$((pass+1)); printf 'PASS  %s\n' "$1"
  else fail=$((fail+1)); printf 'FAIL  %s\n' "$1"; fi
}

age_minutes() { # path minutes
  local e s
  e=$(( $(date +%s) - $2 * 60 ))
  s=$(date -r "$e" +%Y%m%d%H%M.%S 2>/dev/null) || s=$(date -d "@$e" +%Y%m%d%H%M.%S)
  touch -t "$s" "$1"
}

# GNU find compares the exact age, BSD rounds it up to whole minutes; one minute either side of 1440 holds under both.
for g in "${guards[@]}"; do
  copy=$(basename "$(dirname "$(dirname "$g")")")
  tmp="$WS/tmp-$copy"; mkdir -p "$tmp/cc-preview-weak-1439" "$tmp/cc-preview-weak-1441"
  age_minutes "$tmp/cc-preview-weak-1439" 1439
  age_minutes "$tmp/cc-preview-weak-1441" 1441
  printf '{"tool_input":{"file_path":"%s"},"cwd":"%s","session_id":"pins-%s"}' "$WS/cwd/page.html" "$WS/cwd" "$copy" \
    | TMPDIR="$tmp" bash "$g" >/dev/null 2>&1
  [ -d "$tmp/cc-preview-weak-1439" ]; verdict "$copy: a weak marker 1439 minutes old survives the first weak ask's sweep" $?
  [ ! -e "$tmp/cc-preview-weak-1441" ]; verdict "$copy: a weak marker 1441 minutes old is swept by the first weak ask" $?
done

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
