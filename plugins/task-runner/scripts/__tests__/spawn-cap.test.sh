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

# INSIDE A REGISTERED RUN (2026-10-14): the first threshold is max(cap, cards x 3) and the
# hook notifies instead of asking. An ask at #20 left an authorized run idle for 67 minutes.
unset CLAUDE_PROJECT_DIR
RUN="$T/proj"; mkdir -p "$RUN/.claude/task-runner" "$RUN/docs/tasks/demo" "$RUN/src/deep"
git init -q -b main "$RUN" 2>/dev/null && git -C "$RUN" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
{ printf '# Index\n\n| card | title | status |\n|---|---|---|\n'; for c in 01 02 03 04 05 06 07 08 09 10; do printf '| %s | t | pending |\n' "$c"; done; } > "$RUN/docs/tasks/demo/00-INDEX.md"
printf '{"slug":"demo","branch":"main","index_path":"docs/tasks/demo/00-INDEX.md"}' > "$RUN/.claude/task-runner/active-run.json"
fire_at() { # session cwd
  jq -cn --arg s "$1" --arg c "$2" '{session_id:$s,tool_name:"Agent",cwd:$c,tool_input:{}}' | "$BASH_BIN" "$HOOK" 2>/dev/null
}
said=""; last=""
for i in $(seq 1 61); do out=$(fire_at run-a "$RUN/src/deep"); [ -n "$out" ] && { said="$said $i"; last="$out"; }; done
[ "$said" = " 30 60" ] && ok "a 10-card run moves the first threshold to 30, then doubles (from a subdirectory)" \
  || bad "a 10-card run moves the first threshold to 30, then doubles" "got '$said'"
case "$last" in *'"permissionDecision"'*) bad "inside a run it notifies, never asks" "$last" ;;
  *'"systemMessage"'*'"additionalContext"'*) ok "inside a run it notifies the user and the model, never asks" ;;
  *) bad "inside a run it notifies the user and the model, never asks" "got: ${last:-<silent>}" ;; esac
case "$last" in *'registered run demo (10 cards in docs/tasks/demo/00-INDEX.md, about 30 dispatches'*) ok "the notice names the plan" ;;
  *) bad "the notice names the plan" "$last" ;; esac

# A run whose plan is below the cap keeps the cap, and still notifies.
{ printf '| card | title | status |\n|---|---|---|\n| 01 | t | done |\n| 02 | t | pending |\n'; } > "$RUN/docs/tasks/demo/00-INDEX.md"
said=""
for i in $(seq 1 20); do out=$(fire_at run-b "$RUN"); [ -n "$out" ] && said="$said $i:${out:2:13}"; done
[ "$said" = ' 20:systemMessage' ] && ok "a 2-card run keeps the cap of 20, as a notice" || bad "a 2-card run keeps the cap of 20, as a notice" "got '$said'"

# A run with no card index notifies at the cap and says so.
printf '{"slug":"inline","branch":"main"}' > "$RUN/.claude/task-runner/active-run.json"
out=$(for i in $(seq 1 20); do fire_at run-c "$RUN"; done | tail -1)
case "$out" in *'"systemMessage"'*'no card index'*) ok "an inline run notifies at the cap and says it has no plan" ;;
  *) bad "an inline run notifies at the cap and says it has no plan" "got: ${out:-<silent>}" ;; esac

# A sentinel a run left on another branch is not this branch's run: it asks.
printf '{"slug":"old","branch":"main"}' > "$RUN/.claude/task-runner/active-run.json"
git -C "$RUN" checkout -q -b other
out=$(for i in $(seq 1 20); do fire_at run-e "$RUN"; done | tail -1)
case "$out" in *'"permissionDecision":"ask"'*) ok "a run registered on another branch still asks at 20" ;;
  *) bad "a run registered on another branch still asks at 20" "got: ${out:-<silent>}" ;; esac
git -C "$RUN" checkout -q main

# A tag named like the run's branch, made after registration: --abbrev-ref printed `heads/main`,
# so the run read as another branch's and dispatch #20 asked (2026-10-15).
printf '{"slug":"tagged","branch":"main"}' > "$RUN/.claude/task-runner/active-run.json"
git -C "$RUN" tag main
out=$(for i in $(seq 1 20); do fire_at run-t "$RUN"; done | tail -1)
case "$out" in *'"systemMessage"'*'registered run tagged'*) ok "a tag named like the run's branch: still the run, it notifies at 20" ;;
  *) bad "a tag named like the run's branch: still the run, it notifies at 20" "got: ${out:-<silent>}" ;; esac
