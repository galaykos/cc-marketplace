#!/usr/bin/env bash
# run-cost.sh — one line: what this session's process cost since the registered run began (the mtime of .claude/task-runner/active-run.json, else closed-run.json) or --since.
# Misses: prices; another session's tokens (an index run resumed in a new session: minutes since the first registration, tokens of this session only); a --slug or --fresh re-registration restarts the count, and so does touching the record. Exits 0 always.
# Why, limits, history: rationale/derivations/plugin-task-runner.md § plugins/task-runner/scripts/run-cost.sh (marketplace repository)

# Usage:
#   run-cost.sh [--since <epoch seconds | ISO-8601 with a zone>]
set -u

# Shared block templates/blocks/process-cost.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/process-cost.md
# cc_process_cost <since>: one line, what this session's process cost from <since> (epoch seconds, or ISO-8601 with Z or an offset) to
# now, read from CLAUDE_CODE_SESSION_ID's transcript (~/.claude/projects/*/<id>.jsonl) and its agent transcripts (subagents/agent-*.jsonl,
# subagents/workflows/*/agent-*.jsonl): tokens (input, output, cache writes, cache reads) of every record timestamped at or after <since>,
# once per message.id across all files; agents = agent transcripts holding a counted record; whole minutes since <since>. No prices.
# Otherwise `Process cost: unknown — <reason>` (no jq, no session id, no transcript, a bad <since>, jq failed). Status 0 always.
# Misses: other sessions' transcripts, records with no timestamp, compaction (it writes no usage record), agents writing elsewhere.
cc_process_cost() {
  local since="${1:-}" sid="${CLAUDE_CODE_SESSION_ID:-}" t="" f out
  command -v jq >/dev/null 2>&1 || { echo "Process cost: unknown — jq not found"; return 0; }
  case "$sid" in '' | *[!A-Za-z0-9_-]*) echo "Process cost: unknown — no session id (CLAUDE_CODE_SESSION_ID)"; return 0 ;; esac
  for f in "${HOME:-}"/.claude/projects/*/"$sid".jsonl; do [ -f "$f" ] && { t=$f; break; }; done
  [ -n "$t" ] || { echo "Process cost: unknown — no transcript for session $sid"; return 0; }
  out=$(set -- "$t"
    for f in "${t%.jsonl}"/subagents/agent-*.jsonl "${t%.jsonl}"/subagents/workflows/*/agent-*.jsonl; do [ -f "$f" ] && set -- "$@" "$f"; done
    jq -nrR --arg since "$since" --arg main "$t" '
      def off: if . == "Z" then 0 else ((.[1:3] | tonumber) * 3600 + ((.[3:] | ltrimstr(":")) as $m
        | if $m == "" then 0 else ($m | tonumber) * 60 end)) * (if .[0:1] == "-" then -1 else 1 end) end;
      def ep: if test("^[0-9]+$") then tonumber else
        capture("^(?<d>[0-9]{4}-[0-9]{2}-[0-9]{2})[T ](?<h>[0-9]{2}:[0-9]{2})(?<s>:[0-9]{2})?(\\.[0-9]+)?(?<z>Z|[+-][0-9]{2}(:?[0-9]{2})?)$")
        | ("\(.d)T\(.h)\(.s // ":00")Z" | fromdateiso8601) - (.z | off) end;
      def when: [strings | try ep catch empty] | .[0];
      def count($r; $f): ($r.message | if type == "object" then . else {} end) as $m
        | ($m.usage | if type == "object" then . else null end) as $u | ($m.id | if type == "string" then . else null end) as $id
        | if $u == null or $m.model == "<synthetic>" or ($id != null and .seen[$id]) then . else
            (if $id != null then .seen[$id] = true else . end) | ($u.cache_read_input_tokens // 0) as $cr
            | (($u.input_tokens // 0) + ($u.output_tokens // 0) + ($u.cache_creation_input_tokens // 0) + $cr) as $n
            | .cr += $cr | if $f == $main then .main += $n else .sub += $n | .agents[$f] = true end end;
      def tok: if . >= 999500 then (. / 10000 | round) as $c | "\($c / 100 | floor).\($c % 100 | if . < 10 then "0\(.)" else "\(.)" end)M"
        elif . >= 1000 then "\(. / 1000 | round)k" else "\(.)" end;
      def clock: if strflocaltime("%Y-%m-%d") == (now | strflocaltime("%Y-%m-%d")) then strflocaltime("%H:%M")
        else strflocaltime("%Y-%m-%d %H:%M") end;
      ($since | when) as $s
      | if $s == null then "Process cost: unknown — since \($since | tojson) is neither epoch seconds nor ISO-8601 with a zone" else
          reduce (inputs | try fromjson catch null | objects) as $r ({seen: {}, agents: {}, main: 0, sub: 0, cr: 0};
            ($r.timestamp | when) as $t | if $t != null and $t >= $s then count($r; input_filename) else . end)
          | (.main + .sub) as $all | (.agents | length) as $n | (now - $s) as $el
          | "Process cost since \($s | clock): \($n) agent\(if $n == 1 then "" else "s" end) · \($all | tok) tokens (main \(.main | tok),"
            + " subagents \(.sub | tok); \(if $all > 0 then (.cr * 100 / $all | round) else 0 end)% cache reads)"
            + " · \(if $el > 0 then ($el / 60 | floor) else 0 end) min" end' "$@" 2>/dev/null) || out=""
  [ -n "$out" ] || out="Process cost: unknown — jq could not read the transcript"
  printf '%s\n' "$out"
  return 0
}

since=""
while [ $# -gt 0 ]; do
  case "$1" in
    --since) [ $# -ge 2 ] || { echo "Process cost: unknown — --since needs a value"; exit 0; }; since="$2"; shift 2 ;;
    -h | --help) sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Process cost: unknown — unknown argument $1 (usage: run-cost.sh [--since <time>])"; exit 0 ;;
  esac
done
if [ -z "$since" ]; then
  root=$(git rev-parse --show-toplevel 2>/dev/null) || root=$PWD
  for rec in "$root/.claude/task-runner/active-run.json" "$root/.claude/task-runner/closed-run.json"; do
    [ -f "$rec" ] && since=$(date -r "$rec" +%s 2>/dev/null) && break
  done
  [ -n "$since" ] || { echo "Process cost: unknown — no run record under $root/.claude/task-runner/ and no --since"; exit 0; }
fi
cc_process_cost "$since"
exit 0
