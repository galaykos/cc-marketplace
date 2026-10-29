#!/usr/bin/env bash
# Fixtures for scripts/run-cost.sh and the process-cost block it pastes, run by CI through the plugins/*/scripts/__tests__/*.test.sh glob.
# Each counting rule has a fire case and a control on the same fixture; every unknown path must still exit 0.
set -u
unset CLAUDE_PROJECT_DIR
export TZ=UTC
here=$(cd "$(dirname "$0")" && pwd)
PLUGIN=$(cd "$here/../.." && pwd)
RC="$PLUGIN/scripts/run-cost.sh"
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available"; exit 0; }
command -v git >/dev/null 2>&1 || { echo "SKIP: git not available"; exit 0; }

rc=0
WS=$(mktemp -d); trap 'rm -rf "$WS"' EXIT
export HOME="$WS/home"
P="$HOME/.claude/projects/-work-proj"; mkdir -p "$P"
S=1767261600   # 2026-01-01T10:00:00Z
LINE="Process cost since 2026-01-01 10:00:"

check() { # check <label> <want-regex> <args to run-cost.sh>…, run from $IN (default: a dir in no git repo)
  local label=$1 want=$2 out got; shift 2
  out=$(cd "${IN:-$WS}" && bash "$RC" "$@" 2>&1); got=$?
  if [ "$got" = 0 ] && printf '%s\n' "$out" | grep -qE -- "$want"; then echo "PASS: $label"
  else echo "FAIL: $label — want exit 0 and /$want/; got exit $got: $out"; rc=1; fi
}
# rec <ts|-> <message id> <model> <input> <output> <cache write> <cache read>; `-` writes no timestamp
rec() {
  local ts='"timestamp":"'"$1"'",'; [ "$1" = - ] && ts=''
  printf '{"type":"assistant",%s"message":{"id":"%s","model":"%s","role":"assistant","content":[{"type":"text","text":"x"}],"usage":{"input_tokens":%s,"output_tokens":%s,"cache_creation_input_tokens":%s,"cache_read_input_tokens":%s}}}\n' \
    "$ts" "$2" "$3" "$4" "$5" "$6" "$7"
}
user() { printf '{"type":"user","timestamp":"%s","message":{"role":"user","content":"go"}}\n' "$1"; }

# From 10:00 on: main 3,000 tokens (2,700 cache reads), agents 17,000 (14,900) in three transcripts: a resumed one, a plain one and a
# workflow one. 20k, 88%. Before 10:00: 1,000 main tokens, a 50,000-token agent, the resumed agent's 20,000 and the workflow agent's 5,000.
main_fixture() { # main_fixture <session> <second id of m2> <id of the fork's copy of m2>
  local A="$P/$1/subagents"; mkdir -p "$A/workflows/wf_1"
  { printf '{"type":"last-prompt","sessionId":"%s"}\n' "$1"
    rec 2026-01-01T09:59:59.500Z m0 claude-opus-5-5 1000 0 0 0
    rec 2026-01-01T10:00:00.000Z m1 claude-opus-5-5 1 9 90 900
    rec 2026-01-01T10:00:02.000Z m2 claude-opus-5-5 2 18 180 1800
    rec 2026-01-01T10:00:02.100Z "$2" claude-opus-5-5 2 18 180 1800
    printf '{"type":"assistant","timestamp":"2026-01-01T10:00:0\n'
    rec 2026-01-01T10:00:03.000Z m3 '<synthetic>' 5000 0 0 0
    rec - m4 claude-opus-5-5 4000 0 0 0
  } > "$P/$1.jsonl"
  { user 2026-01-01T09:00:00.000Z; rec 2026-01-01T09:00:01.000Z b1 claude-opus-5-5 50000 0 0 0; } > "$A/agent-before.jsonl"
  { user 2026-01-01T09:30:00.000Z; rec 2026-01-01T09:30:01.000Z r1 claude-opus-5-5 20000 0 0 0
    user 2026-01-01T10:09:00.000Z; rec 2026-01-01T10:10:00.000Z r2 claude-opus-5-5 0 100 0 900; } > "$A/agent-resumed.jsonl"
  { printf '{"type":"summary"}\n'; user 2026-01-01T10:05:00.000Z; rec 2026-01-01T10:05:01.000Z s1 claude-opus-5-5 0 300 700 6000
    rec 2026-01-01T10:05:01.300Z s1 claude-opus-5-5 0 300 700 6000; } > "$A/agent-after.jsonl"
  { rec 2026-01-01T10:00:02.000Z "$3" claude-opus-5-5 2 18 180 1800; } > "$A/agent-fork.jsonl"
  { rec - u1 claude-opus-5-5 3000 0 0 0; } > "$A/agent-untimed.jsonl"
  { rec 2026-01-01T09:50:00.000Z w0 claude-opus-5-5 5000 0 0 0; rec 2026-01-01T10:20:00.000Z w1 claude-opus-5-5 0 500 500 8000; } > "$A/workflows/wf_1/agent-w.jsonl"
  printf '{"agentType":"workflow-subagent"}\n' > "$A/workflows/wf_1/agent-w.meta.json"
}
main_fixture s-main m2 m2
main_fixture s-nodedupe m2b m2c
export CLAUDE_CODE_SESSION_ID=s-main

