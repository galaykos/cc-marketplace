#!/usr/bin/env bash
# Tests for scripts/review-diff.sh — the diff file an RV-CARD dispatch names.
#
# Why: reviewers hold Read, Grep and Glob, no shell. Told to review "the diff" with none
# delivered, they re-read whole files and judged against memory (session retro 2026-10-13, V-24).
set -u
unset CLAUDE_PROJECT_DIR

here=$(cd "$(dirname "$0")" && pwd)
RD="$here/../review-diff.sh"
command -v git >/dev/null 2>&1 || { echo "SKIP: git not available"; exit 0; }

rc=0
ok()  { echo "PASS: $1"; }
bad() { echo "FAIL: $1 — $2"; rc=1; }
WS=$(mktemp -d); trap 'rm -rf "$WS"' EXIT

REPO="$WS/repo"; mkdir -p "$REPO/src" "$REPO/ui" "$REPO/app/sub"
git -C "$REPO" init -q && git -C "$REPO" config user.email t@t.t && git -C "$REPO" config user.name t
git -C "$REPO" config diff.noprefix true            # a user setting that would strip a/ b/
printf 'one\ntwo\nthree\n' > "$REPO/src/a.ts"; echo keep > "$REPO/src/other.ts"
git -C "$REPO" add -A && git -C "$REPO" commit -qm "seed"
printf 'one\ntwo\nthree\nguard\n' > "$REPO/src/a.ts"; git -C "$REPO" commit -qam "fix: guard against the empty list"
CB=$(git -C "$REPO" rev-parse HEAD)
printf 'one\nTWO\nthree\nguard\n' > "$REPO/src/a.ts"      # modifies a line the seed commit wrote
echo changed > "$REPO/src/other.ts"                      # outside the card's paths
echo '<template/>' > "$REPO/ui/New.vue"                 # untracked, inside the card's paths
echo scratch > "$REPO/notes.txt"                        # untracked, outside

out=$(cd "$REPO/app/sub" && bash "$RD" --card 03 --base "$CB" src/a.ts ui 2>&1); r=$?
P="$REPO/.claude/task-runner/rv/diff-03.patch"
[ "$r" = 0 ] && [ "$out" = "$P" ] && ok "writes rv/diff-<card>.patch at the repo root and prints its path" || bad "path" "rc=$r out=<$out>"
grep -q '^diff --git a/src/a.ts b/src/a.ts$' "$P" && grep -q '^+TWO$' "$P" \
  && ok "from a subdirectory, root-relative paths name the card's hunk, with a/ b/ headers despite diff.noprefix" || bad "modified file" "$(head -5 "$P")"
grep -q '^diff --git a/ui/New.vue b/ui/New.vue$' "$P" && grep -q '^+<template/>' "$P" \
  && ok "an untracked file under the card's paths, as a new-file diff" || bad "untracked" "$(cat "$P")"
! grep -q 'other.ts\|notes.txt' "$P" && ok "files outside the card's paths stay out" || bad "scope" "$(grep -n 'other\|notes' "$P")"
grep -q '^## src/a.ts:2,+1$' "$P" && grep -qE '^\^?[0-9a-f]{7,} .* two$' "$P" \
  && ok "blames the changed line at the base" || bad "blame" "$(sed -n '/# blame/,$p' "$P")"
grep -q ' seed$' "$P" && ok "names the subject of the commit the blame found" || bad "subject" "$(tail -3 "$P")"
head -1 "$P" | grep -q 'Cite line numbers from the working file' && ok "the file opens with the cite-from-the-working-file rule" || bad "header" "$(head -1 "$P")"

(cd "$REPO" && bash "$RD" --card '../x' --base "$CB" >/dev/null 2>&1); r=$?
[ "$r" = 3 ] && [ ! -e "$REPO/.claude/task-runner/x.patch" ] && ok "a card id with path characters is a usage error" || bad "card id" "rc=$r"
(cd "$REPO" && bash "$RD" --card 04 --base no-such-ref >/dev/null 2>&1); r=$?
[ "$r" = 3 ] && ok "a base that is no commit is a usage error" || bad "base" "rc=$r"
out=$(cd "$REPO" && bash "$RD" --card 05 --base "$CB" app 2>&1 >/dev/null); r=$?
[ "$r" = 4 ] && [ ! -e "$REPO/.claude/task-runner/rv/diff-05.patch" ] && printf '%s' "$out" | grep -q 'no diff' \
  && ok "paths with no diff against the base exit 4, say so and leave no patch" || bad "empty diff" "rc=$r out=<$out>"

exit $rc
