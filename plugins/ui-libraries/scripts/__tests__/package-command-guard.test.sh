#!/usr/bin/env bash
# package-command-guard.test.sh — asserts hooks/package-command-guard.sh's deny / ask / silent verdict per command against throwaway package.json and lockfile fixtures under mktemp.
# Misses: the host's rendering of the verdict and real registry resolution (the payload and lockfiles are hand-built).
set -u

here=$(cd "$(dirname "$0")" && pwd)
HOOK="${1:-$here/../../hooks/package-command-guard.sh}"
[ -x "$HOOK" ] || { printf 'FAIL: %s not executable\n' "$HOOK"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not installed (the hook fails open without it)"; exit 0; }

WS=$(mktemp -d); trap 'rm -rf "$WS"' EXIT
pass=0; fail=0
verdict() { # cwd command -> deny|ask|silent|bad
  local out d
  out=$(jq -cn --arg c "$2" --arg d "$1" '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c},cwd:$d}' | "$HOOK")
  [ -z "$out" ] && { echo silent; return; }
  [ "$(printf '%s\n' "$out" | wc -l)" -eq 1 ] || { echo bad; return; }
  d=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision' 2>/dev/null)
  case "$d" in deny|ask) echo "$d" ;; *) echo bad ;; esac
}
expect() { # want label cwd command
  local got; got=$(verdict "$3" "$4")
  if [ "$got" = "$1" ]; then pass=$((pass+1)); printf 'PASS  %s\n' "$2"
  else fail=$((fail+1)); printf 'FAIL  %s (want %s, got %s)\n' "$2" "$1" "$got"; fi
}

# --- Astryx ---
mkdir -p "$WS/nocli" "$WS/dep" "$WS/devdep" "$WS/mono/packages/web"
echo '{"dependencies":{"@astryxdesign/core":"^0.7.0"}}' > "$WS/nocli/package.json"
echo '{"dependencies":{"@astryxdesign/cli":"^0.7.0"}}' > "$WS/dep/package.json"
echo '{"devDependencies":{"@astryxdesign/cli":"^0.7.0"}}' > "$WS/devdep/package.json"
echo '{"devDependencies":{"@astryxdesign/cli":"^0.7.0"}}' > "$WS/mono/package.json"
echo '{"name":"web"}' > "$WS/mono/packages/web/package.json"
expect deny   'astryx: npx astryx init, no CLI declared'                  "$WS/nocli" 'npx astryx init'
expect deny   'astryx: npx -y astryx, no CLI declared'                    "$WS/nocli" 'npx -y astryx component Button'
expect deny   'astryx: bunx astryx, no CLI declared'                      "$WS/nocli" 'bunx astryx doctor'
expect deny   'astryx: npm exec astryx, no CLI declared'                  "$WS/nocli" 'npm exec astryx -- init'
expect deny   'astryx: after a cd into the project'                       "$WS" 'cd nocli && npx astryx init'
expect silent 'astryx: npx @astryxdesign/cli (the fix itself)'            "$WS/nocli" 'npx @astryxdesign/cli init'
expect silent 'astryx: CLI in dependencies'                               "$WS/dep" 'npx astryx init'
expect silent 'astryx: CLI in devDependencies'                            "$WS/devdep" 'npx astryx template --list'
expect silent 'astryx: CLI declared at the monorepo root'                 "$WS/mono/packages/web" 'npx astryx init'
expect deny   'astryx: astryx@latest names the registry package'          "$WS/dep" 'npx astryx@latest init'
expect deny   'astryx: pnpm dlx always fetches'                           "$WS/dep" 'pnpm dlx astryx init'
expect silent 'astryx: pnpm exec runs the local bin'                      "$WS/dep" 'pnpm exec astryx init'
expect silent 'astryx: grep for the word'                                 "$WS/nocli" 'grep -rn "npx astryx" src'

# --- PrimeReact ---
mkdir -p "$WS/npm10" "$WS/npm11" "$WS/pnpm10" "$WS/yarn10" "$WS/berry10" "$WS/bun10" "$WS/nolock"
echo '{"lockfileVersion":3,"packages":{"node_modules/primereact":{"version":"10.9.9"}}}' > "$WS/npm10/package-lock.json"
echo '{"lockfileVersion":3,"packages":{"node_modules/primereact":{"version":"11.2.3"}}}' > "$WS/npm11/package-lock.json"
printf 'lockfileVersion: %s\n\npackages:\n\n  primereact@10.9.9:\n    resolution: {integrity: x}\n' "'9.0'" > "$WS/pnpm10/pnpm-lock.yaml"
printf '"@primereact/ui@^11.0.0":\n  version "11.2.3"\n\nprimereact@^10.9.0:\n  version "10.9.9"\n' > "$WS/yarn10/yarn.lock"
printf '"primereact@npm:^10.9.0":\n  version: 10.9.9\n' > "$WS/berry10/yarn.lock"
printf '{\n  "packages": {\n    "primereact": ["primereact@10.9.9", "", {}, "sha512-x"],\n  }\n}\n' > "$WS/bun10/bun.lock"
expect ask    'primereact: npm install primereact on a v10 lock'          "$WS/npm10" 'npm install primereact'
expect ask    'primereact: npm i primereact@latest'                       "$WS/npm10" 'npm i primereact@latest'
expect ask    'primereact: pnpm add primereact@11'                        "$WS/pnpm10" 'pnpm add primereact@11'
expect ask    'primereact: yarn add @primereact/ui (classic lock)'        "$WS/yarn10" 'yarn add @primereact/ui'
expect ask    'primereact: yarn add primereact@^11 (berry lock)'          "$WS/berry10" 'yarn add primereact@^11.1.0'
expect ask    'primereact: bun add @primeuix/themes@3'                    "$WS/bun10" 'bun add @primeuix/themes@3'
expect ask    'primereact: npm install @primeuix/themes bare (latest 3)'  "$WS/npm10" 'npm install @primeuix/themes'
expect silent 'primereact: pinned primereact@^10'                         "$WS/npm10" 'npm install primereact@^10'
expect silent 'primereact: primereact@v10-stable'                         "$WS/npm10" 'npm install primereact@v10-stable'
expect silent 'primereact: lock already on 11'                            "$WS/npm11" 'npm install @primereact/ui'
expect silent 'primereact: no lockfile at all'                            "$WS/nolock" 'npm install primereact'
expect silent 'primereact: an unrelated package on a v10 lock'          "$WS/yarn10" 'yarn add primeicons'
mkdir -p "$WS/scoped10"; printf '"@primereact/core@^10.0.0":\n  version "10.0.0"\n' > "$WS/scoped10/yarn.lock"
printf 'packages:\n\n  /@primereact/core@10.0.0:\n    resolution: {integrity: x}\n' > "$WS/scoped10/pnpm-lock.yaml"
expect silent 'primereact: a scoped @primereact/* 10.x entry is not primereact' "$WS/scoped10" 'npm install primereact'
expect silent 'primereact: npm ls is not an install'                      "$WS/npm10" 'npm ls primereact'
expect silent 'primereact: @primeuix/themes@^1 is not the v11 pair'       "$WS/npm10" 'npm install @primeuix/themes@^1'

out=$(printf 'not json' | "$HOOK"; echo "rc=$?")
if [ "$out" = "rc=0" ]; then pass=$((pass+1)); echo 'PASS  malformed payload: silent, exit 0'
else fail=$((fail+1)); echo "FAIL  malformed payload: $out"; fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