check "a record exactly at since counts; one message.id across records and files counts once; <synthetic>, untimed and torn records count nothing" \
  "^$LINE 3 agents · 20k tokens \(main 3k, subagents 17k; 88% cache reads\) · [0-9]+ min$" --since "$S"
CLAUDE_CODE_SESSION_ID=s-nodedupe check "dedupe control: the same records under other ids count twice, and the fork becomes an agent" \
  "^$LINE 4 agents · 24k tokens \(main 5k, subagents 19k; 88% cache reads\)" --since "$S"
check "since control: an hour earlier every earlier record counts, by its own time, in main and in every agent transcript" \
  "^Process cost since 2026-01-01 09:00: 4 agents · 96k tokens \(main 4k, subagents 92k; 18% cache reads\)" --since $((S - 3600))
check "since control: one minute earlier the 09:59:59 main record counts; the resumed agent's 09:30 record and the workflow's 09:50 do not" \
  "^Process cost since 2026-01-01 09:59: 3 agents · 21k tokens \(main 4k, subagents 17k; " --since $((S - 60))
check "since control: one second later the record exactly at 10:00:00 no longer counts" \
  "^$LINE 3 agents · 19k tokens \(main 2k, subagents 17k; " --since $((S + 1))

for since in 2026-01-01T10:00:00Z 2026-01-01T12:00:00+02:00 2026-01-01T05:00-05:00 "2026-01-01 10:00:00.000Z"; do
  check "ISO-8601 since $since reads as the epoch $S" "^$LINE 3 agents · 20k tokens" --since "$since"
done
check "an ISO-8601 time with no zone is unknown, exit 0" "^Process cost: unknown — since \"2026-01-01T10:00:00\" is neither" --since 2026-01-01T10:00:00
check "a word is unknown, exit 0" "^Process cost: unknown — since \"yesterday\" is neither" --since yesterday
s=$(( $(date +%s) - 630 ))
hm=$(date -u -d "@$s" +%H:%M 2>/dev/null || date -u -r "$s" +%H:%M)
day=$(date -u -d "@$s" +%F 2>/dev/null || date -u -r "$s" +%F)
[ "$day" = "$(date -u +%F)" ] || hm="$day $hm"
check "a since today is labelled HH:MM, and minutes are whole minutes since it" "^Process cost since $hm: 0 agents · 0 tokens .* · 10 min$" --since "$s"

