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
#
# CLI:
#   spec-ledger-lint.sh --spec <spec.md>
# Exit codes:
#   0  ledger present and converged (every row CLEAR or ASSUMED)
#   2  violation (reason on stderr)
#   3  usage error
set -euo pipefail

die_usage() {
  printf 'spec-ledger: usage error: %s\n' "$1" >&2
  exit 3
}

violation() {
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

# Extract the ledger section: from the `## Ambiguity ledger` heading (any level,
# optional "(final)") to the next `## ` heading or EOF.
section=$(awk '
  /^##+[[:space:]]+Ambiguity ledger/ { grab=1; next }
  grab && /^##[^#]/ { exit }
  grab { print }
' "$spec")

[ -n "$section" ] || violation "no-ledger: spec has no '## Ambiguity ledger (final)' section — grill must embed the converged ledger before cards"

# Data rows: pipe-table rows minus the header row and the |---| separator.
rows=$(printf '%s\n' "$section" | grep -E '^\|' | grep -Ev '^\|[[:space:]:|-]+\|?$' | grep -Eiv '^\|[[:space:]]*#?[[:space:]]*\|?[[:space:]]*question' || true)

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

exit 0
