#!/usr/bin/env bash
# gate-pins.test.sh — pins both sides of each named limit in hooks/gate.sh: the in-flight record TTL, the behavioral-gate PID file's
#   age cap and deadline, the disclosure tail, the transcript tail, the citation cap, the quote cap, deadline and excerpt cap, the bare-pushback length and the claim window.
set -u

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/gate.sh"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available (hook fails open without it)"; exit 0; }
command -v git >/dev/null 2>&1 || { echo "SKIP: git not available"; exit 0; }
[ -x "$HOOK" ] || { echo "FAIL: hook not executable at $HOOK"; exit 1; }

unset CLAUDE_PROJECT_DIR CLAUDE_PLUGIN_DATA CC_CANDOR_GATE CC_EVIDENCE_GATE TASK_RUNNER_STOP_GATE CC_LOCKFILE_GATE \
  CLAUDE_PLUGIN_OPTION_CC_CANDOR_GATE CLAUDE_PLUGIN_OPTION_CC_EVIDENCE_GATE CLAUDE_PLUGIN_OPTION_TASK_RUNNER_STOP_GATE \
  CLAUDE_PLUGIN_OPTION_CC_LOCKFILE_GATE
pass=0; fail=0
WS="$(mktemp -d)"; trap 'rm -rf "$WS"' EXIT
export TMPDIR="$WS/tmp"; mkdir -p "$TMPDIR"

asst()  { jq -cn --arg t "$1" '{type:"assistant",message:{content:[{type:"text",text:$t}]}}'; }
user()  { jq -cn --arg t "$1" '{type:"user",message:{content:$t}}'; }
edit()  { jq -cn '{type:"assistant",message:{content:[{type:"tool_use",name:"Edit",input:{file_path:"src/app.ts"}}]}}'; }
lines() { yes "$1" | head -n "$2"; }
zebra() { lines zebra "$1" | jq -Rsc '{type:"assistant",message:{content:[{type:"text",text:rtrimstr("\n")}]}}'; }

stop_json() { # cwd transcript [session_id]
  jq -cn --arg cwd "$1" --arg tp "$2" --arg sid "${3:-}" \
    '{hook_event_name:"Stop",session_id:$sid,transcript_path:$tp,cwd:$cwd,stop_hook_active:false}'
}

# expect <label> <cwd> <transcript> <rc> <text-substring|__NONE__> [session_id]; HOOK_ENV, when set, prefixes the hook's environment.
# A block is exit 0 with {"decision":"block",reason,systemMessage} on stdout: rc=2, the text is stderr plus the reason; a bare exit 2 is rc=exit2.
expect() {
  local label="$1" err out rc ok=1
  rm -rf "$2/.claude/candor" "$2/.claude/task-runner/gate-nudge"
  out=$(stop_json "$2" "$3" "${6:-}" | env ${HOOK_ENV:-} bash "$HOOK" 2>"$WS/stderr"); rc=$?
  err=$(cat "$WS/stderr")
  if [ "$rc" = 0 ] && [ -n "$out" ]; then
    if printf '%s' "$out" | jq -e '.decision=="block" and (.reason|type=="string" and length>0) and (.systemMessage|type=="string" and length>0)' >/dev/null 2>&1; then
      rc=2; err="$err${err:+
}$(printf '%s' "$out" | jq -r .reason)"
    else rc=stdout; fi
  elif [ "$rc" = 2 ]; then rc=exit2; fi
  [ "$rc" = "$4" ] || ok=0
  if [ "$5" = "__NONE__" ]; then [ -z "$err" ] || ok=0; else printf '%s' "$err" | grep -qF "$5" || ok=0; fi
  if [ "$ok" -eq 1 ]; then pass=$((pass+1)); printf 'PASS  %s\n' "$label"
  else fail=$((fail+1)); printf 'FAIL  %s (rc=%s want %s; stderr=%s)\n' "$label" "$rc" "$4" "$(printf '%s' "$err" | head -2)"; fi
}

repo() { # dir — a committed repo with a run registered before every stop below
  mkdir -p "$1/.claude/task-runner"
  git -C "$1" init -q && git -C "$1" config user.email t@t.t && git -C "$1" config user.name t
  echo hi > "$1/f.txt"; git -C "$1" add f.txt && git -C "$1" commit -qm init
  printf '{"slug":"t"}' > "$1/.claude/task-runner/active-run.json"
  touch -t 200001010000 "$1/.claude/task-runner/active-run.json"
}

age_minutes() { # file minutes
  local e s
  e=$(( $(date +%s) - $2 * 60 ))
  s=$(date -r "$e" +%Y%m%d%H%M.%S 2>/dev/null) || s=$(date -d "@$e" +%Y%m%d%H%M.%S)
  touch -t "$s" "$1"
}

