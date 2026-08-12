#!/usr/bin/env bash
# verdict-lint.sh — mechanical format check over verifier verdict blocks.
# Usage: verdict-lint.sh [file]   (reads stdin when no file is given)
#
# Enforces the two invariants agents/verifier.md declares but nothing checked:
#   confirmed  => FETCH carries a verbatim quote ("...") AND a retrieval timestamp
#   confirmed  => CORROBORATION names a real source (present, not "none found"/"n/a")
#   unverifiable-this-session => FETCH carries a failure reason (non-empty)
# plus basic shape: CLAIM present, VERDICT one of the four values.
#
# Exit 0: every block passes. Exit 1: violations (one line each on stdout).
# Exit 2: no verdict block found at all.
#
# Residual (honest limitation): this is a FORMAT check. It proves a confirmed
# verdict carries quote+timestamp+corroboration fields — not that the quote is
# real, the fetch happened, or the corroborating source is independent. Those
# stay with the orchestrator's judgment and the verifier's own rules.
set -u

input=$(cat "${1:-/dev/stdin}") || exit 2
fail=0
blocks=0

# Split on CLAIM: lines; lint each block independently.
while IFS= read -r start; do
  blocks=$((blocks + 1))
  block=$(printf '%s\n' "$input" | awk -v s="$start" '
    NR >= s { if (NR > s && $0 ~ /^CLAIM:/) exit; print }')
  claim=$(printf '%s\n' "$block" | sed -n '1s/^CLAIM:[[:space:]]*//p' | cut -c1-50)
  verdict=$(printf '%s\n' "$block" | sed -n 's/^VERDICT:[[:space:]]*//p' | head -1 | tr -d '[:space:]')
  # FETCH / CORROBORATION values run until the next ALL-CAPS field line.
  fetch=$(printf '%s\n' "$block" | awk '/^FETCH:/{f=1} f && /^[A-Z_]+:/ && !/^FETCH:/{f=0} f{print}')
  corr=$(printf '%s\n' "$block" | sed -n 's/^CORROBORATION:[[:space:]]*//p' | head -1)

  bad() { printf 'verdict-lint: block %d (%s): %s\n' "$blocks" "${claim:-no claim}" "$1"; fail=1; }

  case "$verdict" in
    confirmed|refuted|contested|unverifiable-this-session*) : ;;
    "") bad "missing VERDICT line" ; continue ;;
    *)  bad "invalid VERDICT '$verdict'" ; continue ;;
  esac

  if [[ "$verdict" == "confirmed" ]]; then
    printf '%s' "$fetch" | grep -q 'retrieved' \
      || bad "confirmed without a retrieval timestamp in FETCH"
    [[ $(printf '%s' "$fetch" | grep -c '"') -ge 1 && "$fetch" == *'"'*'"'* ]] \
      || bad "confirmed without a verbatim quote in FETCH"
    if [[ -z "$corr" ]] || printf '%s' "$corr" | grep -qiE '^(none( found)?|n/a|-|—)[[:space:].]*$'; then
      bad "confirmed with empty/none CORROBORATION — impossible combination; demote to contested"
    fi
  elif [[ "$verdict" == unverifiable-this-session* ]]; then
    frs=$(printf '%s' "$fetch" | sed 's/^FETCH:[[:space:]]*//' | tr -d '[:space:]')
    [[ -n "$frs" || "$verdict" == *"("*")"* ]] \
      || bad "unverifiable-this-session without a failure reason"
  fi
done < <(printf '%s\n' "$input" | grep -n '^CLAIM:' | cut -d: -f1)

if [[ $blocks -eq 0 ]]; then
  echo "verdict-lint: no CLAIM block found in input" ; exit 2
fi
exit $fail
