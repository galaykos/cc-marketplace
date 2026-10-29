#!/usr/bin/env bash
# Drives receipt-fresh.sh on receipts written here with the reader's own digest: fresh only for a passing check at this HEAD on this tree with
# task-runner's log; stale for every other HEAD, tree, exit, command, log or file shape. Every git command runs in a scratch repo that is its own root.
set -u
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
here="$(cd "$(dirname "$0")/.." && pwd)" || exit 1; s="$here/receipt-fresh.sh"
command -v jq >/dev/null 2>&1 || { echo "FAIL: jq not found"; exit 1; }
tmp=$(mktemp -d) || { echo "FAIL: mktemp -d failed"; exit 1; }
tmp=$(cd "$tmp" && pwd -P) || exit 1
trap 'rm -rf "$tmp"' EXIT
export GIT_CEILING_DIRECTORIES="$tmp"
pass=0; fail=0
ok()  { pass=$((pass+1)); }
bad() { fail=$((fail+1)); printf 'FAIL  %s\n      %s\n' "$1" "$2"; }
# expect <label> <want-rc> <want-line-regex> <args...> — runs the reader from the current directory.
expect() {
  local label="$1" want="$2" re="$3" out rc; shift 3
  out=$(bash "$s" "$@" 2>&1); rc=$?
  if [ "$rc" = "$want" ] && grep -qE "$re" <<<"$out"; then ok; else bad "$label" "rc=$rc out=$out"; fi
}

eval "$(sed -n '/^tree_digest() {$/,/^}$/p' "$s")"
declare -F tree_digest >/dev/null || { echo "FAIL: no tree_digest in $s"; exit 1; }
R=.claude/task-runner/receipt.json
# receipt [<exit>] [<log>] — a version-1 receipt for HEAD and the tree as it is now, holding one suite check and its log.
receipt() {
  local h; h=$(git rev-parse HEAD) || exit 1
  local log=".claude/task-runner/receipts/suite-${h:0:12}.txt"
  mkdir -p .claude/task-runner/receipts && printf '$ make test\nexit %s\n' "${1:-0}" > "$log"
  jq -n --arg h "$h" --arg t "$(ROOT=$repo tree_digest)" --arg l "${2-$log}" --argjson e "${1:-0}" --arg c "make test" \
    '{version:1, head:$h, tree:$t, checks:{suite:{cmd:$c, exit:$e, log:$l, at:"2026-10-26T00:00:00Z"}}}' > "$R"
}
edit() { jq "$1" "$R" > "$R.t" && mv "$R.t" "$R"; }

expect "no --name is a usage error" 2 'usage error: need --name' --root "$tmp"
expect "an unknown argument is a usage error" 2 'usage error: unknown argument' --name suite --bogus
expect "a --name with path characters is a usage error" 2 'usage error: --name takes' --name ../x

nongit="$tmp/nongit"; mkdir -p "$nongit" || exit 1; cd "$nongit" || exit 1
expect "outside a git repository" 1 '^stale: not inside a git repository$' --name suite

repo="$tmp/repo"; mkdir -p "$repo" || exit 1; cd "$repo" || exit 1
git init -q || exit 1
[ "$(git rev-parse --show-toplevel)" = "$repo" ] || { echo "FAIL: scratch repo is not its own root"; exit 1; }
git config user.email t@t; git config user.name t; git config commit.gpgsign false
expect "a repository with no commit" 1 '^stale: the repository has no commit yet$' --name suite
echo one > a.txt; mkdir -p src; echo x > src/b.txt; echo x > src/c.txt; echo .env > .gitignore
git add -A && git commit -q -m one || exit 1
expect "no receipt" 1 '^stale: no receipt at \.claude/task-runner/receipt\.json$' --name suite

receipt
h=$(git rev-parse HEAD)
expect "clean tree, passing check" 0 "^fresh: suite passed at ${h:0:7} \(make test\), log \.claude/task-runner/receipts/suite-${h:0:12}\.txt$" --name suite
expect "the expected command" 0 '^fresh: ' --name suite --cmd "make test"
expect "another command" 1 '^stale: recorded command differs: make test$' --name suite --cmd "make check"
expect "run from a subdirectory" 0 '^fresh: ' --name suite --root src
cd src || exit 1; expect "cwd in a subdirectory" 0 '^fresh: ' --name suite; cd .. || exit 1
cd "$tmp" || exit 1; expect "--root from outside" 0 '^fresh: ' --name suite --root "$repo"; cd "$repo" || exit 1
expect "a check the receipt does not hold" 1 '^stale: the receipt has no lint check$' --name lint

