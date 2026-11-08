#!/usr/bin/env bash
# red-proof.sh — proves a test guards a fix: reverts the fix in the working tree, runs the test (must fail), restores the fix byte-identical, runs the test again (must pass).
# Misses: why the reverted run failed (any failure counts, a hang included); ignored files (outside the whole-tree check); with --commit, a fix inside a path that looks like a test, which is kept, not reverted.
# Why, limits, history: rationale/derivations/plugin-testing.md § plugins/testing/scripts/red-proof.sh (marketplace repository)
#
#   red-proof.sh --test "<command>" (--files <path>... | --commit <sha>) [--timeout SECONDS]
#
#   --files    the fix is these files' working-tree changes against HEAD (new untracked files included)
#   --commit   the fix is that commit's diff, reverse-applied to the working tree; paths that look like tests stay
#   --timeout  cap per test run (default 50, so both runs fit Claude Code's 2-minute Bash timeout); a run past it is killed with its process group and counts as a failure
#
# The index is never touched. One run per repository at a time (a lock in .git/red-proof/). A run killed with SIGKILL leaves its backup there; the next run refuses to start and prints how to restore.
# Exit: 0 proven · 1 the test passed without the fix · 2 usage · 3 nothing reverted, interrupted and restored, or another run holds the lock · 4 the test failed with the fix · 5 could not restore cleanly, or a backup left reverted is pending
set -u
PROG=${0##*/}

usage() {
  printf '%s: %s\n' "$PROG" "$1" >&2
  printf 'usage: %s --test "<command>" (--files <path>... | --commit <sha>) [--timeout SECONDS]\n' "$PROG" >&2
  exit 2
}
help() { awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"; }

TEST="" ; MODE="" ; COMMIT="" ; TIMEOUT=50 ; ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --test) [ $# -ge 2 ] || usage "--test needs a command"; TEST=$2; shift 2 ;;
    --files)
      [ -z "$MODE" ] || usage "--files and --commit are exclusive"; MODE=files; shift
      while [ $# -gt 0 ]; do case "$1" in --*) break ;; esac; ARGS+=("$1"); shift; done ;;
    --commit)
      [ -z "$MODE" ] || usage "--files and --commit are exclusive"
      [ $# -ge 2 ] || usage "--commit needs a commit"; MODE=commit; COMMIT=$2; shift 2 ;;
    --timeout) [ $# -ge 2 ] || usage "--timeout needs seconds"; TIMEOUT=$2; shift 2 ;;
    -h|--help) help; exit 0 ;;
    *) usage "unknown argument $1" ;;
  esac
done
[ -n "$TEST" ] || usage "--test is required"
[ -n "$MODE" ] || usage "name the fix: --files <path>... or --commit <sha>"
[ "$MODE" = commit ] || [ "${#ARGS[@]}" -gt 0 ] || usage "--files needs at least one path"
case "$TIMEOUT" in ''|*[!0-9]*) usage "--timeout must be a positive integer" ;; esac
[ "$TIMEOUT" -gt 0 ] || usage "--timeout must be a positive integer"

ORIG_PWD=$(pwd -P)
top=$(git rev-parse --show-toplevel 2>/dev/null) || usage "not inside a git work tree"
ROOT=$(cd "$top" && pwd -P)
GITDIR=$(git rev-parse --absolute-git-dir 2>/dev/null) || usage "cannot locate the git directory"
STORE="$GITDIR/red-proof"
g() { git -C "$ROOT" --literal-pathspecs "$@"; }

LOCK="$STORE/.lock" ; LOCKED=0

