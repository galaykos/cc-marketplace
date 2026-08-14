#!/usr/bin/env bash
# Smoke tests for terse/hooks/mode.sh — the UserPromptSubmit hook that owns both level
# SWITCHING and the per-turn budget reinforcement.
#
# WHY THIS FILE EXISTS. The hook shipped with zero coverage and its own comments record
# at least three past regressions in the trigger logic: a guard that swallowed the
# documented `terse mode off` request, a level word matched out of the middle of an
# ordinary sentence ("I prefer terse full sentences"), and a negated prompt ("never turn
# on terse") switching the mode ON. Each was found by hand. A 168-line hook with that
# history and no fixtures is the recorded-masquerading-as-gate shape CLAUDE.md's
# has-teeth convention warns about.
#
# The immediate cause is the slash-command branch: `/*) exit 0` disqualified a slash
# prompt from switching AND from reinforcement, so every slash-command turn silently
# lost the budget line. Both halves are asserted here, in both directions — the fix
# would be trivially "achieved" by deleting the branch, which cases 4 and 5 then fail.
#
# Picked up by the CI step that globs plugins/*/scripts/__tests__/*.test.sh, so it is
# enforced from the moment it lands.
set -u
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
HOOK="$ROOT/plugins/terse/hooks/mode.sh"
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available"; exit 0; }
[ -f "$HOOK" ] || { echo "FAIL: $HOOK not found"; exit 1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
rc=0

run() { # $1 prompt, $2 cwd  — CC_TERSE unset so the level FILE is what decides
  jq -n --arg pr "$1" --arg c "$2" \
    '{hook_event_name:"UserPromptSubmit",session_id:"t1",cwd:$c,prompt:$pr}' \
    | env -u CC_TERSE CLAUDE_PLUGIN_ROOT="$ROOT/plugins/terse" bash "$HOOK" 2>/dev/null
}
box() { d="$TMP/b$RANDOM$RANDOM"; mkdir -p "$d/.claude"; printf '%s\n' "$d"; }

has()  { case "$2" in *"$1"*) return 0 ;; esac; return 1; }
check(){ # $1 label, $2 out, $3 want-substring ('' = must be silent)
  if [ -n "$3" ]; then has "$3" "$2" && { echo "PASS: $1"; return; }
  else [ -z "$2" ] && { echo "PASS: $1"; return; }; fi
  echo "FAIL: $1 — got: ${2:-<silent>}"; rc=1
}

BUDGET='chat message only'
CONFIRM='TERSE MODE — level'

# A level must be active for § 3 to have anything to reinforce.
B=$(box); run "/terse:level full" "$B" >/dev/null

# ---- 1-3. the fix: reinforcement survives a slash command ---------------------
check "plain work prompt reinforces"            "$(run 'add a google endpoint' "$B")"                 "$BUDGET"
check "/coding-task reinforces"                 "$(run '/coding-task add a google endpoint' "$B")"    "$BUDGET"
check "namespaced slash command reinforces"     "$(run '/code-architecture:coding-task add it' "$B")" "$BUDGET"
check "another plugin's command reinforces"     "$(run '/ui-ux:build a card' "$B")"                   "$BUDGET"

# ---- 4-5. and switching is still disqualified inside a slash command ----------
# These are what stop the fix from being "delete the branch". A slash command's
# ARGUMENTS are a task description; they must never move the mode.
C=$(box); run "/terse:level full" "$C" >/dev/null
out=$(run '/coding-task please stop being terse and go back to normal length' "$C")
check "slash args do NOT switch the level off"  "$out" "$BUDGET"
check "  …and emit no switch confirmation"      "$(printf '%s' "$out" | grep "$CONFIRM" || true)" ""
out=$(run '/coding-task make it terse ultra.' "$C")
check "slash args do NOT switch the level up"   "$(printf '%s' "$out" | grep "$CONFIRM" || true)" ""

# ---- 6. an explicit /terse:level still switches, and does NOT also reinforce --
D=$(box)
out=$(run '/terse:level ultra' "$D")
check "/terse:level switches"                   "$out" "$CONFIRM"
check "  …without doubling the budget line"     "$(printf '%s' "$out" | grep "$BUDGET" || true)" ""

# ---- 7-9. the guards the hook's own comments say regressed before ------------
E=$(box); run "/terse:level full" "$E" >/dev/null
check "negation does not switch on"             "$(printf '%s' "$(run 'never turn on terse mode' "$E")" | grep "$CONFIRM" || true)" ""
check "level word mid-sentence does not switch" "$(printf '%s' "$(run 'I prefer terse full sentences in docs' "$E")" | grep "$CONFIRM" || true)" ""
check "the hook's own line echoed back is inert" \
  "$(printf '%s' "$(run 'TERSE full — chat message only; full depth in the work.' "$E")" | grep "$CONFIRM" || true)" ""
check "plain 'terse mode off' still switches"   "$(run 'terse mode off' "$E")" "TERSE MODE OFF"

# ---- 10. off / unset means silence -------------------------------------------
check "level off reinforces nothing"            "$(run 'add an endpoint' "$E")" ""
F=$(box)
check "no level set at all is silent"           "$(run 'add an endpoint' "$F")" ""

# ---- 11. fail-open ------------------------------------------------------------
out=$(printf '' | env -u CC_TERSE CLAUDE_PLUGIN_ROOT="$ROOT/plugins/terse" bash "$HOOK" 2>/dev/null); e=$?
[ "$e" -eq 0 ] && echo "PASS: empty stdin exits 0" || { echo "FAIL: empty stdin exit $e"; rc=1; }
out=$(printf '{}' | env -u CC_TERSE CLAUDE_PLUGIN_ROOT="$ROOT/plugins/terse" bash "$HOOK" 2>/dev/null); e=$?
[ "$e" -eq 0 ] && [ -z "$out" ] && echo "PASS: empty JSON is silent, exits 0" \
  || { echo "FAIL: empty JSON (exit $e, out '$out')"; rc=1; }

[ "$rc" -eq 0 ] && echo "mode-hook.test: all assertions passed"
exit "$rc"
