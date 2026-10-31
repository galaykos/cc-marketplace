#!/usr/bin/env bash
# receipt-contract-tests.sh — task-runner's check-receipt.sh writes each receipt in a scratch repo that is its own root, git-workflow's receipt-fresh.sh
# reads it, and the two tree_digest functions must be byte-identical: fresh only when nothing the digest covers moved, stale after every change below.
# Misses: submodules, other gitignored files, hand-written receipts; the reader's own rules are in plugins/git-workflow/scripts/__tests__/receipt-fresh.test.sh.
set -u
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
ROOT="$(cd "$(dirname "$0")/../.." && pwd)" || exit 1
W="$ROOT/plugins/task-runner/scripts/check-receipt.sh"
R="$ROOT/plugins/git-workflow/scripts/receipt-fresh.sh"
command -v jq >/dev/null 2>&1 || { echo "FAIL: jq not found"; exit 1; }
for f in "$W" "$R"; do [ -f "$f" ] || { echo "FAIL: missing $f"; exit 1; }; done

WORK=$(mktemp -d) || { echo "FAIL: mktemp -d failed"; exit 1; }
WORK=$(cd "$WORK" && pwd -P) || exit 1
trap 'rm -rf "$WORK"' EXIT
trap 'exit 130' INT TERM HUP
pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'PASS  %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL  %s\n      %s\n' "$1" "$2"; }
own_root() { [ "$(git rev-parse --show-toplevel 2>/dev/null)" = "$WORK" ] || { echo "FAIL: not in the scratch repo ($PWD)"; exit 1; }; }
write() { bash "$W" run --name suite -- "$@" >/dev/null 2>&1; }
# reads <label> fresh|stale [<reader args>...] — the reader's verdict on the receipt as it stands.
reads() {
  local label="$1" verdict="$2" out rc want=1; shift 2; [ "$verdict" = fresh ] && want=0
  out=$(bash "$R" --name suite "$@" 2>&1); rc=$?
  if [ "$rc" = "$want" ] && [[ "$out" == "$verdict: "* ]]; then ok "$label reads $verdict"; else bad "$label reads $verdict" "rc=$rc out=$out"; fi
}
reset() { own_root; git reset -q --hard && git clean -qfd -e .claude || exit 1; rm -f .claude/task-runner/receipt.json; write true; }
log_of() { jq -r '.checks.suite.log' .claude/task-runner/receipt.json; }

a=$(sed -n '/^tree_digest() {$/,/^}$/p' "$W"); b=$(sed -n '/^tree_digest() {$/,/^}$/p' "$R")
[ -n "$a" ] && [ "$a" = "$b" ] && ok "tree_digest is byte-identical in writer and reader" || bad "tree_digest is byte-identical in writer and reader" "diff the two functions"

cd "$WORK" || exit 1
git init -q || exit 1
own_root
git config user.email t@t; git config user.name t; git config commit.gpgsign false
echo one > a.txt; mkdir -p src; echo x > src/b.txt; echo .env > .gitignore
git add -A && git commit -q -m one || exit 1
echo two > c.txt; git add c.txt && git commit -q -m two || exit 1

write true
reads "clean tree after a passing suite" fresh
out=$(bash "$R" --name suite); h=$(git rev-parse HEAD)
[[ "$out" == "fresh: suite passed at ${h:0:7} (true), log "* ]] && ok "fresh line names HEAD and the command" || bad "fresh line names HEAD and the command" "$out"
reads "the recorded command expected" fresh --cmd true
reads "another command expected" stale --cmd false

mkdir -p .claude/scratch; echo note > .claude/scratch/n.txt
reads "untracked file under .claude/" fresh
rm -rf .claude/scratch
mkdir -p .claude/skills/x; echo skill > .claude/skills/x/SKILL.md
reads "new untracked .claude/skills/x/SKILL.md" stale
reset
echo u > untracked.txt; write true
reads "untracked file present when written" fresh
reset
printf '#!/bin/sh\n' > run.sh; chmod +x run.sh; write true
reads "executable untracked file present when written" fresh
chmod -x run.sh
reads "executable bit dropped" stale
reset
echo A=1 > .env; write true
reads "ignored root .env present when written" fresh
echo A=2 > .env
reads "root .env edited" stale
rm -f .env; reset
ln -s a.txt link; write true
reads "untracked symlink present when written" fresh
rm link; reset

echo edit >> a.txt
reads "edited tracked file" stale
reset
echo staged >> src/b.txt; git add src/b.txt
reads "staged change" stale
reset
echo new > new.txt
reads "new untracked file outside .claude/" stale
reset
git commit -q --allow-empty -m three || exit 1
reads "new commit" stale
reset
git checkout -q HEAD~1 || exit 1
reads "other HEAD" stale
git checkout -q - || exit 1
reset

write false
reads "failed suite" stale
write true
reads "failed suite then a passing run of another command" stale
reset
write bash -c 'echo "a b"'
out=$(bash "$R" --name suite --cmd "bash -c 'echo \"a b\"'"); rc=$?
[ "$rc" = 0 ] && [[ "$out" == *"(bash -c 'echo \"a b\"'), log "* ]] && ok "quoted multi-word command recorded and read back intact" \
  || bad "quoted multi-word command recorded and read back intact" "rc=$rc out=$out"
reset

rm -f "$(log_of)"
reads "missing log" stale
reset
echo tampered >> "$(log_of)"
reads "log not ending with exit 0" stale
reset
cp "$(log_of)" .claude/task-runner/receipts/hand.txt
jq '.checks.suite.log = ".claude/task-runner/receipts/hand.txt"' .claude/task-runner/receipt.json > r.t && mv r.t .claude/task-runner/receipt.json
reads "hand-edited log path" stale
reset
printf '{"version":1,"head":' > .claude/task-runner/receipt.json
reads "corrupt JSON" stale
reset
reads "rewritten after each case" fresh

echo "receipt-contract-tests.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
