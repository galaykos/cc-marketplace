#!/usr/bin/env bash
# Tests for goal-ledger-check.sh — the goal-mode audit-precondition gate.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
check="$here/../goal-ledger-check.sh"
[ -x "$check" ] || { printf 'FAIL: check not executable at %s\n' "$check"; exit 1; }

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
export GOAL_LEDGER_DIR="$tmp/ledgers"

pass=0; fail=0
run_case() {
  desc="$1"; exp_rc="$2"; exp_sub="$3"; shift 3
  set +e; out=$("$check" "$@" 2>&1); rc=$?; set -e
  ok=1
  [ "$rc" = "$exp_rc" ] || ok=0
  [ -n "$exp_sub" ] && { printf '%s' "$out" | grep -q -- "$exp_sub" || ok=0; }
  if [ "$ok" = 1 ]; then printf 'PASS: %s (rc=%s)\n' "$desc" "$rc"; pass=$((pass+1))
  else printf 'FAIL: %s (rc=%s want=%s; out=<%s>)\n' "$desc" "$rc" "$exp_rc" "$out"; fail=$((fail+1)); fi
}

# 1) missing ledger blocks the stamp
run_case "missing ledger -> no-ledger" 2 "no-ledger" --slug csv-export

# 2) --init creates it and verifies writability
run_case "--init creates + probes" 0 "" --init --slug csv-export
[ -f "$GOAL_LEDGER_DIR/goal-ledger-csv-export.md" ] \
  && { printf 'PASS: init created the ledger file\n'; pass=$((pass+1)); } \
  || { printf 'FAIL: init created the ledger file\n'; fail=$((fail+1)); }

# 3) header-only ledger (no decision entries) still blocks the stamp
run_case "header-only ledger -> no-entries" 2 "no-entries" --slug csv-export

# 4) ledger with a decision entry passes
printf -- '- decision: visual consent -> Full mockups (auto)\n' >> "$GOAL_LEDGER_DIR/goal-ledger-csv-export.md"
run_case "ledger with entry -> ok" 0 "" --slug csv-export

# 5) empty file blocks
: > "$GOAL_LEDGER_DIR/goal-ledger-empty.md"
run_case "empty ledger -> empty-ledger" 2 "empty-ledger" --slug empty

# 6) usage errors
run_case "no slug -> usage" 3 "usage"
run_case "path-traversal slug -> usage" 3 "usage" --slug '../etc'

printf -- '---- %s passed, %s failed ----\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
