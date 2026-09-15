#!/usr/bin/env bash
# Fixture tests for hooks/spawn-cap.sh — the subagent dispatch budget.
set -u
HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/spawn-cap.sh"
BASH_BIN="${BASH:-bash}"
pass=0; fail=0
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
export TMPDIR="$T"

ok()  { pass=$((pass+1)); printf 'PASS  %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL  %s\n      %s\n' "$1" "$2"; }

fire() { # session tool
  printf '{"session_id":"%s","tool_name":"%s","tool_input":{}}' "$1" "${2:-Agent}" | "$BASH_BIN" "$HOOK" 2>/dev/null
}

# Dispatch 1..19 must be silent; 20 asks; 21..39 silent; 40 asks.
asked=""
for i in $(seq 1 41); do
  out=$(fire cap-a)
  [ -n "$out" ] && asked="$asked $i"
done
[ "$asked" = " 20 40" ] && ok "asks at the cap and at each doubling, silent between (got:$asked)" \
  || bad "asks at cap then doublings" "expected ' 20 40', got '$asked'"

# The ask is an ask, never a deny — a large fan-out is sometimes right.
out=$(for i in $(seq 1 20); do fire cap-b; done | tail -1)
case "$out" in
  *'"permissionDecision":"ask"'*) ok "the verdict is ask, not deny" ;;
  *) bad "the verdict is ask, not deny" "got: ${out:-<silent>}" ;;
esac
case "$out" in
  *deny*) bad "never emits deny" "$out" ;;
  *) ok "never emits deny" ;;
esac

# The reason names the count, so the user can judge the number rather than the rule.
case "$out" in
  *"dispatch #20"*) ok "the reason names the dispatch number" ;;
  *) bad "the reason names the dispatch number" "got: $out" ;;
esac

# Sessions are counted independently.
out=$(fire cap-c); [ -z "$out" ] && ok "a fresh session starts at zero" || bad "a fresh session starts at zero" "$out"

# CC_SPAWN_CAP moves the threshold.
asked=""
for i in $(seq 1 6); do
  out=$(CC_SPAWN_CAP=3 fire cap-d)
  [ -n "$out" ] && asked="$asked $i"
done
[ "$asked" = " 3 6" ] && ok "CC_SPAWN_CAP=3 asks at 3 and 6" || bad "CC_SPAWN_CAP moves the threshold" "got '$asked'"

out=$(CC_SPAWN_CAP=off fire cap-e)
[ -z "$out" ] && ok "CC_SPAWN_CAP=off disables it" || bad "CC_SPAWN_CAP=off disables it" "$out"

# Tools that are not a dispatch never count.
for i in $(seq 1 30); do fire cap-f Bash >/dev/null; done
out=$(fire cap-f Bash)
[ -z "$out" ] && ok "a non-dispatch tool never counts toward the cap" || bad "non-dispatch tool ignored" "$out"

# Task is the same thing as Agent for this purpose.
asked=""
for i in $(seq 1 20); do out=$(fire cap-g Task); [ -n "$out" ] && asked="$asked $i"; done
[ "$asked" = " 20" ] && ok "Task counts alongside Agent" || bad "Task counts alongside Agent" "got '$asked'"

# fail-open
out=$(printf 'garbage' | "$BASH_BIN" "$HOOK" 2>/dev/null); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok "fail-open on malformed input" || bad "fail-open on malformed input" "rc=$rc out=$out"
out=$(printf '{"tool_name":"Agent"}' | "$BASH_BIN" "$HOOK" 2>/dev/null); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok "fail-open with no session id" || bad "fail-open with no session id" "rc=$rc out=$out"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
