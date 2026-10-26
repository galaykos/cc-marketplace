#!/usr/bin/env bash
# receipt-fresh.sh --name <check> [--root <dir>] [--cmd <expected command>] — reads task-runner's .claude/task-runner/receipt.json; never runs task-runner.
# Fresh (exit 0): same HEAD, exit 0, the expected command if given, its own log ending `exit 0`, an unchanged digest of tracked changes, untracked files and root .env* files.
# Misses: skip-worktree/assume-unchanged files, other gitignored files, untracked files inside submodules, nested non-submodule repos, a receipt written by hand.
set -uo pipefail
PROG=receipt-fresh
usage() { printf '%s: usage error: %s\n' "$PROG" "$1" >&2; exit 2; }
stale() { printf 'stale: %s\n' "$1"; exit 1; }

name=""; dir="."; want=""; has_want=0
while [ $# -gt 0 ]; do
  case "$1" in
    --name) [ $# -ge 2 ] || usage "--name needs an argument"; name="$2"; shift 2 ;;
    --root) [ $# -ge 2 ] || usage "--root needs an argument"; dir="$2"; shift 2 ;;
    --cmd) [ $# -ge 2 ] || usage "--cmd needs an argument"; want="$2"; has_want=1; shift 2 ;;
    -h | --help) sed -n '2,4p' "$0"; exit 0 ;;
    *) usage "unknown argument: $1" ;;
  esac
done
case "$name" in
  "") usage "need --name <check>" ;;
  *[!a-zA-Z0-9._-]*) usage "--name takes letters, digits, '.', '_' and '-' only: $name" ;;
esac

# Byte-for-byte copy of task-runner's check-receipt.sh tree_digest; scripts/smoke/receipt-contract-tests.sh fails when the two differ.
tree_digest() {
  local diff=(diff --binary --no-color --no-ext-diff --no-textconv --no-renames --submodule=diff --ignore-submodules=none)
  local -x GIT_INDEX_FILE
  local idx tmp f p mode out rc n=0 paths=() hashed=() hashes=()
  idx=$(git -C "$ROOT" rev-parse --git-path index) || return 1
  case "$idx" in /*) ;; *) idx="$ROOT/$idx" ;; esac
  tmp=$(mktemp "${TMPDIR:-/tmp}/receipt-index.XXXXXX") || return 1
  if ! cp "$idx" "$tmp" 2>/dev/null; then rm -f "$tmp"; return 1; fi
  GIT_INDEX_FILE=$tmp
  if ! { git -C "$ROOT" ls-files -z --others --exclude-standard -- . ':(exclude).claude/' ':(exclude)taskmaster-docs/' &&
    git -C "$ROOT" ls-files -z --others --exclude-standard -- .claude/skills .claude/agents .claude/commands .claude/hooks .claude/settings.json &&
    git -C "$ROOT" ls-files -z --others --ignored --exclude-standard -- '.env*'; } > "$tmp.paths"; then
    rm -f "$tmp" "$tmp.paths"; return 1
  fi
  while IFS= read -r -d '' f; do
    paths+=("$f")
    p="$ROOT/$f"
    if [ -f "$p" ] && [ ! -L "$p" ] && [ -r "$p" ] && [[ $f != *$'\n'* ]]; then hashed+=("$f"); fi
  done < "$tmp.paths"
  if [ ${#hashed[@]} -gt 0 ]; then
    out=$(printf '%s\n' "${hashed[@]}" | git -C "$ROOT" hash-object --no-filters --stdin-paths) || { rm -f "$tmp" "$tmp.paths"; return 1; }
    hashes=($out)
    [ ${#hashes[@]} -eq ${#hashed[@]} ] || { rm -f "$tmp" "$tmp.paths"; return 1; }
  fi
  out=$({
    printf 'staged\n' && git -C "$ROOT" "${diff[@]}" --cached &&
      printf 'unstaged\n' && git -C "$ROOT" "${diff[@]}" &&
      printf 'untracked\n' &&
      if [ ${#paths[@]} -gt 0 ]; then
        for f in "${paths[@]}"; do
          p="$ROOT/$f"
          mode=100644; [ -x "$p" ] && mode=100755
          if [ -L "$p" ]; then printf '%s\0link %s\n' "$f" "$(readlink "$p")"
          elif [ $n -lt ${#hashed[@]} ] && [ "${hashed[$n]}" = "$f" ]; then printf '%s\0blob %s %s\n' "$f" "${hashes[$n]}" "$mode"; n=$((n + 1))
          elif [ -f "$p" ]; then printf '%s\0blob %s %s\n' "$f" "$(git -C "$ROOT" hash-object --no-filters -- "$f" 2>/dev/null || echo unreadable)" "$mode"
          else printf '%s\0other\n' "$f"
          fi
        done
      fi
  } | git -C "$ROOT" hash-object --stdin)
  rc=$?
  rm -f "$tmp" "$tmp.paths" "$tmp.lock"
  [ "$rc" = 0 ] && printf '%s\n' "$out"
}

command -v jq >/dev/null 2>&1 || stale "jq is not installed, so the receipt cannot be read"
ROOT=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) && [ -n "$ROOT" ] || stale "not inside a git repository"
head=$(git -C "$ROOT" rev-parse --verify -q HEAD) || stale "the repository has no commit yet"
rel=.claude/task-runner/receipt.json
receipt="$ROOT/$rel"
log=".claude/task-runner/receipts/$name-${head:0:12}.txt"
field() { jq -r --arg n "$name" "$1" "$receipt" 2>/dev/null; }

[ -f "$receipt" ] || stale "no receipt at $rel"
[ "$(field 'type == "object" and .version == 1 and (.head | type) == "string" and (.tree | type) == "string" and (.checks | type) == "object"')" = true ] ||
  stale "$rel cannot be read as a receipt"
[ "$(field .head)" = "$head" ] || stale "the receipt is for another commit, not HEAD ${head:0:7}"
[ "$(field '.checks[$n] | type')" = object ] || stale "the receipt has no $name check"
[ "$(field '.checks[$n].cmd | type')" = string ] || stale "the $name check in the receipt records no command"
cmd=$(field '.checks[$n].cmd | gsub("[[:cntrl:]]"; " ")')
[ "$has_want" = 0 ] || [ "$(field '.checks[$n].cmd')" = "$want" ] || stale "recorded command differs: $cmd"
code=$(field '.checks[$n].exit | tojson')
[ "$code" = 0 ] || stale "$name exited $code"
[ "$(field '.checks[$n].log')" = "$log" ] || stale "the $name log is not the one task-runner writes ($log)"
[ -f "$ROOT/$log" ] || stale "the $name log file is missing ($log)"
[ "$(tail -n 1 "$ROOT/$log")" = "exit 0" ] || stale "the $name log does not end with exit 0 ($log)"
now=$(tree_digest) || stale "could not read the working tree"
[ "$(field .tree)" = "$now" ] || stale "files changed since the check ran"
printf 'fresh: %s passed at %s (%s), log %s\n' "$name" "${head:0:7}" "$cmd" "$log"
