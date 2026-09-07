#!/usr/bin/env bash
# code-redteam-diff.sh — deterministic core for the code-redteam skill.
#
# Two modes:
#   --base <git-ref> [--paths <glob>...]
#       Print `git diff <git-ref>..HEAD`, optionally scoped to the given paths.
#       This is the exact code slice the refuter panel is fed.
#   --dedup <seen-file>
#       Read a findings list on stdin (one per line, format: file:line<TAB>title)
#       and print only the NOVEL findings — those whose file:line plus normalized
#       title does not already appear in <seen-file> (same format). SEEN means
#       seen, so <seen-file> holds every previously confirmed finding.
#
# Exit codes: 0 normal, 3 usage error.
set -euo pipefail

PROG=code-redteam-diff
usage() { printf '%s: usage error: %s\n' "$PROG" "$1" >&2; exit 3; }

# Normalize a finding title: lowercase, collapse whitespace runs, trim ends.
# Keeps dedup stable across trivial title rewording between rounds.
normalize_title() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | tr -s '[:space:]' ' ' \
    | sed -e 's/^ //' -e 's/ $//'
}

# Turn a raw "file:line<TAB>title" line into its dedup key
# "file:line<TAB>normalized-title". A line with no tab keys on itself.
key_of() {
  local line="$1" fl title
  fl=${line%%$'\t'*}
  if [ "$fl" = "$line" ]; then
    title=""
  else
    title=${line#*$'\t'}
  fi
  printf '%s\t%s' "$fl" "$(normalize_title "$title")"
}

[ $# -ge 1 ] || usage "no mode given (--base or --dedup)"
mode="$1"; shift

case "$mode" in
  --base)
    [ $# -ge 1 ] || usage "--base requires a git-ref"
    base="$1"; shift
    paths=()
    if [ $# -gt 0 ]; then
      [ "$1" = "--paths" ] || usage "unexpected argument after ref: $1"
      shift
      [ $# -ge 1 ] || usage "--paths requires at least one glob"
      paths=("$@")
    fi
    if [ ${#paths[@]} -gt 0 ]; then
      git diff "$base"..HEAD -- "${paths[@]}"
    else
      git diff "$base"..HEAD
    fi
    ;;
  --dedup)
    [ $# -ge 1 ] || usage "--dedup requires a seen-file"
    seen="$1"; shift
    [ -f "$seen" ] || usage "seen-file not found: $seen"
    seenkeys=$(mktemp)
    trap 'rm -f "$seenkeys"' EXIT
    while IFS= read -r line || [ -n "$line" ]; do
      [ -n "$line" ] || continue
      printf '%s\n' "$(key_of "$line")" >> "$seenkeys"
    done < "$seen"
    while IFS= read -r line || [ -n "$line" ]; do
      [ -n "$line" ] || continue
      k=$(key_of "$line")
      if ! grep -Fxq -- "$k" "$seenkeys"; then
        printf '%s\n' "$line"
      fi
    done
    ;;
  *)
    usage "unknown mode: $mode (expected --base or --dedup)"
    ;;
esac

exit 0
