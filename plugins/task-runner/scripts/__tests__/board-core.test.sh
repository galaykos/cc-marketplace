#!/usr/bin/env bash
# board-core.test.sh — hooks/board-core.ts under node: parseIndex on a fixture for each status form, marker, blockquote,
#   milestone and missing-table case and on this run's real index when the gitignored taskmaster-docs/ copy exists;
#   counts, statusLine and planLine exact strings, record names and the running.pid rule as candor's gate.sh reads them;
#   its open-card count against hooks/announce.sh on the same index; receiptOf against scripts/check-receipt.sh's real output.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CORE="$ROOT/hooks/board-core.ts"
REAL="$ROOT/../../taskmaster-docs/tasks/2026-10-06-ship-claude-code-mods/00-INDEX.md"
command -v node >/dev/null || { echo "FAIL: node is required"; exit 1; }
WS=$(mktemp -d); trap 'rm -rf "$WS"' EXIT
pass=0; fail=0

ok()  { pass=$((pass+1)); printf 'PASS  %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL  %s\n      %s\n' "$1" "$2"; }

cat > "$WS/base.md" <<'EOF'
# Task index — demo

Spec: taskmaster-docs/specs/2026-01-01-demo.md
Branch: feat/demo

## Upgraded statement

> Ship the demo board.
> Ultra: true (model=auto, effort=xhigh)

## Cards

| Card | Title | Depends-on | Agent | Parallel group | Status |
|---|---|---|---|---|---|
| 01 | Done with a note | none | backend | A | done (abc123; review: 2 minor → backlog) |
| 02 | Working | - | backend | A | in_progress (delegated; worker web-dev) |
| 03 | Parked | 01 | generic | B | parked(needs an API key) |
| 04 | Blocked | 03 | generic | B | blocked-by 03 |
| 05 | Pending | 01, 02 | frontend | C | pending |
| 06 | Skipped | 01 | generic | C | skipped (superseded by 05) |
| 07 | No trailing pipe | 05 | generic | D | Done

## Milestones

### Milestone M0 — first thing
Files: a/
Cards: 01, 02, 05

### Milestone M1 — second thing
Files: b/
Cards: 03, 04, 06

## Run note

Cards: 07
Boosted runs stamp an Ultra: true line near the top.

## Coverage

| Success criterion | Covered by | Status |
| --- | --- | --- |
| SC1 demo | 01 | covered |
EOF
if [ -r "$REAL" ]; then cp "$REAL" "$WS/real.md"; else printf 'SKIP  the real index (taskmaster-docs/ is gitignored and absent here)\n'; fi

CASES='
import { existsSync, readFileSync } from "node:fs"
import { pathToFileURL } from "node:url"
const { parseIndex, counts, statusLine, planLine, recordsOf, checkPid, cardKey, receiptOf } = await import(pathToFileURL(process.argv[1]).href)
const ws = process.argv[2]
const base = readFileSync(ws + "/base.md", "utf8")
const b = parseIndex(base, "demo")
const withMarkers = (lines) => parseIndex(base.replace("Branch: feat/demo\n", "Branch: feat/demo\n" + lines.join("\n") + "\n"), "demo").marker
const board = (statuses, marker = null) => ({ slug: "s", specPath: null, marker, milestones: [],
  cards: statuses.map((status, i) => ({ id: String(i + 1).padStart(2, "0"), title: "t", dependsOn: [], group: "A", status })) })
