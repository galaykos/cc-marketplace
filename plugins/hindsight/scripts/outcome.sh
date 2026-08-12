#!/usr/bin/env bash
# outcome.sh — closes the loop the ledger always had the data for: did an
# applied hindsight rule actually move the numbers in later sessions?
#
# Usage: outcome.sh [project-cwd]   (defaults to $PWD; slug derived like collect.sh)
# Reads:  $HOME/.claude/hindsight/<slug>/ledger.jsonl   (written by the SessionEnd hook)
#         $HOME/.claude/hindsight/<slug>/applied.jsonl  (written at harvest apply time)
# Prints a per-rule before/after table. Exit 0 always — a report, not a gate.
#
# Residual (stated, per the has-teeth convention): this is CORRELATION. Sessions
# after an applied rule differ in more than the rule — different work, other
# rules, model updates. A moved number is a hint about where to spend a real
# control/treatment run (see skill-creator's eval loop), not proof the rule
# worked. The honest minimum is printed with every table; MIN_N=3 sessions per
# side before any number is shown at all.
set -u
command -v jq >/dev/null 2>&1 || { echo "outcome: jq required"; exit 0; }
cwd="${1:-$PWD}"
[ -n "${HOME:-}" ] || { echo "outcome: no HOME"; exit 0; }
slug=$(printf '%s' "$cwd" | tr -c '[:alnum:]' '-')
dir="$HOME/.claude/hindsight/$slug"
ledger="$dir/ledger.jsonl"
applied="$dir/applied.jsonl"
MIN_N="${MIN_N:-3}"

[ -f "$applied" ] || { echo "outcome: no applied-rules record yet — records begin at the first harvest apply after hindsight 0.5.0"; exit 0; }
[ -f "$ledger" ]  || { echo "outcome: applied.jsonl exists but no ledger — nothing to grade against"; exit 0; }

echo "## Applied-rule outcomes (correlational — see note)"
echo
echo "| Applied (ts) | Rule (first 60 chars) | Sessions before/after | Friction/session | Errors/session | Direction |"
echo "|---|---|---|---|---|---|"

while IFS= read -r rec; do
  ts=$(jq -r '.ts // empty' <<<"$rec" 2>/dev/null); [ -n "$ts" ] || continue
  text=$(jq -r '(.text // "?") | .[0:60]' <<<"$rec" 2>/dev/null)
  stats=$(jq -c -n --arg ts "$ts" --argjson min "$MIN_N" '
    [inputs | fromjson? // empty | select(.ts_end? and .ts_end != "")] as $rows
    | [$rows[] | select(.ts_end < $ts)] as $before
    | [$rows[] | select(.ts_end > $ts)] as $after
    | def mean(f): if length == 0 then null else (map(f) | add / length) end;
      {nb: ($before | length), na: ($after | length),
       fb: ($before | mean(.friction_events // 0)), fa: ($after | mean(.friction_events // 0)),
       eb: ($before | mean(.errors // 0)),          ea: ($after | mean(.errors // 0))}
  ' -R <"$ledger" 2>/dev/null) || continue
  nb=$(jq -r '.nb' <<<"$stats"); na=$(jq -r '.na' <<<"$stats")
  if [ "$nb" -lt "$MIN_N" ] || [ "$na" -lt "$MIN_N" ]; then
    printf '| %s | %s | %s/%s | — | — | insufficient data (need ≥%s per side) |\n' \
      "$ts" "$text" "$nb" "$na" "$MIN_N"
    continue
  fi
  line=$(jq -r '
    def r2: (. * 100 | round) / 100;
    "\(.fb|r2) → \(.fa|r2)|\(.eb|r2) → \(.ea|r2)|" +
    (if .fa < .fb and .ea <= .eb then "improved"
     elif .fa > .fb and .ea >= .eb then "worsened"
     else "mixed" end)' <<<"$stats")
  printf '| %s | %s | %s/%s | %s\n' "$ts" "$text" "$nb" "$na" "$(sed 's/|/ | /g' <<<"$line")|"
done <"$applied"

echo
echo "> Correlational only: post-apply sessions differ in more than the rule."
echo "> A moved number says where a real control/treatment eval is worth running;"
echo "> it never proves the rule caused the move."
exit 0