git -C "$RUN" tag -d main >/dev/null

# symbolic-ref failing with an exit other than 1 is not a detached head: the branch is unknown, the run counts.
SHIM="$T/shim"; mkdir -p "$SHIM"
printf '#!/bin/sh\nfor a in "$@"; do [ "$a" = symbolic-ref ] && exit 128; done\nexec %s "$@"\n' "$(command -v git)" > "$SHIM/git"; chmod +x "$SHIM/git"
printf '{"slug":"gitfail","branch":"main"}' > "$RUN/.claude/task-runner/active-run.json"
out=$(for i in $(seq 1 20); do PATH="$SHIM:$PATH" fire_at run-x "$RUN"; done | tail -1)
case "$out" in *'"systemMessage"'*'registered run gitfail'*) ok "symbolic-ref exiting 128: still the run, it notifies at 20" ;;
  *) bad "symbolic-ref exiting 128: still the run, it notifies at 20" "got: ${out:-<silent>}" ;; esac

# A sentinel naming no branch is this branch's run, as candor's completion clause reads it.
printf '{"slug":"nobranch"}' > "$RUN/.claude/task-runner/active-run.json"
out=$(for i in $(seq 1 20); do fire_at run-f "$RUN"; done | tail -1)
case "$out" in *'"systemMessage"'*'registered run nobranch'*) ok "a sentinel naming no branch is the current run: it notifies at 20" ;;
  *) bad "a sentinel naming no branch is the current run: it notifies at 20" "got: ${out:-<silent>}" ;; esac

# A --tracks run registered on main before its run branch existed (2026-10-15): the sentinel
# names main, so on run/tm the hook asked at #20. Registered again on the run branch, as
# /task-runner:run --tracks now orders it, the 8-card plan applies.
RR="$(cd "$(dirname "$0")/../.." && pwd)/scripts/register-run.sh"
rm -f "$RUN/.claude/task-runner/active-run.json"
{ printf '| card | title | status |\n|---|---|---|\n'; for c in 01 02 03 04 05 06 07 08; do printf '| %s | t | pending |\n' "$c"; done; } > "$RUN/docs/tasks/demo/00-INDEX.md"
(cd "$RUN" && HOME="$T/nohome" bash "$RR" --index docs/tasks/demo/00-INDEX.md >/dev/null 2>&1)
git -C "$RUN" checkout -q -b run/tm
out=$(for i in $(seq 1 20); do fire_at run-g "$RUN"; done | tail -1)
case "$out" in *'"permissionDecision":"ask"'*) ok "registered on main, then checkout -b run/tm: dispatch #20 asks" ;;
  *) bad "registered on main, then checkout -b run/tm: dispatch #20 asks" "got: ${out:-<silent>}" ;; esac
(cd "$RUN" && HOME="$T/nohome" bash "$RR" --index docs/tasks/demo/00-INDEX.md >/dev/null 2>&1)
said=""
for i in $(seq 1 24); do out=$(fire_at run-h "$RUN"); [ -n "$out" ] && said="$said $i:${out:2:13}"; done
[ "$said" = ' 24:systemMessage' ] && ok "registered again on run/tm: the 8-card plan notifies at 24" \
  || bad "registered again on run/tm: the 8-card plan notifies at 24" "got '$said'"
git -C "$RUN" checkout -q main
rm -f "$RUN/.claude/cc-phase.json"

# Outside a run, the same cwd still asks.
rm -f "$RUN/.claude/task-runner/active-run.json"
out=$(for i in $(seq 1 20); do fire_at run-d "$RUN"; done | tail -1)
case "$out" in *'"permissionDecision":"ask"'*) ok "with no registered run it still asks at 20" ;;
  *) bad "with no registered run it still asks at 20" "got: ${out:-<silent>}" ;; esac

# fail-open
out=$(printf 'garbage' | "$BASH_BIN" "$HOOK" 2>/dev/null); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok "fail-open on malformed input" || bad "fail-open on malformed input" "rc=$rc out=$out"
out=$(printf '{"tool_name":"Agent"}' | "$BASH_BIN" "$HOOK" 2>/dev/null); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok "fail-open with no session id" || bad "fail-open with no session id" "rc=$rc out=$out"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