const ULTRA = "Ultra: true (model=auto, effort=xhigh)"
const GOAL = "Goal: true (model=auto, effort=xhigh) — requires task-runner ≥0.11.0; older runners fall back to interactive execution"
const LEAN = "Goal: true (boost=off) — requires task-runner ≥0.32.0; older runners read a lone Goal marker as boosted"
const REG = 1_000_000
const at = (name, mtimeMs = REG + 1) => ({ name, mtimeMs })
const HEAD = "9f1c2b3a4d5e6f708192a3b4c5d6e7f8091a2b3c"
const NOW = 1_800_000_000_000
const pidFile = (deadline, sha = "9f1c2b3a") => `4242\n${sha}\n${deadline}\n`
const cases = [
  ["done, in_progress, parked(...), blocked-by, pending and skipped map to board statuses",
    b.cards.map((c) => c.status), ["done", "in_progress", "parked", "blocked", "pending", "parked", "done"]],
  ["none and - dependency cells are empty, a comma list splits", b.cards.map((c) => c.dependsOn),
    [[], [], ["01"], ["03"], ["01", "02"], ["01"], ["05"]]],
  ["a capitalised header with an agent column still finds titles and groups", b.cards.map((c) => [c.id, c.title, c.group]),
    [["01", "Done with a note", "A"], ["02", "Working", "A"], ["03", "Parked", "B"], ["04", "Blocked", "B"],
     ["05", "Pending", "C"], ["06", "Skipped", "C"], ["07", "No trailing pipe", "D"]]],
  ["milestones come from their headings, cards from Cards: lines inside them only",
    [b.milestones, b.cards.map((c) => String(c.milestone))],
    [[{ id: "M0", title: "first thing" }, { id: "M1", title: "second thing" }], ["M0", "M0", "M1", "M1", "M0", "M1", "undefined"]]],
  ["an extra column before title moves no field",
    parseIndex("| card | files | title | depends-on | agent | parallel group | status |\n|---|---|---|---|---|---|---|\n" +
      "| 02 | a.ts | Second | 01 | backend | A | pending |\n", "x").cards.map((c) => [c.id, c.title, c.dependsOn, c.group]),
    [["02", "Second", ["01"], "A"]]],
  ["the spec path is read; neither a blockquoted nor a mid-line Ultra: true is a marker", [b.slug, b.specPath, b.marker],
    ["demo", "taskmaster-docs/specs/2026-01-01-demo.md", null]],
  ["a spec path in a blockquote above the Spec: line is ignored",
    parseIndex(base.replace("Spec: ", "> Superseded: taskmaster-docs/specs/2025-01-01-old.md\n\nSpec: "), "demo").specPath,
    "taskmaster-docs/specs/2026-01-01-demo.md"],
  ["an Ultra: line alone is ULTRA", withMarkers([ULTRA]), "ULTRA"],
  ["Goal: and Ultra: lines together are GOAL", withMarkers([ULTRA, GOAL]), "GOAL"],
  ["a Goal: true (boost=off) line is GOAL lean", withMarkers([LEAN]), "GOAL lean"],
  ["card-shaped rows under a header with no card column are no card table",
    parseIndex("# Index\n\n| # | Title | Status |\n|---|---|---|\n| 01 | a | done |\n", "x"), { error: "no card table" }],
  ["a card table with no two-digit card rows is no card table",
    parseIndex("| card | title | status |\n|---|---|---|\n| 1 | a | done |\n", "x"), { error: "no card table" }],
  ["in progress and in-progress read as in_progress, a 1 or 03/04 dependency keeps only two-digit ids",
    parseIndex("| card | title | depends-on | status |\n|---|---|---|---|\n| 01 | a | 1, 03/04 | in progress |\n| 02 | b | #01 | in-progress |\n", "x")
      .cards.map((c) => [c.status, c.dependsOn]), [["in_progress", ["03", "04"]], ["in_progress", ["01"]]]],
  ["counts on the fixture", counts(b), { total: 7, done: 2, parked: 2, unrecognised: 0, inProgress: true }],
  ["a status outside the vocabulary is unrecognised, never pending; an empty or pending cell is pending",
    parseIndex("| card | title | status |\n|---|---|---|\n| 01 | a | committed e93ffc7 — verify 7/7 |\n| 02 | b |  |\n| 03 | c | pending |\n| 04 | d | done — committed f403ab9 |\n", "x")
      .cards.map((c) => c.status), ["unrecognised", "pending", "pending", "done"]],
  ["status line names unrecognised cards after parked ones", statusLine(board(["unrecognised", "unrecognised", "done", "parked"]), "build", null),
    "task-runner  build 5/8  card 1/4  1 parked  2 unrecognised"],
  ["status line while a card is in progress counts it", statusLine(board(["done", "done", "in_progress", "pending"]), "build", null),
    "task-runner  build 5/8  card 3/4"],
  ["status line with two cards in progress counts one", statusLine(board(["done", "in_progress", "in_progress", "pending"]), "build", null),
    "task-runner  build 5/8  card 2/4"],
  ["status line with every card done", statusLine(board(["done", "done", "done"]), "verify", null), "task-runner  verify 6/8  card 3/3"],
  ["status line names parked cards before the marker", statusLine(board(["done", "in_progress", "parked", "blocked"], "GOAL"), "build", null),
    "task-runner  build 5/8  card 2/4  1 parked  goal"],
  ["status line marker words: ULTRA ultra, GOAL and GOAL lean goal",
    ["ULTRA", "GOAL", "GOAL lean"].map((mk) => statusLine(board(["in_progress", "pending"], mk), "build", null)),
    ["task-runner  build 5/8  card 1/2  ultra", "task-runner  build 5/8  card 1/2  goal", "task-runner  build 5/8  card 1/2  goal"]],
  ["status line places each arc phase k of 8, and shows a phase outside the arc bare",
    ["understand", "plan", "review", "ship", "triage", ""].map((phase) => statusLine(null, phase, null)),
    ["task-runner  understand 1/8", "task-runner  plan 4/8", "task-runner  review 7/8", "task-runner  ship 8/8", "task-runner  triage", "task-runner"]],
  ["status line ends with the minutes the background check has run, on a plain run too",
    [statusLine(board(["done", "in_progress", "parked"], "ULTRA"), "verify", 12), statusLine(null, "build", 0)],
    ["task-runner  verify 6/8  card 2/3  1 parked  ultra  check running 12m", "task-runner  build 5/8  check running 0m"]],
  ["status line ends with suite ✓ and the commit for a fresh receipt only",
    [statusLine(board(["done", "in_progress"]), "verify", 3, { isFresh: true, head: "9f1c2b3", cmd: "make test" }),
     statusLine(null, "build", null, { isFresh: false, reason: "files changed since suite ran at 9f1c2b3" }), statusLine(null, "build", null, null)],
    ["task-runner  verify 6/8  card 2/2  check running 3m  suite ✓ 9f1c2b3", "task-runner  build 5/8", "task-runner  build 5/8"]],
  ["receipt: fresh only on exit 0 with a fresh: line naming 7 hex digits and the command; stale keeps the reason on exit 1",
    [receiptOf(0, "fresh: suite passed at 9f1c2b3 (bash -c \"a && (b)\")\n"), receiptOf(1, "stale: the receipt is for another commit (0123456), not 9f1c2b3\n")],
    [{ isFresh: true, head: "9f1c2b3", cmd: "bash -c \"a && (b)\"" },{ isFresh: false, reason: "the receipt is for another commit (0123456), not 9f1c2b3" }]],
  ["receipt: a fresh: line with another exit, a stale: line with exit 0, no line, no exit or a short sha cannot be checked",
    [receiptOf(1, "fresh: suite passed at 9f1c2b3 (x)"), receiptOf(0, "stale: x"), receiptOf(0, ""), receiptOf(null, ""), receiptOf(0, "fresh: suite passed at 9f1c2b (x)")]
      .map((r) => r.isFresh || r.reason),
    Array(5).fill("the receipt could not be checked")],
  ["taskmaster line for understand, shape, decide and plan only",
    ["understand", "shape", "decide", "plan", "build", "verify", "", "Shape"].map((phase) => planLine(phase) ?? null),
    ["taskmaster  understand 1/8", "taskmaster  shape 2/8", "taskmaster  decide 3/8", "taskmaster  plan 4/8", null, null, null, null]],
  ["records: review seen, skip and exempt; control pass and skip; other names are not records",
    recordsOf([at("rv-seen-01.json"), at("rv-skip-02.json"), at("rv-exempt-03.json"), at("rv-agent-04@code-review.code-reviewer.json"),
      at("diff-05.patch"), at("rv-seen-06.json.tmp")],
      [at("nc-pass-01.json"), at("nc-skip-02.json"), at("nc-fail-03.json"), at("nc-pass-04.txt")], REG),
    { review: { "1": "yes", "2": "skip", "3": "exempt" }, control: { "1": "yes", "2": "skip" } }],
  ["records: only those newer than the registration count, an equal mtime is not newer",
    recordsOf([at("rv-seen-01.json", REG - 5), at("rv-seen-02.json", REG), at("rv-seen-03.json", REG + 1)],
      [at("nc-pass-01.json", REG - 5), at("nc-pass-03.json", REG + 1)], REG),
    { review: { "3": "yes" }, control: { "3": "yes" } }],
  ["records: a range- review id is the whole-diff review, not a card; a range- control id is kept, as gate.sh counts it",
    recordsOf([at("rv-skip-range-9f1c2b3a4d5e.json"), at("rv-exempt-range-9f1c2b3a4d5e.json")], [at("nc-pass-range-x.json")], REG),
    { review: {}, control: { "range-x": "yes" } }],
  ["records: a real record outranks a skip, a skip an exempt, in any listing order",
    [recordsOf([at("rv-exempt-01.json"), at("rv-skip-01.json"), at("rv-seen-01.json"), at("rv-exempt-02.json"), at("rv-skip-02.json")],
      [at("nc-skip-01.json"), at("nc-pass-01.json")], REG),
     recordsOf([at("rv-seen-01.json"), at("rv-skip-01.json"), at("rv-exempt-01.json"), at("rv-skip-02.json"), at("rv-exempt-02.json")],
      [at("nc-pass-01.json"), at("nc-skip-01.json")], REG)],
    [{ review: { "1": "yes", "2": "skip" }, control: { "1": "yes" } }, { review: { "1": "yes", "2": "skip" }, control: { "1": "yes" } }]],
  ["a numeric card id loses its leading zeros, any other id is kept",
    ["01", "1", "001", "0", "00", "10", "1a", "A01", "range-01", ""].map(cardKey), ["1", "1", "1", "0", "0", "10", "1a", "A01", "range-01", ""]],
  ["records: --card 1 and --card 001 are the index card 01, ranked together",
    recordsOf([at("rv-skip-01.json"), at("rv-seen-1.json"), at("rv-exempt-002.json")], [at("nc-pass-001.json")], REG),
    { review: { "1": "yes", "2": "exempt" }, control: { "1": "yes" } }],
  ["running.pid: the PID while the deadline is ahead and the sha starts HEAD, none once it has passed",
    [checkPid(pidFile(NOW / 1000 + 1), 0, NOW, HEAD), checkPid(pidFile(NOW / 1000), 0, NOW, HEAD)], ["4242", null]],
  ["running.pid: another HEAD, a sha under 7 hex digits, a non-hex sha or a non-numeric PID is no check",
    [checkPid(pidFile(NOW / 1000 + 60, "0123456"), 0, NOW, HEAD), checkPid(pidFile(NOW / 1000 + 60, "9f1c2b"), 0, NOW, HEAD),
     checkPid(pidFile(NOW / 1000 + 60, "9F1C2B3A"), 0, NOW, HEAD), checkPid(`42a\n9f1c2b3a\n${NOW / 1000 + 60}\n`, 0, NOW, HEAD),
     checkPid(pidFile(NOW / 1000 + 60), 0, NOW, "")],
    [null, null, null, null, null]],
  ["running.pid with no deadline line counts for 240 minutes from its mtime",
    [checkPid("4242\n9f1c2b3a\n", NOW - 240 * 60_000, NOW, HEAD), checkPid("4242\n9f1c2b3a\n", NOW - 240 * 60_000 - 1, NOW, HEAD),
     checkPid("4242\n9f1c2b3a\nsoon\n", NOW - 60_000, NOW, HEAD)],
    ["4242", null, "4242"]],
]
if (existsSync(ws + "/real.md")) {
  const r = parseIndex(readFileSync(ws + "/real.md", "utf8"), "2026-10-06-ship-claude-code-mods")
  const card = (id) => r.cards?.find((c) => c.id === id)
  cases.push(
    ["real index: spec path, no marker, milestones M0-M5", [r.specPath, r.marker, r.milestones?.map((m) => m.id)],
      ["taskmaster-docs/specs/2026-10-06-ship-claude-code-mods.md", null, ["M0", "M1", "M2", "M3", "M4", "M5"]]],
    ["real index: this card row reads past the parallel group column", card("18") && { ...card("18"), status: undefined },
      { id: "18", title: "Parse a card index into the board model", dependsOn: ["12"], group: "M", milestone: "M4" }],
    ["real index: none and a three-id dependency cell", [card("01")?.dependsOn, card("10")?.dependsOn], [[], ["09", "06", "26"]]],
    ["real index: a done cell with a long parenthetical is done", card("01")?.status, "done"],
  )
}
for (const [name, got, want] of cases) console.log([name, JSON.stringify(got), JSON.stringify(want)].join("\t"))
'

