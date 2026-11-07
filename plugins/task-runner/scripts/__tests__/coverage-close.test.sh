#!/usr/bin/env bash
# Harness for coverage-close.sh. Load-bearing: a criterion whose only card was parked is reported `missing`,
# one with a parked and a done card `partial`; an all-done index is clean (so the clean verdict is not vacuous,
# the parked case flips the same fixture).
set -u
here=$(cd "$(dirname "$0")" && pwd)
C="$here/../coverage-close.sh"
[ -x "$C" ] || { printf 'FAIL: coverage-close.sh not executable\n'; exit 1; }
pass=0; fail=0
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
ok()  { printf 'PASS: %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$((fail+1)); }

index() { # <status of 01> <status of 02> <status of 03>
  cat <<EOF
# Index

| Card | Title | Size | Depends on | Agent | Parallel group | Status |
| --- | --- | --- | --- | --- | --- | --- |
| 01 | Add the thing | S | none | generic | A | $1 |
| 02 | Wire the thing | S | 01 | generic | B | $2 |
| 03 | Test the thing | S | 02 | generic | C | $3 |

## Coverage

| Success criterion | Covered by | Status |
| --- | --- | --- |
| 1. The thing exists | 01 | covered |
| 2. The thing is wired and tested | 02, 03 | covered (folded) |
| 3. A note nobody built | — | GAP (accepted) |

Accepted gaps: 3.
EOF
}
expect() { # name rc grep
  out=$(bash "$C" --index "$T/00-INDEX.md" 2>&1); rc=$?
  if [ "$rc" = "$2" ] && { [ -z "$3" ] || printf '%s' "$out" | grep -q -- "$3"; }; then ok "$1"; else bad "$1 (rc=$rc out=$out)"; fi
}

index 'done (abc123)' 'done (def456)' 'done' > "$T/00-INDEX.md"
expect "all cards done: clean, accepted gap listed" 0 "uncovered: 3. A note nobody built"

index 'complete (abc)' 'merged' '✅ shipped' > "$T/00-INDEX.md"
expect "complete, merged and ✅ count as done: clean" 0 "uncovered: 3."

index 'parked — 3 failed cycles' 'done' 'done' > "$T/00-INDEX.md"
expect "only card parked: missing" 1 "missing: 1. The thing exists — no covering card is done (01 parked"

index 'done' 'done' 'halted: suite red' > "$T/00-INDEX.md"
expect "one of two cards halted: partial" 1 "partial: 2. The thing is wired and tested — 1 of 2"

index 'done' 'pending' 'pending' > "$T/00-INDEX.md"
expect "neither card started: missing" 1 "missing: 2."

{ index 'done' 'done' 'done'; } | sed '/^## Coverage/,$d' > "$T/00-INDEX.md"
expect "no coverage table: usage(3)" 3 "no ## Coverage table"

printf '# empty\n' > "$T/00-INDEX.md"
expect "no card table: usage(3)" 3 "no card table"

out=$(bash "$C" --index "$T/nope.md" 2>&1); rc=$?
[ "$rc" = 3 ] && ok "missing index file: usage(3)" || bad "missing index (rc=$rc)"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
