#!/usr/bin/env bash
# Blocking per-plugin context-budget gate (D3/A5). Approximates each
# plugin's session-start description-token surface — the sum, over its
# skills/*/SKILL.md, commands/*.md, agents/*.md (a bundle sums its member
# plugins instead), of the frontmatter `description:` value's byte length,
# chars/4 — and compares it against a committed baseline. Any plugin over
# its baseline fails the run (exit 1); --update-baseline, a missing jq,
# and a missing baseline file stay exit 0.
set -u
cd "$(dirname "$0")/.."

BASELINE=scripts/context-budget-baseline.json
update=0
[ "${1:-}" = "--update-baseline" ] && update=1

command -v jq >/dev/null 2>&1 || { echo "WARN: jq not found, skipping context-budget"; exit 0; }

# Sum of frontmatter description-value bytes across a plugin dir's
# skills/*/SKILL.md, commands/*.md, agents/*.md (tolerates missing dirs).
plugin_desc_bytes() {
  local pdir="$1" total=0 f desc bytes
  for f in "$pdir"/skills/*/SKILL.md "$pdir"/commands/*.md "$pdir"/agents/*.md; do
    [ -f "$f" ] || continue
    desc=$(awk '/^---$/{c++; next} c==1{print} c==2{exit}' "$f" 2>/dev/null \
      | sed -n 's/^description:[[:space:]]*//p' | head -1)
    # single-line description: values only — validate.sh's frontmatter gates keep
    # descriptions on one line; a YAML block scalar would undercount here
    bytes=$(printf '%s' "$desc" | wc -c | tr -d ' ')
    total=$((total + bytes))
  done
  printf '%s' "$total"
}

no_baseline=0
[ -f "$BASELINE" ] || no_baseline=1
# A corrupt baseline would silently exempt every plugin — fail loudly instead.
if [ "$no_baseline" -eq 0 ] && ! jq empty "$BASELINE" 2>/dev/null; then
  echo "FAIL: $BASELINE is not valid JSON — gate cannot run" >&2
  exit 1
fi

printf '%-20s %8s %10s %10s\n' "plugin" "tokens" "baseline" "delta"

new_baseline='{}'
warn_lines=""
fail=0
leaf_tokens_total=0

for pj in plugins/*/.claude-plugin/plugin.json; do
  [ -f "$pj" ] || continue
  bname=$(jq -r '.name' "$pj" 2>/dev/null)
  [ -n "$bname" ] || continue

  if jq -e 'has("dependencies")' "$pj" >/dev/null 2>&1; then
    # Bundle: sum member plugins' description bytes.
    total_bytes=0
    while IFS= read -r member; do
      [ -n "$member" ] || continue
      mdir="plugins/$member"
      [ -d "$mdir" ] || continue
      bytes=$(plugin_desc_bytes "$mdir")
      total_bytes=$((total_bytes + bytes))
    done < <(jq -r '.dependencies[]?' "$pj" 2>/dev/null)
    is_leaf=0
  else
    # Leaf: measure the plugin's own dir.
    total_bytes=$(plugin_desc_bytes "${pj%/.claude-plugin/plugin.json}")
    is_leaf=1
  fi
  tokens=$(( (total_bytes + 2) / 4 ))
  # TOTAL sums leaves only — bundles would double-count their members.
  [ "$is_leaf" -eq 1 ] && leaf_tokens_total=$((leaf_tokens_total + tokens))

  baseline_tok="-"
  delta_str="-"
  if [ "$no_baseline" -eq 0 ]; then
    b=$(jq -r --arg b "$bname" '.[$b] // empty' "$BASELINE" 2>/dev/null)
    if [ -n "$b" ]; then
      baseline_tok="$b"
      delta=$((tokens - b))
      delta_str="$delta"
      if [ "$delta" -gt 0 ]; then
        warn_lines="${warn_lines}FAIL: $bname +$delta tok over baseline (intentional? re-baseline via --update-baseline)
"
        fail=1
      fi
    else
      # No baseline entry: a new plugin must not ship unlimited surface unseen.
      warn_lines="${warn_lines}FAIL: $bname has no baseline entry — add one via --update-baseline
"
      fail=1
    fi
  fi

  printf '%-20s %8s %10s %10s\n' "$bname" "$tokens" "$baseline_tok" "$delta_str"

  nb_tmp=$(printf '%s' "$new_baseline" | jq --arg k "$bname" --argjson v "$tokens" '. + {($k): $v}' 2>/dev/null)
  [ -n "$nb_tmp" ] && new_baseline="$nb_tmp"
done

echo "TOTAL: $leaf_tokens_total tokens"

[ "$no_baseline" -eq 1 ] && echo "WARN: no baseline" >&2

if [ "$update" -eq 1 ]; then
  # Updating IS the remedy — suppress the FAIL/remedy lines on this path.
  printf '%s\n' "$new_baseline" | jq '.' > "$BASELINE" 2>/dev/null
  echo "baseline updated: $BASELINE"
  exit 0
fi
[ -n "$warn_lines" ] && printf '%s' "$warn_lines" >&2

# Baseline missing entirely: warn-only, never block.
[ "$no_baseline" -eq 1 ] && exit 0

exit $fail
