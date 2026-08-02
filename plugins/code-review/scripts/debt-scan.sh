#!/usr/bin/env bash
# Technical-debt ratchet. Counts five language-agnostic debt categories, compares
# them against a committed baseline, and exits non-zero when any category GREW.
#
# The ratchet is the whole value. Asked to "inventory our technical debt", a model
# greps TODO and returns an unordered markdown list with no dates, no baseline and
# no direction — and asked again next month it returns a differently-shaped list
# that cannot be diffed against the first. Counting is not the hard part; having
# last month's number to compare against is.
#
# Shape copied deliberately from scripts/context-budget.sh, the one gate this
# repo's own prior review credits as genuinely enforced: a committed baseline, a
# per-category ratchet, and an explicit --update-baseline that ACCEPTS growth.
# Debt is allowed to grow; it is not allowed to grow silently.
#
#   bash debt-scan.sh [--check] [--update-baseline] [--baseline FILE] [--dir DIR] [--age]
#
#     --check            exit 2 if any category grew vs the baseline (CI mode)
#     --update-baseline  write current counts as the new baseline, exit 0
#     --age              resolve first-seen dates for TODO/FIXME via git pickaxe
#                        (slow — one `git log -S` per marker; off by default)
#
# Exit: 0 clean or baseline written · 2 a category grew · 3 cannot run
#
# HONEST LIMITATIONS.
#   - It counts OCCURRENCES, not severity. Ten trivial suppressions outrank one
#     load-bearing one, and this script cannot tell them apart. It answers "is
#     this getting worse", never "is this bad".
#   - The category patterns are the common spellings across JS/TS, PHP, Python,
#     Go, Java and Ruby. A house-specific suppression comment is invisible.
#   - --age uses `git log -S` per unique marker text: accurate, and O(markers).
#     On a large repo run it deliberately, not in CI.
set -u

baseline=".claude/debt-baseline.json"
dir="."
mode="report"
want_age=0
while [ $# -gt 0 ]; do
  case "$1" in
    --check) mode="check"; shift ;;
    --update-baseline) mode="update"; shift ;;
    --baseline) baseline="${2:-}"; shift 2 ;;
    --dir) dir="${2:-}"; shift 2 ;;
    --age) want_age=1; shift ;;
    -h|--help) sed -n '2,32p' "$0"; exit 0 ;;
    *) printf 'debt-scan: unknown argument %s\n' "$1" >&2; exit 3 ;;
  esac
done

[ -d "$dir" ] || { printf 'debt-scan: no such directory: %s\n' "$dir" >&2; exit 3; }
command -v jq >/dev/null 2>&1 || { printf 'debt-scan: jq required\n' >&2; exit 3; }

# Exclusions: vendored trees are somebody else's debt, and counting them makes the
# number move when a dependency updates — which is exactly the noise a ratchet
# cannot tolerate.
PRUNE='-name node_modules -o -name vendor -o -name .git -o -name dist -o -name build -o -name .venv -o -name target -o -name __pycache__'

scan() { # extended-regex -> count
  find "$dir" \( $PRUNE \) -prune -o -type f \
    \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' -o -name '*.mjs' \
       -o -name '*.php' -o -name '*.py' -o -name '*.go' -o -name '*.rb' -o -name '*.java' \
       -o -name '*.kt' -o -name '*.rs' -o -name '*.cs' -o -name '*.vue' -o -name '*.svelte' \) \
    -print0 2>/dev/null \
  | xargs -0 grep -cEh "$1" 2>/dev/null \
  | awk '{s+=$1} END {print s+0}'
}

