#!/usr/bin/env bash
# floors-core.test.sh — hooks/floors-core.ts under node: parseRegistry on the shipped role-floors.md and on altered
#   copies, rank on aliases and full ids, decideModel on each branch of the floor rule.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CORE="$ROOT/hooks/floors-core.ts"; REG="$ROOT/skills/delegation-contracts/references/role-floors.md"
command -v node >/dev/null || { echo "FAIL: node is required"; exit 1; }
ERR=$(mktemp); trap 'rm -f "$ERR"' EXIT
pass=0; fail=0

ok()  { pass=$((pass+1)); printf 'PASS  %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL  %s\n      %s\n' "$1" "$2"; }

CASES='
import { readFileSync } from "node:fs"
import { pathToFileURL } from "node:url"
const { parseRegistry, rank, decideModel } = await import(pathToFileURL(process.argv[1]).href)
const md = readFileSync(process.argv[2], "utf8")
const show = (v) => v === undefined ? "undefined" : JSON.stringify(v instanceof Map ? Object.fromEntries(v) : v)
const floors = {
  "code-review:code-reviewer": "opus",
  "web-dev:frontend-reviewer": "opus",
  "code-architecture:architecture-reviewer": "opus",
  "code-architecture:system-architect": "opus",
  "taskmaster:spec-adversary": "opus",
  "ultra-deep-research:verifier": "sonnet",
}
const cases = [
  ["the shipped registry parses to its six floors", parseRegistry(md), floors],
  ["a registry line with no tier leaves no floors",
    parseRegistry(md.replace(/^(ultra-deep-research:verifier)\s+sonnet$/m, "$1")), {}],
  ["blocks before the registry are skipped, and an entry-shaped line between fences is outside them",
    parseRegistry("```\n```\nx:y haiku\n```bash\necho hi\n```\n" + md), floors],
  ["a CRLF copy parses to the same floors", parseRegistry(md.replace(/\n/g, "\r\n")), floors],
  ["aliases rank haiku 1, sonnet 2, opus 3, fable 4",
    ["haiku", "sonnet", "opus", "fable"].map(rank), [1, 2, 3, 4]],
  ["full ids rank by their family substring",
    ["claude-haiku-4-5-20251001", "claude-sonnet-5-5", "claude-opus-5-5", "claude-fable-5-1"].map(rank), [1, 2, 3, 4]],
  ["rank ignores case", rank("Claude-OPUS-5-5"), 3],
  ["an unknown or missing model has no rank", [rank("gpt-5"), rank("inherit"), rank(undefined)], [null, null, null]],
  ["no explicit model, fable parent over an opus floor: the parent",
    decideModel({ parentModel: "claude-fable-5-1", floor: "opus" }), "claude-fable-5-1"],
  ["no explicit model, sonnet parent under an opus floor: the floor",
    decideModel({ parentModel: "claude-sonnet-5-5", floor: "opus" }), "opus"],
  ["no explicit model, parent at the floor: the parent",
    decideModel({ parentModel: "claude-opus-5-5", floor: "opus" }), "claude-opus-5-5"],
  ["explicit haiku under a sonnet floor: the floor, whatever the parent",
    decideModel({ explicit: "haiku", parentModel: "claude-fable-5-1", floor: "sonnet" }), "sonnet"],
  ["explicit opus over a sonnet floor is left alone",
    decideModel({ explicit: "opus", parentModel: "claude-haiku-4-5-20251001", floor: "sonnet" }), undefined],
  ["an explicit model at the floor is left alone",
    decideModel({ explicit: "claude-sonnet-5-5", parentModel: "claude-fable-5-1", floor: "sonnet" }), undefined],
  ["an unknown parent or explicit family leaves the spawn alone",
    [decideModel({ parentModel: "gpt-5", floor: "opus" }),
     decideModel({ explicit: "inherit", parentModel: "claude-sonnet-5-5", floor: "opus" })], [undefined, undefined]],
  ["an unknown floor tier leaves the spawn alone",
    decideModel({ parentModel: "claude-sonnet-5-5", floor: "premium" }), undefined],
]
for (const [name, got, want] of cases) console.log([name, show(got), show(want)].join("\t"))
'

if out=$(node --input-type=module -e "$CASES" "$CORE" "$REG" 2>"$ERR"); then
  while IFS=$'\t' read -r name got want; do
    [ "$got" = "$want" ] && ok "$name" || bad "$name" "got $got, want $want"
  done <<<"$out"
else
  bad "node runs floors-core.ts" "$(cat "$ERR")"
fi

printf '\nfloors-core: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
