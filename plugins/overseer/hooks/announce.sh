#!/bin/bash
# announce.sh — SessionStart: one line when the project (git toplevel of the cwd, else the cwd, as program.sh resolves it) has an open overseer program, a milestone neither done nor parked, naming the next runnable one and /overseer:resume. Pure read; silent otherwise and on any error.
# Misses: nothing is printed when killed (timeout 10s); a missed line costs one manual /overseer:status, never state.
# Why, limits, history: rationale/derivations/plugin-overseer.md § plugins/overseer/hooks/announce.sh
{
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
  [ -n "$cwd" ] && [ -d "$cwd" ] || exit 0
  root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || root="$cwd"
  state="$root/.claude/overseer/program.json"
  [ -s "$state" ] || exit 0
  line=$(jq -r '
    (.milestones // []) as $m
    | . as $p
    | ($m | map(select(.status != "done" and .status != "parked"))) as $open
    | ([$m[] | select(.status != "done" and .status != "parked")
        | select(all((.depends // [])[]; . as $d | any($p.milestones[]; .id==$d and .status=="done")))] | .[0]) as $next
    | if ($open | length) == 0 then empty else
      "ℹ overseer: program \"" + (.goal // "?") + "\" open — "
      + (($m | map(select(.status == "done")) | length) | tostring) + "/" + (($m | length) | tostring)
      + " milestones done; next: "
      + (if $next == null then "none runnable (a dependency is parked)" else ($next.id // "?") + " " + ($next.title // "") + " (" + ($next.status // "?") + ")" end)
      + ". Run /overseer:resume to continue."
      end' "$state" 2>/dev/null) || exit 0
  [ -n "$line" ] && printf '%s\n' "$line"
} 2>/dev/null
exit 0
