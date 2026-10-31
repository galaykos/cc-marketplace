#!/usr/bin/env bash
# Drives gone-branches.sh on a clone whose branches the "hosting side" (a second clone of the same bare origin) merged, squash-merged,
# rebase-merged or deleted unmerged: every [gone] branch lands in its class, and the two the old blanket `git branch -D` destroyed read unmerged.
set -u
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
here="$(cd "$(dirname "$0")/.." && pwd)" || exit 1; s="$here/gone-branches.sh"
tmp=$(mktemp -d) || { echo "FAIL: mktemp -d failed"; exit 1; }
tmp=$(cd "$tmp" && pwd -P) || exit 1
trap 'rm -rf "$tmp"' EXIT
export GIT_CEILING_DIRECTORIES="$tmp" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$tmp/fixture.gitconfig"
printf '[user]\n\tname = t\n\temail = t@t\n[init]\n\tdefaultBranch = main\n[commit]\n\tgpgsign = false\n' > "$GIT_CONFIG_GLOBAL"
# The script runs with no identity configured: its squash probe commit must not need one.
printf '[user]\n\tuseConfigOnly = true\n' > "$tmp/user.gitconfig"
pass=0; fail=0
ok()  { pass=$((pass+1)); }
bad() { fail=$((fail+1)); printf 'FAIL  %s\n      %s\n' "$1" "$2"; }
run() { out=$(GIT_CONFIG_GLOBAL="$tmp/user.gitconfig" bash "$s" "$@" 2>&1); rc=$?; }
row() { awk -F'\t' -v b="$1" '$2 == b' <<<"$out"; }
# expect <branch> <class> [<detail substring>] [<worktree>] — checks the branch's row in the last run's output.
expect() {
  local r; r=$(row "$1")
  if [ "$(cut -f1 <<<"$r")" = "$2" ] && [[ "$(cut -f4 <<<"$r")" == *"${3:-}"* ]] && [ "$(cut -f3 <<<"$r")" = "${4:--}" ]; then ok
  else bad "$1 should be $2${3:+ ($3)}${4:+ in $4}" "row: ${r:-none}"; fi
}
c() { echo "$2" >> "$1" && git add "$1" && git commit -qm "$3"; }   # c <file> <line> <subject>

git init -q --bare "$tmp/origin.git"
git clone -q "$tmp/origin.git" "$tmp/srv" 2>/dev/null
cd "$tmp/srv" && c base.txt base base && git push -q origin main
git clone -q "$tmp/origin.git" "$tmp/work" && cd "$tmp/work" || exit 1
new() { git switch -q -c "$1" main; }
push() { git push -q -u origin "$1" 2>/dev/null; }
new merged; c merged.txt 1 "merged: one"; push merged
new squashed; c sq.txt 1 "squashed: one"; c sq.txt 2 "squashed: two"; c sq2.txt 1 "squashed: three"; push squashed
new rebased; c rb.txt 1 "rebased: one"; c rb.txt 2 "rebased: two"; push rebased
new abandoned; for i in 1 2 3 4 5 6 7; do c ab.txt "$i" "abandoned: $i"; done; push abandoned
new late; c late.txt 1 "late: pushed"; push late; c late.txt 2 "late: after the last push"
new wt-clean; c wtc.txt 1 "wt-clean: one"; push wt-clean
new wt-dirty; c wtd.txt 1 "wt-dirty: one"; push wt-dirty
new cur; c cur.txt 1 "cur: one"; push cur
new alive; c alive.txt 1 "alive: one"; push alive
new local-only; c lo.txt 1 "local-only: one"
git switch -q cur
git worktree add -q "$tmp/wt-clean" wt-clean && git worktree add -q "$tmp/wt-dirty" wt-dirty
echo edit >> "$tmp/wt-dirty/wtd.txt"

