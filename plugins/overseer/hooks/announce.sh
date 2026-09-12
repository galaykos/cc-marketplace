#!/bin/bash
# Absolute-path shebang: the fail-open guarantee must hold under a stripped PATH.
# SessionStart announcer for the `overseer` plugin. Prints ONE line when the project
# has an open program (a milestone that is neither done nor parked) so a fresh session
# knows to /overseer:resume instead of starting cold. Resolves the project the same way
# program.sh does — the git toplevel of the session cwd, else the cwd itself — so a
# session opened in a subdirectory is still announced. Silent when no program exists,
# when every milestone is done or parked (that program is closed; `program.sh close`
# archives it), or on any error. Pure read — writes nothing.
# Killed (timeout 10s): prints nothing; the resume command still works, so a missed
# announcement costs one manual /overseer:status, never state.
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
