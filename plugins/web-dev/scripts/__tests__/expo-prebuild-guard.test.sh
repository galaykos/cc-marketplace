#!/usr/bin/env bash
# expo-prebuild-guard.test.sh — asserts hooks/expo-prebuild-guard.sh asks or stays silent per command and per ios/android git state, in throwaway repos under mktemp.
# Misses: a real Expo project and the host's rendering of the ask (the payload is hand-built).
set -u

here=$(cd "$(dirname "$0")" && pwd)
HOOK="${1:-$here/../../hooks/expo-prebuild-guard.sh}"
[ -x "$HOOK" ] || { printf 'FAIL: %s not executable\n' "$HOOK"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not installed (the hook fails open without it)"; exit 0; }
command -v git >/dev/null 2>&1 || { echo "SKIP: git not installed"; exit 0; }

WS=$(mktemp -d); trap 'rm -rf "$WS"' EXIT
pass=0; fail=0
G() { git -C "$1" -c user.email=t@t -c user.name=t -c commit.gpgsign=false "${@:2}" >/dev/null 2>&1; }

verdict() { # cwd command -> ask|silent|bad
  local out
  out=$(jq -cn --arg c "$2" --arg d "$1" '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c},cwd:$d}' | "$HOOK")
  if [ -z "$out" ]; then echo silent
  elif [ "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision' 2>/dev/null)" = ask ] && [ "$(printf '%s\n' "$out" | wc -l)" -eq 1 ]; then echo ask
  else echo bad; fi
}
expect() { # want label cwd command
  local got; got=$(verdict "$3" "$4")
  if [ "$got" = "$1" ]; then pass=$((pass+1)); printf 'PASS  %s\n' "$2"
  else fail=$((fail+1)); printf 'FAIL  %s (want %s, got %s)\n' "$2" "$1" "$got"; fi
}
mkproj() { # name expo-range -> dir with package.json and ios/ + android/
  local d="$WS/$1"; mkdir -p "$d/ios" "$d/android"
  printf '{"dependencies":{"expo":"%s"}}\n' "$2" > "$d/package.json"
  echo plist > "$d/ios/Info.plist"; echo gradle > "$d/android/build.gradle"
  printf '%s' "$d"
}

# Bare: native dirs committed, not ignored.
bare=$(mkproj bare '~57.0.0'); G "$bare" init -q; G "$bare" add -A; G "$bare" commit -qm init
expect ask    'bare, committed native dirs: npx expo prebuild'            "$bare" 'npx expo prebuild'
expect ask    'bare: --clean asks too'                                    "$bare" 'npx expo prebuild --clean'
expect silent 'bare: --no-clean stays silent'                             "$bare" 'npx expo prebuild --no-clean'
expect ask    'bare: bunx runner'                                         "$bare" 'bunx expo prebuild'
expect ask    'bare: after a cd from the parent'                          "$WS" 'cd bare && npx expo prebuild'
expect silent 'bare: expo install is not prebuild'                        "$bare" 'npx expo install expo-camera'
expect silent 'bare: npm run prebuild (wrapper, a stated miss)'           "$bare" 'npm run prebuild'
expect silent 'bare: echo of the word'                                    "$bare" 'echo prebuild'

# CNG: native dirs gitignored and untracked.
cng=$(mkproj cng '~57.0.0'); printf 'ios/\nandroid/\n' > "$cng/.gitignore"; G "$cng" init -q; G "$cng" add -A; G "$cng" commit -qm init
expect silent 'CNG, ignored native dirs: npx expo prebuild'               "$cng" 'npx expo prebuild'

# Tracked AND ignored: clean is silent, a modification asks.
ti=$(mkproj ti '~57.0.0'); G "$ti" init -q; G "$ti" add -A; G "$ti" commit -qm init
printf 'ios/\nandroid/\n' > "$ti/.gitignore"; G "$ti" add .gitignore; G "$ti" commit -qm ignore
expect silent 'tracked+ignored, clean'                                    "$ti" 'npx expo prebuild'
echo edit >> "$ti/ios/Info.plist"
expect ask    'tracked+ignored, an uncommitted edit under ios/'           "$ti" 'npx expo prebuild'
expect silent '--platform android leaves the dirty ios/ alone'            "$ti" 'npx expo prebuild --platform android'

# Untracked, not ignored.
un=$(mkproj un '~57.0.0'); G "$un" init -q
expect ask    'untracked, not ignored native files'                       "$un" 'npx expo prebuild'

# SDK below 57: bare prebuild layers onto existing files.
old=$(mkproj old '~56.0.0'); G "$old" init -q; G "$old" add -A; G "$old" commit -qm init
expect silent 'SDK 56: bare prebuild does not clean'                      "$old" 'npx expo prebuild'
expect ask    'SDK 56: --clean does'                                      "$old" 'npx expo prebuild --clean'

# Outside git.
ng=$(mkproj nogit '~57.0.0')
expect ask    'not a git checkout, native dirs exist'                     "$ng" 'npx expo prebuild'
mkdir -p "$WS/empty"; printf '{"dependencies":{"expo":"~57.0.0"}}\n' > "$WS/empty/package.json"
expect silent 'no ios/ or android/ to lose'                               "$WS/empty" 'npx expo prebuild'

# Fail open on a malformed payload.
out=$(printf 'not json' | "$HOOK"; echo "rc=$?")
if [ "$out" = "rc=0" ]; then pass=$((pass+1)); echo 'PASS  malformed payload: silent, exit 0'
else fail=$((fail+1)); echo "FAIL  malformed payload: $out"; fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
