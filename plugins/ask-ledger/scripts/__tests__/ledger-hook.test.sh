#!/usr/bin/env bash
# Smoke tests for ask-ledger/hooks/ledger.sh — the UserPromptSubmit hook that destructures
# a work-shaped prompt into the things it names and keeps a session ledger. Each case is a
# branch a one-character edit could remove while the happy path stays green: the trigger,
# the three extraction kinds, the clause-start exclusion, dedupe and merge across prompts,
# the substring collapse, the off switch, fail-open.
set -u
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
HOOK="$ROOT/plugins/ask-ledger/hooks/ledger.sh"
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available"; exit 0; }
[ -f "$HOOK" ] || { echo "FAIL: $HOOK not found"; exit 1; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export TMPDIR="$TMP"
rc=0
run() { # $1 prompt, $2 session → prints the ledger entries comma-joined after the call
  jq -n --arg pr "$1" --arg s "$2" '{hook_event_name:"UserPromptSubmit",session_id:$s,transcript_path:("/nowhere/"+$s+".jsonl"),cwd:"/tmp",prompt:$pr}' \
    | env -u CC_ASK_LEDGER bash "$HOOK" >/dev/null 2>&1
  key=$(printf '/nowhere/%s.jsonl' "$2" | cksum | cut -d' ' -f1)
  [ -f "$TMP/cc-ask-ledger-$key/entries" ] && paste -sd, - < "$TMP/cc-ask-ledger-$key/entries"
}
ctx() { jq -n --arg pr "$1" --arg s "$2" '{hook_event_name:"UserPromptSubmit",session_id:$s,transcript_path:("/nowhere/"+$s+".jsonl"),prompt:$pr}' | env -u CC_ASK_LEDGER bash "$HOOK" 2>/dev/null | jq -r '.hookSpecificOutput.additionalContext // empty'; }
check(){ if [ "$2" = "$3" ]; then echo "PASS: $1"; else echo "FAIL: $1 — got: ${2:-<none>} want: ${3:-<none>}"; rc=1; fi; }

check "1 proper nouns, quoted term, digit token with its word" \
  "$(run 'create a Laravel + React project with 2D Sprites, Digimon themed, and a "digimon" library' s1)" "digimon,2D Sprites,Laravel,React"
check "2 a clause-start capital is not a name" "$(run 'Build the parser. Then add tests for Stripe webhooks.' s2)" "Stripe"
check "3 a question with a making verb writes no ledger" "$(run 'how do I add Redis caching?' s3)" ""
check "4 a slash command writes no ledger" "$(run '/taskmaster:task build a Redis cache' s4)" ""
check "5 a later work prompt appends without duplicates" "$(run 'now redo the sprites as Agumon and Gabumon, still Laravel' s1)" "digimon,2D Sprites,Laravel,React,Agumon,Gabumon"
check "6 names inside code spans are ignored" "$(run 'fix the build; the error mentions `Vite` and ```Webpack```' s6)" ""
check "7 stoplist words are not names" "$(run 'implement it on Monday and update the README, then Also the API' s7)" ""
check "8 the context line names the entries and the gate shape" "$(ctx 'build a Stripe checkout' s8 | grep -c 'Stripe.*as named')" "1"
out=$(jq -n '{prompt:"build a Stripe checkout",session_id:"s9",transcript_path:"/nowhere/s9.jsonl"}' | CC_ASK_LEDGER=off bash "$HOOK" 2>/dev/null)
check "9 CC_ASK_LEDGER=off is silent" "$out" ""
out=$(printf 'not json' | bash "$HOOK" 2>/dev/null; echo "rc=$?")
check "10 malformed payload fails open" "$out" "rc=0"
exit $rc
