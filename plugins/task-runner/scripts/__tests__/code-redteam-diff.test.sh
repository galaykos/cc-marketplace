#!/usr/bin/env bash
# Tests for code-redteam-diff.sh (the deterministic core of the code-redteam skill).
#
# SAFETY: every git operation runs against a throwaway `mktemp -d` repo, never the
# live repo. --dedup fixtures also live under the temp dir. The real working tree is
# never touched.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
CR="$here/../code-redteam-diff.sh"

[ -x "$CR" ] || { printf 'FAIL: code-redteam-diff.sh not executable at %s\n' "$CR"; exit 1; }

pass=0; fail=0
ok()  { printf 'PASS: %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$((fail+1)); }

# ---- throwaway git repo: two commits, never the real repo ----
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

git -C "$TMP" init -q
git -C "$TMP" config user.email test@example.com
git -C "$TMP" config user.name "CR Test"
git -C "$TMP" config commit.gpgsign false

printf 'alpha-line-one\n' > "$TMP/first.txt"
git -C "$TMP" add first.txt
git -C "$TMP" commit -q -m "first commit"
FIRST=$(git -C "$TMP" rev-parse HEAD)

printf 'beta-line-two\n' > "$TMP/second.txt"
git -C "$TMP" add second.txt
git -C "$TMP" commit -q -m "second commit"

# ---- case 1: --base <first> shows only the second commit's change ----
diffout=$( cd "$TMP" && "$CR" --base "$FIRST" )
if printf '%s' "$diffout" | grep -q 'beta-line-two' \
   && ! printf '%s' "$diffout" | grep -q 'alpha-line-one'; then
  ok "--base <first> diff contains only the second commit's change"
else
  bad "--base <first> diff scoping wrong"
  printf '%s\n' "$diffout" | sed 's/^/  | /'
fi

# ---- case 2: --paths scopes the diff to a single file ----
diffp=$( cd "$TMP" && "$CR" --base "$FIRST" --paths second.txt )
diffp_none=$( cd "$TMP" && "$CR" --base "$FIRST" --paths first.txt )
if printf '%s' "$diffp" | grep -q 'beta-line-two' && [ -z "$diffp_none" ]; then
  ok "--paths scopes the diff (second.txt shown, first.txt empty)"
else
  bad "--paths scoping wrong"
  printf '%s\n' "$diffp" | sed 's/^/  | /'
fi

# ---- dedup fixtures ----
seenf="$TMP/seen.txt"
printf 'src/a.js:10\tNull deref on user input\n' > "$seenf"

# ---- case 3: --dedup drops the seen finding, keeps the novel one ----
dedupout=$( printf 'src/a.js:10\tNull deref on user input\nsrc/b.js:22\tMissing timeout on fetch\n' \
  | "$CR" --dedup "$seenf" )
if printf '%s' "$dedupout" | grep -q 'Missing timeout on fetch' \
   && ! printf '%s' "$dedupout" | grep -q 'Null deref on user input'; then
  ok "--dedup removes the seen finding and keeps the novel one"
else
  bad "--dedup filtering wrong"
  printf '%s\n' "$dedupout" | sed 's/^/  | /'
fi

# ---- case 4: --dedup normalizes case/whitespace (proves normalized-title match) ----
dedupnorm=$( printf 'src/a.js:10\tNULL   deref on   USER input\n' | "$CR" --dedup "$seenf" )
if [ -z "$dedupnorm" ]; then
  ok "--dedup normalizes case/whitespace when matching the seen finding"
else
  bad "--dedup did not normalize; leftover: $dedupnorm"
fi

# ---- case 5: usage errors exit 3 ----
set +e
( "$CR" --bogus ) >/dev/null 2>&1;      rc_mode=$?
( "$CR" --base ) >/dev/null 2>&1;       rc_base=$?
( "$CR" --dedup ) >/dev/null 2>&1;      rc_dedup=$?
set -e
if [ "$rc_mode" = 3 ] && [ "$rc_base" = 3 ] && [ "$rc_dedup" = 3 ]; then
  ok "usage errors exit 3 (mode=$rc_mode base=$rc_base dedup=$rc_dedup)"
else
  bad "usage exit codes wrong (mode=$rc_mode base=$rc_base dedup=$rc_dedup)"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
