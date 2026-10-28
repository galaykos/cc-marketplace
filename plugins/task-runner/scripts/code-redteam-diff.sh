#!/usr/bin/env bash
# code-redteam-diff.sh --base <git-ref> [--paths <glob>...] | --dedup <seen-file> — prints `git diff <ref>..HEAD`, the refuter panel's slice; or only the stdin findings (file:line<TAB>title) whose file:line and normalized title are not in <seen-file>. Exit 0, 3 usage.
# Misses: a finding re-titled beyond case and spacing, or moved to another line, reads as novel.
# Why, limits, history: rationale/derivations/plugin-task-runner.md § plugins/task-runner/scripts/code-redteam-diff.sh
set -euo pipefail

PROG=code-redteam-diff
usage() { printf '%s: usage error: %s\n' "$PROG" "$1" >&2; exit 3; }

# Lowercased and space-collapsed, so a title reworded only that way between rounds still dedups.
normalize_title() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | tr -s '[:space:]' ' ' \
    | sed -e 's/^ //' -e 's/ $//'
}

# A line with no tab keys on itself.
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