if out=$(node --input-type=module -e "$CASES" "$CORE" "$WS" 2>"$WS/err"); then
  while IFS=$'\t' read -r name got want; do
    [ "$got" = "$want" ] && ok "$name" || bad "$name" "got $got, want $want"
  done <<<"$out"
else
  bad "node runs board-core.ts" "$(cat "$WS/err")"
fi

OPEN='
import { readFileSync } from "node:fs"
import { pathToFileURL } from "node:url"
const { parseIndex, counts } = await import(pathToFileURL(process.argv[1]).href)
const c = counts(parseIndex(readFileSync(process.argv[2], "utf8"), "s"))
console.log(`${c.total - c.done - c.parked} of ${c.total} cards still open`)
'
agree() { # <name> <index file>
  local want got
  mkdir -p "$WS/run/.claude/task-runner"
  printf '{"slug":"s","index_path":"%s"}\n' "$2" > "$WS/run/.claude/task-runner/active-run.json"
  want=$(printf '{"hook_event_name":"SessionStart","source":"startup","cwd":"%s"}' "$WS/run" \
    | env -u CLAUDE_PROJECT_DIR CC_REMIND=on bash "$ROOT/hooks/announce.sh" 2>/dev/null | grep -o '[0-9]* of [0-9]* cards still open')
  got=$(node --input-type=module -e "$OPEN" "$CORE" "$2" 2>&1)
  [ -n "$want" ] && [ "$got" = "$want" ] && ok "$1" || bad "$1" "got $got, want ${want:-no count from announce.sh}"
}
if command -v jq >/dev/null; then
  agree "open cards agree with hooks/announce.sh on the fixture" "$WS/base.md"
  [ -r "$WS/real.md" ] && agree "open cards agree with hooks/announce.sh on the real index" "$WS/real.md"
