#!/usr/bin/env bash
# track-ports.sh — hands each parallel track its own block of TCP ports: `claim --id <track>` prints one sentence naming a block no other claim holds and nothing listens on, `release --id <track>` frees it, `list` prints the claims. Claims live in the main repository's .cc-artifacts/task-runner/ports/, shared by every worktree.
# Misses: a server whose port is hardcoded in config or code and never reads the sentence, a process that binds a port after the claim, ports held by another repository's run, and everything that is not a port (a local database, caches, a Docker daemon).
# Why, limits, history: rationale/derivations/plugin-task-runner.md § plugins/task-runner/scripts/track-ports.sh
set -uo pipefail

PROG=track-ports
usage() { printf '%s: usage: %s claim --id <track> [--count <n>] [--base <port>] | release --id <track> | list\n' "$PROG" "$PROG" >&2; exit 3; }
# Plugins before 2026-11-14 kept run state in .claude/task-runner/: copied once while the new dir is absent, never iso/ (git worktrees), the old dir left as it was.
tr_state_dir() {
  local new="$1/.cc-artifacts/task-runner" old="$1/.claude/task-runner" tmp="$1/.cc-artifacts/.task-runner.$$" e
  if [ ! -d "$new" ] && [ -d "$old" ] && mkdir -p "$tmp" 2>/dev/null; then
    for e in "$old"/* "$old"/.[!.]*; do
      [ -e "$e" ] && [ "${e##*/}" != iso ] || continue
      cp -Rp "$e" "$tmp/" 2>/dev/null || :
    done
    [ -d "$new" ] || mv "$tmp" "$new" 2>/dev/null || :
    rm -rf "$tmp"
  fi
  printf '%s\n' "$new"
}

mode=${1:-}; [ $# -gt 0 ] && shift
id=""; count=10; base=4100
while [ $# -gt 0 ]; do
  case "$1" in
    --id) [ $# -ge 2 ] || usage; id=$2; shift 2 ;;
    --count) [ $# -ge 2 ] || usage; count=$2; shift 2 ;;
    --base) [ $# -ge 2 ] || usage; base=$2; shift 2 ;;
    *) usage ;;
  esac
done
case "$mode" in claim | release) [ -n "$id" ] || usage ;; list) ;; *) usage ;; esac
case "$id" in *[!A-Za-z0-9._-]*) usage ;; esac
case "$count" in '' | *[!0-9]* | 0) usage ;; esac
case "$base" in '' | *[!0-9]*) usage ;; esac
[ "$base" -ge 1024 ] && [ $((base + count)) -le 65536 ] || usage

common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || { printf '%s: not inside a git repository\n' "$PROG" >&2; exit 3; }
root=$(dirname "$common")
tr=$(tr_state_dir "$root")
dir="$tr/ports"
mkdir -p "$dir" 2>/dev/null || { printf '%s: cannot create %s\n' "$PROG" "$dir" >&2; exit 3; }
[ -e "$tr/.gitignore" ] || printf '*\n' > "$tr/.gitignore" 2>/dev/null

say() { printf 'Ports %s-%s are this track'"'"'s (%s): bind every server and test listener there, never on a default port.\n' "$1" "$(($1 + $2 - 1))" "$3"; }
claims() { # one "<id> <base> <count>" line per claim
  local f
  for f in "$dir"/*.claim; do
    [ -f "$f" ] || continue
    printf '%s %s\n' "$(basename "$f" .claim)" "$(head -n 1 "$f")"
  done
}
listening() { (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; }

if [ "$mode" = list ]; then
  claims | while read -r who b c; do printf '%s %s-%s\n' "$who" "$b" "$((b + c - 1))"; done
  exit 0
fi
if [ "$mode" = release ]; then
  rm -f "$dir/$id.claim"
  exit 0
fi

# One claimer at a time: mkdir is atomic, and a lock older than a minute was left by a killed run.
lock="$dir/.lock"; tries=0
until mkdir "$lock" 2>/dev/null; do
  [ -n "$(find "$lock" -maxdepth 0 -mmin +1 2>/dev/null)" ] && { rmdir "$lock" 2>/dev/null; continue; }
  tries=$((tries + 1)); [ "$tries" -lt 100 ] || { printf '%s: another claim holds %s\n' "$PROG" "$lock" >&2; exit 1; }
  sleep 0.1
done
trap 'rmdir "$lock" 2>/dev/null' EXIT

if [ -f "$dir/$id.claim" ]; then
  read -r b c < "$dir/$id.claim"
  say "$b" "$c" "$id"; exit 0
fi
held=$(claims)
b=$base
while [ $((b + count)) -le 65536 ]; do
  free=1
  while read -r _ hb hc; do
    [ -n "${hb:-}" ] || continue
    [ "$b" -lt $((hb + hc)) ] && [ "$hb" -lt $((b + count)) ] && { free=0; break; }
  done <<< "$held"
  if [ "$free" = 1 ]; then
    p=$b
    while [ "$p" -lt $((b + count)) ]; do listening "$p" && { free=0; break; }; p=$((p + 1)); done
  fi
  if [ "$free" = 1 ]; then
    printf '%s %s\n' "$b" "$count" > "$dir/$id.claim" || { printf '%s: cannot write the claim\n' "$PROG" >&2; exit 1; }
    say "$b" "$count" "$id"; exit 0
  fi
  b=$((b + count))
done
printf '%s: no free block of %s ports from %s up\n' "$PROG" "$count" "$base" >&2
exit 1
