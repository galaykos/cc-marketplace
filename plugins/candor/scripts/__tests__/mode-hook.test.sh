#!/usr/bin/env bash
# mode-hook.test.sh — drives hooks/mode.sh with UserPromptSubmit payloads under a sandboxed CLAUDE_CONFIG_DIR and asserts its level switching,
#   the budget line (slash-command turns included), the guards against a false switch, the /config option's rank and fail-open.
# Why, limits, history: rationale/derivations/plugin-candor.md § plugins/candor/scripts/__tests__/mode-hook.test.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
HOOK="$ROOT/plugins/candor/hooks/mode.sh"
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available"; exit 0; }
[ -f "$HOOK" ] || { echo "FAIL: $HOOK not found"; exit 1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
rc=0
# Unpinned, this harness rewrote the runner's real level file; a saved /config option must not leak in either.
export CLAUDE_CONFIG_DIR="$TMP/cfg"; mkdir -p "$CLAUDE_CONFIG_DIR"
unset CLAUDE_PLUGIN_OPTION_CC_TERSE

run() { # $1 prompt, $2 cwd  — CC_TERSE unset so the level FILE is what decides
  jq -n --arg pr "$1" --arg c "$2" \
    '{hook_event_name:"UserPromptSubmit",session_id:"t1",cwd:$c,prompt:$pr}' \
    | env -u CC_TERSE CLAUDE_PLUGIN_ROOT="$ROOT/plugins/candor" bash "$HOOK" 2>/dev/null
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

B=$(box); run "/candor:level full" "$B" >/dev/null

check "plain work prompt reinforces"            "$(run 'add a google endpoint' "$B")"                 "$BUDGET"
check "/coding-task reinforces"                 "$(run '/coding-task add a google endpoint' "$B")"    "$BUDGET"
check "namespaced slash command reinforces"     "$(run '/code-architecture:coding-task add it' "$B")" "$BUDGET"
check "another plugin's command reinforces"     "$(run '/ui-ux:build a card' "$B")"                   "$BUDGET"

C=$(box); run "/candor:level full" "$C" >/dev/null
out=$(run '/coding-task please stop being terse and go back to normal length' "$C")
check "slash args do NOT switch the level off"  "$out" "$BUDGET"
check "  …and emit no switch confirmation"      "$(printf '%s' "$out" | grep "$CONFIRM" || true)" ""
out=$(run '/coding-task make it terse ultra.' "$C")
check "slash args do NOT switch the level up"   "$(printf '%s' "$out" | grep "$CONFIRM" || true)" ""

D=$(box)
out=$(run '/candor:level ultra' "$D")
check "/candor:level switches"                   "$out" "$CONFIRM"
check "  …without doubling the budget line"     "$(printf '%s' "$out" | grep "$BUDGET" || true)" ""

E=$(box); run "/candor:level full" "$E" >/dev/null
check "negation does not switch on"             "$(printf '%s' "$(run 'never turn on terse mode' "$E")" | grep "$CONFIRM" || true)" ""
check "level word mid-sentence does not switch" "$(printf '%s' "$(run 'I prefer terse full sentences in docs' "$E")" | grep "$CONFIRM" || true)" ""
check "the hook's own line echoed back is inert" \
  "$(printf '%s' "$(run 'TERSE full — chat message only; full depth in the work.' "$E")" | grep "$CONFIRM" || true)" ""
check "plain 'terse mode off' still switches"   "$(run 'terse mode off' "$E")" "TERSE MODE OFF"

check "level off reinforces nothing"            "$(run 'add an endpoint' "$E")" ""
F=$(box)
check "no level set at all is silent"           "$(run 'add an endpoint' "$F")" ""

run_opt() { # $1 prompt, $2 cwd, $3 option value, [$4 CC_TERSE]
  jq -n --arg pr "$1" --arg c "$2" \
    '{hook_event_name:"UserPromptSubmit",session_id:"t1",cwd:$c,prompt:$pr}' \
    | if [ -n "${4:-}" ]; then env CC_TERSE="$4" CLAUDE_PLUGIN_OPTION_CC_TERSE="$3" CLAUDE_PLUGIN_ROOT="$ROOT/plugins/candor" bash "$HOOK" 2>/dev/null
      else env -u CC_TERSE CLAUDE_PLUGIN_OPTION_CC_TERSE="$3" CLAUDE_PLUGIN_ROOT="$ROOT/plugins/candor" bash "$HOOK" 2>/dev/null; fi
}
rm -f "$CLAUDE_CONFIG_DIR/terse-mode"
G=$(box)
check "option alone sets the level"             "$(run_opt 'add an endpoint' "$G" full)" "TERSE full"
printf 'lite\n' > "$CLAUDE_CONFIG_DIR/terse-mode"
check "level file beats the option"             "$(run_opt 'add an endpoint' "$G" full)" "TERSE lite"
check "level off names the option still holding it" "$(run_opt '/candor:level off' "$G" full)" "cc_terse keeps it active at full"
check "level off names CC_TERSE before the option" "$(run_opt '/candor:level off' "$G" full ultra)" "CC_TERSE=ultra"
for nl in newcomer:lite expert:full on-call:ultra; do
  n=${nl%%:*} l=${nl#*:}
  check "level off names reader $n held by CC_TERSE, with its length" "$(run_opt '/candor:level off' "$G" '' "$n")" \
    "CC_TERSE=$n is set in the environment and overrides it — still active at $n ($l)."
  check "level off names reader $n held by the option, with its length" "$(run_opt '/candor:level off' "$G" "$n")" \
    "cc_terse keeps it active at $n ($l)."
done

ctx() { jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null; }
session() { printf '{"hook_event_name":"SessionStart","source":"startup"}' \
  | env -u CC_TERSE CLAUDE_PLUGIN_ROOT="$ROOT/plugins/candor" bash "$ROOT/plugins/candor/hooks/activate.sh" 2>/dev/null; }
eq() { # $1 label, $2 got, $3 want
  [ "$2" = "$3" ] && { echo "PASS: $1"; return; }
  echo "FAIL: $1 — want '$3', got '${2:-<empty>}'"; rc=1
}
lvlfile() { cat "$CLAUDE_CONFIG_DIR/terse-mode" 2>/dev/null || echo '<absent>'; }

R=$(box)
while IFS='|' read -r name len budgets jargon cap; do
  rm -f "$CLAUDE_CONFIG_DIR/terse-mode"
  conf=$(run "/candor:level $name" "$R" | ctx)
  line=$(printf '%s\n' "$conf" | grep '^Reader ')
  eq    "$name: the level file stores the reader name"     "$(lvlfile)" "$name"
  check "$name: the switch names its length level"         "$conf" "TERSE MODE — level: $name ($len). Applies"
  check "$name: the switch carries the contract card"      "$conf" "## Contract"
  check "$name: the reader line carries the word rule"     "$line" "Reader $name: $jargon"
  check "$name: …and the cap, none on deliverable findings" "$line" "Lists and findings $cap (no cap when findings are the deliverable)."
  turn=$(run 'add an endpoint' "$R" | ctx)
  check "$name: each prompt names its length level"        "$turn" "TERSE $name ($len) — chat message only"
  check "$name: …with that level's budgets"                "$turn" "$budgets prose lines"
  eq    "$name: …and the same reader line, last"           "$(printf '%s\n' "$turn" | tail -1)" "$line"
  check "$name: SessionStart names its length level"       "$(session | head -1)" "level: $name ($len). Applies"
  eq    "$name: SessionStart injects the same reader line" "$(session | grep '^Reader ')" "$line"
done <<'EOF'
newcomer|lite|answer 10, report 18|explain in plain words, at first use, any plugin or project term a newcomer would not know|≤ 5
expert|full|answer 6, report 12|jargon allowed|≤ 8
on-call|ultra|answer 3, report 6|plain words only: no abbreviations, arrows or internal terms; this replaces ultra's word layer|≤ 3
EOF

rm -f "$CLAUDE_CONFIG_DIR/terse-mode"
conf=$(run '/candor:level full' "$R" | ctx)
check "control full: the switch names no length level"   "$conf" "TERSE MODE — level: full. Applies"
check "control full: …and adds no reader line"           "$(printf '%s\n' "$conf" | grep '^Reader ' || true)" ""
turn=$(run 'add an endpoint' "$R" | ctx)
check "control full: the prompt line is unchanged"       "$turn" "TERSE full — chat message only"
eq    "control full: …one line, no reader line"          "$(printf '%s\n' "$turn" | wc -l | tr -d ' ')" 1
check "control full: SessionStart adds no reader line"   "$(session | grep '^Reader ' || true)" ""

rm -f "$CLAUDE_CONFIG_DIR/terse-mode"
check "an unknown name switches nothing"                 "$(run '/candor:level newbie' "$R")" ""
eq    "  …and writes no level file"                      "$(lvlfile)" "<absent>"
printf 'newbie\n' > "$CLAUDE_CONFIG_DIR/terse-mode"
check "an unknown name in the level file is off"         "$(run 'add an endpoint' "$R")" ""
check "  …and SessionStart says nothing"                 "$(session)" ""

run '/candor:level on-call' "$R" >/dev/null
check "/candor:level off clears a reader name"           "$(run '/candor:level off' "$R" | ctx)" "TERSE MODE OFF"
eq    "  …and removes the level file"                    "$(lvlfile)" "<absent>"
check "  …and the next prompt is silent"                 "$(run 'add an endpoint' "$R")" ""

out=$(printf '' | env -u CC_TERSE CLAUDE_PLUGIN_ROOT="$ROOT/plugins/candor" bash "$HOOK" 2>/dev/null); e=$?
[ "$e" -eq 0 ] && echo "PASS: empty stdin exits 0" || { echo "FAIL: empty stdin exit $e"; rc=1; }
out=$(printf '{}' | env -u CC_TERSE CLAUDE_PLUGIN_ROOT="$ROOT/plugins/candor" bash "$HOOK" 2>/dev/null); e=$?
[ "$e" -eq 0 ] && [ -z "$out" ] && echo "PASS: empty JSON is silent, exits 0" \
  || { echo "FAIL: empty JSON (exit $e, out '$out')"; rc=1; }

[ "$rc" -eq 0 ] && echo "mode-hook.test: all assertions passed"
exit "$rc"
