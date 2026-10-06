#!/usr/bin/env bash
# status-core.test.sh — hooks/status-core.ts under node: on each fixture nextMilestone names the milestone that
#   program.sh's NEXT_FILTER (copied from program.sh at run time, never retyped) selects; overseerLine renders the line.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CORE="$ROOT/hooks/status-core.ts"; PROG="$ROOT/scripts/program.sh"
for c in node jq; do command -v "$c" >/dev/null || { echo "FAIL: $c is required"; exit 1; }; done
ERR=$(mktemp); trap 'rm -f "$ERR"' EXIT
pass=0; fail=0

ok()  { pass=$((pass+1)); printf 'PASS  %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL  %s\n      %s\n' "$1" "$2"; }

line=$(grep -m1 "^NEXT_FILTER='.*'$" "$PROG") || { echo "FAIL: no NEXT_FILTER='...' line in $PROG"; exit 1; }
NEXT_FILTER=${line#NEXT_FILTER=\'}; NEXT_FILTER=${NEXT_FILTER%\'}

CASES='
import { pathToFileURL } from "node:url"
const { nextMilestone, overseerLine } = await import(pathToFileURL(process.argv[1]).href)
const m = (id, status, depends) => ({ id, title: "Title " + id, branch: "feat/" + id, kind: "feature", depends, status })
const named = (r) => r === null ? "none" : `${r.k}/${r.n} ${r.id}`
const inFlight = { milestones: [m("m1", "done", []), { ...m("m2", "accepting", ["m1"]), title: "Client list" }, m("m3", "queued", [])] }
const fixtures = [
  ["all queued, depends absent or null: the first", "1/3 m1",
    { milestones: [m("m1", "queued"), m("m2", "queued", ["m1"]), m("m3", "queued", null)] }],
  ["the first done: the next, in flight, whose dependency it was", "2/3 m2", inFlight],
  ["a milestone whose dependency is not done is skipped", "2/2 m2",
    { milestones: [m("m1", "queued", ["m2"]), m("m2", "queued", [])] }],
  ["a parked milestone is skipped", "2/2 m2", { milestones: [m("m1", "parked", []), m("m2", "queued", [])] }],
  ["a parked dependency is never met", "3/3 m3",
    { milestones: [m("m1", "parked", []), m("m2", "queued", ["m1"]), m("m3", "briefed", [])] }],
  ["every dependency must be done, not just one; null depends waits on nothing", "4/4 m4",
    { milestones: [m("m1", "done", []), m("m2", "parked", []), m("m3", "queued", ["m1", "m2"]), m("m4", "queued", null)] }],
  ["an open milestone waiting only on a parked one: none", "none",
    { milestones: [m("m1", "parked", []), m("m2", "queued", ["m1"])] }],
  ["no milestones yet: none", "none", { goal: "g", milestones: [] }],
  ["every milestone done or parked: none", "none",
    { milestones: [m("m1", "done", []), m("m2", "parked", []), m("m3", "done", ["m1"])] }],
  ["malformed, a null program: none", "none", null],
  ["malformed, no milestones list: none", "none", { goal: "g" }],
  ["malformed, a milestone that is not an object: none", "none", { milestones: ["m1"] }],
  ["malformed, depends that is not a list: none", "none", { milestones: [m("m1", "queued", "m0")] }],
]
for (const [label, want, program] of fixtures) {
  const json = JSON.stringify(program)
  console.log([label, want, named(nextMilestone(JSON.parse(json))), json].join("\t"))
}
console.log(["overseerLine renders the spec line", "overseer  milestone 2/3  m2 Client list (accepting)",
  overseerLine(nextMilestone(inFlight)), ""].join("\t"))
'

if out=$(node --input-type=module -e "$CASES" "$CORE" 2>"$ERR"); then
  while IFS=$'\t' read -r name want got json; do
    [ "$got" = "$want" ] || { bad "$name" "status-core.ts: got $got, want $want"; continue; }
    if [ -n "$json" ]; then
      # program.sh reads a jq error as no next milestone: its `nxt=$(jq ...)` comes back empty.
      jqid=$(jq -r "$NEXT_FILTER | .id // \"none\"" <<<"$json" 2>/dev/null) || jqid=none
      [ "$jqid" = "${want##* }" ] || { bad "$name" "program.sh NEXT_FILTER: got $jqid, want ${want##* }"; continue; }
    fi
    ok "$name"
  done <<<"$out"
else
  bad "node runs status-core.ts" "$(cat "$ERR")"
fi

printf '\nstatus-core: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
