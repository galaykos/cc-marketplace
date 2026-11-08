#!/usr/bin/env bash
# Fixtures for plugins/testing/scripts/red-proof.sh, each in a throwaway git repo.
#
# The verdict matters less than the restore: a run that loses the user's fix is worse
# than no run. So every case compares a manifest of the whole working tree (bytes,
# executable bits, untracked files) plus the index before and after.
set -u
cd "$(dirname "$0")/../../../.." || exit 1
S="$(pwd)/plugins/testing/scripts/red-proof.sh"
rc=0
FX=$(mktemp -d); trap 'chmod -R u+w "$FX" 2>/dev/null; rm -rf "$FX"' EXIT

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; rc=1; }

# A repo whose src/calc.sh prints BUG at HEAD; tests/check.sh demands FIXED.
mkrepo() {
  local r="$FX/$1"
  mkdir -p "$r/src" "$r/tests"
  git -C "$r" init -q
  git -C "$r" config user.email t@example.invalid; git -C "$r" config user.name t
  printf 'echo BUG\n' > "$r/src/calc.sh"
  printf 'out=$(sh src/calc.sh); [ "$out" = FIXED ] || { echo "expected FIXED, got $out"; exit 1; }\n' > "$r/tests/check.sh"
  git -C "$r" add -A; git -C "$r" commit -qm init
  printf '%s' "$r"
}
manifest() { # dir -> every file's path, blob id and x bit, then the index and staged diff
  ( cd "$1" || exit 1
    find . -path ./.git -prune -o \( -type f -o -type l \) -print | LC_ALL=C sort | while IFS= read -r f; do
      printf '%s %s %s\n' "$f" "$(git hash-object --no-filters "$f")" "$( [ -x "$f" ] && echo x)"; done
    git ls-files -s; git diff --cached --binary | git hash-object --stdin )
}
same_tree() { # label before-file dir
  if [ "$(manifest "$3")" = "$(cat "$2")" ]; then pass "$1: working tree and index byte-identical afterwards"
  else fail "$1: working tree or index changed"; diff <(cat "$2") <(manifest "$3") | sed 's/^/      /'; fi
}
expect_rc() { if [ "$2" = "$3" ]; then pass "$1 (rc=$3)"; else fail "$1 — want rc=$2, got $3"; fi; }
no_backup() { if [ -z "$(ls -A "$1/.git/red-proof" 2>/dev/null)" ]; then pass "$2: no backup left in .git/red-proof"; else fail "$2: backup left behind"; fi; }

# --- proven: the test fails with the fix reverted and passes with it ---------
r=$(mkrepo proven); printf 'echo FIXED\n' > "$r/src/calc.sh"; manifest "$r" > "$FX/m.proven"
out=$(cd "$r" && bash "$S" --test "sh tests/check.sh" --files src/calc.sh 2>&1); got=$?
expect_rc "a guarding test is PROVEN" 0 "$got"
printf '%s' "$out" | grep -q 'expected FIXED, got BUG' && pass "the reverted run's own failure is shown" || fail "reverted-run output missing"
same_tree proven "$FX/m.proven" "$r"; no_backup "$r" proven

# --- a test that passes without the fix does not guard it --------------------
r=$(mkrepo noguard); printf 'echo FIXED\n' > "$r/src/calc.sh"; manifest "$r" > "$FX/m.noguard"
out=$(cd "$r" && bash "$S" --test "true" --files src/calc.sh 2>&1); got=$?
expect_rc "a test green without the fix exits 1" 1 "$got"
printf '%s' "$out" | grep -q 'does not guard this fix' && pass "exit 1 says the test does not guard" || fail "exit 1 message missing"
same_tree noguard "$FX/m.noguard" "$r"

# --- a test that fails with the fix proves nothing ---------------------------
r=$(mkrepo redwith); printf 'echo STILLBUG\n' > "$r/src/calc.sh"; manifest "$r" > "$FX/m.redwith"
(cd "$r" && bash "$S" --test "sh tests/check.sh" --files src/calc.sh >/dev/null 2>&1); got=$?
expect_rc "a test red with the fix exits 4" 4 "$got"
same_tree redwith "$FX/m.redwith" "$r"

