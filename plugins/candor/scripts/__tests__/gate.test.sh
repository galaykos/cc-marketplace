#!/usr/bin/env bash
# Author-time tests for the candor Stop gate.
#
# The hook reads the Stop payload's transcript_path (session JSONL) and blocks a
# turn on either of two clauses: a file:line citation that does not resolve, or a
# position retracted after bare pushback with nothing re-checked. These cases
# drive it with synthetic transcripts plus canned Stop-hook stdin and assert rc +
# stderr — including every fail-open, escape and mode the header promises.
#
# The payload carries transcript_path, not session_id: this hook's entire input is
# the transcript, and a harness that sent only session_id would grade a branch the
# host never takes (scripts/lib/plugin-checks.sh, pc_harness_payload).
set -u

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
HOOK="$ROOT/plugins/candor/hooks/gate.sh"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available (hook fails open without it)"; exit 0; }
[ -x "$HOOK" ] || { echo "FAIL: hook not executable at $HOOK"; exit 1; }

pass=0; fail=0
WS="$(mktemp -d)"; trap 'rm -rf "$WS"' EXIT
CWD="$WS/proj"; mkdir -p "$CWD/src" "$CWD/deep/nested"
MARKER="$CWD/.claude/candor-last"
CLAIMED="$CWD/.claude/candor-blocked"

# Real files the citations can resolve against.
printf 'a\nb\nc\nd\ne\n' > "$CWD/src/real.ts"           # 5 lines
printf 'x\ny\n'          > "$CWD/deep/nested/deep.ts"   # 2 lines

# Transcript builders: one JSONL line per entry.
asst()  { jq -cn --arg t "$1" '{type:"assistant",message:{content:[{type:"text",text:$t}]}}'; }
user()  { jq -cn --arg t "$1" '{type:"user",message:{content:$t}}'; }
tools() { jq -cn '$ARGS.positional | {type:"assistant",message:{content:[.[] | {type:"tool_use",name:.}]}}' --args "$@"; }
tres()  { jq -cn '{type:"user",message:{content:[{type:"tool_result",content:"ok"}]}}'; }

payload()        { jq -cn --arg tp "$1" --arg cwd "$CWD" '{transcript_path:$tp,cwd:$cwd,stop_hook_active:false}'; }
payload_active() { jq -cn --arg tp "$1" --arg cwd "$CWD" '{transcript_path:$tp,cwd:$cwd,stop_hook_active:true}'; }

check()      { rm -f "$MARKER" "$CLAIMED"; check_keep "$@"; }
check_keep() {
  local desc="$1" envv="$2" tfile="$3" exp_rc="$4" exp_sub="$5" err rc ok=1
  err=$(payload "$tfile" | env $envv bash "$HOOK" 2>&1 >/dev/null); rc=$?
  [ "$rc" -eq "$exp_rc" ] || ok=0
  if [ "$exp_sub" != "__NONE__" ]; then
    printf '%s' "$err" | grep -qF "$exp_sub" || ok=0
  else
    [ -z "$err" ] || ok=0
  fi
  if [ "$ok" -eq 1 ]; then pass=$((pass+1)); printf 'PASS  %s\n' "$desc"
  else fail=$((fail+1)); printf 'FAIL  %s (rc=%s want %s; stderr=%s)\n' "$desc" "$rc" "$exp_rc" "$err"; fi
}

CITE_SUB='cites a location that does not exist'
REV_SUB='retracts your position anyway'

# ---------------------------------------------------------------------------
# CLAUSE 1 — citations
# ---------------------------------------------------------------------------
T="$WS/c1.jsonl"; { user "where is the bug"; asst "The bug is at src/ghost.ts:12 — fix it there."; } > "$T"
check "nonexistent file:line blocks"                  "" "$T" 2 "$CITE_SUB"
check_keep "same message re-stop passes (one-shot)"   "" "$T" 0 "__NONE__"

T="$WS/c2.jsonl"; { user "where"; asst "See src/real.ts:3 for the guard."; } > "$T"
check "resolving citation passes"                     "" "$T" 0 "__NONE__"

T="$WS/c3.jsonl"; { user "where"; asst "See src/real.ts:900 for the guard."; } > "$T"
check "citation past EOF blocks"                      "" "$T" 2 "$CITE_SUB"

