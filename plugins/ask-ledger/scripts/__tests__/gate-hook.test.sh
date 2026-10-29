#!/usr/bin/env bash
# Smoke tests for ask-ledger/hooks/gate.sh — the Stop gate that refuses a final message
# without an accounting line per ledgered name. Branches: no ledger → silent; every name
# accounted → silent; one missing → a JSON block naming it; the three verbs all count; a
# case-insensitive match; the two-block ceiling; the off switch; fail-open; an accounted
# name is not owed by later turns unless a later prompt names it again.
set -u
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
HOOK="$ROOT/plugins/ask-ledger/hooks/gate.sh"
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available"; exit 0; }
[ -f "$HOOK" ] || { echo "FAIL: $HOOK not found"; exit 1; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export TMPDIR="$TMP"
rc=0
ledger() { # $1 session, then names
  s="$1"; shift; key=$(printf '/nowhere/%s.jsonl' "$s" | cksum | cut -d' ' -f1)
  mkdir -p "$TMP/cc-ask-ledger-$key"; printf '%s\n' "$@" > "$TMP/cc-ask-ledger-$key/entries"
}
hook() { # payload on stdin, env assignments as args → "<stderr> <reason> rc=N" on one line; a JSON block (exit 0) is rc=2, a bare exit 2 rc=exit2
  local o e r
  o=$(env "$@" bash "$HOOK" 2>"$TMP/stderr"); r=$?; e=$(cat "$TMP/stderr")
  if [ "$r" = 0 ] && [ -n "$o" ]; then
    if printf '%s' "$o" | jq -e '.decision=="block" and (.reason|length>0) and (.systemMessage|length>0)' >/dev/null 2>&1; then
      r=2; e="$e${e:+
}$(printf '%s' "$o" | jq -r .reason)"
    else r=stdout; fi
  elif [ "$r" = 2 ]; then r=exit2; fi
  printf '%s%src=%s' "$e" "${e:+
}" "$r" | tr '\n' ' '
}
run() { # $1 session, $2 final message → "<stderr> <reason> rc=N"
  jq -n --arg s "$1" --arg m "$2" '{hook_event_name:"Stop",session_id:$s,transcript_path:("/nowhere/"+$s+".jsonl"),stop_hook_active:false,last_assistant_message:$m}' \
    | hook -u CC_ASK_LEDGER
}
check(){ case "$2" in *"$3"*) echo "PASS: $1";; *) echo "FAIL: $1 — got: $2"; rc=1;; esac; }
is(){ if [ "$2" = "$3" ]; then echo "PASS: $1"; else echo "FAIL: $1 — got: $2 want: $3"; rc=1; fi; }
prompt() { # $1 session, $2 prompt → runs ledger.sh as the UserPromptSubmit before a Stop
  jq -n --arg s "$1" --arg pr "$2" '{hook_event_name:"UserPromptSubmit",session_id:$s,transcript_path:("/nowhere/"+$s+".jsonl"),cwd:"/tmp",prompt:$pr}' \
    | env -u CC_ASK_LEDGER bash "$ROOT/plugins/ask-ledger/hooks/ledger.sh" >/dev/null 2>&1
}

check "1 no ledger: silent" "$(run s0 'done')" "rc=0"
ledger s1 Laravel "2D Sprites" Digimon
check "2 all accounted: silent" "$(run s1 $'Laravel: as named\n2D Sprites: as named\nDigimon: substituted → invented mascots, my hedge, not asked')" "rc=0"
ledger s1b Laravel "2D Sprites" Digimon
r=$(run s1b $'Laravel: as named\n2D Sprites: as named')
check "3 one missing blocks (JSON decision on stdout, exit 0)" "$r" "rc=2"
ledger s1d Laravel Digimon
sm=$(jq -n '{hook_event_name:"Stop",session_id:"s1d",transcript_path:"/nowhere/s1d.jsonl",stop_hook_active:false,last_assistant_message:"Laravel: as named"}' \
  | env -u CC_ASK_LEDGER bash "$HOOK" 2>/dev/null | jq -r .systemMessage)
is "3b the block tells the person why in one plain line" "$sm" "ask-ledger sent the turn back: the reply does not say what happened to Digimon."
check "4 the block names the missing entry" "$r" "what happened to Digimon"
check "4b the block asks for the answer's verdict before the name lines" "$r" "Restate the answer's one-line verdict first, then one line per name"
ledger s1c Laravel "2D Sprites" Digimon
check "5 omitted counts, case-insensitive" "$(run s1c $'laravel: OMITTED → out of scope\n2d sprites: as named\ndigimon: as named')" "rc=0"
ledger s2 Stripe
run s2 'no accounting' >/dev/null; run s2 'still none' >/dev/null
check "6 third stop after two blocks ends the turn with a warning" "$(run s2 'still none')" "rc=0"
is "6b the names a give-up warned about are not warned about again next turn" "$(run s2 'a later turn')" "rc=0"
out=$(jq -n '{hook_event_name:"Stop",session_id:"s3",transcript_path:"/nowhere/s3.jsonl",last_assistant_message:"x"}' | hook CC_ASK_LEDGER=off)
check "7 CC_ASK_LEDGER=off is silent" "$out" "rc=0"
out=$(printf 'not json' | hook)
check "8 malformed payload fails open" "$out" "rc=0"
ledger s4 React
T="$TMP/s4.jsonl"; printf '%s\n' '{"type":"assistant","uuid":"a1","message":{"role":"assistant","content":[{"type":"text","text":"working"}]}}' '{"type":"assistant","uuid":"a2","message":{"role":"assistant","content":[{"type":"text","text":"React: as named"}]}}' > "$T"
out=$(jq -n --arg t "$T" '{hook_event_name:"Stop",session_id:"s4",transcript_path:$t}' | hook -u CC_ASK_LEDGER)
check "9 without last_assistant_message the transcript's final assistant text is read" "$out" "rc=0"

# --- 10-12 an accounted name is settled (2026-10-08). The ledger was session-cumulative, so
#     `Iinstalled`, accounted `as named` in the turn that named it, was demanded again at the
#     end of later turns ("PR + Merge", "resume the survey") and blocked two of them. ---
ledger s10 Iinstalled
is "10a the turn that names it accounts for it" "$(run s10 'Iinstalled: as named — prompt-coach 0.1.0')" "rc=0"
is "10b a later turn that never named it owes no line" "$(run s10 'Merged; CI green.')" "rc=0"
ledger s11 Laravel Digimon
r=$(run s11 'Laravel: as named')
check "11a a partial accounting blocks on the missing name only" "$r" "what happened to Digimon, which"
is "11b the retry owes only the names the block listed" "$(run s11 'Digimon: substituted → invented mascots, my hedge')" "rc=0"
prompt s12 'build a Stripe checkout'
is "12a a prompt-ledgered name accounted in its turn passes" "$(run s12 'Stripe: as named')" "rc=0"
prompt s12 'check if CI is done and merge'
is "12b the next turn owes nothing" "$(run s12 'Merged.')" "rc=0"
prompt s12 'now add Stripe refunds to the checkout'
check "12c a later prompt that names it again owes it again" "$(run s12 'Refunds added.')" "what happened to Stripe, which"
exit $rc
