#!/usr/bin/env bash
# check-receipt.sh — `run` runs a check from the repo root and records it in .claude/task-runner/receipt.json; `check` says it still holds: same HEAD, exit 0, its own log ending `exit 0`, an unchanged digest of tracked changes, untracked files and root .env* files.
# Misses: skip-worktree/assume-unchanged files, other gitignored files, untracked files inside submodules, nested non-submodule repos, a receipt written by hand.
# Why, limits, history: rationale/derivations/plugin-task-runner.md § plugins/task-runner/scripts/check-receipt.sh
set -uo pipefail

PROG=check-receipt
TAIL_LINES=60

print_usage() {
  printf '%s\n' "usage: $PROG run --name <name> [--timeout <seconds>] -- <command...>" \
    "       $PROG check --name <name> [--cmd <expected command>]" \
    "run exits with the command's status (3 usage, 5 not a git work tree); check exits 0 fresh, 1 stale."
}
usage() { printf '%s: usage error: %s\n' "$PROG" "$1" >&2; exit 3; }
stale() { printf 'stale: %s\n' "$1"; exit 1; }

MODE=${1:-}
case "$MODE" in
  run | check) shift ;;
  -h | --help) print_usage; exit 0 ;;
  *) usage "the first argument must be run or check" ;;
esac
bad() { [ "$MODE" = check ] && stale "usage error: $1"; usage "$1"; }

NAME=""; TIMEOUT=""; WANT=""; HAS_WANT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --name) [ $# -ge 2 ] || bad "--name needs an argument"; NAME=$2; shift 2 ;;
    --timeout) [ "$MODE" = run ] || bad "--timeout belongs to run"; [ $# -ge 2 ] || bad "--timeout needs an argument"; TIMEOUT=$2; shift 2 ;;
    --cmd) [ "$MODE" = check ] || bad "--cmd belongs to check"; [ $# -ge 2 ] || bad "--cmd needs an argument"; WANT=$2; HAS_WANT=1; shift 2 ;;
    --) shift; break ;;
    *) bad "unknown argument: $1" ;;
  esac
done
case "$NAME" in
  "") bad "need --name <name>" ;;
  *[!a-zA-Z0-9._-]*) bad "--name takes letters, digits, '.', '_' and '-' only: $NAME" ;;
