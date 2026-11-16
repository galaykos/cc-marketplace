#!/usr/bin/env bash
# Harness for card-status.sh, ported from the card_status tool's tests (tests/status.test.ts, removed in 0.59.0).
# Load-bearing: a write changes exactly one cell and no other byte; every refusal leaves the index byte-identical.
set -u
here=$(cd "$(dirname "$0")" && pwd)
C="$here/../card-status.sh"
[ -x "$C" ] || { printf 'FAIL: card-status.sh not executable\n'; exit 1; }
pass=0; fail=0
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
I="$T/00-INDEX.md"
ok()  { printf 'PASS: %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$((fail+1)); }

row() { printf '| %s | Card %s | none | generic | A | %s |\n' "$1" "$1" "$2"; }
board() { # <status 01> <status 02> <status 03> <status 04>
  printf '# Index\n\n| card | title | depends-on | agent | parallel group | status |\n|---|---|---|---|---|---|\n'
  row 01 "$1"; row 02 "$2"; row 03 "$3"; row 04 "$4"
  printf '\n## Coverage\n\n| Success criterion | Covered by | Status |\n|---|---|---|\n| 1. It ships | 02 | covered |\n'
}
seed() { board "$@" >"$I"; cp "$I" "$T/before"; }
run() { out=$(bash "$C" --index "$I" "$@" 2>&1); rc=$?; }
status_of() { grep "^| $1 |" "$I" | awk -F'|' '{ s = $(NF-1); gsub(/^ +| +$/, "", s); print s }'; }
unchanged() { cmp -s "$I" "$T/before"; }
refused() { # <name> <expected text> -- <args...>
  local name=$1 want=$2; shift 3
  run "$@"
  if [ "$rc" = 1 ] && printf '%s' "$out" | grep -qF -- "$want" && unchanged; then ok "$name"; else bad "$name (rc=$rc out=$out)"; fi
}

seed 'done (ad591b7e)' in_progress pending pending
run --card 2 --to done --detail '(9f1c2b3a)'
board 'done (ad591b7e)' 'done — (9f1c2b3a)' pending pending >"$T/want"
if [ "$rc" = 0 ] && [ "$out" = 'card 2: in_progress → done — (9f1c2b3a)' ] && cmp -s "$I" "$T/want"; then
  ok "writes done with its detail and leaves every other byte as it was"
else bad "done write (rc=$rc out=$out)"; diff "$T/want" "$I"; fi

seed pending pending pending pending
printf '%s' "$(cat "$I")" >"$I"; cp "$I" "$T/before"
run --card 01 --to done
if [ "$rc" = 0 ] && [ -n "$(tail -c1 "$I")" ] && [ "$(wc -l <"$I")" = "$(wc -l <"$T/before")" ]; then
  ok "an index with no final newline gets none"
else bad "no-final-newline (rc=$rc)"; fi

seed done in_progress pending pending
refused "refuses a parked status with no reason" 'a parked card names its reason' -- --card 03 --to parked --detail 'too large for one session'
refused "refuses a forecast in place of a reason" 'is a forecast, not a reason' -- --card 03 --to parked --reason infeasible --detail 'out of budget'
refused "refuses evidence with no detail" 'needs a detail' -- --card 03 --to parked --reason evidence
run --card 03 --to parked --reason evidence --detail '3 cycles, TypeError at parse.py:41'
[ "$rc" = 0 ] && [ "$(status_of 03)" = 'parked (evidence: 3 cycles, TypeError at parse.py:41)' ] \
  && ok "parks on evidence with the failing line" || bad "evidence park (rc=$rc out=$out)"

seed done in_progress pending pending
refused "a split names its child cards" 'names its child cards' -- --card 02 --to parked --reason split
refused "a split child must have a row" 'child 09 has no card row' -- --card 02 --to parked --reason split --children '03 09'
refused "a split never names itself" 'cannot be its own child' -- --card 02 --to parked --reason split --children 2
run --card 02 --to parked --reason split --children '03,04'
[ "$rc" = 0 ] && [ "$(status_of 02)" = 'parked (split: 03 04)' ] && ok "a split with real children is written" || bad "split (rc=$rc out=$out)"

seed done 'parked (split: 03 04)' done pending
refused "a split parent reopens only once every child is done" 'its child 04 is not done' -- --card 02 --to pending
run --card 04 --to done
run --card 02 --to pending
[ "$rc" = 0 ] && [ "$(status_of 02)" = pending ] && ok "the parent reopens once the children are done" || bad "reopen (rc=$rc out=$out)"

seed done in_progress pending pending
refused "refuses an unknown card, naming the cards" 'no card 9 in the index (cards: 01 02 03 04)' -- --card 9 --to done
refused "refuses an unknown status" 'status is one of' -- --card 03 --to committed
refused "refuses a detail that would break the row" 'one line with no |' -- --card 03 --to done --detail 'a | b'

seed done in_progress pending pending
run --card 03 --to in_progress
[ "$rc" = 0 ] && printf '%s' "$out" | grep -qF 'card 02 is also in_progress' && [ "$(status_of 03)" = in_progress ] \
  && ok "a second in_progress is noted, still written" || bad "second in_progress (rc=$rc out=$out)"
seed done done pending pending
run --card 03 --to in_progress
[ "$rc" = 0 ] && ! printf '%s' "$out" | grep -q 'also in_progress' && ok "a lone in_progress draws no note" || bad "lone in_progress (out=$out)"

printf '# Index\n\nNo table.\n' >"$I"; cp "$I" "$T/before"
refused "an index with no card table is refused, not rewritten" 'no card table' -- --card 01 --to done

printf '# Index\n\n| # | Title | Status |\n|---|---|---|\n| 1 | One | `pending` |\n' >"$I"
run --card 01 --to done
[ "$rc" = 0 ] && grep -qF '| 1 | One | done |' "$I" && ok "a # column and a backticked cell are read as park-check reads them" || bad "# column (rc=$rc out=$out)"

out=$(bash "$C" --card 01 --to done 2>&1); rc=$?
[ "$rc" = 2 ] && ok "no index is a usage error, exit 2" || bad "usage (rc=$rc)"

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
