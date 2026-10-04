#!/usr/bin/env bash
# gate-pins.test.sh — pins both sides of each named limit in hooks/gate.sh: the in-flight record TTL, the disclosure tail,
#   the transcript tail, the citation cap, the bare-pushback length and the claim window.
set -u

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
HOOK="$ROOT/plugins/candor/hooks/gate.sh"

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

# expect <label> <cwd> <transcript> <rc> <stderr-substring|__NONE__> [session_id]
expect() {
  local label="$1" err rc ok=1
  rm -rf "$2/.claude/candor" "$2/.claude/task-runner/gate-nudge"
  err=$(stop_json "$2" "$3" "${6:-}" | bash "$HOOK" 2>&1 >/dev/null); rc=$?
  [ "$rc" -eq "$4" ] || ok=0
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

RUN_SUB='registered run with no behavioral-gate pass'
CLAIM_SUB='no command ran after the last edit'

# A find -mmin age is truncated by GNU and rounded up by BSD, so each record sits two minutes off the boundary.
RA="$WS/inflight"; repo "$RA"
SID="sess-pins"
IDIR="$TMPDIR/cc-candor-inflight-$(printf '%s' "$SID" | cksum | cut -d' ' -f1)"
REC="$IDIR/$(printf '%s' agentA | cksum | cut -d' ' -f1)"
CLEAN="$WS/clean.jsonl"; { user "run the cards"; asst "Waiting on the workers."; } > "$CLEAN"
mkdir -p "$IDIR"; printf 'agentA\n' > "$REC"; age_minutes "$REC" 178
expect "in-flight TTL: a 178-minute record still counts, the stop is not blocked" "$RA" "$CLEAN" 0 "still in flight" "$SID"
printf 'agentA\n' > "$REC"; age_minutes "$REC" 182
expect "in-flight TTL: a 182-minute record is swept, the stop blocks" "$RA" "$CLEAN" 2 "$RUN_SUB" "$SID"
if [ ! -e "$REC" ]; then pass=$((pass+1)); printf 'PASS  in-flight TTL: the 182-minute record is deleted from disk\n'
else fail=$((fail+1)); printf 'FAIL  in-flight TTL: the 182-minute record is deleted from disk\n'; fi

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