mkdir -p .claude/other; echo scratch > .claude/other/x.txt
expect "untracked file under .claude/" 0 '^fresh: ' --name suite
mkdir -p taskmaster-docs; echo spec > taskmaster-docs/spec.md
expect "untracked file under taskmaster-docs/" 0 '^fresh: ' --name suite
rm -rf .claude/other taskmaster-docs
mkdir -p .claude/skills/x; echo skill > .claude/skills/x/SKILL.md
expect "untracked project skill" 1 '^stale: files changed since the check ran$' --name suite
rm -rf .claude/skills

echo two >> a.txt
expect "edited tracked file" 1 '^stale: files changed since the check ran$' --name suite
git add a.txt
expect "staged change" 1 '^stale: files changed since the check ran$' --name suite
git reset -q --hard || exit 1
echo new > new.txt
expect "new untracked file" 1 '^stale: files changed since the check ran$' --name suite
receipt; chmod +x new.txt
expect "untracked file made executable" 1 '^stale: files changed since the check ran$' --name suite
rm new.txt; receipt
echo A=1 > .env; receipt; echo A=2 > .env
expect "ignored root .env edited" 1 '^stale: files changed since the check ran$' --name suite
rm .env; receipt
mkdir -p .claudex; echo new > .claudex/new.txt
expect "untracked file under a name that only starts with .claude" 1 '^stale: files changed' --name suite
rm -rf .claudex
ln -s src/b.txt link; receipt
expect "untracked symlink, unchanged" 0 '^fresh: ' --name suite
ln -sfn src/c.txt link
expect "untracked symlink pointed at a file with the same content" 1 '^stale: files changed since the check ran$' --name suite
rm link; receipt
git rm -q src/b.txt
expect "deleted tracked file" 1 '^stale: files changed since the check ran$' --name suite
git reset -q --hard || exit 1
chmod +x a.txt
expect "mode change" 1 '^stale: files changed since the check ran$' --name suite
chmod -x a.txt
expect "tree restored reads fresh again" 0 '^fresh: ' --name suite

git commit -q --allow-empty -m two || exit 1
expect "new commit" 1 "^stale: the receipt is for another commit, not HEAD $(git rev-parse HEAD | cut -c1-7)$" --name suite
receipt
git checkout -q HEAD~1 || exit 1
expect "other HEAD" 1 '^stale: the receipt is for another commit' --name suite
git checkout -q - || exit 1
expect "back on the receipt's HEAD" 0 '^fresh: ' --name suite
h=$(git rev-parse HEAD)

receipt 1
expect "failed check" 1 '^stale: suite exited 1$' --name suite
receipt; rm .claude/task-runner/receipts/*.txt
expect "missing log" 1 '^stale: the suite log file is missing' --name suite
receipt; echo appended >> ".claude/task-runner/receipts/suite-${h:0:12}.txt"
expect "log not ending with exit 0" 1 '^stale: the suite log does not end with exit 0' --name suite
receipt 0 .claude/task-runner/receipts/other.txt; cp ".claude/task-runner/receipts/suite-${h:0:12}.txt" .claude/task-runner/receipts/other.txt
expect "log at another path" 1 '^stale: the suite log is not the one task-runner writes' --name suite
receipt 0 ""
expect "empty log path" 1 '^stale: the suite log is not the one task-runner writes' --name suite

receipt; edit '.checks.suite.cmd = "make\ntest"'
expect "a command holding a newline prints on one line" 0 "^fresh: suite passed at ${h:0:7} \(make test\), log " --name suite
receipt; edit 'del(.checks.suite.cmd)'
expect "check with no command" 1 'records no command$' --name suite
receipt; edit '.checks.suite.exit = "0"'
expect "exit as a string" 1 '^stale: suite exited "0"$' --name suite
receipt; edit '.version = 2'
expect "unknown version" 1 'cannot be read as a receipt$' --name suite
receipt; edit 'del(.tree)'
expect "no tree field" 1 'cannot be read as a receipt$' --name suite
printf '{"version":1,' > "$R"
expect "truncated JSON" 1 'cannot be read as a receipt$' --name suite
: > "$R"
expect "empty receipt" 1 'cannot be read as a receipt$' --name suite
echo '[1,2]' > "$R"
expect "a JSON array" 1 'cannot be read as a receipt$' --name suite

echo "receipt-fresh.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