# --- untracked files: a new fix file and an unrelated one, plus a staged change ---
r=$(mkrepo untracked)
printf 'echo FIXED\n' > "$r/src/helper.sh"; chmod +x "$r/src/helper.sh"
printf 'sh src/helper.sh\n' > "$r/src/calc.sh"; git -C "$r" add src/calc.sh
printf 'scratch notes, never committed\n' > "$r/notes.txt"
manifest "$r" > "$FX/m.untracked"
out=$(cd "$r" && bash "$S" --test "sh tests/check.sh" --files src/calc.sh src/helper.sh 2>&1); got=$?
expect_rc "untracked new fix file: PROVEN" 0 "$got"
same_tree untracked "$FX/m.untracked" "$r"
printf '%s' "$out" | grep -q 'untracked files included: identical' && pass "the report states the whole-tree check" || fail "whole-tree check line missing"

# --- the test hangs with the fix reverted: killed at --timeout, fix restored ---
r=$(mkrepo hang); printf 'echo FIXED\n' > "$r/src/calc.sh"; manifest "$r" > "$FX/m.hang"
start=$(date +%s)
out=$(cd "$r" && bash "$S" --test 'grep -q FIXED src/calc.sh || sleep 4321' --files src/calc.sh --timeout 2 2>&1); got=$?
took=$(( $(date +%s) - start ))
expect_rc "a hang without the fix counts as the failure" 0 "$got"
printf '%s' "$out" | grep -q 'timed out after 2s' && pass "the hang is named, not passed off as an assertion" || fail "timeout not reported"
[ "$took" -lt 30 ] && pass "the hung run was cut at the cap (${took}s)" || fail "the run took ${took}s"
pgrep -f '^sleep 4321' >/dev/null && fail "the hung test process survived" || pass "the hung test's process group was killed"
same_tree hang "$FX/m.hang" "$r"; no_backup "$r" hang

# --- red-proof itself is terminated mid-hang: the trap restores the fix -------
r=$(mkrepo term); printf 'echo FIXED\n' > "$r/src/calc.sh"; manifest "$r" > "$FX/m.term"
(cd "$r" && exec bash "$S" --test 'grep -q FIXED src/calc.sh || sleep 4322' --files src/calc.sh --timeout 120) > "$FX/term.out" 2>&1 &
pid=$!
for _ in $(seq 1 100); do grep -q BUG "$r/src/calc.sh" 2>/dev/null && break; sleep 0.1; done
grep -q BUG "$r/src/calc.sh" && pass "the fix was reverted before the signal" || fail "the fix was never reverted"
kill -TERM "$pid"; wait "$pid"; got=$?
expect_rc "SIGTERM during the reverted run exits 3" 3 "$got"
grep -q 'fix restored byte-identical' "$FX/term.out" && pass "the trap reports the restore" || fail "no restore report after SIGTERM"
pgrep -f '^sleep 4322' >/dev/null && fail "the test survived red-proof's termination" || pass "the test's process group died with the run"
same_tree term "$FX/m.term" "$r"; no_backup "$r" term

# --- --commit: the commit's diff is reverse-applied; its test file stays -------
r=$(mkrepo commit)
printf 'echo FIXED\n' > "$r/src/calc.sh"; printf '# reworded\n' >> "$r/tests/check.sh"
git -C "$r" commit -qam "fix calc"; manifest "$r" > "$FX/m.commit"
out=$(cd "$r" && bash "$S" --test "sh tests/check.sh" --commit HEAD 2>&1); got=$?
expect_rc "--commit HEAD with fix and test: PROVEN" 0 "$got"
printf '%s' "$out" | grep -q 'kept, not reverted (look like tests): tests/check.sh' && pass "the commit's test file is kept" || fail "test file not reported as kept"
same_tree commit "$FX/m.commit" "$r"

