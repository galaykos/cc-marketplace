#!/usr/bin/env bash
# candor-scan.test.sh — runs scripts/candor-scan.sh over synthetic transcripts and asserts each axis count, the --last window, the resolution
#   root, the standing column, and exit 0 on every path, hits included.
# Why, limits, history: rationale/derivations/plugin-candor.md § plugins/candor/scripts/__tests__/candor-scan.test.sh
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

# The lookup is hooks/cite.sh, the gate's own; these shapes were false hits before 0.8.0.
mkdir -p "$PROJ/node_modules/scrolly/dist" "$PROJ/vendor/acme/lib"
printf 'x\n' > "$PROJ/node_modules/scrolly/dist/scrolly.mjs"
seq 1 20 > "$PROJ/vendor/acme/lib/Thing.php"
T="$WS/deps.jsonl"
{ asst "The easing lives at scrolly.mjs:783."
  asst "See $PROJ/vendor/acme/lib/Thing.php:12 for the hook."
  asst "The admin panel is at shop.localhost:8080 and api.test:3000."; } > "$T"
axis_is "a dependency basename, an absolute vendor/ path and dev hosts are not counted" "$T" unresolved-citation 0
T="$WS/deps-bad.jsonl"
{ asst "See src/Invented.php:12 for the handler."
  asst "See $PROJ/vendor/acme/lib/Thing.php:99 past the end."; } > "$T"
axis_is "an invented basename beside a vendor/ tree and an absolute vendor/ path past EOF are counted" "$T" unresolved-citation 2
out=$(cd "$PROJ" && bash "$SCAN" --session-file "$T" 2>&1)
if printf '%s' "$out" | grep -qF "src/Invented.php:12 — no file named Invented.php found under $PROJ (8 deep;" && ! printf '%s' "$out" | grep -q anywhere; then
  pass=$((pass+1)); printf 'PASS  a missing basename names what was searched, never "anywhere"\n'
else fail=$((fail+1)); printf 'FAIL  a missing basename names what was searched, never "anywhere"\n%s\n' "$out"; fi
# One lookup, hooks/cite.sh, sourced by both: the gate and the report must agree on the same message, both ways.
G="$ROOT/plugins/candor/hooks/gate.sh"
agree() { # <desc> <message> <gate verdict: 2 blocked (JSON block on stdout, exit 0), 0 passed> <scan count>
  local t="$WS/agree$((++na)).jsonl" grc n gout
  { user "where is it"; asst "$2"; } > "$t"
  rm -rf "$PROJ/.claude"
  gout=$(jq -cn --arg tp "$t" --arg cwd "$PROJ" '{transcript_path:$tp,cwd:$cwd,stop_hook_active:false}' \
    | env -u CLAUDE_PROJECT_DIR -u CLAUDE_PLUGIN_DATA TMPDIR="$WS" bash "$G" 2>/dev/null); grc=$?
  if [ "$grc" = 0 ] && [ -n "$gout" ]; then
    printf '%s' "$gout" | jq -e '.decision=="block"' >/dev/null 2>&1 && grc=2 || grc=stdout
  elif [ "$grc" = 2 ]; then grc=exit2; fi
  n=$(cd "$PROJ" && bash "$SCAN" --session-file "$t" 2>&1 | awk '$1=="unresolved-citation" {print $2; exit}')
  if [ "$grc" = "$3" ] && [ "$n" = "$4" ]; then pass=$((pass+1)); printf 'PASS  %s\n' "$1"
  else fail=$((fail+1)); printf 'FAIL  %s (gate exit %s want %s; scan %s want %s)\n' "$1" "$grc" "$3" "${n:-<none>}" "$4"; fi
}
na=0
agree "gate and report agree: a vendor/ citation, a dependency basename and localhost:8000 are no fabrication" \
  "See vendor/acme/lib/Thing.php:12 and scrolly.mjs:783; the dev server answers on localhost:8000 and shop.localhost:8080." 0 0
agree "gate and report agree: an invented basename beside them is one" \
  "See vendor/acme/lib/Thing.php:12 and src/Invented.php:12; the dev server answers on localhost:8000." 2 1
if grep -q 'hooks/cite.sh' "$SCAN" && grep -q '/cite.sh"' "$G" && ! grep -qE 'maxdepth 8|_find\(\)|resolve\(\)' "$G" "$SCAN"; then
  pass=$((pass+1)); printf 'PASS  gate.sh and candor-scan.sh carry no citation lookup of their own\n'
else fail=$((fail+1)); printf 'FAIL  gate.sh and candor-scan.sh carry no citation lookup of their own\n'; fi

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

out=$(cd "$PROJ" && bash "$SCAN" --session-file "$WS/apol.jsonl" 2>&1)
g=$(printf '%s\n' "$out" | grep -c 'GATED'); r=$(printf '%s\n' "$out" | grep -c 'recorded only')
if [ "$g" -eq 2 ] && [ "$r" -eq 4 ]; then pass=$((pass+1)); printf 'PASS  standing column: 2 gated, 4 recorded\n'
else fail=$((fail+1)); printf 'FAIL  standing column: 2 gated, 4 recorded (got %s/%s)\n' "$g" "$r"; fi

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
