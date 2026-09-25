#!/usr/bin/env bash
# Smoke tests for ask-ledger/hooks/ledger.sh — the UserPromptSubmit hook that destructures
# a work-shaped prompt into the things it names and keeps a session ledger. Each case is a
# branch a one-character edit could remove while the happy path stays green: the trigger,
# the three extraction kinds, the clause-start exclusion, dedupe and merge across prompts,
# the substring collapse, the existing-identifier filter, the off switch, fail-open.
#
# The `run()` cases below pass cwd=/tmp deliberately: /tmp is not a git work tree, so the
# existing-identifier filter is inert there and every extraction case reads the raw
# extractor. Cases 14-16 supply a real fixture repo and are the only ones that exercise it.
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
check "11 a harness-injected notification writes no ledger" "$(run '<system-reminder>
[SYSTEM NOTIFICATION - NOT USER INPUT]
<task-notification><result>Done. Add worked pairs: NULL, WHERE, Pagination. FAIL 0, WARN 2.</result></task-notification>
</system-reminder>' s11)" ""
check "12 a Stop-hook relay writes no ledger" "$(run 'Stop hook feedback:
[gate.sh]: ask-ledger: the ask named Stripe and the final message does not account for it. Add one line.' s12)" ""
check "13 a real ask that quotes a marker mid-sentence still writes a ledger" "$(run 'Fix candor so the Stop hook feedback: line it prints names the Stripe webhook that failed' s13)" "Stop,Stripe"
check "13b a subagent hand-back writes no ledger" "$(run 'Another Claude session sent a message:
<agent-message from="ac61f13cc0e92d08a">
[Subagent hand-back] The text below is the final report of a subagent this session delegated to.
  RV-CARD 08: Add the PopoverContent fix. NOT merge-ready until Card 09 lands.
</agent-message>' s13b)" ""
check "13c a bare agent-message tag writes no ledger" "$(run '<agent-message from="a0d31354dca16ebac">Build the Stripe adapter next.</agent-message>' s13c)" ""
check "13d a hand-back frame under a harness note writes no ledger" "$(run 'Note: relayed.
[Subagent hand-back] Create PopoverContent for Card 03.' s13d)" ""

# --- 14-16 the existing-identifier filter (2026-09-22). A name the repo already carries
#     is code to be REPAIRED, not a thing to be delivered; ledgering it made the Stop gate
#     demand an accounting line for every class the ask happened to mention. ---
if command -v git >/dev/null 2>&1; then
  FX="$TMP/fixture"; mkdir -p "$FX/app"
  git -C "$FX" init -q 2>/dev/null
  printf '# Acme\nA Laravel + Inertia app.\n' > "$FX/README.md"
  printf '<?php\nuse App\\Models\\Invoice;\nclass OrderController {}\n' > "$FX/app/OrderController.php"
  git -C "$FX" add -A >/dev/null 2>&1
  git -C "$FX" -c user.email=t@t -c user.name=t commit -qm init >/dev/null 2>&1
  runat() { # $1 prompt, $2 session, $3 cwd
    jq -n --arg pr "$1" --arg s "$2" --arg c "$3" '{hook_event_name:"UserPromptSubmit",session_id:$s,transcript_path:("/nowhere/"+$s+".jsonl"),cwd:$c,prompt:$pr}' \
      | env -u CC_ASK_LEDGER bash "$HOOK" >/dev/null 2>&1
    key=$(printf '/nowhere/%s.jsonl' "$2" | cksum | cut -d' ' -f1)
    [ -f "$TMP/cc-ask-ledger-$key/entries" ] && paste -sd, - < "$TMP/cc-ask-ledger-$key/entries"
  }
  check "14 identifiers the repo already carries are not ledgered" \
    "$(runat 'Fix the eager loading in OrderController so Invoice loads under Inertia' s14 "$FX")" ""
  check "15 case does not save an existing name (Laravel vs laravel)" \
    "$(runat 'update the Laravel config' s15 "$FX")" ""
  check "16 a name the repo has never heard of still ledgers" \
    "$(runat 'add a Stripe checkout to OrderController' s16 "$FX")" "Stripe"
else
  echo "SKIP: 14-16 existing-identifier filter (git not available)"
fi
exit $rc
