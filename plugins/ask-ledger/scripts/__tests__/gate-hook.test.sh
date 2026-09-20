#!/usr/bin/env bash
# Smoke tests for ask-ledger/hooks/gate.sh — the Stop gate that refuses a final message
# without an accounting line per ledgered name. Branches: no ledger → silent; every name
# accounted → silent; one missing → exit 2 naming it; the three verbs all count; a
# case-insensitive match; the two-block ceiling; the off switch; fail-open.
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
run() { # $1 session, $2 final message → "rc=N|stderr"
  out=$(jq -n --arg s "$1" --arg m "$2" '{hook_event_name:"Stop",session_id:$s,transcript_path:("/nowhere/"+$s+".jsonl"),stop_hook_active:false,last_assistant_message:$m}' \
    | env -u CC_ASK_LEDGER bash "$HOOK" 2>&1 >/dev/null; echo "rc=$?")
  printf '%s' "$out" | tr '\n' ' '
}
check(){ case "$2" in *"$3"*) echo "PASS: $1";; *) echo "FAIL: $1 — got: $2"; rc=1;; esac; }

check "1 no ledger: silent" "$(run s0 'done')" "rc=0"
ledger s1 Laravel "2D Sprites" Digimon
check "2 all accounted: silent" "$(run s1 $'Laravel: as named\n2D Sprites: as named\nDigimon: substituted → invented mascots, my hedge, not asked')" "rc=0"
r=$(run s1 $'Laravel: as named\n2D Sprites: as named')
check "3 one missing blocks with exit 2" "$r" "rc=2"
check "4 the block names the missing entry" "$r" "named Digimon"
check "5 omitted counts, case-insensitive" "$(run s1 $'laravel: OMITTED → out of scope\n2d sprites: as named\ndigimon: as named')" "rc=0"
ledger s2 Stripe
run s2 'no accounting' >/dev/null; run s2 'still none' >/dev/null
check "6 third stop after two blocks ends the turn with a warning" "$(run s2 'still none')" "rc=0"
out=$(jq -n '{hook_event_name:"Stop",session_id:"s3",transcript_path:"/nowhere/s3.jsonl",last_assistant_message:"x"}' | CC_ASK_LEDGER=off bash "$HOOK" 2>&1; echo "rc=$?")
check "7 CC_ASK_LEDGER=off is silent" "$out" "rc=0"
out=$(printf 'not json' | bash "$HOOK" 2>/dev/null; echo "rc=$?")
check "8 malformed payload fails open" "$out" "rc=0"
ledger s4 React
T="$TMP/s4.jsonl"; printf '%s\n' '{"type":"assistant","uuid":"a1","message":{"role":"assistant","content":[{"type":"text","text":"working"}]}}' '{"type":"assistant","uuid":"a2","message":{"role":"assistant","content":[{"type":"text","text":"React: as named"}]}}' > "$T"
out=$(jq -n --arg t "$T" '{hook_event_name:"Stop",session_id:"s4",transcript_path:$t}' | env -u CC_ASK_LEDGER bash "$HOOK" 2>&1; echo "rc=$?")
check "9 without last_assistant_message the transcript's final assistant text is read" "$out" "rc=0"
exit $rc