# A later edit to the same line: the reverse patch does not apply, nothing is touched.
printf 'echo FIXED-AGAIN\n' > "$r/src/calc.sh"; manifest "$r" > "$FX/m.conflict"
(cd "$r" && bash "$S" --test "sh tests/check.sh" --commit HEAD >/dev/null 2>&1); got=$?
expect_rc "a commit that no longer reverse-applies exits 3" 3 "$got"
same_tree conflict "$FX/m.conflict" "$r"

# --- --commit that adds, deletes, renames and chmods, with a binary: each reverts, each comes back ---
r=$(mkrepo acd)
printf 'old\n' > "$r/src/old.sh"; printf 'gone\n' > "$r/src/gone.sh"; printf 'tool\n' > "$r/src/tool.sh"; git -C "$r" add -A; git -C "$r" commit -qm base
printf 'echo FIXED\n' > "$r/src/calc.sh"; mkdir -p "$r/src/lib"; git -C "$r" mv src/old.sh src/lib/moved.sh; printf 'moved\n' >> "$r/src/lib/moved.sh"
git -C "$r" rm -q src/gone.sh; printf '\000\001\002\377bin' > "$r/src/blob.bin"; chmod +x "$r/src/tool.sh"
git -C "$r" add -A; git -C "$r" commit -qm "fix with add, delete, rename, mode, binary"; manifest "$r" > "$FX/m.acd"
t='s=$(grep -q FIXED src/calc.sh && echo green || echo red); { find src -type f | LC_ALL=C sort; [ -x src/tool.sh ] && echo exec; } > '"$FX"'/acd.$s; sh tests/check.sh'
(cd "$r" && bash "$S" --test "$t" --commit HEAD >/dev/null 2>&1); got=$?
expect_rc "--commit with an add, a delete, a rename, a mode change and a binary: PROVEN" 0 "$got"
[ "$(cat "$FX/acd.red" 2>/dev/null)" = "$(printf 'src/calc.sh\nsrc/gone.sh\nsrc/old.sh\nsrc/tool.sh')" ] \
  && pass "the reverted run saw the parent's files: blob and moved file gone, deleted and old name back, x bit off" \
  || { fail "the reverted run saw the wrong files"; sed 's/^/      /' "$FX/acd.red" 2>/dev/null; }
[ "$(cat "$FX/acd.green" 2>/dev/null)" = "$(printf 'src/blob.bin\nsrc/calc.sh\nsrc/lib/moved.sh\nsrc/tool.sh\nexec')" ] \
  && pass "the green run saw the commit's files again" || fail "the green run saw the wrong files"
same_tree acd "$FX/m.acd" "$r"; no_backup "$r" acd

# --- a user's diff config does not reach the reverse patch ---------------------
for cfg in diff.noprefix=true diff.context=0; do
  r=$(mkrepo "cfg-${cfg%%=*}"); git -C "$r" config "${cfg%%=*}" "${cfg#*=}"
  printf '# a\n# b\n# c\necho BUG\n# d\n# e\n# f\n' > "$r/src/calc.sh"; git -C "$r" commit -qam "mid-file"
  printf '# a\n# b\n# c\necho FIXED\n# d\n# e\n# f\n' > "$r/src/calc.sh"; git -C "$r" commit -qam fix; manifest "$r" > "$FX/m.cfg"
  (cd "$r" && bash "$S" --test "sh tests/check.sh" --commit HEAD >/dev/null 2>&1); got=$?
  expect_rc "--commit with $cfg in the repo config: PROVEN" 0 "$got"
  same_tree "$cfg" "$FX/m.cfg" "$r"
done

# --- --commit on a file name git would C-quote: tab, quotes, backslash ---------
r=$(mkrepo odd); odd=$'src/odd "q"\tname\\x.sh'
printf 'echo BUG\n' > "$r/$odd"; git -C "$r" add -A; git -C "$r" commit -qm odd
printf 'echo FIXED\n' > "$r/$odd"; git -C "$r" commit -qam "fix odd"; manifest "$r" > "$FX/m.odd"
(cd "$r" && bash "$S" --test 'cat src/odd* | grep -q FIXED' --commit HEAD >/dev/null 2>&1); got=$?
expect_rc "--commit on an odd file name reverts it: PROVEN" 0 "$got"
same_tree odd "$FX/m.odd" "$r"

