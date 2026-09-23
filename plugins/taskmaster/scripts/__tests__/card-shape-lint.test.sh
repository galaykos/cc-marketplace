#!/usr/bin/env bash
# Tests for card-shape-lint.sh — the structural lint over a role-tagged card.
# Each case writes a fixture card, captures the exit code and the reason string,
# and prints PASS/FAIL. The good card is asserted FIRST: a lint that fails
# everything passes every "blocks X" case, so the clean pass is the load-bearing one.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
lint="$here/../card-shape-lint.sh"
[ -x "$lint" ] || { printf 'FAIL: lint not executable at %s\n' "$lint"; exit 1; }

FX=$(mktemp -d); trap 'rm -rf "$FX"' EXIT
export CC_CARDLINT_DIR="$FX/records"
pass=0; fail=0

run_case() { # <desc> <expected_rc> <expected_stderr_substr> <card-body>
  desc="$1"; exp_rc="$2"; exp_sub="$3"; body="$4"
  f="$FX/$(printf '%s' "$desc" | tr -c 'a-zA-Z0-9' '_').md"
  printf '%s\n' "$body" > "$f"
  set +e; out=$("$lint" --card "$f" 2>&1); rc=$?; set -e
  ok=1
  [ "$rc" = "$exp_rc" ] || ok=0
  [ -n "$exp_sub" ] && { printf '%s' "$out" | grep -qF -- "$exp_sub" || ok=0; }
  if [ "$ok" = 1 ]; then printf 'PASS: %s (rc=%s)\n' "$desc" "$rc"; pass=$((pass+1))
  else printf 'FAIL: %s (rc=%s want=%s; out=<%s> want-substr=<%s>)\n' "$desc" "$rc" "$exp_rc" "$out" "$exp_sub"; fail=$((fail+1)); fi
}

good='# 03 — Extract invoice totals

<card id="03">
<goal>Card 04 needs totals as a standalone rounded function.</goal>

<facts>
<file path="invoices/invoice.py" line="11" mode="edit">totals summed inline</file>
<file path="invoices/totals.py" mode="create"/>
<current>total() returns an unrounded Decimal</current>
<target>total() returns a Decimal quantized to 2 places</target>
</facts>

<must>
<change>create invoices/totals.py with compute_total; Invoice.total() delegates to it</change>
<interface consumer="04">def compute_total(lines: list[Line], tax_rate: Decimal) -> Decimal</interface>
<skill name="money-conventions"/>
</must>

<must-not>
<file path="invoices/discounts.py" reason="known float bug, owned by card 05"/>
<rule reason="card 04 imports the exact signature">rename or add parameters</rule>
</must-not>

<proof>
<criterion>Invoice.total() still returns Decimal("22.00") for the existing case</criterion>
<criterion>a .005 total rounds up to the next cent</criterion>
<verify>python3 -m unittest tests.test_totals.TotalsTest.test_half_up_rounding</verify>
</proof>

<depends-on>none</depends-on>
<agent>backend</agent>
</card>'

run_case "good card passes" 0 "" "$good"

# --- legacy shape: accepted with a NOTE, never blocked ---
run_case "legacy bold-label card -> NOTE, exit 0" 0 "NOTE legacy" \
'# 03 — old shape

**Verify:** `pytest -k rounds asserts 10.01`
**Agent:** backend'

run_case "neither shape -> no-shape" 2 "no-shape" \
'# 03 — nothing

just prose'

# --- one finding per rule ---
run_case "missing <goal>" 2 "missing-section: <goal>" "$(printf '%s' "$good" | grep -v '<goal>')"
run_case "missing <depends-on>" 2 "missing-section: <depends-on>" "$(printf '%s' "$good" | grep -v '<depends-on>')"
run_case "two <verify>" 2 "verify-count: expected exactly one <verify>, found 2" \
  "$(printf '%s' "$good" | sed 's|<verify>\(.*\)</verify>|<verify>\1</verify>\n<verify>npm test -- x</verify>|')"
run_case "no <verify>" 2 "verify-count" "$(printf '%s' "$good" | grep -v '<verify>')"
run_case "multi-line <verify>" 2 "verify-multiline" \
  "$(printf '%s' "$good" | sed 's|<verify>\(.*\)</verify>|<verify>\n\1\n</verify>|')"
run_case "no <criterion>" 2 "no-criterion" "$(printf '%s' "$good" | grep -v '<criterion>')"
run_case "<file> without mode" 2 "file-mode" \
  "$(printf '%s' "$good" | sed 's| mode="create"||')"
run_case "<file mode=edit> without line" 2 "file-line" \
  "$(printf '%s' "$good" | sed 's| line="11"||')"
run_case "<must-not> file without reason" 2 "must-not-reason" \
  "$(printf '%s' "$good" | sed 's| reason="known float bug, owned by card 05"||')"
run_case "<must-not> rule with empty reason" 2 "must-not-reason" \
  "$(printf '%s' "$good" | sed 's|reason="card 04 imports the exact signature"|reason=""|')"
run_case "<interface> without consumer" 2 "interface-consumer" \
  "$(printf '%s' "$good" | sed 's| consumer="04"||')"
run_case "<skill> without name" 2 "skill-name" \
  "$(printf '%s' "$good" | sed 's|<skill name="money-conventions"/>|<skill/>|')"
run_case "<agent> outside vocabulary" 2 "agent-vocabulary" \
  "$(printf '%s' "$good" | sed 's|<agent>backend</agent>|<agent>wizard</agent>|')"
run_case "<agent>generic</agent> is in vocabulary" 0 "" \
  "$(printf '%s' "$good" | sed 's|<agent>backend</agent>|<agent>generic</agent>|')"

# --- every finding is reported, not just the first ---
f="$FX/multi.md"
printf '%s\n' "$good" | sed -e 's| consumer="04"||' -e 's| line="11"||' > "$f"
set +e; out=$("$lint" --card "$f" 2>&1); rc=$?; set -e
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q interface-consumer && printf '%s' "$out" | grep -q file-line; then
  printf 'PASS: two defects -> both reported (rc=%s)\n' "$rc"; pass=$((pass+1))
else printf 'FAIL: two defects -> both reported (rc=%s out=<%s>)\n' "$rc" "$out"; fail=$((fail+1)); fi

# --- usage ---
set +e; out=$("$lint" 2>&1); rc=$?; set -e
if [ "$rc" = 3 ]; then printf 'PASS: usage: no args (rc=3)\n'; pass=$((pass+1))
else printf 'FAIL: usage: no args (rc=%s)\n' "$rc"; fail=$((fail+1)); fi

# --- a run record is written on both verdicts ---
if grep -rq "$(printf '\tcard-shape\tpass\t')" "$CC_CARDLINT_DIR" && grep -rq "$(printf '\tcard-shape\tblock\t')" "$CC_CARDLINT_DIR"; then
  printf 'PASS: run record written for pass and block\n'; pass=$((pass+1))
else printf 'FAIL: run record missing under %s\n' "$CC_CARDLINT_DIR"; fail=$((fail+1)); fi

printf -- '---- %s passed, %s failed ----\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
