#!/usr/bin/env bash
# review-diff.sh — write the diff a reviewer reads, so no reviewer has to run git.
#
# Usage:
#   review-diff.sh --card <id> --base <ref> [<path>...]
#
# WHY. The reviewer agents hold Read, Grep and Glob: no shell. Dispatches said "review the
# diff" and never delivered one, so reviewers re-read whole files (1.4M to 16M cache-read
# tokens a review), compared against memory or another checkout, and skipped the history
# pass their rubric asks for; a hand-made patch file then drew patch-line citations.
# The orchestrator runs this before each RV-CARD dispatch and names the printed path in it.
# (The run-close range review is /code-review:review, which writes its own.)
#
# Writes .claude/task-runner/rv/diff-<id>.patch: `git diff <base> -- <paths>` (the working
# tree against the card's base, so uncommitted work is in it; paths are root-relative, as a
# card lists them, from any directory; no path is the whole tree),
# each untracked file under <paths> as a new-file diff, then, per hunk that changes existing
# lines, the blame of those lines at <base>, and the subjects of the commits it names.
# Prints the path. candor's completion clause reads each card file's `diff --git` lines to
# find the cards that touched UI files.
#
# Exit: 0 written, 3 usage, 4 no diff for the paths given (nothing written), 5 not a git
# work tree or not writable.
# Misses: a rename reads as a delete and an add; a binary file is named, not shown; a path
# git quotes (spaces, non-ASCII) gets no blame; lines a hunk only adds have no history.
set -euo pipefail

PROG=review-diff
usage() { printf '%s: usage error: %s\n' "$PROG" "$1" >&2; exit 3; }
die() { printf '%s: %s\n' "$PROG" "$1" >&2; exit 5; }

CARD=""; BASE=""; PATHS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --card) [ $# -ge 2 ] || usage "--card needs an argument"; CARD="$2"; shift 2 ;;
    --base) [ $# -ge 2 ] || usage "--base needs an argument"; BASE="$2"; shift 2 ;;
    -h | --help) grep -E '^#' "$0" | sed 's/^#!.*//; s/^# \{0,1\}//'; exit 0 ;;
    --) shift; PATHS+=("$@"); break ;;
    -*) usage "unknown argument: $1" ;;
    *) PATHS+=("$1"); shift ;;
  esac
done

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || die "not inside a git work tree"
# Pinned so a user's diff config cannot change the headers the blame pass and candor parse.
G=(git -C "$ROOT" -c diff.noprefix=false -c diff.mnemonicPrefix=false -c core.quotePath=true)

[ -n "$CARD" ] || usage "need --card <id>"
[ -n "$BASE" ] || usage "need --base <ref>"
case "$CARD" in *[!a-zA-Z0-9._-]*) usage "--card carries path characters: $CARD" ;; esac
git -C "$ROOT" rev-parse -q --verify "$BASE^{commit}" >/dev/null 2>&1 || usage "--base resolves to no commit: $BASE"
B12=$(git -C "$ROOT" rev-parse --short=12 "$BASE")
[ ${#PATHS[@]} -gt 0 ] || PATHS=(":/")

DIR="$ROOT/.claude/task-runner/rv"
mkdir -p "$DIR" 2>/dev/null || die "cannot create $DIR"
[ -e "${DIR%/*}/.gitignore" ] || printf '*\n' > "${DIR%/*}/.gitignore"
OUT="$DIR/diff-$CARD.patch"

write() {
  printf '# %s: working tree against %s. Cite line numbers from the working file, never from this patch.\n' "$CARD" "$B12"
  "${G[@]}" diff --no-color --no-ext-diff "$BASE" -- "${PATHS[@]}"
  git -C "$ROOT" ls-files --others --exclude-standard --full-name -z -- "${PATHS[@]}" |
    while IFS= read -r -d '' f; do
      "${G[@]}" diff --no-color --no-ext-diff --no-index -- /dev/null "$f" || [ $? -eq 1 ]
    done
  local hunks f s n shas="" bl c
  hunks=$("${G[@]}" diff --no-color --no-ext-diff -U0 "$BASE" -- "${PATHS[@]}" |
    awk '/^--- a\//{f=substr($0,7); next} /^--- /{f=""; next}
         /^@@ /{ if (f=="") next; split(substr($2,2),a,","); n=(a[2]==""?1:a[2]+0); if (n>0) print f "\t" a[1] "\t" n }')
  [ -n "$hunks" ] || return 0
  printf '\n# blame at %s of the lines each hunk changes\n' "$B12"
  while IFS=$'\t' read -r f s n; do
    printf '## %s:%s,+%s\n' "$f" "$s" "$n"
    bl=$(git -C "$ROOT" blame --date=short -L "$s,+$n" "$BASE" -- "$f" 2>/dev/null || true)
    [ -n "$bl" ] || continue
    printf '%s\n' "$bl"
    shas="$shas $(printf '%s\n' "$bl" | sed -nE 's/^\^?([0-9a-f]{7,}) .*/\1/p' | sort -u | tr '\n' ' ')"
  done <<EOF
$hunks
EOF
  printf '\n# commits those lines came from\n'
  for c in $(printf '%s\n' $shas | sort -u); do
    git -C "$ROOT" log -1 --format='%h %ad %s' --date=short "$c" 2>/dev/null || true
  done
}
write > "$OUT" || die "cannot write $OUT"
if ! grep -q '^diff --git ' "$OUT"; then
  rm -f "$OUT"
  printf '%s: no diff against %s for: %s (paths are root-relative)\n' "$PROG" "$B12" "${PATHS[*]}" >&2
  exit 4
fi
printf '%s\n' "$OUT"
