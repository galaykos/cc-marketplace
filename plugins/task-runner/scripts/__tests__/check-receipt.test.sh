#!/usr/bin/env bash
# check-receipt.test.sh — scripts/check-receipt.sh in throwaway repos: the receipt and log `run` writes, the one line and exit
#   `check` gives, and each change that must turn a receipt stale or leave it fresh.
set -u
unset CLAUDE_PROJECT_DIR GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE

here=$(cd "$(dirname "$0")" && pwd) || exit 1
CR="$here/../check-receipt.sh"
command -v git >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 || { echo "SKIP: git and jq are required"; exit 0; }

rc=0
ok()  { echo "PASS: $1"; }
bad() { echo "FAIL: $1 — $2"; rc=1; }
WS=$(mktemp -d) || exit 1
trap 'rm -rf "$WS"' EXIT
n=0

# Sets R to a new repo of its own; stops the harness before any git write could reach an enclosing repo.
fresh_repo() {
  n=$((n + 1)); R="$WS/r$n"
  mkdir -p "$R/src" || exit 1
  git -C "$R" init -q || exit 1
  [ "$(git -C "$R" rev-parse --git-dir)" = .git ] || { echo "FAIL: $R is not a repo of its own; stopping before git writes reach another"; exit 1; }
  git -C "$R" config user.email t@t.t && git -C "$R" config user.name t
}
# Sets R to a new repo with one commit and a passing `suite` receipt.
seeded() {
  fresh_repo
  printf 'one\n' > "$R/src/a.txt"; printf 'two\n' > "$R/b.txt"
  git -C "$R" add -A && git -C "$R" commit -qm seed
  in_r run --name suite -- sh -c 'echo suite ok' >/dev/null 2>&1
}
in_r() { (cd "$R" || exit 1; "$CR" "$@"); }
check() { (cd "$1" || exit 1; "$CR" check --name "${2:-suite}"); }
is_fresh() { local out; out=$(check "$1" "${3:-suite}"); local r=$?
  [ "$r" = 0 ] && [ "${out#fresh: }" != "$out" ] && ok "$2" || bad "$2" "rc=$r out=<$out>"; }
is_stale() { local out; out=$(check "$1" "${4:-suite}"); local r=$?
  [ "$r" = 1 ] && case "$out" in "stale: "*"$3"*) true ;; *) false ;; esac && ok "$2" || bad "$2" "rc=$r out=<$out>"; }
edit_receipt() { jq "$1" "$R/.claude/task-runner/receipt.json" > "$WS/edited" && mv "$WS/edited" "$R/.claude/task-runner/receipt.json"; }

seeded; H=$(git -C "$R" rev-parse HEAD)
out=$(check "$R"); r=$?
[ "$r" = 0 ] && [ "$out" = "fresh: suite passed at ${H:0:7} (sh -c 'echo suite ok')" ] \
  && ok "a passing run reads fresh: one line naming the check, HEAD's first 7 and the command" || bad "fresh line" "rc=$r out=<$out>"
jq -e --arg h "$H" --arg log ".claude/task-runner/receipts/suite-${H:0:12}.txt" \
  '.version == 1 and .head == $h and (.tree | test("^[0-9a-f]{40,64}$")) and (.checks | keys) == ["suite"]
   and .checks.suite.cmd == "sh -c '"'"'echo suite ok'"'"'" and .checks.suite.exit == 0 and .checks.suite.log == $log
   and (.checks.suite.at | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$"))' "$R/.claude/task-runner/receipt.json" >/dev/null \
  && ok "receipt.json holds version 1, the full HEAD, a tree digest and checks.suite {cmd, exit, log, at}" \
  || bad "receipt shape" "$(cat "$R/.claude/task-runner/receipt.json")"

seeded; H=$(git -C "$R" rev-parse HEAD)
out=$(cd "$R/src" || exit 1; "$CR" run --name lint -- sh -c 'pwd; seq 1 100; exit 7' 2>/dev/null); r=$?
L="$R/.claude/task-runner/receipts/lint-${H:0:12}.txt"
[ "$r" = 7 ] && ok "run exits with the command's exit status" || bad "run exit" "rc=$r"
[ "$(head -1 <<<"$out")" = "$R" ] && ok "run runs the command from the repo root, whatever the shell's directory" || bad "run cwd" "$(head -1 <<<"$out")"
[ "$(head -1 "$L")" = "\$ sh -c 'pwd; seq 1 100; exit 7'" ] && [ "$(sed -n 2p "$L")" = 41 ] && [ "$(tail -2 "$L" | head -1)" = 100 ] \
  && [ "$(tail -1 "$L")" = "exit 7" ] && [ "$(wc -l < "$L")" -eq 62 ] \
  && ok "the log holds the command line, the last 60 output lines and the exit status" || bad "log tail" "$(head -3 "$L"; tail -2 "$L")"
is_stale "$R" "a failed command reads stale, naming its exit" "lint failed at ${H:0:7} (exit 7)" lint
is_fresh "$R" "a second check at the same HEAD and tree keeps the first one's record"

seeded
in_r run --name suite -- sh -c 'echo "a b"; exit 0' "it's" '' >/dev/null 2>&1
cmd=$(jq -r .checks.suite.cmd "$R/.claude/task-runner/receipt.json")
eval "set -- $cmd"
[ "$cmd" = "sh -c 'echo \"a b\"; exit 0' 'it'\\''s' ''" ] && [ $# = 5 ] && [ "$3" = 'echo "a b"; exit 0' ] && [ "$4" = "it's" ] && [ -z "$5" ] \
  && ok "the recorded command keeps each argument's quoting, so it reruns as it ran" || bad "quoting" "cmd=<$cmd> argc=$#"

seeded; in_r run --name suite -- false >/dev/null 2>&1; out=$(in_r run --name suite -- true 2>&1 >/dev/null); r=$?
[ "$r" = 0 ] && case "$out" in *"keeps the failed run of a different command"*"(false)"*) true ;; *) false ;; esac \
  && ok "a different command cannot replace a failed one at the same commit and tree, and run says so" || bad "masking message" "rc=$r out=<$out>"
