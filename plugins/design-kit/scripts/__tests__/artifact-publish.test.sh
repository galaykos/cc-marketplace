#!/usr/bin/env bash
# Drives artifact-publish.sh against a bare remote: without --push nothing reaches
# the remote; with --push the orphan branch carries artifacts/<slug>.html and an
# index.html listing it; a second artifact joins the index; the source repo's
# branch, HEAD and working tree are untouched throughout; no attribution trailer.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null

git init -q -b main "$tmp/repo"
git -C "$tmp/repo" -c user.name=t -c user.email=t@x commit -q --allow-empty -m init
git init -q --bare "$tmp/remote.git"
git -C "$tmp/repo" remote add origin "$tmp/remote.git"
git -C "$tmp/repo" -c user.name=t -c user.email=t@x push -q origin main
echo dirty > "$tmp/repo/scratch.txt"
head_before="$(git -C "$tmp/repo" rev-parse HEAD)"
mkdir -p "$tmp/repo/.design-kit/artifacts"
printf '<!doctype html><html><head><title>First page</title></head><body>one</body></html>' > "$tmp/repo/.design-kit/artifacts/first.html"
printf '<!doctype html><html><head><title>Second page</title></head><body>two</body></html>' > "$tmp/repo/.design-kit/artifacts/second.html"

cd "$tmp/repo"
out="$(GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@x GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@x bash "$here/artifact-publish.sh" .design-kit/artifacts/first.html)"
case "$out" in *"not pushed"*) ;; *) echo "FAIL: dry run output: $out"; exit 1 ;; esac
git ls-remote --heads origin design-kit-pages | grep -q . && { echo "FAIL: pushed without --push"; exit 1; }

out="$(GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@x GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@x bash "$here/artifact-publish.sh" .design-kit/artifacts/first.html --push)"
case "$out" in *"pushed design-kit-pages to origin"*) ;; *) echo "FAIL: push output: $out"; exit 1 ;; esac
git ls-remote --heads origin design-kit-pages | grep -q . || { echo "FAIL: branch not on remote"; exit 1; }
git fetch -q origin design-kit-pages
git show FETCH_HEAD:artifacts/first.html | grep -q 'First page' || { echo "FAIL: artifact missing on branch"; exit 1; }
git show FETCH_HEAD:index.html | grep -q '<a href="artifacts/first.html">First page</a>' || { echo "FAIL: index missing entry"; exit 1; }
git show FETCH_HEAD:.nojekyll >/dev/null 2>&1 || { echo "FAIL: .nojekyll"; exit 1; }
git log -1 --format=%B FETCH_HEAD | grep -qiE 'co-authored-by|generated with' && { echo "FAIL: attribution trailer"; exit 1; }
[ "$(git show FETCH_HEAD --format=%P -s)" = "" ] || { echo "FAIL: first commit should be an orphan root"; exit 1; }

GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@x GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@x bash "$here/artifact-publish.sh" .design-kit/artifacts/second.html --push >/dev/null
git fetch -q origin design-kit-pages
git show FETCH_HEAD:index.html | grep -q 'artifacts/first.html' || { echo "FAIL: index lost first"; exit 1; }
git show FETCH_HEAD:index.html | grep -q 'artifacts/second.html' || { echo "FAIL: index missing second"; exit 1; }
[ "$(git rev-list --count FETCH_HEAD)" = 2 ] || { echo "FAIL: second publish should extend the branch"; exit 1; }

[ "$(git rev-parse --abbrev-ref HEAD)" = main ] || { echo "FAIL: source branch changed"; exit 1; }
[ "$(git rev-parse HEAD)" = "$head_before" ] || { echo "FAIL: source HEAD moved"; exit 1; }
[ "$(cat scratch.txt)" = dirty ] || { echo "FAIL: working tree touched"; exit 1; }
git worktree list | grep -q design-kit-pages && { echo "FAIL: scratch worktree left behind"; exit 1; }
git branch --list design-kit-pages | grep -q . && { echo "FAIL: pages branch left in the source repo"; exit 1; }

echo "PASS artifact-publish.test.sh"
