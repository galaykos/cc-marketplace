#!/usr/bin/env bash
# gone-branches.sh — sorts each local branch whose upstream is [gone]: merged (ancestor of the default branch), content-merged (every commit's patch, or the whole branch squashed into one, is on it), unmerged, or skipped (current, default, checked out in the main worktree, dirty or unreadable worktree).
# Prints a `default` line naming the branch compared against and how it was found, then `<class>\t<branch>\t<worktree or ->\t<detail>` per branch; writes no ref. Exit 0 listed, 1 not a repo or no default branch, 2 usage.
# Misses: a branch merged into a non-default branch, a squash edited on the remote (conflict fixes, review edits), a default branch not yet fetched; each reads unmerged, never merged.
# Why, limits, history: rationale/derivations/plugin-git-workflow.md § plugins/git-workflow/scripts/gone-branches.sh
set -uo pipefail
PROG=gone-branches
if [ $# -gt 0 ]; then
  case "$1" in -h | --help) sed -n '2,4p' "$0"; exit 0 ;; esac
  printf '%s: usage error: takes no arguments, got %s\n' "$PROG" "$1" >&2; exit 2
fi
git rev-parse --git-dir >/dev/null 2>&1 || { printf '%s: not a git repository\n' "$PROG" >&2; exit 1; }

gone=()
while IFS=$'\t' read -r ref track; do
  [ "$track" = '[gone]' ] && gone+=("${ref#refs/heads/}")
done < <(git for-each-ref --format='%(refname)%09%(upstream:track)' refs/heads)
if [ ${#gone[@]} -eq 0 ]; then printf 'none\t-\t-\tno local branch has a [gone] upstream\n'; exit 0; fi

if def=$(git symbolic-ref -q refs/remotes/origin/HEAD) && git rev-parse -q --verify "$def^{commit}" >/dev/null; then
  how="from origin/HEAD"
elif git rev-parse -q --verify 'refs/heads/main^{commit}' >/dev/null; then
  def=refs/heads/main; how="local main: origin/HEAD does not resolve"
elif git rev-parse -q --verify 'refs/heads/master^{commit}' >/dev/null; then
  def=refs/heads/master; how="local master: origin/HEAD does not resolve and there is no main"
else
  printf '%s: no default branch: origin/HEAD does not resolve and there is no local main or master\n' "$PROG" >&2; exit 1
fi
name=${def#refs/remotes/}; name=${name#refs/heads/}
case "$def" in refs/remotes/*) own=${name#*/} ;; *) own=$name ;; esac
printf 'default\t%s\t-\t%s\n' "$name" "$how"

wt_list=$(git worktree list --porcelain 2>/dev/null)
main_wt=$(sed -n '1s/^worktree //p' <<<"$wt_list")
cur=$(git symbolic-ref -q HEAD)
worktree_of() {
  local path="" line
  while IFS= read -r line; do
    case "$line" in
      'worktree '*) path=${line#worktree } ;;
      "branch refs/heads/$1") printf '%s' "$path"; return 0 ;;
    esac
  done <<<"$wt_list"
}

squash_on_default() {
  local b=$1 base t out
  base=$(git merge-base "$def" "$b" 2>/dev/null) || return 1
  # An empty diff shares its patch-id with every empty commit on the default branch.
  [ "$(git rev-parse "$base^{tree}")" = "$(git rev-parse "$b^{tree}")" ] && return 1
  t=$(GIT_AUTHOR_NAME=probe GIT_AUTHOR_EMAIL=probe@invalid GIT_COMMITTER_NAME=probe GIT_COMMITTER_EMAIL=probe@invalid \
    git commit-tree -p "$base" -m squash-probe "$b^{tree}" 2>/dev/null) || return 1
  out=$(git cherry "$def" "$t" 2>/dev/null) || return 1
  [ "${out:0:2}" = '- ' ]
}

classify() {
  local br=$1 wt=$2 b="refs/heads/$1" st out n log
  cls=skipped
  if [ "$b" = "$cur" ]; then detail="current branch"; return; fi
  if [ "$br" = "$own" ]; then detail="the default branch"; return; fi
  if [ -n "$wt" ]; then
    if [ "$wt" = "$main_wt" ]; then detail="checked out in the main worktree"; return; fi
    if ! st=$(git -C "$wt" status --porcelain 2>/dev/null); then
      detail="worktree cannot be read (git worktree prune clears one deleted from disk)"; return
    fi
    if [ -n "$st" ]; then detail="dirty worktree: uncommitted or untracked changes"; return; fi
  fi
  if git merge-base --is-ancestor "$b" "$def" 2>/dev/null; then cls=merged; detail="ancestor of $name"; return; fi
  cls=content-merged
  # git cherry skips merge commits, so content a merge commit adds would go uncompared.
  if [ "$(git rev-list --merges --count "$def..$b" 2>/dev/null)" = 0 ] &&
    out=$(git cherry "$def" "$b" 2>/dev/null) && [ -n "$out" ] && ! grep -q '^+' <<<"$out"; then
    detail="every commit's patch is on $name"; return
  fi
  if squash_on_default "$b"; then detail="the branch squashed into one patch is on $name"; return; fi
  cls=unmerged
  n=$(git rev-list --count "$def..$b" 2>/dev/null) || n=0
  log=$(git log --no-decorate --no-show-signature --format='%h %s' -n 5 "$def..$b" 2>/dev/null | tr '\t' ' ' | awk 'NR > 1 { printf "; " } { printf "%s", $0 }')
  detail="$n commit$([ "$n" = 1 ] || echo s) not on $name: $log"
  [ "$n" -gt 5 ] && detail+=" +$((n - 5)) more"
}

for br in "${gone[@]}"; do
  wt=$(worktree_of "$br")
  classify "$br" "$wt"
  printf '%s\t%s\t%s\t%s\n' "$cls" "$br" "${wt:--}" "$detail"
done
exit 0
