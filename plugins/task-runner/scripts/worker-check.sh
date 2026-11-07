#!/usr/bin/env bash
# worker-check.sh [--since <sha>] — run after a worker returns, inside a registered run: reports a local branch other than the run's whose tip commit is newer than the run's registration (a stray commit), and a diff since <sha> (default start_sha) where 20+ added code lines and 30%+ of them are comment-only. Exit 1 with one `worker-check: <kind>: <detail>` line per finding on stdout, 0 clean, 3 no run or usage.
# Misses: commands a worker ran (a migration against the dev database leaves no diff), a new untracked file with an old mtime (cp -p, tar), a stray commit on the run's own branch, comments added in .md or config files, a block comment's inner lines without a leading `*`; a user committing on another branch during the run reads as stray.
# Why, limits, history: rationale/derivations/plugin-task-runner.md § plugins/task-runner/scripts/worker-check.sh
set -uo pipefail

PROG=worker-check
usage() { printf '%s: %s\n' "$PROG" "$1" >&2; exit 3; }

since=""
while [ $# -gt 0 ]; do
  case "$1" in
    --since) [ $# -ge 2 ] || usage "--since requires a sha"; since=$2; shift 2 ;;
    -h | --help) usage "usage: worker-check.sh [--since <sha>]" ;;
    *) usage "unknown argument: $1" ;;
  esac
done

command -v jq >/dev/null 2>&1 || usage "jq is required"
root=$(git rev-parse --show-toplevel 2>/dev/null) || usage "not inside a git work tree"
# The run sentinel lives in the main checkout; a linked worktree reaches it through the common dir.
common=$(cd "$root" && git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || common="$root/.git"
main=$(dirname "$common")
sent=""
for d in "$root" "$main"; do [ -f "$d/.claude/task-runner/active-run.json" ] && { sent="$d/.claude/task-runner/active-run.json"; break; }; done
[ -n "$sent" ] || usage "no registered run (.claude/task-runner/active-run.json); run register-run.sh first"

branch=$(jq -r '.branch // empty' "$sent" 2>/dev/null)
start=$(jq -r '.start_sha // empty' "$sent" 2>/dev/null)
[ -n "$since" ] || since=$start
[ -n "$since" ] && git -C "$root" rev-parse -q --verify "$since^{commit}" >/dev/null 2>&1 || usage "cannot resolve the base commit '$since'"
reg=$(stat -c %Y "$sent" 2>/dev/null || stat -f %m "$sent" 2>/dev/null) || usage "cannot read the run's registration time"

found=0
say() { printf 'worker-check: %s\n' "$1"; found=1; }

while IFS=$'\t' read -r ref ts sha subj; do
  [ -n "$ref" ] || continue
  [ "$ref" = "$branch" ] && continue
  case "$ref" in "$branch"-track-*) continue ;; esac   # track-orchestration's own per-track branches
  [ "$ts" -gt "$reg" ] 2>/dev/null || continue
  say "stray-commit: branch $ref got ${sha:0:12} \"$subj\" after the run registered on ${branch:-its branch}"
done < <(git -C "$root" for-each-ref refs/heads --format='%(refname:short)%09%(committerdate:unix)%09%(objectname)%09%(contents:subject)' 2>/dev/null)

counts=$(
  {
    git -C "$root" diff --unified=0 --no-color "$since" -- . 2>/dev/null
    git -C "$root" ls-files --others --exclude-standard -z 2>/dev/null | while IFS= read -r -d '' f; do
      [ "$root/$f" -nt "$sent" ] || continue
      printf '+++ b/%s\n' "$f"; sed 's/^/+/' "$root/$f" 2>/dev/null
    done
  } | awk '
    /^\+\+\+ / { f = substr($0, 7); n = split(f, p, "."); ext = (n > 1) ? tolower(p[n]) : ""; next }
    /^\+/ {
      kind = ""
      if (ext ~ /^(js|mjs|cjs|jsx|ts|tsx|java|kt|go|rs|c|h|cc|cpp|hpp|cs|php|swift|scala|dart|css|scss|less)$/) kind = "c"
      else if (ext ~ /^(py|rb|sh|bash|zsh|pl|r)$/) kind = "hash"
      else if (ext ~ /^(sql|lua|hs)$/) kind = "dash"
      else if (ext ~ /^(html|vue|svelte|xml)$/) kind = "c"
      if (kind == "") next
      line = substr($0, 2); sub(/^[ \t]+/, "", line)
      if (line == "") next
      code++
      if (kind == "c" && line ~ /^(\/\/|\/\*|\*|<!--)/) com++
      else if (kind == "hash" && line ~ /^#/ && line !~ /^#!/ && line !~ /^#\[/) com++
      else if (kind == "dash" && line ~ /^--/) com++
    }
    END { printf "%d %d\n", com + 0, code + 0 }')
com=${counts%% *}; code=${counts##* }
if [ "${code:-0}" -gt 0 ] && [ "${com:-0}" -ge 20 ] && [ $((com * 100 / code)) -ge 30 ]; then
  say "comment-heavy: $com of $code added code lines since ${since:0:12} are comment-only; strip comments the card did not ask for (code-review:comment-discipline)"
fi

exit "$found"
