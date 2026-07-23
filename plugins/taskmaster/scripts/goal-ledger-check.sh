#!/usr/bin/env bash
# goal-ledger-check.sh — mechanical gate for goal mode's audit precondition.
#
# The ultra skill (Goal audit trail) makes the goal ledger's writability an
# ACTIVATION PRECONDITION: no auto-take may proceed unaudited. This script is
# the bash form of that rule at the two moments that matter:
#   --slug <slug>         verify .claude/taskmaster/goal-ledger-<slug>.md exists,
#                         is non-empty, and contains at least one decision entry
#                         (a "## " or "- " line beyond the header). Run it BEFORE
#                         task-cards stamps `Goal: true` into 00-INDEX.md.
#   --init --slug <slug>  create the ledger with a header if absent, then verify
#                         writability by appending+removing a probe line. Run it
#                         at goal activation.
#
# LIMITATION: proves the file exists, has entries, and is writable — cannot prove
# every auto-take was actually logged. It converts "forgot the ledger entirely"
# from silent to blocking; entry completeness stays a prose obligation.
#
# Exit codes:
#   0  ledger present/writable (per mode)
#   2  violation (reason on stderr)
#   3  usage error
set -euo pipefail

PROG=goal-ledger
usage() { printf '%s: usage error: %s\n' "$PROG" "$1" >&2; exit 3; }
violation() { printf '%s: %s\n' "$PROG" "$1" >&2; exit 2; }

slug=""; init=0; base="${GOAL_LEDGER_DIR:-.claude/taskmaster}"
while [ $# -gt 0 ]; do
  case "$1" in
    --slug) [ $# -ge 2 ] || usage "--slug needs an argument"; slug="$2"; shift 2 ;;
    --init) init=1; shift ;;
    -h|--help) grep -E '^#' "$0" | sed 's/^#!.*//; s/^# \{0,1\}//'; exit 0 ;;
    *) usage "unknown argument: $1" ;;
  esac
done
[ -n "$slug" ] || usage "need --slug <slug>"
case "$slug" in *[!a-zA-Z0-9._-]*) usage "slug carries path characters: $slug" ;; esac

ledger="$base/goal-ledger-$slug.md"

if [ "$init" = 1 ]; then
  mkdir -p "$base" 2>/dev/null || violation "init-failed: cannot create $base"
  [ -f "$ledger" ] || printf '# Goal ledger — %s\n\n' "$slug" > "$ledger" 2>/dev/null \
    || violation "init-failed: cannot create $ledger"
  # writability probe: append + remove one line; a failed append here is the
  # exact failure mode the precondition exists to catch.
  if ! printf '<!-- probe -->\n' >> "$ledger" 2>/dev/null; then
    violation "not-writable: append to $ledger failed — halt, never proceed unaudited"
  fi
  grep -vF '<!-- probe -->' "$ledger" > "$ledger.tmp" && mv "$ledger.tmp" "$ledger"
  exit 0
fi

[ -f "$ledger" ] || violation "no-ledger: $ledger missing — goal mode may not stamp 'Goal: true' without its audit trail"
[ -s "$ledger" ] || violation "empty-ledger: $ledger is empty — no auto-take was audited"
grep -Eq '^(## |- )' "$ledger" \
  || violation "no-entries: $ledger holds no decision entries (no '## '/'- ' lines) — auto-takes were not audited"
exit 0