RUN_SUB='has no recorded pass of behavioral-gate.sh'
CLAIM_SUB='no command ran after the last edit'

# A find -mmin age is truncated by GNU and rounded up by BSD, so each record sits two minutes off the boundary.
RA="$WS/inflight"; repo "$RA"
SID="sess-pins"
IDIR="$TMPDIR/cc-candor-inflight-$(printf '%s' "$SID" | cksum | cut -d' ' -f1)"
REC="$IDIR/$(printf '%s' agentA | cksum | cut -d' ' -f1)"
CLEAN="$WS/clean.jsonl"; { user "run the cards"; asst "Waiting on the workers."; } > "$CLEAN"
mkdir -p "$IDIR"; printf 'agentA\n' > "$REC"; age_minutes "$REC" 178
expect "in-flight TTL: a 178-minute record still counts, the stop is not blocked" "$RA" "$CLEAN" 0 "still running" "$SID"
printf 'agentA\n' > "$REC"; age_minutes "$REC" 182
expect "in-flight TTL: a 182-minute record is swept, the stop blocks" "$RA" "$CLEAN" 2 "$RUN_SUB" "$SID"
if [ ! -e "$REC" ]; then pass=$((pass+1)); printf 'PASS  in-flight TTL: the 182-minute record is deleted from disk\n'
else fail=$((fail+1)); printf 'FAIL  in-flight TTL: the 182-minute record is deleted from disk\n'; fi

RP="$WS/bgpid"; repo "$RP"; mkdir -p "$RP/.claude/task-runner/bg"; PIDF="$RP/.claude/task-runner/bg/running.pid"
# Named like the gate: with /proc the hook checks the recorded PID's command line, not only that it is live.
printf 'sleep 600 & s=$!\ntrap "kill $s; exit 0" TERM\nwait\n' > "$WS/behavioral-gate.sh"
bash "$WS/behavioral-gate.sh" >/dev/null 2>&1 & LIVE=$!
[ -d /proc/self ] && for i in 1 2 3 4 5 6 7 8 9 10; do grep -qs 'behavioral-gate' "/proc/$LIVE/cmdline" && break; sleep 0.2; done
# No line 3 is a task-runner before 0.48.0, which writes no deadline: the file's age decides.
printf '%s\n%s\n' "$LIVE" "$(git -C "$RP" rev-parse HEAD)" > "$PIDF"; age_minutes "$PIDF" 238
expect "bg PID age: a 238-minute running.pid with no deadline and a live PID at HEAD still holds the block" "$RP" "$CLEAN" 0 "still running"
age_minutes "$PIDF" 242
expect "bg PID age: a 242-minute running.pid with no deadline and a live PID at HEAD is ignored, the stop blocks" "$RP" "$CLEAN" 2 "$RUN_SUB"
# Line 3, task-runner 0.48.0+: the epoch second the gate's own total ends it by, whatever the file's age.
printf '%s\n%s\n%s\n' "$LIVE" "$(git -C "$RP" rev-parse HEAD)" $(($(date +%s) + 600)) > "$PIDF"; age_minutes "$PIDF" 300
expect "bg PID deadline: a 300-minute running.pid whose deadline is 10 minutes ahead still holds the block" "$RP" "$CLEAN" 0 "still running"
printf '%s\n%s\n%s\n' "$LIVE" "$(git -C "$RP" rev-parse HEAD)" $(($(date +%s) - 60)) > "$PIDF"
expect "bg PID deadline: a fresh running.pid whose deadline passed a minute ago is ignored, the stop blocks" "$RP" "$CLEAN" 2 "$RUN_SUB"
kill "$LIVE" 2>/dev/null; wait "$LIVE" 2>/dev/null

RB="$WS/disclosure"; repo "$RB"
printf '{"head":"%s","cards_total":1,"cards_done":1,"cards_parked":0}' "$(git -C "$RB" rev-parse HEAD)" > "$RB/.claude/task-runner/gate-pass.json"
mkdir -p "$RB/.claude/task-runner/reductions"
printf '{"kind":"dispatch","id":"zq7k","reason":"x"}' > "$RB/.claude/task-runner/reductions/dispatch-zq7k.json"
T="$WS/said200.jsonl"; { asst "Reduced: zq7k, one dispatch."; zebra 199; } > "$T"
expect "disclosure tail: an id on the 200th-last line of assistant text counts as named" "$RB" "$T" 0 "__NONE__"
T="$WS/said201.jsonl"; { asst "Reduced: zq7k, one dispatch."; zebra 200; } > "$T"
expect "disclosure tail: an id on the 201st-last line is unread, the stop blocks" "$RB" "$T" 2 "never names"

