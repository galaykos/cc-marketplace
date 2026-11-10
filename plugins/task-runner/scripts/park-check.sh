#!/usr/bin/env bash
# park-check.sh --index <00-INDEX.md> — at run close, reads the card table's Status column: prints `unclassified:` for a parked card whose status does not open `parked` + one of evidence, misspec, needs-user, split, guard, and `split-orphan:` for a split naming no child, itself, or a number with no card row. Exit 1 on either, 0 clean, 3 when the index has no card table.
# Misses: a reason that is untrue (`evidence` written over a forecast), a card left pending or skipped instead of parked, a split whose children do not add up to the parent.
# Why, limits, history: rationale/derivations/plugin-task-runner.md § plugins/task-runner/scripts/park-check.sh
set -uo pipefail

PROG=park-check
usage() { printf '%s: %s\n' "$PROG" "$1" >&2; exit 3; }
idx=""
while [ $# -gt 0 ]; do
  case "$1" in
    --index) [ $# -ge 2 ] || usage "--index requires a path"; idx=$2; shift 2 ;;
    *) usage "usage: park-check.sh --index <00-INDEX.md>" ;;
  esac
done
[ -n "$idx" ] && [ -f "$idx" ] || usage "no index file: ${idx:-<none>}"

awk -F'|' '
  function trim(s) { gsub(/^[ \t`*]+|[ \t`*]+$/, "", s); return s }
  function norm(n) { sub(/^0+/, "", n); return n == "" ? "0" : n }
  /^## / { mode = ""; next }
  /^\|/ {
    if (mode == "") {
      cc = sc = 0
      for (i = 2; i < NF; i++) {
        h = tolower(trim($i))
        if (h == "card" || h == "#") cc = i
        if (h == "status") sc = i
      }
      if (cc && sc) { mode = "card"; ccol = cc; scol = sc }
      next
    }
    if ($0 ~ /^\|[ \t:|-]+\|[ \t]*$/) next
    id = trim($ccol); if (id !~ /^[0-9]+$/) next
    n++; shown[n] = id; key[n] = norm(id); cell[n] = trim($scol); rows[norm(id)] = 1
    next
  }
  !/^\|/ { if (mode != "") mode = "" }
  END {
    if (!n) { print "park-check: no card table with a Status column" > "/dev/stderr"; exit 3 }
    for (k = 1; k <= n; k++) {
      st = tolower(cell[k])
      if (st !~ /^parked/) continue
      rest = st; sub(/^parked/, "", rest); sub(/^[^a-z]+/, "", rest)
      if (match(rest, /^(evidence|misspec|needs-user|split|guard)/) == 0 || substr(rest, RLENGTH + 1, 1) ~ /[a-z0-9_-]/) {
        printf "unclassified: card %s — %s\n", shown[k], cell[k]; bad = 1; continue
      }
      if (rest !~ /^split/) continue
      sub(/^split/, "", rest); sub(/\).*$/, "", rest)
      m = split(rest, parts, /[^0-9]+/); kids = 0
      for (j = 1; j <= m; j++) {
        if (parts[j] == "") continue
        kids++; c = norm(parts[j])
        if (c == key[k]) { printf "split-orphan: card %s names itself as a child\n", shown[k]; bad = 1 }
        else if (!(c in rows)) { printf "split-orphan: card %s names child %s, which has no card row\n", shown[k], parts[j]; bad = 1 }
      }
      if (!kids) { printf "split-orphan: card %s is split into no child cards\n", shown[k]; bad = 1 }
    }
    exit bad ? 1 : 0
  }' "$idx"
