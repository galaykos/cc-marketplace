#!/usr/bin/env bash
# reads-hook.test.sh — drives hooks/reads.sh (PostToolUse Read|Bash) and gate.sh's partial-read clause with payloads carrying a path-shaped
#   transcript_path: which slices are recorded, merged and cleared, the Stop that warns or stays silent, and the off switch.
set -u

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
READS="$ROOT/plugins/candor/hooks/reads.sh"; GATE="$ROOT/plugins/candor/hooks/gate.sh"
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available (both hooks fail open without it)"; exit 0; }
[ -x "$READS" ] && [ -x "$GATE" ] || { echo "FAIL: hooks not executable under $ROOT/plugins/candor/hooks"; exit 1; }

unset CLAUDE_PROJECT_DIR CLAUDE_PLUGIN_DATA CC_READ_LEDGER CC_CANDOR_GATE CLAUDE_PLUGIN_OPTION_CC_READ_LEDGER CLAUDE_PLUGIN_OPTION_CC_CANDOR_GATE
pass=0; fail=0
WS="$(mktemp -d)"; trap 'rm -rf "$WS"' EXIT
export TMPDIR="$WS/tmp"; mkdir -p "$TMPDIR"
P="$WS/proj"; mkdir -p "$P/src"
seq 1 100 > "$P/src/big.txt"; seq 1 5 > "$P/src/small.txt"
TP="$WS/home/.claude/projects/-proj/7c2a.jsonl"; mkdir -p "$(dirname "$TP")"
LEDGER="$TMPDIR/cc-candor-reads-$(printf '%s' "$TP" | cksum | cut -d' ' -f1)"
READS_SUB='[candor] reads:'

ok()  { pass=$((pass+1)); printf 'PASS  %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL  %s (%s)\n' "$1" "$2"; }
reset() { rm -rf "$P/.claude" "$LEDGER"; }
read_call() { # tool_input-json [env] [cwd]
  jq -cn --argjson ti "$1" --arg tp "$TP" --arg cwd "${3:-$P}" '{hook_event_name:"PostToolUse",tool_name:"Read",tool_input:$ti,transcript_path:$tp,cwd:$cwd}' \
    | env ${2:-} bash "$READS"
}
bash_call() { jq -cn --arg c "$1" --arg tp "$TP" --arg cwd "$P" '{hook_event_name:"PostToolUse",tool_name:"Bash",tool_input:{command:$c},transcript_path:$tp,cwd:$cwd}' | bash "$READS"; }
stop() { # final-message [env] — sets rc, err, out and msg (out's systemMessage)
  out=$(jq -cn --arg m "$1" --arg tp "$TP" --arg cwd "$P" '{hook_event_name:"Stop",transcript_path:$tp,cwd:$cwd,last_assistant_message:$m,stop_hook_active:false}' \
    | env ${2:-} bash "$GATE" 2>"$WS/err"); rc=$?; err=$(cat "$WS/err")
  msg=$(printf '%s' "$out" | jq -r '.systemMessage // empty' 2>/dev/null)
}
quiet()  { [ "$rc" -eq 0 ] && [ -z "$err" ] && [ -z "$out" ]; }
warned() { [ "$rc" -eq 0 ] && [ -z "$err" ] && printf '%s' "$msg" | grep -qF "$READS_SUB" && printf '%s' "$msg" | grep -qF "$1"; }
entry() { [ -f "$LEDGER" ] && awk -F'\t' -v b="$1" '{ n = split($1, a, "/") } a[n] == b { print $2 " " $3 }' "$LEDGER"; }

reset; read_call "{\"file_path\":\"$P/src/big.txt\",\"offset\":1,\"limit\":40}"
[ "$(entry big.txt)" = "100 1-40" ] && ok "a Read of 40 lines of a 100-line file is recorded, on disk under the hashed transcript_path" || bad "record" "$(entry big.txt)"
stop "The parser looks fine."
warned 'src/big.txt:1-40 (of 100 lines)' && printf '%s' "$msg" | grep -qF 'CC_READ_LEDGER=off' \
  && ok "a final message that never names the file shows the user one systemMessage naming the switch, stderr empty, exit 0" || bad "warn" "rc=$rc err=$err out=$out"
[ ! -e "$LEDGER" ] && ok "the ledger clears at that stop" || bad "clears" "still on disk"
stop "The parser looks fine."
quiet && ok "the next stop is silent" || bad "silent after clear" "rc=$rc err=$err out=$out"

reset; : > "$TMPDIR/cc-candor-reads-1"; : > "$TMPDIR/cc-candor-reads-2"; touch -t 200001010000 "$TMPDIR/cc-candor-reads-1"; bash_call "head -n 20 src/big.txt"
[ ! -e "$TMPDIR/cc-candor-reads-1" ] && [ -e "$TMPDIR/cc-candor-reads-2" ] && ok "a write sweeps read ledgers older than 1440 minutes, not younger ones" || bad "sweep" "$(ls "$TMPDIR")"
rm -f "$TMPDIR/cc-candor-reads-2"

reset; read_call "{\"file_path\":\"$P/src/big.txt\",\"offset\":1,\"limit\":40}" "" "$P/src"; stop "The parser looks fine."
warned 'src/big.txt:1-40' && [ ! -e "$P/src/.claude" ] && [ ! -e "$P/.claude" ] \
  && ok "a read recorded from a nested cwd reaches the stop taken at the project root; nothing lands in the project" || bad "ledger outside the cwd" "rc=$rc err=$err"

