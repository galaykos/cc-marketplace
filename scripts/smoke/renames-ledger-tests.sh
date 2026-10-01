#!/usr/bin/env bash
# Smoke tests for pc_renames_ledger (scripts/lib/plugin-checks.sh), plus its validate.sh
# wiring.
#
# The live repo's TSV and renames were generated from one source, so a clean run proves
# nothing. These fixtures are the record that every arm has been watched fail.
#
# WHAT IS PINNED IS THE ASSERTION LIST BELOW. pc_renames_ledger's own header says what the
# check does and does not catch; if the two disagree, the assertions win.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/scripts/lib/plugin-checks.sh" 2>/dev/null || { echo "FAIL: cannot source plugin-checks.sh"; exit 1; }

WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT
trap 'exit 130' INT TERM HUP
pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'PASS  %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL  %s\n      %s\n' "$1" "$2"; }

# mk <renames-json> <name:successor>… — a fake root listing ${LIVE:-web-dev security}, with
# the given renames object and one TSV row per pair.
mk() {
  local renames="$1" pair plugins; shift
  rm -rf "$WORK/root"
  mkdir -p "$WORK/root/.claude-plugin" "$WORK/root/scripts"
  plugins=$(printf '%s\n' ${LIVE:-web-dev security} | jq -R '{name: .}' | jq -s -c .)
  printf '{"name":"t","plugins":%s,"renames":%s}\n' "$plugins" "$renames" \
    > "$WORK/root/.claude-plugin/marketplace.json"
  printf '# name\tsuccessor\tremoved\tprose_match\treason\n' > "$WORK/root/scripts/removed-plugins.tsv"
  for pair in "$@"; do
    printf '%s\t%s\t2026-09-29\tno\tfixture\n' "${pair%%:*}" "${pair#*:}" >> "$WORK/root/scripts/removed-plugins.tsv"
  done
}

# expect <want-rc> <want-output> <label>
expect() {
  local out rc
  out=$(pc_renames_ledger "$WORK/root" 2>&1); rc=$?
  [ "$rc" = "$1" ] && [ "$out" = "$2" ] && ok "$3" || bad "$3" "want rc=$1 '$2', got rc=$rc '$out'"
}

mk '{"nextjs":"web-dev"}' nextjs:web-dev old:null
expect 1 "renames-missing old" "TSV row with no renames key fails"

mk '{"nextjs":null}' nextjs:web-dev
expect 1 "renames-mismatch nextjs web-dev null" "renames value differing from the TSV successor fails"

mk '{"security":null}' security:null
expect 1 "renames-live-key security" "renames key that is a current plugin fails"

mk '{"nextjs":"vite","vite":"gone"}' nextjs:vite vite:gone
expect 1 "renames-dangling nextjs gone
renames-dangling vite gone" "renames chain ending at an unknown name fails"

mk '{"a":"b","b":"a"}' a:b b:a
expect 1 "renames-cycle a
renames-cycle b" "renames cycle fails"

mk '{"a":"a"}' a:a
expect 1 "renames-cycle a" "renames self-loop fails"

mk '{"c":"a","a":"b","b":"a"}' c:a a:b b:a
expect 1 "renames-cycle c
renames-cycle a
renames-cycle b" "renames chain running into a cycle fails"

mk '{"nextjs":"web-dev","vite":"web-dev"}' nextjs:web-dev
expect 1 "renames-orphan vite" "renames key with no TSV row fails"

mk '{"nextjs":"web-dev","old":null}' nextjs:web-dev old:null
expect 0 "" "consistent TSV and renames pass"

LIVE=security mk '{"nextjs":"web-dev","web-dev":"security","vite":"web-dev"}' nextjs:web-dev web-dev:security vite:web-dev
expect 0 "" "renames chain through a removed name passes"

mk '{"nextjs":"web-dev","old":null}'
printf '# c\r\nnextjs\tweb-dev\t2026-09-29\tno\tfixture\r\n\r\n \t \r\n\nold\tnull\t2026-09-29\tno\tfixture\r\n' \
  > "$WORK/root/scripts/removed-plugins.tsv"
