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
