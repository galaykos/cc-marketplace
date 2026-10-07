#!/usr/bin/env bash
# coach-core-gate.test.sh — hooks/coach-core.ts under node: every isEligible rule (origin, prefix, attachments, the
#   token and unspaced thresholds, a passed hash, mute), textHash against FNV-1a vectors, the escalation cap at 10,
#   and each back-off transition (a third consecutive failure, a success resetting the run, expiry).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CORE="$ROOT/hooks/coach-core.ts"
command -v node >/dev/null || { echo "FAIL: node is required"; exit 1; }
WS=$(mktemp -d); trap 'rm -rf "$WS"' EXIT
pass=0; fail=0

ok()  { pass=$((pass+1)); printf 'PASS  %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL  %s\n      %s\n' "$1" "$2"; }

CASES='
import { pathToFileURL } from "node:url"
const { LIMITS, isEligible, textHash, canEscalate, isBackingOff, afterJudge } = await import(pathToFileURL(process.argv[1]).href)
const TEXT = "fix the login bug"
const eligible = (over) => isEligible({ text: TEXT, origin: "composer", attachments: 0, passed: [], muted: false, ...over })
const OTHER_ORIGINS = ["bridge", "sdk", "task-notification", "scheduled-trigger", "peer", "peer-send-message", "projects-relay",
  "channel", "coordinator", "observer", "observer-activity", "auto-continuation", "unclassified", "slack-ping", "plugin", ""]
const T = 1_000_000
const FRESH = { escalations: 0, failures: 0, backoffUntil: null }
const run = (g, steps) => steps.reduce((s, [outcome, escalated, now]) => afterJudge(s, outcome, escalated, now), g)
const escalate = (n) => run(FRESH, Array.from({ length: n }, (_, i) => ["ok", true, T + i]))
const failed3 = run(FRESH, [["failed", false, T], ["failed", false, T + 1], ["failed", true, T + 2]])
const cases = [
  ["a four-word composer prompt with no attachments is eligible", eligible({}), true],
  ["a prompt starting with /, ! or # is not eligible",
    ["/review the login bug", "!git status --short now", "#always use pnpm here"].map((text) => eligible({ text })), [false, false, false]],
  ["/, ! or # after leading whitespace still skips it",
    ["  /review the login bug", "\t!git status --short now", " #always use pnpm here"].map((text) => eligible({ text })), [false, false, false]],
  ["/, ! or # past the first character does not skip it",
    ["fix the /login route", "fix it right now!", "fix issue #42 today"].map((text) => eligible({ text })), [true, true, true]],
  ["one attachment makes a prompt not eligible", eligible({ attachments: 1 }), false],
  ["every origin but composer is not eligible", OTHER_ORIGINS.map((origin) => eligible({ origin })), OTHER_ORIGINS.map(() => false)],
  ["three tokens under 16 non-space characters are not eligible, four tokens are",
    [eligible({ text: "fix it now" }), eligible({ text: "fix it now please" })], [false, true]],
  ["tokens split on any whitespace, a newline and a tab included", eligible({ text: "fix\nit\tnow please" }), true],
  ["one unspaced run of 15 characters is not eligible, 16 is",
    [eligible({ text: "字".repeat(15) }), eligible({ text: "字".repeat(16) })], [false, true]],
  ["fewer than four tokens still count 16 non-space characters, spaces excluded",
    [eligible({ text: "abcdefg ijklmnop" }), eligible({ text: "abcdefgh ijklmnop" })], [false, true]],
  ["eight astral-plane characters count as eight, not their sixteen UTF-16 halves", eligible({ text: "😀".repeat(8) }), false],
  ["a text whose hash the session marked to pass is not eligible", eligible({ passed: [textHash(TEXT)] }), false],
  ["a passed hash matches the exact text only: a trailing space is another text",
    eligible({ text: TEXT + " ", passed: [textHash(TEXT)] }), true],
  ["mute makes every prompt not eligible", eligible({ muted: true }), false],
  ["a whitespace-only prompt is not eligible", eligible({ text: " \n\t " }), false],
  ["textHash is FNV-1a 32-bit over UTF-8 bytes, zero-padded to 8 hex digits",
    ["", "a", "foobar", "naïve", "p426"].map(textHash), ["811c9dc5", "e40c292c", "bf9cf968", "999a082b", "01483fad"]],
  ["LIMITS carry the spec numbers", LIMITS,
    { deadlineMs: 5000, cap: 10, backoffFailures: 3, backoffMs: 600000, promptChars: 4000, totalChars: 8000 }],
  ["after 9 escalations one more may run, after 10 none", [canEscalate(escalate(9)), canEscalate(escalate(10))], [true, false]],
  ["an escalation counts whether it succeeds or fails; a first pass alone does not",
    [afterJudge(FRESH, "failed", true, T), afterJudge(FRESH, "ok", true, T), afterJudge(FRESH, "ok", false, T).escalations],
    [{ escalations: 1, failures: 1, backoffUntil: null }, { escalations: 1, failures: 0, backoffUntil: null }, 0]],
  ["two consecutive failures do not back off, the third backs off 10 minutes from it, resets the run and keeps the escalation count",
    [run(FRESH, [["failed", false, T], ["failed", true, T + 1]]), failed3],
    [{ escalations: 1, failures: 2, backoffUntil: null }, { escalations: 1, failures: 0, backoffUntil: T + 2 + 600000 }]],
  ["a success resets the failure run: fail, fail, ok, fail, fail is no back-off",
    run(FRESH, [["failed", false, T], ["failed", false, T + 1], ["ok", false, T + 2], ["failed", false, T + 3], ["failed", false, T + 4]]),
    { escalations: 0, failures: 2, backoffUntil: null }],
  ["the back-off holds until its last millisecond and ends at its deadline; no back-off never holds",
    [isBackingOff(failed3, T + 2), isBackingOff(failed3, T + 2 + 599999), isBackingOff(failed3, T + 2 + 600000), isBackingOff(FRESH, T)],
    [true, true, false, false]],
]
for (const [name, got, want] of cases) console.log([name, JSON.stringify(got), JSON.stringify(want)].join("\t"))
'

if out=$(node --input-type=module -e "$CASES" "$CORE" 2>"$WS/err"); then
  while IFS=$'\t' read -r name got want; do
    [ "$got" = "$want" ] && ok "$name" || bad "$name" "got $got, want $want"
  done <<<"$out"
else
  bad "node runs coach-core.ts" "$(cat "$WS/err")"
fi

printf '\ncoach-core-gate: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