P="$WS/proj"; mkdir -p "$P/src"
T="$WS/tail4000.jsonl"; { edit; lines '{"type":"progress"}' 3998; asst "Done."; } > "$T"
expect "transcript tail: an edit 4000 entries from the end is read, the naked claim blocks" "$P" "$T" 2 "$CLAIM_SUB"
T="$WS/tail4001.jsonl"; { edit; lines '{"type":"progress"}' 3999; asst "Done."; } > "$T"
expect "transcript tail: an edit 4001 entries from the end is unread, the claim passes" "$P" "$T" 0 "__NONE__"

for i in $(seq -w 1 25); do echo x > "$P/src/f$i.ts"; done
cites() { local i s=""; for i in $(seq -w 1 "$1"); do s="$s src/f$i.ts:1,"; done; printf 'See%s and src/zz_ghost.ts:9.' "$s"; }
T="$WS/cite25.jsonl"; { user "where"; asst "$(cites 24)"; } > "$T"
expect "citation cap: the 25th distinct citation is checked, a fabricated one blocks" "$P" "$T" 2 "cites a location that does not exist"
T="$WS/cite26.jsonl"; { user "where"; asst "$(cites 25)"; } > "$T"
expect "citation cap: a 26th citation is unchecked, a fabricated one passes" "$P" "$T" 0 "__NONE__"

