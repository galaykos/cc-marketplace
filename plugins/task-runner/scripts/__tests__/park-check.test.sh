#!/usr/bin/env bash
# Harness for park-check.sh. Load-bearing: the same index is clean with a classified park and red with a
# forecast in its place, so the clean verdict is not vacuous; a split must name child rows that exist.
set -u
here=$(cd "$(dirname "$0")" && pwd)
C="$here/../park-check.sh"
[ -x "$C" ] || { printf 'FAIL: park-check.sh not executable\n'; exit 1; }
pass=0; fail=0
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
ok()  { printf 'PASS: %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$((fail+1)); }

index() { # <status of 01> <status of 02> <status of 03>
  cat <<EOT
# Index

| Card | Title | Size | Depends on | Agent | Parallel group | Status |
| --- | --- | --- | --- | --- | --- | --- |
| 01 | Add the thing | S | none | generic | A | $1 |
| 02 | Wire the thing | S | 01 | generic | B | $2 |
| 03 | Test the thing | S | 02 | generic | C | $3 |

## Coverage

| Success criterion | Covered by | Status |
| --- | --- | --- |
| 1. The thing exists | 01 | parked on a hunch |
EOT
}
expect() { # name rc grep [absent-grep]
  out=$(bash "$C" --index "$T/00-INDEX.md" 2>&1); rc=$?
  if [ "$rc" = "$2" ] && { [ -z "$3" ] || printf '%s' "$out" | grep -q -- "$3"; } \
     && { [ -z "${4:-}" ] || ! printf '%s' "$out" | grep -q -- "$4"; }; then ok "$1"; else bad "$1 (rc=$rc out=$out)"; fi
}

index 'done (abc123)' 'done' 'pending' > "$T/00-INDEX.md"
expect "no parked card is clean" 0 ""

index 'done' 'parked (evidence: 3 cycles, TypeError at parse.py:41)' 'blocked-by 02' > "$T/00-INDEX.md"
expect "a park carrying evidence is clean" 0 ""

index 'done' 'parked — too large for one session' 'blocked-by 02' > "$T/00-INDEX.md"
expect "the same park written as a forecast is unclassified" 1 "unclassified: card 02 — parked — too large for one session"

index 'parked(infeasible in budget)' 'parked' 'Parked (Guard: scope.sh refused src/x.ts)' > "$T/00-INDEX.md"
expect "a legacy parked(reason) with no class is unclassified" 1 "unclassified: card 01"
expect "a bare parked is unclassified" 1 "unclassified: card 02"
expect "a classified park beside them stays silent, any letter case" 1 "" "card 03"

index 'parked (misspec: card names src/a.ts, the symbol lives in src/b.ts)' 'parked: needs-user — which currency rounds?' 'parked (evidence-free guess)' > "$T/00-INDEX.md"
expect "misspec and needs-user are reasons" 1 "" "card 0[12]"
expect "a reason word glued to more letters is not that reason" 1 "unclassified: card 03"

index 'parked (split: 02 3)' 'pending' 'done' > "$T/00-INDEX.md"
expect "a split naming existing child rows is clean, leading zeros aside" 0 ""

index 'parked (split: 02 07)' 'pending' 'done' > "$T/00-INDEX.md"
expect "a split naming a number with no row is an orphan" 1 "split-orphan: card 01 names child 07, which has no card row"

index 'parked (split)' 'parked (split: 02)' 'done' > "$T/00-INDEX.md"
expect "a split with no child is an orphan" 1 "split-orphan: card 01 is split into no child cards"
expect "a split naming itself is an orphan" 1 "split-orphan: card 02 names itself as a child"

index 'parked (split: 02) — see 99 in the backlog' 'done' 'done' > "$T/00-INDEX.md"
expect "numbers after the closing bracket are not children" 0 ""

printf '# Index\n\nNo table here.\n' > "$T/00-INDEX.md"
expect "an index with no card table exits 3" 3 "no card table"

out=$(bash "$C" 2>&1); rc=$?
[ "$rc" = 3 ] && ok "no --index exits 3" || bad "no --index exits 3 (rc=$rc out=$out)"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
