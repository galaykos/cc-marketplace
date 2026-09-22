#!/usr/bin/env bash
# artifact-publish.sh — put one artifact on an orphan pages branch, in a scratch
# worktree, and push ONLY with --push.
#
#   artifact-publish.sh <artifact.html> [--branch design-kit-pages] [--remote origin] [--push]
#
# WHAT IT DOES. Fetches <remote>/<branch> if it exists (else starts an orphan),
# checks it out in a temporary worktree, copies the artifact to
# artifacts/<slug>.html, regenerates index.html from every artifacts/*.html
# (title from <title>), commits, and — only with --push — pushes. Then it removes
# the worktree. Your current branch, index and working tree are never touched:
# everything happens in the scratch worktree. Without --push it prints the commit
# it made locally and stops; the command asks you, then re-runs with --push.
#
# It prints the Pages URL it EXPECTS for a github.com or gitlab.com remote and
# says in the same breath that it never turns Pages on — enabling Pages for the
# branch (GitHub: Settings › Pages › branch <branch>, root; GitLab: a pages CI job)
# is yours to do once.
#
# WHAT IT DOES NOT DO. No force-push, no deletion, no other branch, no attribution
# trailers in the commit. It refuses when the artifact is not a .html file or the
# repo has no such remote. Standing: scripts/__tests__/artifact-publish.test.sh
# drives it against a bare remote.
set -euo pipefail

artifact=""; branch="design-kit-pages"; remote="origin"; push=0
while [ $# -gt 0 ]; do
  case "$1" in
    --branch) branch="$2"; shift ;;
    --remote) remote="$2"; shift ;;
    --push) push=1 ;;
    -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
    -*) echo "artifact-publish: unknown flag $1" >&2; exit 2 ;;
    *) artifact="$1" ;;
  esac
  shift
done
[ -n "$artifact" ] || { echo "artifact-publish: usage: artifact-publish.sh <artifact.html> [--branch B] [--remote R] [--push]" >&2; exit 2; }
[ -f "$artifact" ] || { echo "artifact-publish: no such file: $artifact" >&2; exit 2; }
case "$artifact" in *.html|*.htm) ;; *) echo "artifact-publish: $artifact is not an .html artifact" >&2; exit 2 ;; esac
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "artifact-publish: not inside a git repository" >&2; exit 3; }
git remote get-url "$remote" >/dev/null 2>&1 || { echo "artifact-publish: no remote named '$remote'" >&2; exit 3; }

artifact_abs="$(cd "$(dirname "$artifact")" && pwd)/$(basename "$artifact")"
slug="$(basename "$artifact" .html)"; slug="${slug%.htm}"
root="$(git rev-parse --show-toplevel)"
wt="$(mktemp -d "${TMPDIR:-/tmp}/design-kit-pages.XXXXXX")"
scratch="design-kit-pages-scratch-$$"
cleanup() {
  git -C "$root" worktree remove --force "$wt" >/dev/null 2>&1 || rm -rf "$wt"
  git -C "$root" branch -D "$scratch" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Detached or on a throwaway orphan name: the source repo never gains a
# `<branch>` ref, so a dry run followed by a real run cannot collide.
if git -C "$root" fetch --quiet "$remote" "$branch" 2>/dev/null; then
  git -C "$root" worktree add --quiet --detach "$wt" FETCH_HEAD
else
  git -C "$root" worktree add --quiet --detach "$wt"
  git -C "$wt" checkout --quiet --orphan "$scratch"
  git -C "$wt" rm -rfq --cached . >/dev/null 2>&1 || true
  find "$wt" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
fi

mkdir -p "$wt/artifacts"
cp "$artifact_abs" "$wt/artifacts/$slug.html"
title_of() { tr '\n' ' ' < "$1" | sed -n 's/.*<title>\([^<]*\)<\/title>.*/\1/p' | head -1; }
{
  printf '<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>artifacts</title>'
  printf '<style>body{font:16px/1.5 system-ui,sans-serif;max-width:48rem;margin:40px auto;padding:0 20px;color:#1d1d1b;background:#fbfbf9}li{margin:.35em 0}</style></head><body><h1>artifacts</h1><ul>'
  for f in "$wt"/artifacts/*.html; do
    [ -f "$f" ] || continue
    n="$(basename "$f")"; t="$(title_of "$f")"; [ -n "$t" ] || t="$n"
    printf '<li><a href="artifacts/%s">%s</a></li>' "$n" "$t"
  done
  printf '</ul></body></html>\n'
} > "$wt/index.html"
touch "$wt/.nojekyll"

git -C "$wt" add -A
if git -C "$wt" diff --cached --quiet; then
  echo "artifact-publish: $slug.html is already on $branch — nothing to commit"
else
  git -C "$wt" -c user.name="$(git -C "$root" config user.name || echo design-kit)" \
                -c user.email="$(git -C "$root" config user.email || echo design-kit@localhost)" \
                commit --quiet -m "artifact: $slug" -m "Published by design-kit to the $branch pages branch."
  echo "artifact-publish: committed artifacts/$slug.html on $branch (local, in a scratch worktree)"
fi

url="$(git -C "$root" remote get-url "$remote")"
pages=""
case "$url" in
  *github.com[:/]*) ownerrepo="${url#*github.com}"; ownerrepo="${ownerrepo#[:/]}"; ownerrepo="${ownerrepo%.git}"
    pages="https://${ownerrepo%%/*}.github.io/${ownerrepo#*/}/artifacts/$slug.html" ;;
  *gitlab.com[:/]*) ownerrepo="${url#*gitlab.com}"; ownerrepo="${ownerrepo#[:/]}"; ownerrepo="${ownerrepo%.git}"
    pages="https://${ownerrepo%%/*}.gitlab.io/${ownerrepo#*/}/artifacts/$slug.html" ;;
esac

if [ "$push" = 1 ]; then
  git -C "$wt" push --quiet "$remote" "HEAD:refs/heads/$branch"
  echo "artifact-publish: pushed $branch to $remote"
  if [ -n "$pages" ]; then
    echo "artifact-publish: expected URL once Pages serves branch '$branch' (this script never enables Pages): $pages"
  else
    echo "artifact-publish: remote host not recognised — serve branch '$branch' with whatever static hosting the remote offers"
  fi
else
  echo "artifact-publish: not pushed. Re-run with --push after the user confirms; the branch is '$branch' on '$remote'."
  if [ -n "$pages" ]; then
    echo "artifact-publish: it would serve at $pages once Pages is enabled for that branch"
  fi
fi
