#!/usr/bin/env bash
# Author-time tests for candor-scan.sh — the report-only transcript measurement
# behind /candor:check.
#
# Two properties matter and both are asserted: the counts are right, and the exit
# code is 0 on every path including the ones with hits. A measurement that can
# fail a build is a gate wearing a report's name, and this repo's has-teeth
# convention makes that the over-claim it forbids.
set -u

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
SCAN="$ROOT/plugins/candor/scripts/candor-scan.sh"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available"; exit 0; }
[ -x "$SCAN" ] || { echo "FAIL: scan not executable at $SCAN"; exit 1; }

pass=0; fail=0
WS="$(mktemp -d)"; trap 'rm -rf "$WS"' EXIT
PROJ="$WS/proj"; mkdir -p "$PROJ/src"
printf 'a\nb\nc\n' > "$PROJ/src/real.ts"   # 3 lines

asst()  { jq -cn --arg t "$1" '{type:"assistant",message:{content:[{type:"text",text:$t}]}}'; }
user()  { jq -cn --arg t "$1" '{type:"user",message:{content:$t}}'; }
tools() { jq -cn '$ARGS.positional | {type:"assistant",message:{content:[.[] | {type:"tool_use",name:.}]}}' --args "$@"; }

# axis_is <desc> <transcript> <axis-label> <expected-count>
axis_is() {
  local desc="$1" t="$2" axis="$3" want="$4" out rc got ok=1
  out=$(cd "$PROJ" && bash "$SCAN" --session-file "$t" 2>&1); rc=$?
  got=$(printf '%s\n' "$out" | awk -v a="$axis" '$1==a {print $2; exit}')
  [ "$rc" -eq 0 ] || ok=0
  [ "${got:-x}" = "$want" ] || ok=0
  if [ "$ok" -eq 1 ]; then pass=$((pass+1)); printf 'PASS  %s\n' "$desc"
  else fail=$((fail+1)); printf 'FAIL  %s (%s=%s want %s, rc=%s)\n' "$desc" "$axis" "${got:-<none>}" "$want" "$rc"; fi
}

T="$WS/flat.jsonl"
{ asst "Great question! The handler lives in the router."
  asst "You're absolutely right about the ordering."
  asst "The handler lives in the router."; } > "$T"
axis_is "flattery openers counted"        "$T" flattery-opener 2
axis_is "clean message not counted"       "$T" defensive 0

T="$WS/apol.jsonl"
{ asst "I apologise — that was wrong."
  asst "My mistake, the flag is inverted."
  asst "Sorry about that, sorry again, sorry once more."
  asst "Rebuilt the index."; } > "$T"
axis_is "apologies counted per message, not per occurrence" "$T" apology 3

T="$WS/def.jsonl"
{ asst "As I said, the worker restarts on exit."
  asst "To be fair, you asked for the shorter version."
  asst "Rebuilt the index."; } > "$T"
axis_is "defensive phrasing counted"      "$T" defensive 2

T="$WS/emo.jsonl"
{ asst "I completely failed to check that."
  asst "Perfect! The build is green."
  asst "Rebuilt the index."; } > "$T"
axis_is "emotional intensifiers counted"  "$T" emotional-intensifier 2

T="$WS/cite.jsonl"
{ asst "See src/real.ts:2 for the guard."
  asst "And src/ghost.ts:12 for the handler."
  asst "And src/real.ts:900 past the end."; } > "$T"
axis_is "unresolved citations counted, resolving ones not" "$T" unresolved-citation 2

