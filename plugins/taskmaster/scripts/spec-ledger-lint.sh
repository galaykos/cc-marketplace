#!/usr/bin/env bash
# spec-ledger-lint.sh — author-time gate for grill's core rule: "no spec while
# the ambiguity ledger holds an UNKNOWN row" (skills/grill/SKILL.md). The spec
# must embed its final ledger, and that ledger must be fully converged.
#
# LIMITATION (honest scope, same class as verify-teeth-lint):
#   This lint proves the spec CARRIES a converged ledger table — it cannot prove
#   the interrogation really happened or that the rows are truthful. It converts
#   "silently skip convergence" into "must actively fabricate a resolved ledger",
#   and makes the final ledger a reviewable audit artifact inside the spec.
#
# Checks (each -> exit 2, `spec-ledger: <reason>` on stderr):
#   no-ledger     : spec has no `## Ambiguity ledger (final)` section
#   empty-ledger  : the section holds no data rows
#   open-unknown  : a row carries the UNKNOWN status token
#   no-status     : a data row carries none of CLEAR / ASSUMED / UNKNOWN
#   no-source     : a CLEAR row's Source cell holds no alphanumeric character (empty,
#                   a dash, a "?"). grill promises "decisions (CLEAR rows with sources)";
#                   a blank source is a settled claim nothing can be traced back to.
#                   LENIENT BY DESIGN: a table with no Source column at all is an
#                   accepted header variant, so its last cell is the status token and
#                   the check passes. It catches the dropped source, not the absent column.
#   no-criteria   : spec has no `## Success criteria` section. coverage-check and
#                   spec-redteam both key off that exact heading, so a spec without it
#                   degrades both into silent no-ops rather than failing loudly.
#
# CLI:
#   spec-ledger-lint.sh --spec <spec.md>
# Exit codes:
#   0  ledger present and converged (every row CLEAR or ASSUMED)
#   2  violation (reason on stderr)
#   3  usage error (Honest limitation law: claude-authoring/skills/authoring-skills/SKILL.md "The four laws".)
set -euo pipefail

# RUN RECORD. The lint is a gate when it runs, and nothing observed that it ran —
# a card set could reach execution with none of the three invoked and every check in
# the repo green. `record_run` appends one line per invocation beside the card; the
# reader is hooks/card-lint-observe.sh. Written on BOTH outcomes: the record says the
# lint ran and what it said, never that the card is good.
_cardlint_target=""
. "$(dirname "$0")/card-lint-record.sh" 2>/dev/null || true
record_run() { # $1 = verdict. No-op in --line mode: no file to key the record on.
  [ -n "$_cardlint_target" ] || return 0
  command -v cardlint_write >/dev/null 2>&1 || return 0
  cardlint_write spec-ledger "$_cardlint_target" "$1"
}

die_usage() {
  printf 'spec-ledger: usage error: %s\n' "$1" >&2
  exit 3
}

violation() {
  record_run block
  printf 'spec-ledger: %s\n' "$1" >&2
  exit 2
}

spec=""
while [ $# -gt 0 ]; do
  case "$1" in
    --spec)
      [ $# -ge 2 ] || die_usage "--spec needs an argument"
      spec="$2"; shift 2 ;;
    -h|--help)
      grep -E '^#' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *)
      die_usage "unknown argument: $1" ;;
  esac
done

[ -n "$spec" ] || die_usage "need --spec <spec.md>"
[ -f "$spec" ] || die_usage "spec file not found: $spec"
_cardlint_target="$spec"

# Extract the ledger section: from the `## Ambiguity ledger` heading (any level,
# optional "(final)") to the next `## ` heading or EOF.
section=$(awk '
  /^##+[[:space:]]+Ambiguity ledger/ { grab=1; next }
  grab && /^##[^#]/ { exit }
  grab { print }
' "$spec")

[ -n "$section" ] || violation "no-ledger: spec has no '## Ambiguity ledger (final)' section — grill must embed the converged ledger before cards"

# Data rows: pipe-table rows minus the header row and the |---| separator.
# Header forms accepted: "Question"-style and grill's canonical "Item"-style
# (`| # | Item | Current understanding | Status | Source |`), case-insensitive.
rows=$(printf '%s\n' "$section" | grep -E '^\|' | grep -Ev '^\|[[:space:]:|-]+\|?$' | grep -Eiv '^\|[[:space:]]*#?[[:space:]]*\|?[[:space:]]*(question|item)' || true)

[ -n "$rows" ] || violation "empty-ledger: ledger section holds no data rows"

open=$(printf '%s\n' "$rows" | grep -E '(^|[^[:alnum:]_])UNKNOWN([^[:alnum:]_]|$)' || true)
if [ -n "$open" ]; then
  first=$(printf '%s\n' "$open" | head -1)
  violation "open-unknown: ledger still holds an UNKNOWN row — no spec while an UNKNOWN row holds. First: ${first}"
fi

nostatus=$(printf '%s\n' "$rows" | grep -Ev '(^|[^[:alnum:]_])(CLEAR|ASSUMED)([^[:alnum:]_]|$)' || true)
if [ -n "$nostatus" ]; then
  first=$(printf '%s\n' "$nostatus" | head -1)
  violation "no-status: ledger row carries no CLEAR/ASSUMED status. First: ${first}"
fi

nosource=$(printf '%s\n' "$rows" | awk '
  !/(^|[^[:alnum:]_])CLEAR([^[:alnum:]_]|$)/ { next }
  {
    line = $0
    sub(/[[:space:]]+$/, "", line)
    sub(/\|$/, "", line)
    n = split(line, f, "|")
    src = f[n]
    if (src !~ /[[:alnum:]]/) print $0
  }' || true)
if [ -n "$nosource" ]; then
  first=$(printf '%s\n' "$nosource" | head -1)
  violation "no-source: CLEAR row cites no source — a settled decision must name what settled it. First: ${first}"
fi

grep -qEi '^##+[[:space:]]+Success criteria' "$spec" \
  || violation "no-criteria: spec has no '## Success criteria' section — coverage-check and spec-redteam both read that heading"

record_run pass
exit 0