esac
case "$TIMEOUT" in "" | *[!0-9]*) [ -z "$TIMEOUT" ] || bad "--timeout takes whole seconds: $TIMEOUT" ;; esac
[ "$MODE" = check ] && [ $# -gt 0 ] && bad "check takes no command"
[ "$MODE" = run ] && [ $# -eq 0 ] && bad "need the command after --"

if ! ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || [ -z "$ROOT" ]; then
  [ "$MODE" = check ] && stale "not inside a git work tree"
  printf '%s: not inside a git work tree; nothing was run\n' "$PROG" >&2; exit 5
fi
RECEIPT_REL=.claude/task-runner/receipt.json
RECEIPT="$ROOT/$RECEIPT_REL"
HEAD=$(git -C "$ROOT" rev-parse -q --verify HEAD 2>/dev/null) || HEAD=""
LOG_REL=".claude/task-runner/receipts/$NAME-${HEAD:0:12}.txt"

# The working tree's digest, which every reader of the receipt recomputes byte for byte. Reads ROOT; never writes the repository's index.
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

# Each argument as one shell word, single-quoted only when it needs to be, so the recorded command reruns as it ran.
words() {
  local a q out=""
  for a in "$@"; do
    case "$a" in
      "" | *[!A-Za-z0-9_./:@%+,-]*)
        q=""
        while [[ $a == *"'"* ]]; do q="$q${a%%"'"*}'\\''"; a=${a#*"'"}; done
        a="'$q$a'" ;;
    esac
    out="$out${out:+ }$a"
  done
  printf '%s' "$out"
}

if [ "$MODE" = check ]; then
  command -v jq >/dev/null 2>&1 || stale "jq is not installed, so the receipt cannot be read"
  [ -f "$RECEIPT" ] || stale "no receipt has been written ($RECEIPT_REL)"
  [ -n "$HEAD" ] || stale "the repository has no commit yet"
  field() { jq -r --arg n "$NAME" "$1" "$RECEIPT" 2>/dev/null; }
  [ "$(field 'type == "object" and .version == 1 and (.head | type) == "string" and (.tree | type) == "string" and (.checks | type) == "object"')" = true ] ||
    stale "the receipt cannot be read ($RECEIPT_REL)"
  was=$(field .head)
  [ "$was" = "$HEAD" ] || stale "the receipt is for another commit (${was:0:7}), not ${HEAD:0:7}"
  [ "$(field '.checks[$n] | type')" = object ] || stale "the receipt holds no $NAME check"
  cmd=$(field '.checks[$n].cmd | strings | gsub("[[:cntrl:]]"; " ")')
  [ "$HAS_WANT" = 0 ] || [ "$(field '.checks[$n].cmd | strings')" = "$WANT" ] || stale "recorded command differs: $cmd"
  code=$(field '.checks[$n].exit | tojson')
  [ "$code" = 0 ] || stale "$NAME failed at ${HEAD:0:7} (exit $code)"
  log=$(field '.checks[$n].log | strings')
  [ "$log" = "$LOG_REL" ] || stale "the $NAME log is not the one this script writes (${log:-none recorded})"
  [ -f "$ROOT/$log" ] || stale "the $NAME log is missing ($log)"
  [ "$(tail -n 1 "$ROOT/$log")" = "exit 0" ] || stale "the $NAME log does not end with exit 0 ($log)"
  now=$(tree_digest) || stale "the working tree could not be read"
  [ "$(field .tree)" = "$now" ] || stale "files changed since $NAME ran at ${HEAD:0:7}"
  printf 'fresh: %s passed at %s (%s)\n' "$NAME" "${HEAD:0:7}" "$cmd"
  exit 0
fi

CMD=$(words "$@")
TREE=""
[ -z "$HEAD" ] || TREE=$(tree_digest) || TREE=""
OUT=$(mktemp "${TMPDIR:-/tmp}/check-receipt.XXXXXX") || { printf '%s: cannot create a temp file; nothing was run\n' "$PROG" >&2; exit 5; }
trap 'rm -f "$OUT"' EXIT

CAP=()
if [ -n "$TIMEOUT" ]; then
  for bin in timeout gtimeout; do
    command -v "$bin" >/dev/null 2>&1 || continue
    if "$bin" -k 1 1 true >/dev/null 2>&1; then CAP=("$bin" -k 10 "$TIMEOUT"); else CAP=("$bin" "$TIMEOUT"); fi
    break
  done
  [ ${#CAP[@]} -gt 0 ] || printf '%s: no timeout or gtimeout here; running without the %ss cap\n' "$PROG" "$TIMEOUT" >&2
fi

if [ ${#CAP[@]} -gt 0 ]; then
  (cd "$ROOT" && exec "${CAP[@]}" "$@") 2>&1 | tee "$OUT"
else
  (cd "$ROOT" && exec "$@") 2>&1 | tee "$OUT"
fi
RC=${PIPESTATUS[0]}

skip() { printf '%s: %s exited %s; no receipt written: %s\n' "$PROG" "$NAME" "$RC" "$1" >&2; exit "$RC"; }
[ -n "$HEAD" ] || skip "the repository has no commit yet"
[ -n "$TREE" ] || skip "the working tree could not be read"
command -v jq >/dev/null 2>&1 || skip "jq is not installed"
SAME=$(jq -r --arg h "$HEAD" --arg t "$TREE" 'type == "object" and .version == 1 and .head == $h and .tree == $t and (.checks | type) == "object"' \
  "$RECEIPT" 2>/dev/null) || SAME=false
if [ "$SAME" = true ]; then
  FAILED=$(jq -r --arg n "$NAME" --arg c "$CMD" '.checks[$n] | select(type == "object" and .exit != 0 and .cmd != $c) | .cmd | tostring' "$RECEIPT" 2>/dev/null)
  [ -z "$FAILED" ] || skip "the receipt keeps the failed run of a different command at this commit ($FAILED); run that command again to replace it"
fi
mkdir -p "$ROOT/.claude/task-runner/receipts" 2>/dev/null || skip "cannot create .claude/task-runner/receipts"
[ -e "$ROOT/.claude/task-runner/.gitignore" ] || printf '*\n' > "$ROOT/.claude/task-runner/.gitignore" 2>/dev/null
{
  printf '$ %s\n' "$CMD"
  tail -n "$TAIL_LINES" "$OUT"
  [ ! -s "$OUT" ] || [ -z "$(tail -c 1 "$OUT")" ] || printf '\n'
  printf 'exit %s\n' "$RC"
} > "$ROOT/$LOG_REL" 2>/dev/null || skip "cannot write $LOG_REL"

ENTRY=$(jq -n --arg cmd "$CMD" --argjson exit "$RC" --arg log "$LOG_REL" --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{cmd: $cmd, exit: $exit, log: $log, at: $at}') || skip "cannot build the receipt entry"
if [ "$SAME" = true ]; then
  jq --arg n "$NAME" --argjson e "$ENTRY" '.checks[$n] = $e' "$RECEIPT" > "$RECEIPT.tmp.$$"
else
  jq -n --arg n "$NAME" --argjson e "$ENTRY" --arg h "$HEAD" --arg t "$TREE" '{version: 1, head: $h, tree: $t, checks: {($n): $e}}' > "$RECEIPT.tmp.$$"
fi && mv "$RECEIPT.tmp.$$" "$RECEIPT" || { rm -f "$RECEIPT.tmp.$$"; skip "cannot write $RECEIPT_REL"; }
printf '%s: %s exited %s at %s; recorded in %s\n' "$PROG" "$NAME" "$RC" "${HEAD:0:7}" "$RECEIPT_REL" >&2
exit "$RC"