# A reverted backup is checked before any pid: a pid is reused after a SIGKILL, and that backup holds the only copy of the fix.
refuse_if_reverted() {
  local old
  for old in "$STORE"/*/; do
    [ -f "$old/reverted" ] || continue
    old=${old%/}
    printf '%s: a red-proof run left the fix reverted; its backup is %s\n' "$PROG" "$old" >&2
    kill -0 "${old##*-}" 2>/dev/null && printf 'pid %s, which wrote it, is alive: if it is a red-proof run, let it finish first. A pid reused after a killed run is alive too.\n' "${old##*-}" >&2
    printf '\n' >&2
    cat "$old/RECOVER" >&2 2>/dev/null || printf 'its RECOVER file is gone; the backup copies are under %s/files\n' "$old" >&2
    exit 5
  done
}
take_lock() { mkdir "$LOCK" 2>/dev/null || return 1; LOCKED=1; printf '%s\n' "$$" > "$LOCK/pid"; }
release_lock() { [ "$LOCKED" = 1 ] && rm -rf "$LOCK"; LOCKED=0; rmdir "$STORE" 2>/dev/null; }

mkdir -p "$STORE" 2>/dev/null || { printf '%s: cannot create %s\n' "$PROG" "$STORE" >&2; exit 3; }
refuse_if_reverted
trap release_lock EXIT
trap 'exit 3' INT TERM HUP
if ! take_lock; then
  owner=$(cat "$LOCK/pid" 2>/dev/null)
  # A dead holder's lock is broken under a second mkdir, and only if it still names that holder.
  if [ -n "$owner" ] && ! kill -0 "$owner" 2>/dev/null && mkdir "$LOCK-break" 2>/dev/null; then
    [ "$(cat "$LOCK/pid" 2>/dev/null)" = "$owner" ] && rm -rf "$LOCK"
    take_lock; rmdir "$LOCK-break"
  fi
  if [ "$LOCKED" != 1 ]; then
    printf '%s: another red-proof run (pid %s) holds this repository'"'"'s lock; wait for it to finish.\n' "$PROG" "${owner:-?}" >&2
    printf 'If `ps -p %s` shows no red-proof (a pid reused after a killed run), no backup is marked reverted and the lock alone can go: rm -rf %q\n' "${owner:-?}" "$LOCK" >&2
    exit 3
  fi
fi
refuse_if_reverted
for old in "$STORE"/*/; do # left by a dead run before its revert or after its verified restore
  [ -d "$old" ] || continue
  old=${old%/}
  kill -0 "${old##*-}" 2>/dev/null || rm -rf "$old"
done

# Paths in a test-shaped place stay put in --commit mode: reverting the test with the fix fails the run for the wrong reason.
TESTLIKE='(^|/)(tests?|__tests__|__mocks__|specs?|testdata|fixtures)/|(^|/)test_[^/]*$|(_test|_spec|\.test|\.spec|Test|Tests)\.[A-Za-z0-9]+$|(^|/)conftest\.py$'
FIX=() ; KEPT=""
if [ "$MODE" = files ]; then
  for p in "${ARGS[@]}"; do
    case "$p" in /*) abs=$p ;; *) abs="$ORIG_PWD/$p" ;; esac
    { [ -d "$abs" ] && [ ! -L "$abs" ]; } && usage "$p is a directory; name the files"
    d=$(cd "$(dirname "$abs")" 2>/dev/null && pwd -P) || usage "cannot resolve $p (its directory does not exist; use --commit)"
    case "$d/" in "$ROOT"/*) ;; *) usage "$p is outside the repository $ROOT" ;; esac
    d=${d#"$ROOT"}; d=${d#/}
    FIX+=("${d:+$d/}$(basename "$abs")")
  done
  for p in "${FIX[@]}"; do
    printf '%s\n' "$p" | grep -qE "$TESTLIKE" && printf 'warning: %s looks like a test; reverting it makes the red run fail for the wrong reason\n' "$p" >&2
  done
else
  sha=$(git rev-parse --verify --quiet "$COMMIT^{commit}") || usage "--commit $COMMIT is not a commit"
  n=$(git rev-list --parents -n 1 "$sha" | wc -w | tr -d ' ')
  [ "$n" -le 2 ] || usage "$COMMIT is a merge commit; name the fix with --files"
  if [ "$n" -eq 2 ]; then parent="$sha^"; else parent=$(git hash-object -t tree /dev/null); fi
  while IFS= read -r -d '' p; do
    [ -n "$p" ] || continue
    if printf '%s\n' "$p" | grep -qE "$TESTLIKE"; then KEPT="$KEPT $p"; else FIX+=("$p"); fi
  done < <(g diff-tree -r -z --name-only --no-renames "$parent" "$sha")
  [ "${#FIX[@]}" -gt 0 ] || { printf '%s: every path %s touches looks like a test; nothing to revert\n' "$PROG" "$COMMIT"; exit 3; }
fi

RUN="$STORE/$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$RUN/files" || { printf '%s: cannot create %s\n' "$PROG" "$RUN" >&2; exit 3; }
trap 'rm -rf "$RUN"; exit 3' INT TERM HUP

# The whole non-ignored working tree, untracked files included, as one tree id, through a scratch copy of the index.
tree_of() {
  rm -f "$RUN/index"
  [ -f "$GITDIR/index" ] && cp "$GITDIR/index" "$RUN/index"
  ( cd "$ROOT" && GIT_INDEX_FILE="$RUN/index" git add -A . >/dev/null 2>&1 && GIT_INDEX_FILE="$RUN/index" git write-tree )
}
TREE0=$(tree_of) || { rm -rf "$RUN"; printf '%s: cannot snapshot the working tree (git add -A failed)\n' "$PROG" >&2; exit 3; }

copy_entry() { # src dst: a symlink as a symlink, a file with its mode and times
  mkdir -p "$(dirname "$2")" || return 1
  if [ -L "$1" ]; then ln -s "$(readlink "$1")" "$2"; else cp -p "$1" "$2"; fi
}
PRESENT=() # per FIX index: 1 backed up, 0 absent before; kept in memory, so a deleted copy cannot pass as "absent"
for i in "${!FIX[@]}"; do
  p=${FIX[$i]}
  PRESENT[$i]=0
  if [ -e "$ROOT/$p" ] || [ -L "$ROOT/$p" ]; then
    copy_entry "$ROOT/$p" "$RUN/files/$p" || { rm -rf "$RUN"; printf '%s: cannot back up %s\n' "$PROG" "$p" >&2; exit 3; }
    PRESENT[$i]=1
  fi
  d=$(dirname "$p")
  while [ "$d" != . ] && [ ! -d "$ROOT/$d" ]; do printf '%s\n' "$d" >> "$RUN/created-dirs"; d=$(dirname "$d"); done
done

{
  printf 'red-proof stopped with the fix reverted. Before the run the working tree was git tree %s.\n' "$TREE0"
  printf 'Restore every fix path, then delete the backup so red-proof runs again:\n\n  cd %q\n' "$ROOT"
  for i in "${!FIX[@]}"; do
    p=${FIX[$i]}
    if [ "${PRESENT[$i]}" = 1 ]; then printf '  rm -f %q && cp -pPR %q %q\n' "$p" "$RUN/files/$p" "$p"
    else printf '  rm -f %q\n' "$p"; fi
  done
  printf '  rm -rf %q\n\nThe same bytes are also in git: git restore --source=%s --worktree -- <path>\n' "$RUN" "$TREE0"
} > "$RUN/RECOVER"

CHILD="" ; WATCH="" ; REVERTED=0
kill_child() {
  if [ -n "$CHILD" ]; then
    kill -TERM -- -"$CHILD" 2>/dev/null
    [ "$REVERTED" = 1 ] || sleep 1 # with the fix reverted, the restore waits for nothing
    kill -KILL -- -"$CHILD" 2>/dev/null
  fi
  [ -n "$WATCH" ] && kill -KILL -- -"$WATCH" 2>/dev/null
  CHILD="" ; WATCH=""
}

restore() {
  local i p bad=0
  for i in "${!FIX[@]}"; do
    p=${FIX[$i]}
    if [ "${PRESENT[$i]}" = 1 ] && [ ! -e "$RUN/files/$p" ] && [ ! -L "$RUN/files/$p" ]; then
      bad=1; printf '    backup copy missing: %s (its bytes are in git tree %s)\n' "$p" "$TREE0" >&2; continue
    fi
    if [ -e "$ROOT/$p" ] || [ -L "$ROOT/$p" ]; then rm -f "$ROOT/$p" 2>/dev/null || bad=1; fi
    if [ "${PRESENT[$i]}" = 1 ]; then copy_entry "$RUN/files/$p" "$ROOT/$p" 2>/dev/null || bad=1; fi
  done
  if [ -f "$RUN/created-dirs" ]; then
    sort -r "$RUN/created-dirs" | while IFS= read -r d; do rmdir "$ROOT/$d" 2>/dev/null; done
  fi
  return "$bad"
}

# Byte check of each fix path against its backup copy: content, symlink target, executable bit, existence.
verify_fix() {
  local i p a b bad=0
  for i in "${!FIX[@]}"; do
    p=${FIX[$i]} ; a="$RUN/files/$p" ; b="$ROOT/$p"
    if [ "${PRESENT[$i]}" = 0 ]; then { [ -e "$b" ] || [ -L "$b" ]; } && { bad=1; printf '    should be absent: %s\n' "$p"; }
    elif [ -L "$a" ]; then [ -L "$b" ] && [ "$(readlink "$a")" = "$(readlink "$b")" ] || { bad=1; printf '    differs: %s\n' "$p"; }
    elif [ -e "$a" ]; then
      { [ -f "$b" ] && [ ! -L "$b" ] && cmp -s "$a" "$b" && { [ -x "$a" ] && [ -x "$b" ] || { [ ! -x "$a" ] && [ ! -x "$b" ]; }; }; } \
        || { bad=1; printf '    differs: %s\n' "$p"; }
    else bad=1; printf '    backup copy missing: %s (its bytes are in git tree %s)\n' "$p" "$TREE0"
    fi
  done
  return "$bad"
}

recover_loud() {
  printf '\nRED-PROOF COULD NOT RESTORE THE FIX CLEANLY. The backup stays at %s, and the tree before the run is git tree %s.\n' "$RUN" "$TREE0" >&2
  cat "$RUN/RECOVER" >&2 2>/dev/null || printf 'Its RECOVER file is gone. Restore from git: cd %q && git restore --source=%s --worktree -- <path>\n' "$ROOT" "$TREE0" >&2
}

finish_interrupted() {
  trap '' INT TERM HUP
  kill_child
  if [ "$REVERTED" = 1 ]; then
    printf '\n%s: interrupted with the fix reverted; restoring it\n' "$PROG" >&2
    if restore && verify_fix >&2; then REVERTED=0; rm -rf "$RUN"; printf '%s: fix restored byte-identical; no verdict\n' "$PROG" >&2; exit 3; fi
    REVERTED=0; recover_loud; exit 5
  fi
  rm -rf "$RUN"; exit 3
}
on_exit() {
  rc=$?
  if [ "$REVERTED" = 1 ]; then
    kill_child
    if restore && verify_fix >&2; then rm -rf "$RUN"; else recover_loud; release_lock; exit 5; fi
  fi
  release_lock
  exit "$rc"
}
trap finish_interrupted INT TERM HUP
trap on_exit EXIT

run_test() { # label -> RC, TIMED
  local log="$RUN/$1.log"
  rm -f "$RUN/capped"
  set -m
  ( cd "$ORIG_PWD" && exec bash -c "$TEST" ) </dev/null >"$log" 2>&1 &
  CHILD=$!
  ( sleep "$TIMEOUT"; : > "$RUN/capped"; kill -TERM -- -"$CHILD" 2>/dev/null; sleep 3; kill -KILL -- -"$CHILD" 2>/dev/null ) </dev/null >/dev/null 2>&1 &
  WATCH=$!
  set +m
  wait "$CHILD" 2>/dev/null; RC=$?
  kill -KILL -- -"$WATCH" 2>/dev/null; wait "$WATCH" 2>/dev/null
  kill -KILL -- -"$CHILD" 2>/dev/null # what the test left running in its group must not outlive it into the restore
  TIMED=0
  [ -f "$RUN/capped" ] && TIMED=1
  CHILD="" ; WATCH=""
}
show_tail() { if [ -s "$RUN/$1.log" ]; then tail -n 12 "$RUN/$1.log" | sed 's/^/    | /'; else printf '    | (no output)\n'; fi; }

printf 'red-proof: fix = %s path(s) from %s: %s\n' "${#FIX[@]}" "$( [ "$MODE" = files ] && echo '--files' || echo "--commit $COMMIT")" "${FIX[*]}"
[ -n "$KEPT" ] && printf 'kept, not reverted (look like tests):%s\n' "$KEPT"
printf 'recovery point: tree %s; backup %s (deleted when the run ends cleanly)\n' "$TREE0" "$RUN"

REVERTED=1
: > "$RUN/reverted"
rev_ok=1
if [ "$MODE" = files ]; then
  for p in "${FIX[@]}"; do
    if git -C "$ROOT" cat-file -e "HEAD:$p" 2>/dev/null; then g restore --source=HEAD --worktree -- "$p" 2>>"$RUN/revert.err" || { rev_ok=0; break; }
    else rm -f "$ROOT/$p" 2>>"$RUN/revert.err" || { rev_ok=0; break; }; fi
  done
else
  g diff-tree -p --binary --no-renames "$parent" "$sha" -- "${FIX[@]}" > "$RUN/fix.patch" # plumbing: no diff.noprefix, diff.context or other diff.* config
  { g apply -R --check "$RUN/fix.patch" && g apply -R "$RUN/fix.patch"; } 2>>"$RUN/revert.err" || rev_ok=0
fi
if [ "$rev_ok" = 0 ]; then
  printf '%s: could not revert the fix:\n' "$PROG"; sed 's/^/    | /' "$RUN/revert.err"
  restore && verify_fix && { REVERTED=0; rm -rf "$RUN"; printf 'working tree unchanged; no verdict\n'; exit 3; }
  REVERTED=0; recover_loud; exit 5
fi
TREE1=$(tree_of)
if [ "$TREE1" = "$TREE0" ]; then
  restore && verify_fix && { REVERTED=0; rm -rf "$RUN"; printf 'NOTHING REVERTED: the working tree is the same with the fix reverted (no change vs HEAD in the named files?); the test was not run.\n'; exit 3; }
  REVERTED=0; recover_loud; exit 5
fi

printf '\n1/3 fix reverted; running the test (must FAIL)\n'
run_test red; RED_RC=$RC; RED_TIMED=$TIMED
if [ "$RED_TIMED" = 1 ]; then printf '    FAIL: timed out after %ss and killed (counted as a failure: a hang, not an assertion)\n' "$TIMEOUT"
elif [ "$RED_RC" -ne 0 ]; then printf '    FAIL rc=%s, as required\n' "$RED_RC"
else printf '    PASS rc=0 with the fix reverted\n'; fi

trap '' INT TERM HUP
if ! restore || ! verify_fix; then REVERTED=0; recover_loud; exit 5; fi
rm -f "$RUN/reverted"; REVERTED=0
trap finish_interrupted INT TERM HUP
TREE2=$(tree_of)
others=$(g diff-tree -r --name-only --no-renames "$TREE0" "$TREE2" 2>/dev/null)
printf '\n2/3 fix restored: %s path(s) byte-identical to before the run\n' "${#FIX[@]}"
if [ "$TREE2" = "$TREE0" ]; then printf '    whole working tree, untracked files included: identical (tree %s)\n' "$TREE0"
else
  printf '    whole working tree: the test command itself changed these during the reverted run (left as they are):\n'
  printf '%s\n' "$others" | sed 's/^/      /'
fi

printf '\n3/3 running the test with the fix (must PASS)\n'
run_test green; GREEN_RC=$RC; GREEN_TIMED=$TIMED
if [ "$GREEN_TIMED" = 1 ]; then printf '    FAIL: timed out after %ss and killed; a slower suite needs --timeout N and a Bash timeout above 2N+10 seconds\n' "$TIMEOUT"
elif [ "$GREEN_RC" -ne 0 ]; then printf '    FAIL rc=%s\n' "$GREEN_RC"
else printf '    PASS rc=0\n'; fi

printf '\n'
if [ "$GREEN_TIMED" = 1 ] || [ "$GREEN_RC" -ne 0 ]; then
  printf 'NOT PROVEN: the test fails WITH the fix, so its failure without the fix shows nothing. Its output:\n'; show_tail green
  rm -rf "$RUN"; exit 4
fi
if [ "$RED_TIMED" = 0 ] && [ "$RED_RC" -eq 0 ]; then
  printf 'NOT PROVEN: the test passed with the fix reverted, so it does not guard this fix. Rewrite it until the revert turns it red.\n'
  rm -rf "$RUN"; exit 1
fi
printf 'PROVEN: the test fails without the fix and passes with it. Reverted-run output:\n'; show_tail red
rm -rf "$RUN"; exit 0
