#!/usr/bin/env bash
# card-status.sh --index <00-INDEX.md> --card NN --to <status> [--reason R] [--detail D] [--children "NN NN"] — writes one card's Status cell; refuses (exit 1) an unknown status or card, a park with no reason or no detail, a split naming no child, itself or a missing row, a split parent reopened before its children are done, a detail with | or a newline. Exit 0 written, 2 usage or I/O.
# Misses: who calls it (a subagent can run it; only the orchestrator should), a reason that is untrue, a second in_progress card (noted on stderr, still written, since a delegated parallel group has several).
# Why, limits, history: rationale/derivations/plugin-task-runner.md § plugins/task-runner/scripts/card-status.sh
set -uo pipefail

PROG=card-status
STATUSES="pending in_progress done parked blocked skipped"
REASONS="evidence misspec needs-user split guard"
die() { printf '%s: %s\n' "$PROG" "$1" >&2; exit 2; }
refuse() { printf '%s: %s\n' "$PROG" "$1" >&2; exit 1; }

idx="" card="" to="" reason="" detail="" children=""
while [ $# -gt 0 ]; do
  case "$1" in
    --index|--card|--to|--reason|--detail|--children)
      [ $# -ge 2 ] || die "$1 requires a value"
      case "$1" in
        --index) idx=$2 ;; --card) card=$2 ;; --to) to=$2 ;;
        --reason) reason=$2 ;; --detail) detail=$2 ;; --children) children=$2 ;;
      esac
      shift 2 ;;
    *) die "usage: card-status.sh --index <00-INDEX.md> --card NN --to <status> [--reason R] [--detail D] [--children \"NN NN\"]" ;;
  esac
done
[ -n "$idx" ] && [ -f "$idx" ] || die "no index file: ${idx:-<none>}"
[ -n "$card" ] || die "--card is required"

is_one_of() { case " $2 " in *" $1 "*) return 0 ;; esac; return 1; }
key_of() { printf '%s' "$1" | sed -E 's/^0+([0-9])/\1/'; }
first_word() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | grep -oE '^[a-z_]+' || true; }
trim() { local s=$1; s=${s#"${s%%[![:space:]]*}"}; printf '%s' "${s%"${s##*[![:space:]]}"}"; }

is_one_of "$to" "$STATUSES" || refuse "status is one of ${STATUSES// /, }"

# The first table whose header names a card (or #) column and a status column. One line per row:
# <line number> US <id> US <status cell>, after a first line holding the status field number.
US=$'\037'
table=$(awk -F'|' -v US="$US" '
  function trim(s) { gsub(/^[ \t`*]+|[ \t`*]+$/, "", s); return s }
  done_ { next }
  !/^\|/ { if (sc) done_ = 1; next }
  !sc {
    c = s = 0
    for (i = 2; i <= NF; i++) { h = tolower(trim($i)); if (!c && (h == "card" || h == "#")) c = i; if (!s && h == "status") s = i }
    if (c && s) { cc = c; sc = s; print sc }
    next
  }
  $0 ~ /^\|[ \t:|-]+\|[ \t]*$/ { next }
  { id = trim($cc); if (id ~ /^[0-9]+$/) print NR US id US trim($sc) }
' "$idx") || die "cannot read $idx"

scol=$(printf '%s\n' "$table" | head -n1)
rows=$(printf '%s\n' "$table" | tail -n +2)
[ -n "$scol" ] && [ -n "$rows" ] || refuse "the index has no card table with a status column"

want=$(key_of "$(trim "$card")")
line="" id="" from="" ids="" others=""
while IFS="$US" read -r n rid rst; do
  [ -n "$n" ] || continue
  ids="$ids $rid"
  if [ -z "$line" ] && [ "$(key_of "$rid")" = "$want" ]; then line=$n; id=$rid; from=$rst
  else others="$others$rid$US$rst"$'\n'; fi
done <<<"$rows"
[ -n "$line" ] || refuse "no card $card in the index (cards:$ids)"

status_of() { # <id> — the status cell of the row whose key matches, or nothing (exit 1) with no such row
  local k; k=$(key_of "$1")
  while IFS="$US" read -r n rid rst; do
    [ -n "$n" ] && [ "$(key_of "$rid")" = "$k" ] && { printf '%s' "$rst"; return 0; }
  done <<<"$rows"
  return 1
}

# A split parent leaves parked only once every child it names is done.
if [ "$to" != parked ]; then
  named=$(printf '%s' "$from" | grep -ioE '^parked[^[:alnum:]_]+split([^[:alnum:]_][^)]*)?' || true)
  named=${named#*[sS][pP][lL][iI][tT]}
  open=""
  for child in $(printf '%s' "$named" | grep -oE '[0-9]+' || true); do
    st=$(status_of "$child") && [ "$(first_word "$st")" = done ] && continue
    open="${open:+$open, }$child"
  done
  [ -z "$open" ] || refuse "card $id is split and its child $open is not done; finish or park the children first"
fi

detail=$(trim "$detail")
case "$detail" in *'|'*|*$'\n'*|*$'\r'*) refuse "detail must be one line with no | in it" ;; esac

if [ "$to" != parked ]; then
  cell=$to; [ -z "$detail" ] || cell="$to — $detail"
else
  if [ -z "$reason" ] || ! is_one_of "$reason" "$REASONS"; then
    refuse "a parked card names its reason: one of ${REASONS// /, }. \"Too large\" or \"infeasible\" is a forecast, not a reason: make the card's smallest step and run its verify command first"
  fi
  if [ "$reason" != split ]; then
    [ -n "$detail" ] || refuse "parked ($reason) needs a detail: what was tried and the failing line, the mismatch, the question, or the refusal text"
    cell="parked ($reason: $detail)"
  else
    read -r -a kid_list <<<"${children//,/ }"
    kids="${kid_list[*]-}"
    [ -n "$kids" ] || refuse "a split names its child cards in --children; append them to the index first"
    for child in $kids; do
      [ "$(key_of "$child")" != "$(key_of "$id")" ] || refuse "card $id cannot be its own child"
      status_of "$child" >/dev/null || refuse "child $child has no card row; append it to the index first"
    done
    cell="parked (split: $kids)"; [ -z "$detail" ] || cell="$cell — $detail"
  fi
fi

if [ "$to" = in_progress ]; then
  while IFS="$US" read -r rid rst; do
    [ -n "$rid" ] && [ "$(first_word "$rst")" = in_progress ] \
      && printf '%s: note: card %s is also in_progress; one card at a time unless its parallel group was delegated\n' "$PROG" "$rid" >&2
  done <<<"$others"
fi

tmp=$(mktemp "${idx}.XXXXXX") || die "cannot write beside $idx"
trap 'rm -f "$tmp"' EXIT
# Every other byte stays as it was, a missing final newline included.
noeol=0; [ -z "$(tail -c1 "$idx")" ] || noeol=1
CELL=" $cell " awk -F'|' -v OFS='|' -v L="$line" -v S="$scol" -v NOEOL="$noeol" '
  NR == L { $S = ENVIRON["CELL"] }
  NR > 1 { print prev }
  { prev = $0 }
  END { if (NR) printf "%s%s", prev, (NOEOL ? "" : "\n") }
' "$idx" >"$tmp" || die "cannot rewrite $idx"
cat "$tmp" >"$idx" || die "cannot write $idx"
printf 'card %s: %s → %s\n' "$card" "${from:-(empty)}" "$cell"