# --- nearest silent input: the named file has no change, the test never runs ---
r=$(mkrepo nochange); manifest "$r" > "$FX/m.nochange"
(cd "$r" && bash "$S" --test "touch $FX/ran" --files src/calc.sh >/dev/null 2>&1); got=$?
expect_rc "no change in the named file exits 3" 3 "$got"
[ -e "$FX/ran" ] && fail "the test ran with nothing reverted" || pass "the test was not run"
same_tree nochange "$FX/m.nochange" "$r"

# --- restore fails: exit 5, backup kept, the printed recovery works -----------
if [ "$(id -u)" != 0 ]; then
  r=$(mkrepo stuck); printf 'echo FIXED\n' > "$r/src/calc.sh"; manifest "$r" > "$FX/m.stuck"
  out=$(cd "$r" && bash "$S" --test 'grep -q FIXED src/calc.sh || chmod a-w src; sh tests/check.sh' --files src/calc.sh 2>&1); got=$?
  expect_rc "a restore that cannot write exits 5" 5 "$got"
  printf '%s' "$out" | grep -q 'COULD NOT RESTORE THE FIX CLEANLY' && pass "exit 5 is loud" || fail "exit 5 not loud"
  rec=$(ls -d "$r"/.git/red-proof/*/ 2>/dev/null | head -1)
  [ -n "$rec" ] && [ -f "$rec/RECOVER" ] && pass "the backup and RECOVER file are kept" || fail "backup missing after exit 5"
  (cd "$r" && bash "$S" --test true --files src/calc.sh >/dev/null 2>&1); got=$?
  expect_rc "the next run refuses while a backup is pending" 5 "$got"
  chmod u+w "$r/src"
  sed -n 's/^  //p' "$rec/RECOVER" | (cd "$r" && bash) && pass "the printed recovery commands run" || fail "recovery commands failed"
  same_tree "recovered" "$FX/m.stuck" "$r"; no_backup "$r" recovered
else
  echo "SKIP: restore-failure case needs a non-root user (root ignores the read-only directory)"
fi

# --- SIGINT and SIGHUP mid-run restore the fix like SIGTERM (job control, so the signal is not ignored) ---
for sig in INT HUP; do
  r=$(mkrepo "sig$sig"); printf 'echo FIXED\n' > "$r/src/calc.sh"; manifest "$r" > "$FX/m.sig"
  set -m
  (cd "$r" && exec bash "$S" --test 'grep -q FIXED src/calc.sh || sleep 4327' --files src/calc.sh --timeout 120) > "$FX/sig.out" 2>&1 &
  pid=$!
  set +m
  for _ in $(seq 1 100); do grep -q BUG "$r/src/calc.sh" 2>/dev/null && pgrep -f '^sleep 4327' >/dev/null && break; sleep 0.1; done
  kill -"$sig" "$pid"; wait "$pid"; got=$?
  expect_rc "SIG$sig during the reverted run exits 3" 3 "$got"
  grep -q 'fix restored byte-identical' "$FX/sig.out" && pass "SIG$sig: the trap reports the restore" || fail "SIG$sig: no restore report"
  pgrep -f '^sleep 4327' >/dev/null && { fail "SIG$sig: the test survived"; pkill -f '^sleep 4327'; } || pass "SIG$sig: the test's process group died with the run"
  same_tree "sig$sig" "$FX/m.sig" "$r"; no_backup "$r" "sig$sig"
done

# --- a process the test backgrounds does not outlive the test into the restore ---
r=$(mkrepo bg); printf 'echo FIXED\n' > "$r/src/calc.sh"; manifest "$r" > "$FX/m.bg"
(cd "$r" && bash "$S" --test '(sleep 4328 &); sleep 4329 & sh tests/check.sh' --files src/calc.sh >/dev/null 2>&1); got=$?
expect_rc "a test that leaves a background process: PROVEN" 0 "$got"
pgrep -f '^sleep 432[89]' >/dev/null && { fail "the test's background processes survived the run"; pkill -f '^sleep 432[89]'; } || pass "the test's background processes were killed with its group"
same_tree bg "$FX/m.bg" "$r"

# --- a backup copy deleted mid-run: exit 5, never "absent before" -------------
r=$(mkrepo lost); printf 'echo FIXED\n' > "$r/src/calc.sh"; manifest "$r" > "$FX/m.lost"
out=$(cd "$r" && bash "$S" --test 'grep -q FIXED src/calc.sh || { rm -f .git/red-proof/*/files/src/calc.sh; exit 1; }' --files src/calc.sh 2>&1); got=$?
expect_rc "a backup copy missing at restore exits 5" 5 "$got"
printf '%s' "$out" | grep -q 'backup copy missing: src/calc.sh' && pass "the missing copy is named" || fail "the missing copy is not named"
[ -e "$r/src/calc.sh" ] && pass "the reverted file is left in place, not deleted" || fail "the file was deleted"
(cd "$r" && bash "$S" --test true --files src/calc.sh >/dev/null 2>&1); got=$?
expect_rc "the next run refuses while that backup is pending" 5 "$got"
tree0=$(printf '%s' "$out" | sed -n 's/^recovery point: tree \([0-9a-f]*\);.*/\1/p')
git -C "$r" restore --source="$tree0" --worktree -- src/calc.sh && rm -rf "$r/.git/red-proof"
same_tree "lost, recovered from the printed tree" "$FX/m.lost" "$r"