expect 0 "" "CRLF TSV with blank lines passes"

mk '{"old":null}' old:null
rm "$WORK/root/scripts/removed-plugins.tsv"
expect 1 "renames-ledger-unreadable scripts/removed-plugins.tsv" "missing TSV is a finding, not a pass"

mk '{"old":null}'
rm "$WORK/root/scripts/removed-plugins.tsv"; mkdir "$WORK/root/scripts/removed-plugins.tsv"
expect 1 "renames-ledger-unreadable scripts/removed-plugins.tsv" "TSV path that is a directory is a finding, not a pass"

# unreadable_mp <marketplace.json body> <label>
unreadable_mp() {
  mk '{"old":null}' old:null
  printf '%s\n' "$1" > "$WORK/root/.claude-plugin/marketplace.json"
  expect 1 "renames-ledger-unreadable .claude-plugin/marketplace.json" "$2"
}
unreadable_mp '{"name":"t","plugins":[{"name":"web-dev"}]}' "marketplace.json without renames is a finding, not a pass"
unreadable_mp '{"name":"t","plugins":[' "non-JSON marketplace.json is a finding, not a pass"
unreadable_mp '{"name":"t","plugins":[{"name":"web-dev"}],"renames":{"old":1}}' "non-string renames value is a finding, not a pass"
unreadable_mp '{"name":"t","plugins":[{"name":"web-dev"}],"renames":{"old":"null"}}' 'string "null" renames value is a finding, not a pass'
unreadable_mp '{"name":"t","plugins":["web-dev"],"renames":{"old":null}}' "non-object plugins entry is a finding, not a pass"

mk '{"old":null,"bad":null}' old:null
printf 'bad\tnull\n' >> "$WORK/root/scripts/removed-plugins.tsv"
expect 1 "renames-ledger-unreadable scripts/removed-plugins.tsv:3
renames-orphan bad" "malformed TSV row is a finding, not a pass"

mk '{"nextjs":"web-dev","old":null}' nextjs:web-dev old:null
# The stub drains its operands: under an ignored SIGPIPE, jq writing to a closed pipe prints an error expect would capture.
mkdir "$WORK/bin"; printf '#!/bin/sh\ncat -- "$@" >/dev/null 2>&1\nexit 2\n' > "$WORK/bin/awk"; chmod +x "$WORK/bin/awk"
SAVED_PATH="$PATH"; PATH="$WORK/bin:$PATH"
expect 1 "renames-ledger-unreadable scripts/removed-plugins.tsv" "an unreadable ledger (awk exit 2) fails closed"
PATH="$SAVED_PATH"

out=$(pc_renames_ledger "$ROOT" 2>&1); rc=$?
[ "$rc" = 0 ] && [ -z "$out" ] \
  && ok "live repo ledger is consistent" \
  || bad "live repo ledger is consistent" "rc=$rc: $out"

HINT="scripts/removed-plugins.tsv and marketplace.json renames disagree — every removed name needs a renames entry equal to its TSV successor, every chain must end at a current plugin or null without a cycle, and no renames key may be a live plugin; for renames-missing, add the entry (the jq command in scripts/removed-plugins.tsv's header rewrites the whole map, so run it only when every finding is renames-missing); for renames-orphan or renames-mismatch, add or correct the TSV row — never drop or retarget a committed renames key"
if grep -v '^[[:space:]]*#' "$ROOT/scripts/validate.sh" | grep -A1 -F 'renames_gap=$(pc_renames_ledger .) || true' \
   | grep -qF "[ -n \"\$renames_gap\" ] && lane_err \"\$renames_gap\" \"$HINT\""; then
  ok "validate.sh feeds pc_renames_ledger output to lane_err with its hint"
else
  bad "validate.sh feeds pc_renames_ledger output to lane_err with its hint" "the call is missing, commented out, or no longer feeds lane_err its hint"
fi

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