tokens() { # tokens <session> <main input> [<agent input>]: one record after 10:00 in the main thread, one in an agent
  mkdir -p "$P/$1/subagents"; rec 2026-01-01T10:00:01.000Z "$1-a" claude-opus-5-5 "$2" 0 0 0 > "$P/$1.jsonl"
  [ -z "${3:-}" ] || rec 2026-01-01T10:00:02.000Z "$1-b" claude-opus-5-5 "$3" 0 0 0 > "$P/$1/subagents/agent-1.jsonl"
}
tokens s-m 999500; tokens s-m2 999499; tokens s-k 0 1600; tokens s-u 999
CLAUDE_CODE_SESSION_ID=s-m check "999,500 tokens print as 1.00M" "^$LINE 0 agents · 1.00M tokens \(main 1.00M, subagents 0;" --since "$S"
CLAUDE_CODE_SESSION_ID=s-m2 check "999,499 tokens print as 999k" "^$LINE 0 agents · 999k tokens \(main 999k, subagents 0;" --since "$S"
CLAUDE_CODE_SESSION_ID=s-k check "1,600 tokens round to 2k; one agent is singular" "^$LINE 1 agent · 2k tokens \(main 0, subagents 2k; 0% cache reads\)" --since "$S"
CLAUDE_CODE_SESSION_ID=s-u check "under 1,000 tokens print as the number" "^$LINE 0 agents · 999 tokens \(main 999, subagents 0;" --since "$S"
P2="$HOME/.claude/projects/-work-big"; mkdir -p "$P2"
rec 2026-01-01T10:00:01.000Z big1 claude-opus-5-5 240000 0 0 1600000 > "$P2/s-big.jsonl"
CLAUDE_CODE_SESSION_ID=s-big check "millions print as M with two decimals; a transcript in another project dir is found; no agents dir is zero" \
  "^$LINE 0 agents · 1.84M tokens \(main 1.84M, subagents 0; 87% cache reads\)" --since "$S"

out=$(env -u CLAUDE_CODE_SESSION_ID bash "$RC" --since "$S" 2>&1); got=$?
[ "$got" = 0 ] && [ "$out" = "Process cost: unknown — no session id (CLAUDE_CODE_SESSION_ID)" ] && echo "PASS: no session id is unknown, exit 0" \
  || { echo "FAIL: no session id — got exit $got: $out"; rc=1; }
CLAUDE_CODE_SESSION_ID='../x' check "a session id with a path character is unknown, exit 0" "^Process cost: unknown — no session id" --since "$S"
CLAUDE_CODE_SESSION_ID=s-none check "no transcript for the session is unknown, exit 0" "^Process cost: unknown — no transcript for session s-none" --since "$S"
out=$(PATH=/nonexistent "$BASH" "$RC" --since "$S" 2>&1); got=$?
[ "$got" = 0 ] && [ "$out" = "Process cost: unknown — jq not found" ] && echo "PASS: no jq on PATH is unknown, exit 0" \
  || { echo "FAIL: no jq on PATH — got exit $got: $out"; rc=1; }
printf '{"type":"assistant","timestamp":"2026-01-01T10:00:01Z"' > "$P/s-torn.jsonl"
CLAUDE_CODE_SESSION_ID=s-torn check "a transcript holding only a torn line counts zero, exit 0" \
  "^$LINE 0 agents · 0 tokens \(main 0, subagents 0; 0% cache reads\)" --since "$S"
check "an unknown argument is unknown, exit 0" "^Process cost: unknown — unknown argument --bogus" --bogus
check "--since with no value is unknown, exit 0" "^Process cost: unknown — --since needs a value" --since

REPO="$WS/repo"; mkdir -p "$REPO/sub/dir" "$REPO/.claude/task-runner"
git -C "$REPO" init -q
run_in() { IN="$REPO/sub/dir" check "$@"; }
run_in "no run record and no --since is unknown, exit 0" "^Process cost: unknown — no run record under $REPO/.claude/task-runner/"
printf '{"slug":"demo"}\n' > "$REPO/.claude/task-runner/closed-run.json"
TZ=UTC touch -t 202601011000.00 "$REPO/.claude/task-runner/closed-run.json"
run_in "a closed run counts from closed-run.json's mtime, from a subdirectory of the repo" "^$LINE 3 agents · 20k tokens"
printf '{"slug":"demo"}\n' > "$REPO/.claude/task-runner/active-run.json"
TZ=UTC touch -t 202601010900.00 "$REPO/.claude/task-runner/active-run.json"
run_in "active-run.json wins over closed-run.json" "^Process cost since 2026-01-01 09:00: 4 agents · 96k tokens"
run_in "--since wins over the run record" "^$LINE 3 agents · 20k tokens" --since "$S"

grep -q 'scripts/run-cost\.sh' "$PLUGIN/commands/run.md" \
  && echo "PASS: /task-runner:run's completion report calls scripts/run-cost.sh" \
  || { echo "FAIL: commands/run.md does not call scripts/run-cost.sh"; rc=1; }

exit $rc
