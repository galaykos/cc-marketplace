#!/usr/bin/env bash
# coverage-close.sh --index <00-INDEX.md> — at run close, joins the index's card table (Status column) with its `## Coverage` table: prints `missing:` for a success criterion none of whose cards is done, `partial:` when only some are, and `uncovered:` for a criterion no card covers. Exit 1 on any missing or partial, 0 otherwise, 3 when the index lacks either table.
# Misses: a card marked done whose change does not meet the criterion (the reviewers' job), a criterion row whose cards are named in prose rather than as numbers, a status cell not opening with "done" for finished work.
# Why, limits, history: rationale/derivations/plugin-task-runner.md § plugins/task-runner/scripts/coverage-close.sh
set -uo pipefail

PROG=coverage-close
usage() { printf '%s: %s\n' "$PROG" "$1" >&2; exit 3; }
idx=""
while [ $# -gt 0 ]; do
  case "$1" in
    --index) [ $# -ge 2 ] || usage "--index requires a path"; idx=$2; shift 2 ;;
    *) usage "usage: coverage-close.sh --index <00-INDEX.md>" ;;
  esac
done
[ -n "$idx" ] && [ -f "$idx" ] || usage "no index file: ${idx:-<none>}"

awk -F'|' '
  function trim(s) { gsub(/^[ \t`*]+|[ \t`*]+$/, "", s); return s }
  function norm(n) { sub(/^0+/, "", n); return n == "" ? "0" : n }
  /^## / { insec = ($0 ~ /^## Coverage[[:space:]]*$/); mode = ""; next }
  /^\|/ {
    # A header row: find the columns by name, wherever the table sits.
    if (mode == "" ) {
      cc = sc = cr = cb = 0
      for (i = 2; i < NF; i++) {
        h = tolower(trim($i))
        if (h == "card" || h == "#") cc = i
        if (h == "status") sc = i
        if (h ~ /^success criteri/) cr = i
        if (h == "covered by") cb = i
      }
      if (insec && cr && cb) { mode = "cov"; covst = sc; next }
      if (!insec && cc && sc) { mode = "card"; ccol = cc; scol = sc; next }
      next
    }
    if ($0 ~ /^\|[ \t:|-]+\|[ \t]*$/) next           # separator row
    if (mode == "card") {
      id = trim($ccol); if (id !~ /^[0-9]+$/) next
      st = tolower(trim($scol)); id = norm(id)
      cards[id] = 1; status[id] = st; done[id] = (st ~ /^done/); havecards = 1
      next
    }
    if (mode == "cov") {
      crit = trim($cr); by = trim($cb); if (crit == "") next
      ncov++; havecov = 1
      n = split(by, parts, /[^0-9]+/); k = 0; d = 0; detail = ""
      for (j = 1; j <= n; j++) {
        if (parts[j] == "") continue
        id = norm(parts[j]); k++
        if (id in done && done[id]) d++
        else detail = detail sprintf("%s%s %s", (detail == "" ? "" : ", "), parts[j], (id in status ? status[id] : "has no card row"))
      }
      if (k == 0) { printf "uncovered: %s\n", crit; next }
      if (d == 0) { printf "missing: %s — no covering card is done (%s)\n", crit, detail; bad = 1 }
      else if (d < k) { printf "partial: %s — %d of %d covering cards done (%s)\n", crit, d, k, detail; bad = 1 }
      next
    }
  }
  !/^\|/ { if (mode != "") mode = "" }
  END {
    if (!havecards) { print "coverage-close: no card table with a Status column" > "/dev/stderr"; exit 3 }
    if (!havecov) { print "coverage-close: no ## Coverage table (Success criterion | Covered by)" > "/dev/stderr"; exit 3 }
    exit bad ? 1 : 0
  }' "$idx"