is_stale "$R" "so false then true still reads stale" "suite failed"
seeded; in_r run --name suite -- sh -c "test -e '$WS/flag'" >/dev/null 2>&1; touch "$WS/flag"
in_r run --name suite -- sh -c "test -e '$WS/flag'" >/dev/null 2>&1; rm -f "$WS/flag"
is_fresh "$R" "the same command run again replaces its own failure"

seeded; printf 'one\nedited\n' > "$R/src/a.txt"
is_stale "$R" "an edited tracked file reads stale" "files changed since suite ran"
seeded; printf 'staged\n' > "$R/b.txt"; git -C "$R" add b.txt
is_stale "$R" "a staged change reads stale" "files changed"
seeded; git -C "$R" rm -q --cached b.txt
is_stale "$R" "a file removed from the index alone reads stale" "files changed"
seeded; printf 'new\n' > "$R/src/new.txt"
is_stale "$R" "a new untracked file outside .claude/ reads stale" "files changed"
seeded; printf 'x\n' > "$R/scratch.txt"; in_r run --name suite -- true >/dev/null 2>&1; printf 'y\n' > "$R/scratch.txt"
is_stale "$R" "an untracked file whose content changed reads stale, though its name did not" "files changed"
seeded; printf 'x\n' > "$R/tool.sh"; in_r run --name suite -- true >/dev/null 2>&1; chmod +x "$R/tool.sh"
is_stale "$R" "an untracked file made executable reads stale" "files changed"
seeded; mkdir -p "$R/.claude/notes" "$R/taskmaster-docs/tasks/x"; printf 'n\n' > "$R/.claude/notes/n.md"; printf 'i\n' > "$R/taskmaster-docs/tasks/x/00-INDEX.md"
is_fresh "$R" "untracked files in .claude/ state and taskmaster-docs/ leave it fresh"
seeded; mkdir -p "$R/.claude/skills/new"; printf 'skill\n' > "$R/.claude/skills/new/SKILL.md"
is_stale "$R" "a new untracked project skill under .claude/skills/ reads stale" "files changed"
seeded; printf '{}\n' > "$R/.claude/settings.json"
is_stale "$R" "a new untracked .claude/settings.json reads stale" "files changed"
seeded; printf '.env*\n*.log\n' > "$R/.gitignore"; git -C "$R" add .gitignore; git -C "$R" commit -qm ignore
printf 'A=1\n' > "$R/.env"; in_r run --name suite -- true >/dev/null 2>&1; printf 'noise\n' > "$R/build.log"
is_fresh "$R" "another gitignored file leaves it fresh (a stated limit, not a guarantee)"
printf 'A=2\n' > "$R/.env"
is_stale "$R" "a gitignored root .env whose content changed reads stale" "files changed"
seeded; printf 'one\n' > "$R/src/a.txt"; touch -d '2001-01-01' "$R/src/a.txt" 2>/dev/null || touch "$R/src/a.txt"
sum=$(cksum < "$R/.git/index")
is_fresh "$R" "a file rewritten with the same content leaves it fresh"
[ "$(cksum < "$R/.git/index")" = "$sum" ] && ok "check leaves .git/index untouched, though a file's stat info changed" || bad "index write" "the index changed"

fresh_repo; S="$R"; printf 's\n' > "$S/s.txt"; git -C "$S" add s.txt && git -C "$S" commit -qm sub
fresh_repo; printf 'top\n' > "$R/top.txt"; git -C "$R" add top.txt && git -C "$R" -c protocol.file.allow=always submodule add -q "$S" sub >/dev/null 2>&1 && git -C "$R" commit -qm with-sub
printf 'dirty\n' > "$R/sub/s.txt"; in_r run --name suite -- true >/dev/null 2>&1; printf 'dirtier\n' > "$R/sub/s.txt"
is_stale "$R" "a further edit inside an already dirty submodule reads stale" "files changed"

