#!/usr/bin/env bash
# Fixtures for plugins/task-runner/scripts/reduction-record.sh.
#
# The record is what candor's completion gate counts and what makes the closing report
# name a cut, so its FILE NAME and its JSON are the contract. Until 0.41.0 nothing drove
# this script at all. The cases: a plain record; --evidence stored repo-relative; an
# evidence path that is missing or outside the repo refused with no record left behind
# (a record pointing at nothing reads as proof later); the bad-kind usage error; and a
# call from a subdirectory landing at the repo root, where the gate looks.
set -u
cd "$(dirname "$0")/../../../.." || exit 1
S="$PWD/plugins/task-runner/scripts/reduction-record.sh"
rc=0
FX=$(mktemp -d); trap 'rm -rf "$FX"' EXIT
# This session exports CLAUDE_PROJECT_DIR at the marketplace repo; the script must not
# need it, and a harness that inherited it would test the wrong root.
unset CLAUDE_PROJECT_DIR

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not found"; exit 0; }

G="$FX/repo"; mkdir -p "$G/sub" "$G/.cc-artifacts/task-runner/walk/m1/desktop"
git init -q "$G" 2>/dev/null
printf 'png' > "$G/.cc-artifacts/task-runner/walk/m1/desktop/index.png"
mkdir -p "$FX/outside"
RD="$G/.cc-artifacts/task-runner/reductions"

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; rc=1; }

run_in() { # dir args... ; sets out/err/got
  local d="$1"; shift
  out=$( (cd "$d" && bash "$S" "$@") 2>"$FX/err"); got=$?
  err=$(cat "$FX/err")
}

# 1. A basic record: the file name candor's gate strips to the id, and valid JSON.
run_in "$G" --kind other --id x1 --reason 'a "quoted" reason'
if [ "$got" -eq 0 ] && [ "$out" = "reduction-recorded" ] &&
   jq -e '.kind=="other" and .id=="x1" and .reduced==true and .reason=="a \"quoted\" reason" and (has("evidence")|not)' "$RD/other-x1.json" >/dev/null 2>&1; then
  pass "basic record written as other-x1.json with no evidence key"
else fail "basic record (rc=$got, out=$out)"; fi
case "$err" in *"REDUCED (other) x1"*) pass "the reduction is disclosed on stderr" ;;
  *) fail "no stderr disclosure: $err" ;; esac

# 2. --evidence is recorded, repo-relative, and echoed.
run_in "$G" --kind coverage --id bg-0123456789ab --reason "UI files, no JS runner" \
  --evidence .cc-artifacts/task-runner/walk/m1
if [ "$got" -eq 0 ] &&
   [ "$(jq -r '.evidence' "$RD/coverage-bg-0123456789ab.json" 2>/dev/null)" = ".cc-artifacts/task-runner/walk/m1" ]; then
  pass "--evidence recorded repo-relative"
else fail "--evidence not recorded (rc=$got)"; fi
case "$err" in *"evidence for this reduction: .cc-artifacts/task-runner/walk/m1"*) pass "evidence echoed on stderr" ;;
  *) fail "evidence not echoed: $err" ;; esac

# A FILE is evidence too, not only a directory.
run_in "$G" --kind coverage --id walk-m1 --reason "one shot" \
  --evidence .cc-artifacts/task-runner/walk/m1/desktop/index.png
[ "$got" -eq 0 ] && [ "$(jq -r '.evidence' "$RD/coverage-walk-m1.json" 2>/dev/null)" = ".cc-artifacts/task-runner/walk/m1/desktop/index.png" ] \
  && pass "a file path is accepted as evidence" || fail "file evidence (rc=$got)"

# 3. A missing evidence path is a usage error and leaves NO record.
run_in "$G" --kind coverage --id gone1 --reason "r" --evidence .cc-artifacts/task-runner/walk/nope
if [ "$got" -eq 3 ] && [ ! -e "$RD/coverage-gone1.json" ]; then
  pass "missing evidence path rejected (rc=3), no record"
else fail "missing evidence: want rc=3 and no record, got rc=$got"; fi

# Outside the repo root is refused the same way, however it is spelled.
run_in "$G" --kind coverage --id out1 --reason "r" --evidence "$FX/outside"; got1=$got
run_in "$G/sub" --kind coverage --id out2 --reason "r" --evidence ../../outside
if [ "$got1" -eq 3 ] && [ "$got" -eq 3 ] && [ ! -e "$RD/coverage-out1.json" ] && [ ! -e "$RD/coverage-out2.json" ]; then
  pass "evidence outside the repo root rejected (absolute and ../), no record"
else fail "outside evidence: want rc=3 twice and no record, got rc=$got1 and $got"; fi

# 4. The bad-kind usage error.
run_in "$G" --kind bogus --id k1 --reason "r"
[ "$got" -eq 3 ] && [ ! -e "$RD/bogus-k1.json" ] && pass "unknown --kind is a usage error (rc=3)" \
  || fail "bad kind: want rc=3, got $got"
run_in "$G" --id k2 --reason "r"
[ "$got" -eq 3 ] && pass "missing --kind is a usage error (rc=3)" || fail "missing kind: want rc=3, got $got"

# 5. From a subdirectory: the record lands at the repo root, none in sub/, and a
# relative --evidence resolves against the shell's cwd.
run_in "$G/sub" --kind suite --id s1 --reason "narrowed" --evidence ../.cc-artifacts/task-runner/walk/m1
if [ "$got" -eq 0 ] && [ -f "$RD/suite-s1.json" ] && [ ! -e "$G/sub/.claude" ] && [ ! -e "$G/sub/.cc-artifacts" ] &&
   [ "$(jq -r '.evidence' "$RD/suite-s1.json" 2>/dev/null)" = ".cc-artifacts/task-runner/walk/m1" ]; then
  pass "subdirectory call anchors at the repo root; relative evidence resolved"
else fail "subdirectory call (rc=$got; sub/.claude or sub/.cc-artifacts exists? $([ -e "$G/sub/.claude" ] || [ -e "$G/sub/.cc-artifacts" ] && echo yes || echo no))"; fi
[ -f "$G/.cc-artifacts/task-runner/.gitignore" ] && pass "state root ignores itself" || fail "no .cc-artifacts/task-runner/.gitignore"

# 6. A run registered before 2026-11-14 keeps its records in .claude/task-runner/: the next record lands beside a one-time
# copy of them under .cc-artifacts/task-runner/, and the old dir is left as it was.
O="$FX/old"; mkdir -p "$O/.claude/task-runner/reductions"; git init -q "$O" 2>/dev/null
printf '{"kind":"dispatch","id":"d1","reduced":true,"reason":"r"}\n' > "$O/.claude/task-runner/reductions/dispatch-d1.json"
before=$(cd "$O/.claude" && find . -type f -exec cksum {} + | sort)
run_in "$O" --kind other --id o1 --reason "r"
if [ "$got" -eq 0 ] && [ -f "$O/.cc-artifacts/task-runner/reductions/other-o1.json" ] && [ -f "$O/.cc-artifacts/task-runner/reductions/dispatch-d1.json" ] &&
   [ "$(cd "$O/.claude" && find . -type f -exec cksum {} + | sort)" = "$before" ]; then
  pass "a legacy run's records are copied once and the new record lands beside them; .claude/task-runner/ untouched"
else fail "legacy records (rc=$got): $(cd "$O" && find .claude .cc-artifacts -type f 2>&1 | tr '\n' ' ')"; fi

[ "$rc" -eq 0 ] && echo "All reduction-record fixtures passed."
exit "$rc"