else
  printf 'SKIP  announce.sh agreement (jq is required)\n'
fi

RECEIPT='
import { pathToFileURL } from "node:url"
const { receiptOf } = await import(pathToFileURL(process.argv[1]).href)
console.log(JSON.stringify(receiptOf(Number(process.argv[2]), process.argv[3])))
'
said() { # <repo> — receiptOf over what check-receipt.sh check prints there
  local out code
  out=$(cd "$1" && "$ROOT/scripts/check-receipt.sh" check --name suite); code=$?
  node --input-type=module -e "$RECEIPT" "$CORE" "$code" "$out" 2>&1
}
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
R="$WS/repo"
if command -v git >/dev/null && command -v jq >/dev/null && mkdir -p "$R" && git -C "$R" init -q && [ "$(git -C "$R" rev-parse --git-dir)" = .git ]; then
  git -C "$R" config user.email t@t.t && git -C "$R" config user.name t && echo a > "$R/a.txt" && git -C "$R" add a.txt && git -C "$R" commit -qm seed
  H=$(git -C "$R" rev-parse --short=7 HEAD)
  (cd "$R" && "$ROOT/scripts/check-receipt.sh" run --name suite -- true >/dev/null 2>&1)
  got=$(said "$R"); want="{\"isFresh\":true,\"head\":\"$H\",\"cmd\":\"true\"}"
  [ "$got" = "$want" ] && ok "receiptOf reads check-receipt.sh's fresh line as fresh at its commit" || bad "receipt agreement, fresh" "got $got, want $want"
  echo b > "$R/a.txt"
  got=$(said "$R"); want="{\"isFresh\":false,\"reason\":\"files changed since suite ran at $H\"}"
  [ "$got" = "$want" ] && ok "receiptOf keeps check-receipt.sh's stale reason" || bad "receipt agreement, stale" "got $got, want $want"
else
  printf 'SKIP  receipt agreement (git and jq are required)\n'
fi

printf '\nboard-core: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