seeded; git -C "$R" commit -q --allow-empty -m next
is_stale "$R" "a new commit reads stale" "the receipt is for another commit"
seeded; H=$(git -C "$R" rev-parse HEAD); rm -f "$R/.claude/task-runner/receipts/suite-${H:0:12}.txt"
is_stale "$R" "a missing log reads stale" "the suite log is missing"
seeded; H=$(git -C "$R" rev-parse HEAD); cp "$R/.claude/task-runner/receipts/suite-${H:0:12}.txt" "$R/.claude/task-runner/copied.txt"
edit_receipt '.checks.suite.log = ".claude/task-runner/copied.txt"'
is_stale "$R" "a log at any other path reads stale" "not the one this script writes"
seeded; H=$(git -C "$R" rev-parse HEAD); printf 'exit 1\n' >> "$R/.claude/task-runner/receipts/suite-${H:0:12}.txt"
is_stale "$R" "a log whose last line is not exit 0 reads stale" "does not end with exit 0"
seeded; printf '{"version":1,"head":' > "$R/.claude/task-runner/receipt.json"
is_stale "$R" "corrupt JSON reads stale" "the receipt cannot be read"
seeded; edit_receipt '.version = 2'
is_stale "$R" "another receipt version reads stale" "cannot be read"
seeded; edit_receipt '.checks.suite.exit = "0"'
is_stale "$R" "an exit recorded as the string \"0\" reads stale" "suite failed"
seeded; edit_receipt '.head = "0123456789abcdef0123456789abcdef01234567"'
is_stale "$R" "a receipt naming another HEAD reads stale" "another commit (0123456)"
seeded
is_stale "$R" "a name the receipt does not hold reads stale" "the receipt holds no lint check" lint
seeded; rm -f "$R/.claude/task-runner/receipt.json"
is_stale "$R" "no receipt reads stale" "no receipt has been written"

seeded
out=$(cd "$R" || exit 1; "$CR" check --name suite --cmd "sh -c 'echo suite ok'"); r=$?
[ "$r" = 0 ] && ok "--cmd naming the recorded command reads fresh" || bad "--cmd same" "rc=$r out=<$out>"
out=$(cd "$R" || exit 1; "$CR" check --name suite --cmd true); r=$?
[ "$r" = 1 ] && [ "$out" = "stale: recorded command differs: sh -c 'echo suite ok'" ] && ok "--cmd naming another command reads stale, showing the recorded one" \
  || bad "--cmd differs" "rc=$r out=<$out>"
in_r run --name suite --cmd true -- true >/dev/null 2>&1; r=$?
[ "$r" = 3 ] && ok "--cmd belongs to check: run refuses it (exit 3)" || bad "--cmd in run" "rc=$r"

seeded; in_r run --name lint -- true >/dev/null 2>&1
git -C "$R" commit -q --allow-empty -m next; in_r run --name lint -- true >/dev/null 2>&1
[ "$(jq -c '.checks | keys' "$R/.claude/task-runner/receipt.json")" = '["lint"]' ] && [ "$(jq -r .head "$R/.claude/task-runner/receipt.json")" = "$(git -C "$R" rev-parse HEAD)" ] \
  && ok "a run at another HEAD replaces the receipt, never merges into it" || bad "replace" "$(cat "$R/.claude/task-runner/receipt.json")"
is_stale "$R" "so the earlier HEAD's suite is gone from it" "holds no suite check"
seeded; printf 'dirty\n' > "$R/b.txt"; in_r run --name lint -- true >/dev/null 2>&1
[ "$(jq -c '.checks | keys' "$R/.claude/task-runner/receipt.json")" = '["lint"]' ] && ok "a run on another tree replaces the receipt too" \
  || bad "replace tree" "$(jq -c .checks "$R/.claude/task-runner/receipt.json")"

out=$(cd "$WS" || exit 1; "$CR" check --name suite); r=$?
[ "$r" = 1 ] && [ "$out" = "stale: not inside a git work tree" ] && ok "check outside a git work tree is stale, exit 1" || bad "no repo" "rc=$r out=<$out>"
seeded; out=$(check "$R" '../x'); r=$?
[ "$r" = 1 ] && case "$out" in "stale: usage error: "*) true ;; *) false ;; esac && ok "a check usage error is still stale, exit 1, never another code" || bad "check usage" "rc=$r out=<$out>"
in_r run --name suite >/dev/null 2>&1; r=$?
[ "$r" = 3 ] && ok "run with no command is a usage error (exit 3)" || bad "run usage" "rc=$r"
if command -v timeout >/dev/null 2>&1 || command -v gtimeout >/dev/null 2>&1; then
  seeded; in_r run --name suite --timeout 1 -- sleep 5 >/dev/null 2>&1; r=$?
  [ "$r" = 124 ] && ok "--timeout caps the command (exit 124)" || bad "timeout" "rc=$r"
  is_stale "$R" "and the capped run reads stale" "suite failed at"
else
  echo "SKIP: --timeout (no timeout or gtimeout here)"
fi

exit $rc