# --- concurrent runs: one lock per repository ------------------------------
r=$(mkrepo duo); printf 'echo FIXED\n' > "$r/src/calc.sh"; manifest "$r" > "$FX/m.duo"
# A loaded machine can start the second run after the first ends, so the check is no overlap, not a refusal.
t='echo in >> '"$FX"'/duo.log; sleep 1; echo out >> '"$FX"'/duo.log; sh tests/check.sh'
: > "$FX/duo.log"
(cd "$r" && bash "$S" --test "$t" --files src/calc.sh >/dev/null 2>&1) & p1=$!
(cd "$r" && bash "$S" --test "$t" --files src/calc.sh >/dev/null 2>&1) & p2=$!
wait "$p1"; r1=$?; wait "$p2"; r2=$?
case "$(printf '%s\n' "$r1" "$r2" | sort | tr '\n' ' ')" in
  "0 3 "|"0 5 "|"0 0 ") pass "two runs started together: one proves, the other refuses or runs after it (rc=$r1/$r2)" ;;
  *) fail "two runs started together returned rc=$r1 and rc=$r2" ;;
esac
seq=$(tr '\n' ' ' < "$FX/duo.log")
case "$seq" in
  "in out in out "|"in out in out in out in out ") pass "the two runs' tests never overlapped ($(grep -c in "$FX/duo.log") test runs)" ;;
  *) fail "the two runs' tests overlapped: $seq" ;;
esac
same_tree duo "$FX/m.duo" "$r"; no_backup "$r" duo

# A second run during the first one's reverted run: it touches nothing and prints the restore commands.
t='if grep -q FIXED src/calc.sh; then exit 0; fi; touch '"$FX"'/duo.red; sleep 3; exit 1'
rm -f "$FX/duo.red"
(cd "$r" && bash "$S" --test "$t" --files src/calc.sh > "$FX/duo1.out" 2>&1) & p1=$!
for _ in $(seq 1 100); do [ -e "$FX/duo.red" ] && break; sleep 0.1; done
out=$(cd "$r" && bash "$S" --test true --files src/calc.sh 2>&1); got=$?
expect_rc "a run while another has the fix reverted exits 5" 5 "$got"
printf '%s' "$out" | grep -q 'which wrote it, is alive' && printf '%s' "$out" | grep -q 'Restore every fix path' \
  && pass "it names the live pid and still prints the restore commands" || fail "no live-pid note or no restore commands"
printf '%s' "$out" | grep -qE 'if it is gone, remove' && fail "it advises deleting the backup" || pass "it never advises deleting the backup"
wait "$p1"; got=$?
expect_rc "the first run is unaffected and PROVEN" 0 "$got"
same_tree "duo, second run during the first" "$FX/m.duo" "$r"; no_backup "$r" "duo second"

