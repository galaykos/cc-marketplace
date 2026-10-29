#!/usr/bin/env bash
# spec-ledger-lint.sh — author-time gate for grill's core rule, "no spec while the ambiguity ledger holds an UNKNOWN row" (skills/grill/SKILL.md): the spec must embed its final ledger, fully converged, and a `## Success criteria` section.
# Misses: whether the interrogation happened or the rows are truthful (skipping convergence now means fabricating a resolved ledger); a table with no Source column at all (its last cell is the status token, so no-source passes).
# Why, limits, history: rationale/derivations/plugin-taskmaster.md § plugins/taskmaster/scripts/spec-ledger-lint.sh (marketplace repository)

# Checks (each -> exit 2, `spec-ledger: <reason>` on stderr):
#   no-ledger     : spec has no `## Ambiguity ledger (final)` section
#   empty-ledger  : the section holds no data rows
#   open-unknown  : a row carries the UNKNOWN status token
#   no-status     : a data row carries none of CLEAR / ASSUMED / UNKNOWN
#   no-source     : a CLEAR row's Source cell holds no alphanumeric character (empty,
#                   a dash, a "?").
#   no-criteria   : spec has no `## Success criteria` section.
#
# CLI:
#   spec-ledger-lint.sh --spec <spec.md>
# Exit codes:
#   0  ledger present and converged (every row CLEAR or ASSUMED)
#   2  violation (reason on stderr)
#   3  usage error (Honest limitation law: .claude/skills/authoring-skills/SKILL.md (in the marketplace repository) "The four laws".)
set -euo pipefail

# Run record (card-lint-record.sh), written on both outcomes: the lint ran and what it said, never that the spec is good.
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

# The ledger section: from the `## Ambiguity ledger` heading (any level, optional "(final)") to the next `## ` heading or EOF.
section=$(awk '
  /^##+[[:space:]]+Ambiguity ledger/ { grab=1; next }
  grab && /^##[^#]/ { exit }
  grab { print }
' "$spec")

[ -n "$section" ] || violation "no-ledger: spec has no '## Ambiguity ledger (final)' section — grill must embed the converged ledger before cards"

# Data rows: pipe-table rows minus the |---| separator and a "Question"- or grill's "Item"-style header (`| # | Item | Current understanding | Status | Source |`), case-insensitive.
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
