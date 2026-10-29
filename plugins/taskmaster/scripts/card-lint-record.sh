#!/usr/bin/env bash
# card-lint-record.sh — the one definition of the card-lint run record, sourced by the four card linters and hooks/card-lint-observe.sh: one TSV line appended per run (<iso8601-utc> <linter> <verdict> <target-basename>) to .lint-records/<target-basename>.log beside the target (CC_CARDLINT_DIR overrides), keyed on the card because cards are linted in one session and run in another.
# Misses: whether the card is good — a record proves only that the linter ran on that file; nothing re-reads the card, and a record can be written by hand. The writers fail silently and return 0 — a linter must never fail because its bookkeeping could not be written; cardlint_has returns 1 when no record exists.
# Why, limits, history: rationale/derivations/plugin-taskmaster.md § plugins/taskmaster/scripts/card-lint-record.sh

cardlint_dir() { # $1 = target file -> ledger dir (not created)
  if [ -n "${CC_CARDLINT_DIR:-}" ]; then
    printf '%s' "$CC_CARDLINT_DIR"
  else
    printf '%s/.lint-records' "$(dirname "$1")"
  fi
}

cardlint_file() { # $1 = target file -> that file's record path
  # Not hashed: the basename is already a legal filename, and a ledger you can grep beats an opaque one.
  printf '%s/%s.log' "$(cardlint_dir "$1")" "$(basename "$1")"
}

cardlint_write() { # $1 = linter name, $2 = target file, $3 = verdict. Always 0.
  local d f
  [ -n "${2:-}" ] || return 0
  d=$(cardlint_dir "$2") 2>/dev/null || return 0
  f=$(cardlint_file "$2") 2>/dev/null || return 0
  mkdir -p "$d" 2>/dev/null || return 0
  printf '%s\t%s\t%s\t%s\n' \
    "$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null)" "$1" "${3:-run}" "$(basename "$2")" \
    >> "$f" 2>/dev/null || return 0
  return 0
}

cardlint_has() { # $1 = linter name, $2 = target file -> 0 when a record exists
  local f
  f=$(cardlint_file "$2") 2>/dev/null || return 1
  [ -r "$f" ] || return 1
  grep -q "$(printf '\t%s\t' "$1")" "$f" 2>/dev/null
}