reset; read_call "{\"file_path\":\"$P/src/big.txt\",\"offset\":1,\"limit\":40}"; stop "Only the first 40 lines of big.txt were read."
quiet && ok "a final message naming the file's basename is silent" || bad "named" "rc=$rc err=$err out=$out"

reset; read_call "{\"file_path\":\"$P/src/big.txt\",\"limit\":40}"; bash_call "sed -n '41,70p' src/big.txt"; bash_call "tail -n 30 src/big.txt"
[ ! -e "$LEDGER" ] && ok "a Read, a sed -n slice and a tail that together cover the file clear it" || bad "covered" "$(entry big.txt)"
reset; read_call "{\"file_path\":\"$P/src/big.txt\",\"limit\":10}"; read_call "{\"file_path\":\"$P/src/big.txt\"}"
[ ! -e "$LEDGER" ] && ok "a later Read with no offset or limit clears it" || bad "whole read clears" "$(entry big.txt)"
reset; read_call "{\"file_path\":\"$P/src/big.txt\",\"offset\":20,\"limit\":10}"; read_call "{\"file_path\":\"$P/src/big.txt\",\"offset\":50}"
[ ! -e "$LEDGER" ] && ok "a Read starting past line 1 of an unrecorded file records nothing" || bad "mid-file Read" "$(entry big.txt)"
reset; read_call "{\"file_path\":\"$P/src/big.txt\",\"offset\":1,\"limit\":40}"; read_call "{\"file_path\":\"$P/src/big.txt\",\"offset\":50}"
[ "$(entry big.txt)" = "100 1-40,50-100" ] && ok "a later Read starting past line 1 merges into the entry already recorded" || bad "offset merges" "$(entry big.txt)"

reset; bash_call "head -n 20 src/big.txt"; [ "$(entry big.txt)" = "100 1-20" ] && ok "head -n 20 records 1-20" || bad "head -n" "$(entry big.txt)"
reset; bash_call "cd src && head -15 big.txt 2>/dev/null"; [ "$(entry big.txt)" = "100 1-15" ] && ok "head -15 after a cd, stderr redirected, records 1-15" || bad "head -N cd" "$(entry big.txt)"
reset; bash_call "tail -n 10 src/big.txt"; bash_call "sed -n 214,231p src/big.txt; sed -n 5,9p src/big.txt"
[ ! -e "$LEDGER" ] && ok "tail -n 10 and mid-file sed -n slices of an unrecorded file record nothing" || bad "tail/mid-file" "$(entry big.txt)"
reset; bash_call "sed -n 1,9p src/big.txt && sed -n '30p' src/big.txt"; [ "$(entry big.txt)" = "100 1-9,30-30" ] && ok "sed -n 1,9p records, a later sed -n 30p merges into it" || bad "sed" "$(entry big.txt)"
reset; bash_call "(cd src && ls) && head -n 20 src/big.txt"; [ "$(entry big.txt)" = "100 1-20" ] && ok "a path the cd before it does not resolve is tried from the payload cwd" || bad "cd fallback" "$(entry big.txt)"

SHIM="$WS/shim"; mkdir -p "$SHIM"
for c in find touch mkdir awk; do printf '#!/bin/sh\necho "%s $*" >> "%s"\nexec "%s" "$@"\n' "$c" "$WS/calls" "$(command -v "$c")" > "$SHIM/$c"; chmod +x "$SHIM/$c"; done
reset; : > "$WS/calls"; read_call "{\"file_path\":\"$P/src/big.txt\"}" "PATH=$SHIM:$PATH"
[ ! -s "$WS/calls" ] && [ ! -e "$LEDGER" ] && ok "a whole-file Read with no ledger exits before any find, touch, mkdir or awk" || bad "clear hot path" "$(cat "$WS/calls")"
reset; bash_call "head -n 20 src/big.txt"; : > "$WS/calls"; read_call "{\"file_path\":\"$P/src/big.txt\"}" "PATH=$SHIM:$PATH"
[ ! -e "$LEDGER" ] && ! grep -qF 'print NR' "$WS/calls" && ok "a whole-file Read clears its entry without counting the file's lines" || bad "clear counts lines" "$(cat "$WS/calls")"

reset; bash_call "head -n 50 src/small.txt"; bash_call "cat src/big.txt | head -5"; bash_call "git log --oneline | head -n 5"
bash_call "sed -i '1,5d' src/small.txt.bak; tail -f src/big.txt; grep -n head src/big.txt; sed -n 1,10p src/missing.txt"
[ ! -e "$LEDGER" ] && ok "a slice covering a short file, a pipe's head, sed -i, tail -f, grep and a missing file record nothing" || bad "neighbours" "$(cat "$LEDGER")"

reset; read_call "{\"file_path\":\"$P/src/big.txt\",\"offset\":1,\"limit\":40}" "CC_READ_LEDGER=off"; stop "Done." "CC_READ_LEDGER=off"
[ ! -e "$LEDGER" ] && quiet && ok "CC_READ_LEDGER=off records nothing and the stop is silent" || bad "off" "rc=$rc err=$err out=$out"

reset
jq -cn --arg tp "$TP" --arg cwd "$P" --arg f "$P/src/big.txt" '{hook_event_name:"PostToolUse",tool_name:"Read",agent_id:"a9",tool_input:{file_path:$f,limit:10},transcript_path:$tp,cwd:$cwd}' | bash "$READS"
[ ! -e "$LEDGER" ] && ok "a read made inside a subagent records nothing" || bad "subagent" "ledger written"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