QUOTE_SUB='quotes text that is not in that file'
for i in $(seq -w 1 21); do printf 'export const value_%s = compute(%s);\n' "$i" "$i" > "$P/src/q$i.ts"; done
quotes() { # <n> right quotes, then a wrong one in the next file
  local i
  for i in $(seq -w 1 "$1"); do printf 'src/q%s.ts:1 — quote: `export const value_%s = compute(%s);`\n' "$i" "$i" "$i"; done
  printf 'src/q%02d.ts:1 — quote: `export const value_none = invented();`' $(( 10#$1 + 1 ))
}
T="$WS/quote20.jsonl"; { user "review"; asst "$(quotes 19)"; } > "$T"
expect "quote cap: the 20th marked quote is checked, a wrong one blocks" "$P" "$T" 2 "src/q20.ts:1 $QUOTE_SUB"
T="$WS/quote21.jsonl"; { user "review"; asst "$(quotes 20)"; } > "$T"
expect "quote cap: a 21st marked quote is unchecked, a wrong one passes" "$P" "$T" 0 "__NONE__"
# The deadline counts bash's SECONDS, which a hook imports from its environment: the hook starts that many seconds in.
T="$WS/quote-late.jsonl"; { user "review"; asst "$(quotes 0)"; } > "$T"
HOOK_ENV="SECONDS=4" expect "quote deadline: a hook 4 s in still starts the check, a wrong quote blocks" "$P" "$T" 2 "$QUOTE_SUB"
HOOK_ENV="SECONDS=6" expect "quote deadline: a hook 6 s in starts none, a wrong quote passes" "$P" "$T" 0 "__NONE__"
# Per file:line, not per line: a git that takes 1.2 s a call pushes the first of two paths past the deadline, leaving the quote undecided.
SHIM="$WS/slowgit"; mkdir -p "$SHIM"
printf '#!/bin/sh\ncase " $* " in *" show "*|*" ls-files "*) sleep 1.2 ;; esac\nexec %s "$@"\n' "$(command -v git)" > "$SHIM/git"; chmod +x "$SHIM/git"
T="$WS/quote-two.jsonl"; { user "review"; asst 'src/q01.ts:1 and src/q02.ts:1 — quote: `export const value_none = invented();`'; } > "$T"
expect "quote deadline: a quote two files both lack blocks when there is time" "$P" "$T" 2 "$QUOTE_SUB"
t0=$SECONDS
HOOK_ENV="PATH=$SHIM:$PATH SECONDS=4" expect "quote deadline: the second file:line, reached past the deadline, leaves the quote undecided" "$P" "$T" 0 "__NONE__"
# The outcome alone cannot tell this from checking the second path late (the search would not judge it either): the time can.
el=$((SECONDS - t0))
if [ "$el" -lt 5 ]; then pass=$((pass+1)); printf 'PASS  quote deadline: the second path is never read, the hook returns in %s s (one slow path is 2.4 s)\n' "$el"
else fail=$((fail+1)); printf 'FAIL  quote deadline: the second path is never read (took %s s; reading it costs another 2.4 s)\n' "$el"; fi

# Through stdin: one exec argument is capped at 128 KiB on Linux, under the excerpt cap.
tres() { printf '%s' "$1" | jq -Rsc '{type:"user",message:{content:[{type:"tool_result",tool_use_id:"t1",content:.}]}}'; }
# The search of earlier tool output stops at the deadline too: a grep that takes 2.2 s on the first quote leaves the second unjudged.
SLOWGREP="$WS/slowgrep"; mkdir -p "$SLOWGREP"
printf '#!/bin/sh\ncase " $* " in *" -C3 "*) sleep 2.2 ;; esac\nexec %s "$@"\n' "$(command -v grep)" > "$SLOWGREP/grep"; chmod +x "$SLOWGREP/grep"
T="$WS/quote-search.jsonl"
{ user "review"; tres '+export const shipped = fromTheBranch();'
  asst $'src/q01.ts:1 — quote: `export const shipped = fromTheBranch();`\nsrc/q02.ts:1 — quote: `export const value_none = invented();`'; } > "$T"
expect "quote deadline, search: with time, a made-up quote after one found in tool output blocks" "$P" "$T" 2 "src/q02.ts:1 $QUOTE_SUB"
HOOK_ENV="PATH=$SLOWGREP:$PATH SECONDS=4" expect "quote deadline, search: reached past the deadline, it is not judged" "$P" "$T" 0 "__NONE__"

# The excerpt cap: QUOTE_EXCERPT_BYTES of context around a quote word is judged; one byte more gives way to the next word, and
#   a quote whose every word passes the cap is not judged. Both words here (zqrun…, xx) sit on all 4096 64-byte lines.
cap_case() { # <extra bytes> -> transcript path
  local f="$WS/excerpt$1.jsonl" body
  body=$(lines "$(printf 'zqrunzqtokenlongest%044d' 0 | tr 0 x)" 4096)
  [ "$1" = 0 ] || body="${body}x"
  # No user line: it would sit within the 3 lines of context grep adds and count toward the excerpt.
  { tres "$body"; asst 'src/q01.ts:1 — quote: `zqrunzqtokenlongest = xx`'; } > "$f"
  [ "$(jq -rs '.[0].message.content[0].content | length' "$f" 2>/dev/null)" -ge 262143 ] || echo "fixture: tool result missing from $f" >&2
  printf '%s' "$f"
}
expect "quote excerpt cap: 262144 bytes of context are judged, the made-up quote blocks" "$P" "$(cap_case 0)" 2 "$QUOTE_SUB"
expect "quote excerpt cap: one byte more for every word is not judged, the quote passes" "$P" "$(cap_case 1)" 0 "__NONE__"
T="$WS/excerpt-next.jsonl"; head -n 1 "$(cap_case 1)" > "$T"; asst 'src/q01.ts:1 — quote: `zqrunzqtokenlongest = absentword`' >> "$T"
expect "quote excerpt cap: a word past the cap gives way to the next, and one found nowhere blocks" "$P" "$T" 2 "$QUOTE_SUB"

# The extraction budget: a jq that takes 1 s over the transcript finishes inside QUOTE_EXTRACT_SECONDS (2) and the made-up quote
#   is judged; one that takes 3 s is killed, and nothing is judged.
SLOWJQ="$WS/slowjq"; mkdir -p "$SLOWJQ"
printf '#!/bin/sh\ncase "$*" in *cc-candor-quote*) sleep "${SLOWJQ_S:-0}" ;; esac\nexec %s "$@"\n' "$(command -v jq)" > "$SLOWJQ/jq"; chmod +x "$SLOWJQ/jq"
T="$WS/quote-extract.jsonl"; { user "review"; asst "$(quotes 0)"; } > "$T"
HOOK_ENV="PATH=$SLOWJQ:$PATH SLOWJQ_S=1" expect "quote extraction budget: 1 s of extraction is inside it, the made-up quote blocks" "$P" "$T" 2 "$QUOTE_SUB"
HOOK_ENV="PATH=$SLOWJQ:$PATH SLOWJQ_S=3" expect "quote extraction budget: 3 s is past it, nothing is judged, the quote passes" "$P" "$T" 0 "__NONE__"

pushback() { printf 'Are you sure? %s' "$(lines z "$(($1 - 14))" | tr -d '\n')"; }
T="$WS/push400.jsonl"; { asst "The retry is disabled."; user "$(pushback 400)"; asst "You're right, my mistake."; } > "$T"
expect "bare pushback: a 400-byte challenge is bare, the reversal blocks" "$P" "$T" 2 "retracts your position anyway"
T="$WS/push401.jsonl"; { asst "The retry is disabled."; user "$(pushback 401)"; asst "You're right, my mistake."; } > "$T"
expect "bare pushback: a 401-byte challenge is an argument, the reversal passes" "$P" "$T" 0 "__NONE__"

T="$WS/claim30.jsonl"; { edit; asst "Done."; zebra 29; } > "$T"
expect "claim window: a claim on the 30th-last line is read, the naked claim blocks" "$P" "$T" 2 "$CLAIM_SUB"
T="$WS/claim31.jsonl"; { edit; asst "Done."; zebra 30; } > "$T"
expect "claim window: a claim on the 31st-last line is unread, the turn passes" "$P" "$T" 0 "__NONE__"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