# The hosting side: three merge styles, a closed PR (abandoned), a squash of what was pushed (late), then a branch sweep.
cd "$tmp/srv" && git fetch -q origin
git merge -q --no-ff -m "Merge merged" origin/merged
git merge -q --squash origin/squashed >/dev/null 2>&1 && git commit -qm "squashed (#2)"
git cherry-pick "$(git merge-base main origin/rebased)..origin/rebased" >/dev/null
git merge -q --squash origin/late >/dev/null 2>&1 && git commit -qm "late (#5)"
for b in wt-clean wt-dirty cur; do git merge -q --no-ff -m "Merge $b" "origin/$b"; done
git push -q origin main
git push -q origin --delete merged squashed rebased abandoned late wt-clean wt-dirty cur 2>/dev/null
cd "$tmp/work" && git fetch -q --prune
# A merge of main into the branch that adds a file of its own; the hosting side rebase-merges only the plain commit.
new evil; c ev.txt 1 "evil: one"; git merge -q --no-ff --no-commit origin/main >/dev/null 2>&1
echo only-in-merge > ev-merge.txt && git add ev-merge.txt && git commit -qm "Merge main into evil, adding ev-merge.txt"
push evil; git switch -q cur
cd "$tmp/srv" && git fetch -q origin && git cherry-pick origin/evil^1 >/dev/null && git push -q origin main && git push -q origin --delete evil 2>/dev/null
cd "$tmp/work" && git fetch -q --prune

# The old rule's input: both unmerged branches carry [gone], so its blanket -D took them.
for b in abandoned late; do
  git branch -vv | grep -qE "^[*+ ] +$b +[0-9a-f]+ \[origin/$b: gone\]" && ok || bad "$b should show [gone] in git branch -vv" "$(git branch -vv)"
done
# Per-commit patch-ids miss a squash of three commits; only the squash probe can see it.
[ "$(git cherry origin/main squashed | grep -c '^+')" = 3 ] && ok || bad "git cherry alone should call all three squashed commits unique" "$(git cherry origin/main squashed)"

refs_before=$(git for-each-ref)
run
[ "$rc" = 0 ] && ok || bad "a repo with [gone] branches exits 0" "rc=$rc out=$out"
[ "$(head -1 <<<"$out")" = "$(printf 'default\torigin/main\t-\tfrom origin/HEAD')" ] && ok || bad "first line names origin/main from origin/HEAD" "$out"
expect merged merged "ancestor of origin/main"
expect squashed content-merged "squash"
expect rebased content-merged "every commit's patch"
expect abandoned unmerged "7 commits not on origin/main: "
expect late unmerged "late: after the last push"
expect wt-clean merged "" "$tmp/wt-clean"
expect wt-dirty skipped "dirty" "$tmp/wt-dirty"
expect cur skipped "current branch" "$tmp/work"
expect evil unmerged "adding ev-merge.txt"
r=$(row abandoned); [[ "$r" == *"abandoned: 7"*"abandoned: 3 +2 more" ]] && ok || bad "unmerged commits are listed newest first, capped at five" "$r"
[ -z "$(row alive)$(row local-only)" ] && ok || bad "a live or absent upstream is not listed" "$out"
[ "$(wc -l <<<"$out" | tr -d ' ')" = 10 ] && ok || bad "one default line plus one line per [gone] branch" "$out"
[ "$(git for-each-ref)" = "$refs_before" ] && ok || bad "no ref is written" "$(diff <(echo "$refs_before") <(git for-each-ref))"

cd "$tmp/wt-clean" && run
expect wt-clean skipped "current branch" "$tmp/wt-clean"
expect cur skipped "main worktree" "$tmp/work"
cd "$tmp/work"

# Fallbacks: local main never pulled, so the remotely merged branch now reads unmerged (the safe direction).
git remote set-head origin -d && run
[[ "$(head -1 <<<"$out")" == "$(printf 'default\tmain\t-\t')local main"* ]] && ok || bad "origin/HEAD unset falls back to local main" "$out"
expect merged unmerged "not on main"
git branch -q -m main master && run
[[ "$(head -1 <<<"$out")" == "$(printf 'default\tmaster\t-\t')local master"* ]] && ok || bad "no main falls back to local master" "$out"
git branch -q -D master && run
[ "$rc" = 1 ] && [[ "$out" == *"no default branch"* ]] && ok || bad "no default branch exits 1" "rc=$rc out=$out"

cd "$tmp/srv" && run
[ "$rc" = 0 ] && [ "$out" = "$(printf 'none\t-\t-\tno local branch has a [gone] upstream')" ] && ok || bad "no [gone] branch prints one none line" "rc=$rc out=$out"
run --dry-run
[ "$rc" = 2 ] && ok || bad "an argument is a usage error" "rc=$rc out=$out"
mkdir "$tmp/nongit" && cd "$tmp/nongit" && run
[ "$rc" = 1 ] && [[ "$out" == *"not a git repository"* ]] && ok || bad "outside a repo exits 1" "rc=$rc out=$out"

echo "gone-branches.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