# 1. SUPPRESSIONS — the category teams actually bleed on, and the one a TODO grep
#    misses entirely, because a suppression reads as code rather than as debt.
P_SUPPRESS='eslint-disable|@ts-ignore|@ts-expect-error|@phpstan-ignore|@psalm-suppress|# *noqa|@SuppressWarnings|#\[allow\(|// *nolint|rubocop:disable|# *type: *ignore|@pragma\('
# 2. SKIPPED / QUARANTINED TESTS — a test that does not run is a claim nobody checks.
P_SKIP='\b(it|test|describe|context)\.(skip|todo)\b|\bx(it|describe)\b|@pytest\.mark\.(skip|xfail)|markTestSkipped|markTestIncomplete|t\.Skip\(|@Ignore\b|@Disabled\b|#\[ignore\]'
# 3. BARE MARKERS — no owner, no date, no issue link.
P_TODO='(^|[^[:alnum:]])(TODO|FIXME|HACK|XXX)([^[:alnum:](]|$)'
# 4. DEPRECATED-SYMBOL REFERENCES — the deprecation was announced; nothing counts
#    whether callers actually left.
P_DEPRECATED='@deprecated|Deprecated\(|DeprecationWarning'
# 5. FEATURE FLAGS PAST THEIR REMOVAL DATE — approaches:rollout-planning tells
#    authors to write a removal date down and nothing in this marketplace has ever
#    read one back. This counts the flags that carry one at all; the date check is
#    reported separately below.
P_FLAG='(feature_?flag|isEnabled\(|featureEnabled\(|flags?\.[a-zA-Z_]+ *(===|==) *true|LaunchDarkly|unleash)'

suppress=$(scan "$P_SUPPRESS")
skipped=$(scan "$P_SKIP")
todo=$(scan "$P_TODO")
deprecated=$(scan "$P_DEPRECATED")
flags=$(scan "$P_FLAG")

current=$(jq -nc \
  --argjson suppressions "$suppress" \
  --argjson skipped_tests "$skipped" \
  --argjson bare_markers "$todo" \
  --argjson deprecated_refs "$deprecated" \
  --argjson feature_flags "$flags" \
  '{suppressions:$suppressions,skipped_tests:$skipped_tests,bare_markers:$bare_markers,deprecated_refs:$deprecated_refs,feature_flags:$feature_flags}')

printf '%-18s %8s %10s %8s\n' category current baseline delta
have_baseline=0
[ -f "$baseline" ] && jq empty "$baseline" 2>/dev/null && have_baseline=1

grew=0
for k in suppressions skipped_tests bare_markers deprecated_refs feature_flags; do
  cur=$(printf '%s' "$current" | jq -r --arg k "$k" '.[$k]')
  if [ "$have_baseline" -eq 1 ]; then
    base=$(jq -r --arg k "$k" '.[$k] // empty' "$baseline")
  else
    base=""
  fi
  if [ -n "$base" ]; then
    d=$((cur - base))
    printf '%-18s %8s %10s %+8d\n' "$k" "$cur" "$base" "$d"
    [ "$d" -gt 0 ] && grew=1
  else
    printf '%-18s %8s %10s %8s\n' "$k" "$cur" "-" "-"
  fi
done

# Age is reported, never ratcheted: "340 TODOs" is a number nobody acts on;
# "11 of them are older than two years, 3 in payments" is a decision.
if [ "$want_age" -eq 1 ] && command -v git >/dev/null 2>&1 && git -C "$dir" rev-parse >/dev/null 2>&1; then
  printf '\noldest bare markers (first seen, via git log -S):\n'
  find "$dir" \( $PRUNE \) -prune -o -type f -print0 2>/dev/null \
    | xargs -0 grep -hoE "$P_TODO.{0,60}" 2>/dev/null | sed 's/^[^A-Z]*//' | sort -u | head -40 \
    | while IFS= read -r marker; do
        [ -n "$marker" ] || continue
        first=$(git -C "$dir" log -S"$marker" --reverse --format=%as -- . 2>/dev/null | head -1)
        [ -n "$first" ] && printf '  %s  %s\n' "$first" "$marker"
      done | sort | head -15
fi

case "$mode" in
  update)
    mkdir -p "$(dirname "$baseline")" 2>/dev/null
    printf '%s\n' "$current" | jq '.' > "$baseline"
    printf '\nbaseline written: %s\n' "$baseline"
    exit 0 ;;
  check)
    if [ "$have_baseline" -eq 0 ]; then
      printf '\ndebt-scan: no baseline at %s — run --update-baseline once to start the ratchet\n' "$baseline" >&2
      exit 3
    fi
    if [ "$grew" -eq 1 ]; then
      printf '\ndebt-scan: a debt category grew against the baseline. Pay it down, or accept it deliberately with --update-baseline (the acceptance is the point — it lands in the diff and someone reviews it).\n' >&2
      exit 2
    fi
    printf '\ndebt-scan: no category grew.\n'
    exit 0 ;;
  *)
    [ "$have_baseline" -eq 0 ] && printf '\nno baseline yet — run --update-baseline to start the ratchet\n'
    exit 0 ;;
esac