T="$WS/c4.jsonl"; { user "where"; asst "See src/real.ts:6 — the last line."; } > "$T"
check "one line past wc -l tolerated (no trailing newline)" "" "$T" 0 "__NONE__"

T="$WS/c5.jsonl"; { user "where"; asst "Fetch https://example.com/index.php:80 for the port demo."; } > "$T"
check "URL with a port is not a citation"             "" "$T" 0 "__NONE__"

T="$WS/c6.jsonl"; { user "where"; asst "The service listens on example.com:8080 in staging."; } > "$T"
check "host:port is not a citation"                   "" "$T" 0 "__NONE__"

T="$WS/c7.jsonl"; { user "where"; asst "Create src/ghost.ts and put the handler there."; } > "$T"
check "bare nonexistent path (no line) passes"        "" "$T" 0 "__NONE__"

T="$WS/c8.jsonl"; { asst "It is at src/ghost.ts:12."; user "and now"; asst "All set."; } > "$T"
check "stale citation in an EARLIER message does not bleed" "" "$T" 0 "__NONE__"

T="$WS/c9.jsonl"; { user "where"; asst "See nested/deep.ts:2 — cited from a subdirectory."; } > "$T"
check "subdirectory-relative citation resolves"       "" "$T" 0 "__NONE__"

T="$WS/c10.jsonl"; { user "where"; asst "See $CWD/src/real.ts:2 for it."; } > "$T"
check "absolute path citation resolves"               "" "$T" 0 "__NONE__"

T="$WS/c11.jsonl"; { user "when"; asst "The job ran at 10:30 and took v1.2.3:4 seconds."; } > "$T"
check "clock times and version strings are not citations" "" "$T" 0 "__NONE__"

# The resolver ladder. Measured on 47 real transcripts, an abbreviated path is far
# more common than an invented one, so only a basename that exists NOWHERE blocks.
T="$WS/c12.jsonl"; { user "where"; asst "See src/wrong/dir/deep.ts:1 — abbreviated path, real filename."; } > "$T"
check "unique basename under a wrong directory resolves" "" "$T" 0 "__NONE__"

T="$WS/c13.jsonl"; { user "where"; asst "See src/wrong/dir/deep.ts:99 — line past the resolved file."; } > "$T"
check "wrong-directory path still line-checked once unique" "" "$T" 2 "$CITE_SUB"

printf 'q\n' > "$CWD/src/dup.ts"; printf 'q\n' > "$CWD/deep/dup.ts"
T="$WS/c14.jsonl"; { user "where"; asst "See lib/elsewhere/dup.ts:400 — ambiguous basename."; } > "$T"
check "ambiguous basename is not decidable, passes"  "" "$T" 0 "__NONE__"

T="$WS/c15.jsonl"; { user "where"; asst "See plugins/x/.../real.ts:900 — an elided path."; } > "$T"
check "elided path (...) is prose, not a citation"   "" "$T" 0 "__NONE__"

T="$WS/c16.jsonl"; { user "where"; asst "See src/ghost.ts:12 — invented filename."; } > "$T"
check "invented basename blocks with the name in the reason" "" "$T" 2 "no file named ghost.ts exists anywhere"

# ---------------------------------------------------------------------------
# CLAUSE 2 — unevidenced reversal
# ---------------------------------------------------------------------------
T="$WS/r1.jsonl"; { asst "The retry is disabled."; user "Are you sure?"; asst "You're absolutely right, my mistake — it is enabled."; } > "$T"
check "bare pushback + retraction + no tool blocks"   "" "$T" 2 "$REV_SUB"
check_keep "same reversal re-stop passes (one-shot)"  "" "$T" 0 "__NONE__"

T="$WS/r2.jsonl"; { asst "The retry is disabled."; user "Are you sure?"; tools Bash; tres; asst "You're right — the setting is on."; } > "$T"
check "a tool call after the pushback passes"         "" "$T" 0 "__NONE__"

T="$WS/r3.jsonl"; { asst "It is disabled."; user "No, it is set in config/queue.php"; asst "You're right, my mistake."; } > "$T"
check "pushback carrying a path disarms the clause"   "" "$T" 0 "__NONE__"

