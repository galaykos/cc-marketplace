#!/usr/bin/env bash
# Report-only per-bundle context-budget gate (D3/A5). Approximates each
# bundle's session-start description-token surface — the sum, over every
# member plugin's skills/*/SKILL.md, commands/*.md, agents/*.md, of the
# frontmatter `description:` value's byte length, chars/4 — and compares it
# against a committed baseline. Never fails the build: always exits 0.
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
      | sed -n 's/^description:[[:space:]]*//p')
    # single-line description: values only — validate.sh's frontmatter gates keep
    # descriptions on one line; a YAML block scalar would undercount here
    bytes=$(printf '%s' "$desc" | wc -c | tr -d ' ')
    total=$((total + bytes))
  done
  printf '%s' "$total"
}

no_baseline=0
[ -f "$BASELINE" ] || no_baseline=1

printf '%-20s %8s %10s %10s\n' "bundle" "tokens" "baseline" "delta"

new_baseline='{}'
warn_lines=""

for pj in plugins/*/.claude-plugin/plugin.json; do
  [ -f "$pj" ] || continue
  jq -e 'has("dependencies")' "$pj" >/dev/null 2>&1 || continue
  bname=$(jq -r '.name' "$pj" 2>/dev/null)
  [ -n "$bname" ] || continue

  total_bytes=0
  while IFS= read -r member; do
    [ -n "$member" ] || continue
    mdir="plugins/$member"
    [ -d "$mdir" ] || continue
    bytes=$(plugin_desc_bytes "$mdir")
    total_bytes=$((total_bytes + bytes))
  done < <(jq -r '.dependencies[]?' "$pj" 2>/dev/null)
  tokens=$(( (total_bytes + 2) / 4 ))

  baseline_tok="-"
  delta_str="-"
  if [ "$no_baseline" -eq 0 ]; then
    b=$(jq -r --arg b "$bname" '.[$b] // empty' "$BASELINE" 2>/dev/null)
    if [ -n "$b" ]; then
      baseline_tok="$b"
      delta=$((tokens - b))
      delta_str="$delta"
      if [ "$delta" -gt 0 ]; then
        warn_lines="${warn_lines}WARN: $bname +$delta tok over baseline
"
      fi
    fi
  fi

  printf '%-20s %8s %10s %10s\n' "$bname" "$tokens" "$baseline_tok" "$delta_str"

  nb_tmp=$(printf '%s' "$new_baseline" | jq --arg k "$bname" --argjson v "$tokens" '. + {($k): $v}' 2>/dev/null)
  [ -n "$nb_tmp" ] && new_baseline="$nb_tmp"
done

[ "$no_baseline" -eq 1 ] && echo "WARN: no baseline" >&2
[ -n "$warn_lines" ] && printf '%s' "$warn_lines" >&2

if [ "$update" -eq 1 ]; then
  printf '%s\n' "$new_baseline" | jq '.' > "$BASELINE" 2>/dev/null
  echo "baseline updated: $BASELINE"
fi

exit 0
