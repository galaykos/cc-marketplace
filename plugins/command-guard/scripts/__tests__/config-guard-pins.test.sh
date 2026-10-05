#!/usr/bin/env bash
# config-guard-pins.test.sh — pins both sides of hooks/config-guard.sh's per-call Bash target cap.
set -u
HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/config-guard.sh"
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq is required (the hook fails open without it)"; exit 0; }
unset CC_CONFIG_GUARD CLAUDE_DESTRUCTIVE_GUARD CLAUDE_PLUGIN_OPTION_CC_CONFIG_GUARD CLAUDE_PLUGIN_OPTION_CLAUDE_DESTRUCTIVE_GUARD
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
pass=0; fail=0
verdict() { # label status
  if [ "$2" -eq 0 ]; then pass=$((pass+1)); printf 'PASS  %s\n' "$1"
  else fail=$((fail+1)); printf 'FAIL  %s\n' "$1"; fi
}

printf '{}\n' > "$T/tsconfig.json"
writes() { # count -> a command writing count-1 plain files, then tsconfig.json
  local i cmd=""
  for ((i = 1; i < $1; i++)); do printf 'x\n' > "$T/n$i.txt"; cmd="${cmd}echo x > n$i.txt; "; done
  printf '%secho {} > tsconfig.json' "$cmd"
}
bashfire() { # command
  jq -cn --arg c "$1" --arg d "$T" '{session_id:"cg", cwd:$d, tool_name:"Bash", tool_input:{command:$c}}' | bash "$HOOK" 2>/dev/null
}
out=$(bashfire "$(writes 8)")
case "$out" in *'"permissionDecision":"ask"'*'(`tsconfig.json`)'*) true ;; *) false ;; esac
verdict "target cap: the 8th file one Bash call writes is asked about" $?
out=$(bashfire "$(writes 9)")
[ -z "$out" ]; verdict "target cap: the 9th file one Bash call writes is not read" $?

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
