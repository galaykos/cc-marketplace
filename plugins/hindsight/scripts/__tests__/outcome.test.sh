#!/usr/bin/env bash
# Fixture tests for outcome.sh — before/after math, the insufficient-data
# honesty row, and the no-record path, over a synthetic HOME.
set -u
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/outcome.sh"
export HOME="$(mktemp -d)"; trap 'rm -rf "$HOME"' EXIT
pass=0; fail=0
proj="/tmp/proj-x"
slug=$(printf '%s' "$proj" | tr -c '[:alnum:]' '-')
dir="$HOME/.claude/hindsight/$slug"; mkdir -p "$dir"

expect() { if grep -q "$2" <<<"$OUT"; then pass=$((pass+1)); else echo "FAIL $1: missing '$2'"; echo "$OUT" | tail -5; fail=$((fail+1)); fi; }

# No applied.jsonl → the honest no-record line.
OUT=$(bash "$SCRIPT" "$proj")
expect "no-record" "no applied-rules record yet"

# Ledger: 3 high-friction sessions before, 3 low after the applied ts.
: > "$dir/ledger.jsonl"
for i in 1 2 3; do
  printf '{"v":1,"ts_end":"2026-08-0%sT10:00:00Z","turns":50,"friction_events":9,"errors":6}\n' "$i" >> "$dir/ledger.jsonl"
done
for i in 6 7 8; do
  printf '{"v":1,"ts_end":"2026-08-0%sT10:00:00Z","turns":50,"friction_events":2,"errors":1}\n' "$i" >> "$dir/ledger.jsonl"
done
printf '{"v":1,"ts":"2026-08-04T12:00:00Z","kind":"rule","text":"always run the linter before claiming done"}\n' > "$dir/applied.jsonl"

OUT=$(bash "$SCRIPT" "$proj")
expect "table row"     "always run the linter"
expect "counts"        "| 3/3 |"
expect "friction move" "9 → 2"
expect "errors move"   "6 → 1"
expect "direction"     "improved"
expect "caveat"        "Correlational only"

# Insufficient data: applied ts too recent (0 after-rows).
printf '{"v":1,"ts":"2026-08-09T12:00:00Z","kind":"rule","text":"newest rule"}\n' >> "$dir/applied.jsonl"
OUT=$(bash "$SCRIPT" "$proj")
expect "insufficient" "insufficient data"

# Worsened direction detected.
printf '{"v":1,"ts":"2026-08-05T00:00:00Z","kind":"rule","text":"a rule that made it worse"}\n' > "$dir/applied.jsonl"
: > "$dir/ledger.jsonl"
for i in 1 2 3; do printf '{"v":1,"ts_end":"2026-08-0%sT10:00:00Z","friction_events":1,"errors":0}\n' "$i" >> "$dir/ledger.jsonl"; done
for i in 6 7 8; do printf '{"v":1,"ts_end":"2026-08-0%sT10:00:00Z","friction_events":5,"errors":3}\n' "$i" >> "$dir/ledger.jsonl"; done
OUT=$(bash "$SCRIPT" "$proj")
expect "worsened" "worsened"

echo "outcome tests: $pass passed, $fail failed"
exit $((fail > 0))
