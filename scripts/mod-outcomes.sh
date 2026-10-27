#!/usr/bin/env bash
# mod-outcomes.sh — prints the outcome counts this marketplace's mods keep in each plugin's $.store (key `outcomes`): suggestions shown, accepted or passed over; prompt-coach judgments, flags and buttons; spawn-floor raises.
# Does not: say which project a count came from, see a session with mods off, or show that anything helped. Always exits 0.
# Why, limits, history: rationale/derivations/scripts.md § scripts/mod-outcomes.sh
set -u

dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/store"
command -v jq >/dev/null 2>&1 || { echo "mod-outcomes: jq is required"; exit 0; }
[ -d "$dir" ] || { echo "mod-outcomes: no store directory at $dir (no mod has saved anything yet)"; exit 0; }

found=0
for f in "$dir"/*.json; do
  [ -f "$f" ] || continue
  rows=$(jq -r '(.outcomes // {}) | to_entries[] | select(.value | type == "number") | "\(.key)\t\(.value)"' "$f" 2>/dev/null) || continue
  [ -n "$rows" ] || continue
  found=1
  name=$(basename "$f" .json)
  printf '%s (%s)\n' "${name%%_*}" "$f"
  printf '%s\n' "$rows" | LC_ALL=C sort | while IFS="$(printf '\t')" read -r key count; do
    printf '  %-48s %6s\n' "$key" "$count"
  done
  # accepted / shown per suggestion: the one ratio the counts support without a control arm.
  printf '%s\n' "$rows" | awk -F'\t' '
    $1 ~ /^suggest\..*\.shown$/    { t = $1; sub(/^suggest\./, "", t); sub(/\.shown$/, "", t); shown[t] = $2 }
    $1 ~ /^suggest\..*\.accepted$/ { t = $1; sub(/^suggest\./, "", t); sub(/\.accepted$/, "", t); took[t] = $2 }
    END { for (t in shown) printf "  %-48s %5.0f%%\n", "suggest." t " accepted of shown", 100 * (took[t] + 0) / shown[t] }'
done

[ "$found" = 1 ] || echo "mod-outcomes: no outcome counts yet under $dir"
exit 0
