#!/usr/bin/env bash
# skills-stamp-lint.sh — author-time lint for a task card's `Skills to apply` stamp.
#
# WHY: the stamp is what makes a framework/stack best-practice skill (laravel,
# react, vue, …) reach the card's executor. If a card that touches FRAMEWORK source
# is stamped "none detected", every downstream routing silently applies no skill —
# the card is implemented framework-blind. This lint refuses that: a framework card
# must name at least one skill.
#
# It is deliberately NARROW — it fails ONLY for source extensions that unambiguously
# have a best-practice plugin (.php/.blade.php/.vue/.jsx/.tsx). Generic .ts/.js/.py
# cards are NOT forced (a "none detected" there is defensible), so false positives
# are avoided.
#
# CLI:
#   skills-stamp-lint.sh --card <card.md>                    # lint the card's stamp
#   skills-stamp-lint.sh --line "<value>" --files "<paths>"  # (testing) parts form
# Exit codes:
#   0  OK (non-framework card, or framework card that names a skill)
#   2  block: missing-stamp | framework-card-no-skill
#   3  usage
set -euo pipefail

PROG=skills-stamp
usage() { printf '%s: usage error: %s\n' "$PROG" "$1" >&2; exit 3; }
fail()  { printf '%s: %s\n' "$PROG" "$1" >&2; exit 2; }

mode=""; card=""; line=""; files=""
while [ $# -gt 0 ]; do
  case "$1" in
    --card)  [ $# -ge 2 ] || usage "--card needs an argument"; card="$2"; mode=card; shift 2 ;;
    --line)  [ $# -ge 2 ] || usage "--line needs an argument"; line="$2"; mode=parts; shift 2 ;;
    --files) [ $# -ge 2 ] || usage "--files needs an argument"; files="$2"; shift 2 ;;
    -h|--help) grep -E '^#' "$0" | sed 's/^#!.*//; s/^# \{0,1\}//'; exit 0 ;;
    *) usage "unknown argument: $1" ;;
  esac
done

if [ "$mode" = card ]; then
  [ -f "$card" ] || usage "card file not found: $card"
  raw=$(grep -E -m1 '\*\*Skills to apply:\*\*' "$card" 2>/dev/null || true)
  [ -n "$raw" ] || fail "missing-stamp: card has no **Skills to apply:** line"
  line=${raw#*\*\*Skills to apply:\*\*}
  files=$(grep -vF -- "$raw" "$card" || true)   # the card minus the stamp line
elif [ "$mode" != parts ]; then
  usage "need --card <file> (or --line \"<value>\" --files \"<paths>\" for testing)"
fi

# normalize the stamp value: trim, strip one backtick layer, trim
val=$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^`//' -e 's/`$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

# framework-strong source signal: extensions that unambiguously map to a plugin skill
fw_re='\.blade\.php|\.(php|vue|jsx|tsx)([^a-z0-9]|$)'
if printf '%s' "$files" | grep -Eiq -- "$fw_re"; then
  low=$(printf '%s' "$val" | tr 'A-Z' 'a-z')
  case "$low" in
    ""|none*|"n/a"|"n\a"|"-"|"—")
      fail "framework-card-no-skill: card touches framework source but names no skill (stamp: \"$val\") — name the relevant best-practice skill (e.g. laravel-best-practices)" ;;
  esac
fi
exit 0