# A SIGKILL during the green run leaves no reverted marker: a later edit is never offered for overwrite.
t='if grep -q FIXED src/calc.sh; then touch '"$FX"'/duo.green; sleep 4330; fi; exit 1'
rm -f "$FX/duo.green"
(cd "$r" && exec bash "$S" --test "$t" --files src/calc.sh >/dev/null 2>&1) & p1=$!
for _ in $(seq 1 100); do [ -e "$FX/duo.green" ] && break; sleep 0.1; done
kill -KILL "$p1"; wait "$p1" 2>/dev/null; pkill -f '^sleep 4330'
printf 'echo FIXED, and edited after the kill\n' > "$r/src/calc.sh"; manifest "$r" > "$FX/m.duo2"
out=$(cd "$r" && bash "$S" --test 'grep -q FIXED src/calc.sh' --files src/calc.sh 2>&1); got=$?
expect_rc "after a SIGKILL in the green run the next run takes the stale lock and proves" 0 "$got"
printf '%s' "$out" | grep -q 'left the fix reverted' && fail "the next run offered the old backup over the newer edit" || pass "the next run does not offer the old backup"
same_tree "duo, newer edit kept" "$FX/m.duo2" "$r"; no_backup "$r" "duo stale lock"

# A reverted backup whose pid is alive (here: this harness, as after pid reuse): refused with the restore commands, kept.
r=$(mkrepo reused); printf 'echo FIXED\n' > "$r/src/calc.sh"
mkdir -p "$r/.git/red-proof/20260101-000000-$$/files"; : > "$r/.git/red-proof/20260101-000000-$$/reverted"
printf 'Restore every fix path (fixture)\n' > "$r/.git/red-proof/20260101-000000-$$/RECOVER"
out=$(cd "$r" && bash "$S" --test "sh tests/check.sh" --files src/calc.sh 2>&1); got=$?
expect_rc "a reverted backup with a live pid is refused" 5 "$got"
printf '%s' "$out" | grep -q 'Restore every fix path (fixture)' && pass "its RECOVER is printed although the pid is alive" || fail "RECOVER not printed for a live pid"
[ -f "$r/.git/red-proof/20260101-000000-$$/reverted" ] && pass "the backup is kept" || fail "the backup was removed"

# A run killed before it reverted anything leaves a backup dir with no `reverted` marker: cleared, not refused.
r=$(mkrepo stale); printf 'echo FIXED\n' > "$r/src/calc.sh"
sh -c 'exit 0' & dead=$!; wait "$dead"
mkdir -p "$r/.git/red-proof/20260101-000000-$dead/files"
(cd "$r" && bash "$S" --test "sh tests/check.sh" --files src/calc.sh >/dev/null 2>&1); got=$?
expect_rc "a stale pre-revert backup dir does not block the next run" 0 "$got"
no_backup "$r" stale

# --- usage --------------------------------------------------------------------
r=$(mkrepo usage)
ec() { local label="$1" want="$2"; shift 2; (cd "$r" && "$@" >/dev/null 2>&1); expect_rc "$label" "$want" "$?"; }
ec "missing --test is a usage error" 2 bash "$S" --files src/calc.sh
ec "no --files or --commit is a usage error" 2 bash "$S" --test true
ec "--files with --commit is a usage error" 2 bash "$S" --test true --files src/calc.sh --commit HEAD
ec "a directory in --files is a usage error" 2 bash "$S" --test true --files src
ec "a non-integer --timeout is a usage error" 2 bash "$S" --test true --files src/calc.sh --timeout soon
mkdir -p "$FX/nogit"; (cd "$FX/nogit" && GIT_CEILING_DIRECTORIES="$FX" bash "$S" --test true --files x >/dev/null 2>&1)
expect_rc "outside a git work tree is a usage error" 2 "$?"

[ "$rc" -eq 0 ] && echo "All red-proof fixtures passed."
exit "$rc"