T="$WS/r4.jsonl"; { asst "It is disabled."; user 'Are you sure? `retry_after` is right there.'; asst "You're right, apologies."; } > "$T"
check "pushback carrying a backtick disarms"          "" "$T" 0 "__NONE__"

LONG="Are you sure about that? I have been staring at this for an hour and my reading of the situation is that the worker does in fact retry, because the supervisor restarts it on a non-zero exit and the job is not marked failed until the attempt counter is exhausted, which is a completely different mechanism from what you described and I would like you to reconcile the two before we go any further with this."
T="$WS/r5.jsonl"; { asst "It is disabled."; user "$LONG"; asst "You're right, I was wrong."; } > "$T"
check "long argued pushback disarms (>400 chars)"     "" "$T" 0 "__NONE__"

T="$WS/r6.jsonl"; { asst "It is disabled."; user "Are you sure?"; asst "I re-read the settings — you're right, it is on."; } > "$T"
check "stated basis (re-read) passes"                 "" "$T" 0 "__NONE__"

T="$WS/r7.jsonl"; { asst "It is disabled."; user "Are you sure?"; asst "I still think it is disabled; the flag defaults to false."; } > "$T"
check "holding the position passes"                   "" "$T" 0 "__NONE__"

T="$WS/r8.jsonl"; { user "add a test"; asst "You're right that a test helps — added."; } > "$T"
check "retraction language without pushback passes"   "" "$T" 0 "__NONE__"

T="$WS/r9.jsonl"; { asst "Deleting the branch now."; user "No, don't do that."; asst "Understood — leaving it in place."; } > "$T"
check "an instruction (not a challenge) passes"       "" "$T" 0 "__NONE__"

# Clause priority: a turn that trips both reports the citation.
T="$WS/p1.jsonl"; { asst "It is fine."; user "Are you sure?"; asst "You're right, my mistake — see src/ghost.ts:9."; } > "$T"
check "citation clause reported first when both trip" "" "$T" 2 "$CITE_SUB"

# ---------------------------------------------------------------------------
# Modes and fail-open
# ---------------------------------------------------------------------------
T="$WS/m1.jsonl"; { user "where"; asst "The bug is at src/ghost.ts:12."; } > "$T"
check "warn mode prints but does not block" "CC_CANDOR_GATE=warn" "$T" 0 "$CITE_SUB"
check "off mode is silent"                  "CC_CANDOR_GATE=off"  "$T" 0 "__NONE__"

check "missing transcript fails open"       "" "$WS/does-not-exist.jsonl" 0 "__NONE__"

T="$WS/f1.jsonl"; : > "$T"
check "empty transcript fails open"         "" "$T" 0 "__NONE__"

T="$WS/f2.jsonl"; printf 'not json at all\n' > "$T"
check "malformed transcript fails open"     "" "$T" 0 "__NONE__"

T="$WS/f3.jsonl"; { tools Read; } > "$T"
check "no assistant prose fails open"       "" "$T" 0 "__NONE__"

# Namespaced disarm: this gate's OWN continuation releases the turn; a sibling
# gate's block (shared flag set, no record of ours) does not.
T="$WS/d1.jsonl"; { user "where"; asst "The bug is at src/ghost.ts:12."; } > "$T"
rm -f "$MARKER" "$CLAIMED"
payload "$T" | bash "$HOOK" >/dev/null 2>&1
if [ -f "$CLAIMED" ]; then pass=$((pass+1)); printf 'PASS  block writes the namespaced record\n'
else fail=$((fail+1)); printf 'FAIL  block writes the namespaced record\n'; fi
payload_active "$T" | bash "$HOOK" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 0 ] && [ ! -f "$CLAIMED" ]; then pass=$((pass+1)); printf 'PASS  own continuation releases and clears the record\n'
else fail=$((fail+1)); printf 'FAIL  own continuation releases and clears the record (rc=%s)\n' "$rc"; fi
rm -f "$MARKER" "$CLAIMED"
payload_active "$T" | bash "$HOOK" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 2 ]; then pass=$((pass+1)); printf 'PASS  sibling block does not disarm this gate\n'
else fail=$((fail+1)); printf 'FAIL  sibling block does not disarm this gate (rc=%s)\n' "$rc"; fi

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