# Citations resolve against the transcript's recorded cwd, not the shell's. A
# session that ran elsewhere must not report every one of its real paths missing.
OTHER="$WS/other"; mkdir -p "$OTHER/lib"; printf 'p\nq\n' > "$OTHER/lib/other.ts"
T="$WS/cwd.jsonl"
{ jq -cn --arg c "$OTHER" '{type:"assistant",cwd:$c,message:{content:[{type:"text",text:"See lib/other.ts:1 in the other project."}]}}'; } > "$T"
axis_is "citations resolve against the transcript cwd" "$T" unresolved-citation 0
out=$(cd "$PROJ" && bash "$SCAN" --session-file "$T" 2>&1)
if printf '%s' "$out" | grep -qF "citations resolved against: $OTHER"; then
  pass=$((pass+1)); printf 'PASS  the resolution root is reported\n'
else fail=$((fail+1)); printf 'FAIL  the resolution root is reported\n%s\n' "$out"; fi

T="$WS/elide.jsonl"
{ asst "See plugins/x/.../real.ts:900 — an elided path."
  asst "And src/ghost.ts:1 — an invented filename."; } > "$T"
axis_is "elided paths skipped, invented basename counted" "$T" unresolved-citation 1

T="$WS/rev.jsonl"
{ asst "The retry is disabled."; user "Are you sure?"; asst "You're right, my mistake."
  asst "The queue is FIFO."; user "Are you sure?"; tools Bash; asst "You're right, it is LIFO."
  asst "The lock is advisory."; user "No, it is in config/db.php"; asst "You're right, my mistake."; } > "$T"
axis_is "only the unevidenced reversal counted" "$T" unevidenced-reversal 1

T="$WS/win.jsonl"
{ asst "Great question! One."
  asst "Great question! Two."
  asst "Plain three."; } > "$T"
axis_is "--last narrows the window" "$T" flattery-opener 2
out=$(cd "$PROJ" && bash "$SCAN" --session-file "$T" --last 1 2>&1); rc=$?
got=$(printf '%s\n' "$out" | awk '$1=="flattery-opener" {print $2; exit}')
if [ "$rc" -eq 0 ] && [ "$got" = "0" ]; then pass=$((pass+1)); printf 'PASS  --last 1 sees only the final message\n'
else fail=$((fail+1)); printf 'FAIL  --last 1 sees only the final message (got %s rc=%s)\n' "${got:-<none>}" "$rc"; fi

# Exit code is 0 on every path, including a transcript full of hits.
out=$(cd "$PROJ" && bash "$SCAN" --session-file "$WS/apol.jsonl" 2>&1); rc=$?
if [ "$rc" -eq 0 ]; then pass=$((pass+1)); printf 'PASS  exits 0 with hits present\n'
else fail=$((fail+1)); printf 'FAIL  exits 0 with hits present (rc=%s)\n' "$rc"; fi

out=$(cd "$PROJ" && bash "$SCAN" --session-file "$WS/nope.jsonl" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'no readable transcript'; then
  pass=$((pass+1)); printf 'PASS  missing transcript reports and exits 0\n'
else fail=$((fail+1)); printf 'FAIL  missing transcript reports and exits 0 (rc=%s out=%s)\n' "$rc" "$out"; fi

T="$WS/junk.jsonl"; printf 'not json\n' > "$T"
out=$(cd "$PROJ" && bash "$SCAN" --session-file "$T" 2>&1); rc=$?
if [ "$rc" -eq 0 ]; then pass=$((pass+1)); printf 'PASS  malformed transcript exits 0\n'
else fail=$((fail+1)); printf 'FAIL  malformed transcript exits 0 (rc=%s)\n' "$rc"; fi

# The standing column is part of the contract: two axes gated, four recorded.
out=$(cd "$PROJ" && bash "$SCAN" --session-file "$WS/apol.jsonl" 2>&1)
g=$(printf '%s\n' "$out" | grep -c 'GATED'); r=$(printf '%s\n' "$out" | grep -c 'recorded only')
if [ "$g" -eq 2 ] && [ "$r" -eq 4 ]; then pass=$((pass+1)); printf 'PASS  standing column: 2 gated, 4 recorded\n'
else fail=$((fail+1)); printf 'FAIL  standing column: 2 gated, 4 recorded (got %s/%s)\n' "$g" "$r"; fi

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
