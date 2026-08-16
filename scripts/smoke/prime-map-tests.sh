#!/usr/bin/env bash
# Behavioural tests for skill-router/hooks/prime.sh — the SessionStart "repo-relevant
# skills" line.
#
# WHY A FIXTURE HARNESS AND NOT ONLY A GATE. pc_prime_coverage compares the skill NAMES
# prime.sh emits against coding-entry/references/skill-map.md. It cannot see the
# PREDICATE that decides when a name is emitted, so it is blind to the exact regression
# it was written for: `dep package.json '"(react|vue|@?tailwind)'` asserted
# tailwind-best-practices on any React or Vue dependency, and the map has always carried
# a tailwind row, so the gate stays green while the session's first line states a
# falsehood. A static name check can never catch that. Running the hook against fixture
# repos and asserting the emitted line can, and does.
#
# Each case asserts BOTH directions. A map that names nothing passes every must-not-name
# assertion, so every fixture that forbids a skill also requires one.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$ROOT/plugins/skill-router/hooks/prime.sh"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available (hook fails open without it)"; exit 0; }
[ -f "$HOOK" ] || { echo "FAIL: hook not found at $HOOK"; exit 1; }

pass=0; fail=0
WS="$(mktemp -d)"; trap 'rm -rf "$WS"' EXIT

emit() {
  printf '{"hook_event_name":"SessionStart","source":"startup","cwd":"%s","session_id":"prime"}' "$1" \
    | CLAUDE_PLUGIN_ROOT="$ROOT/plugins/skill-router" bash "$HOOK" 2>/dev/null
}
names()   { case "$2" in *"$3"*) pass=$((pass+1)); printf 'PASS  %s names %s\n' "$1" "$3" ;;
                        *) fail=$((fail+1)); printf 'FAIL  %s does NOT name %s\n      got: %s\n' "$1" "$3" "${2:-<nothing>}" ;; esac; }
omits()   { case "$2" in *"$3"*) fail=$((fail+1)); printf 'FAIL  %s wrongly names %s\n      got: %s\n' "$1" "$3" "$2" ;;
                        *) pass=$((pass+1)); printf 'PASS  %s omits %s\n' "$1" "$3" ;; esac; }

# A: the regression itself. React present, Tailwind absent — the emitted line must not
# claim Tailwind. Laravel and Livewire are present and must be named; php must NOT be,
# because skill-map.md declares laravel and plain-php stack-exclusive.
A="$WS/a"; mkdir -p "$A"
printf '{"require":{"php":"^8.2","laravel/framework":"^11.0","livewire/livewire":"^3.0"}}' > "$A/composer.json"
printf '{"dependencies":{"react":"^18.2.0","styled-components":"^6.1.0"}}' > "$A/package.json"
OA="$(emit "$A")"
omits "laravel+react, no tailwind:" "$OA" "tailwind-best-practices"
names "laravel+react, no tailwind:" "$OA" "laravel-best-practices"
names "laravel+react, no tailwind:" "$OA" "livewire-best-practices"
names "laravel+react, no tailwind:" "$OA" "react-server-state"
omits "laravel+react, no tailwind:" "$OA" "php-best-practices"

# B: positive control. Without it, a hook that emits nothing passes every case above.
B="$WS/b"; mkdir -p "$B"
printf '{"devDependencies":{"tailwindcss":"^3.4.0"},"dependencies":{"react":"^18.2.0"}}' > "$B/package.json"
OB="$(emit "$B")"
names "real tailwind present:" "$OB" "tailwind-best-practices"
names "real tailwind present:" "$OB" "react-server-state"

# C: the stack-exclusive rule in the other direction — php WITHOUT laravel.
C="$WS/c"; mkdir -p "$C"
printf '{"require":{"php":"^8.2","symfony/console":"^7.0"}}' > "$C/composer.json"
OC="$(emit "$C")"
names "php without laravel:" "$OC" "php-best-practices"
omits "php without laravel:" "$OC" "laravel-best-practices"

# D: an empty repo must not assert a stack at all.
D="$WS/d"; mkdir -p "$D"
OD="$(emit "$D")"
omits "empty repo:" "$OD" "laravel-best-practices"
omits "empty repo:" "$OD" "react-server-state"
omits "empty repo:" "$OD" "tailwind-best-practices"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
