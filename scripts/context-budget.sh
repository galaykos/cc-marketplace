#!/usr/bin/env bash
# Blocking per-plugin context-budget gate (D3/A5). Approximates each
# plugin's session-start token surface — the sum, over its
# skills/*/SKILL.md, commands/*.md, agents/*.md (a bundle sums its member
# plugins instead), of the frontmatter `description:` value's byte length,
# PLUS the stdout of its SessionStart hooks (run sandboxed against an empty
# project — a deterministic, repo-neutral lower bound; real hook output can
# grow with the user's project). chars/4 — compared against a committed
# baseline. A plugin more than its tolerance over baseline fails (exit 1);
# --update-baseline, a missing jq, and a missing baseline file stay exit 0.
# NOT metered (dynamic, per-prompt): UserPromptSubmit/PostToolUse/etc. hook
# output — those plugins are listed informationally at the end of the run.
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

# Stdout bytes a plugin's SessionStart hooks inject each session, measured by
# executing them in a throwaway sandbox (empty CLAUDE_PROJECT_DIR/HOME, minimal
# SessionStart JSON on stdin, fail-open per hook). Deterministic lower bound.
HOOK_SANDBOX=$(mktemp -d)
trap 'rm -rf "$HOOK_SANDBOX"' EXIT
TIMEOUT_CMD=""
command -v timeout >/dev/null 2>&1 && TIMEOUT_CMD="timeout 10"

plugin_sessionstart_bytes() {
  local pdir="$1" total=0 cmd resolved out bytes
  local hj="$pdir/hooks/hooks.json"
  [ -f "$hj" ] || { printf '0'; return; }
  while IFS= read -r cmd; do
    [ -n "$cmd" ] || continue
    resolved=${cmd//'${CLAUDE_PLUGIN_ROOT}'/$pdir}
    out=$(printf '{"hook_event_name":"SessionStart","source":"startup","cwd":"%s"}' "$HOOK_SANDBOX" \
      | CLAUDE_PLUGIN_ROOT="$pdir" CLAUDE_PROJECT_DIR="$HOOK_SANDBOX" HOME="$HOOK_SANDBOX" \
        $TIMEOUT_CMD bash -c "$resolved" 2>/dev/null) || true
    bytes=$(printf '%s' "$out" | wc -c | tr -d ' ')
    total=$((total + bytes))
  done < <(jq -r '.hooks.SessionStart[]?.hooks[]?.command // empty' "$hj" 2>/dev/null)
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
    # Bundle: sum member plugins' description + SessionStart-hook bytes.
    total_bytes=0
    while IFS= read -r member; do
      [ -n "$member" ] || continue
      mdir="plugins/$member"
      [ -d "$mdir" ] || continue
      bytes=$(( $(plugin_desc_bytes "$mdir") + $(plugin_sessionstart_bytes "$mdir") ))
      total_bytes=$((total_bytes + bytes))
    done < <(jq -r '.dependencies[]?' "$pj" 2>/dev/null)
    is_leaf=0
    members=$(jq -r '.dependencies | length' "$pj" 2>/dev/null || echo 1)
  else
    # Leaf: measure the plugin's own dir (descriptions + SessionStart stdout).
    pdir="${pj%/.claude-plugin/plugin.json}"
    total_bytes=$(( $(plugin_desc_bytes "$pdir") + $(plugin_sessionstart_bytes "$pdir") ))
    is_leaf=1
    members=1
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
      # Tolerance: 2 tokens for a leaf, 2 x member-count for a bundle.
      #
      # BASIS (a number with no stated basis is theater). The metric is bytes/4,
      # so 2 tokens is an 8-byte edit — one short word. Every meaningful
      # description change is larger: adding a trigger phrase costs 15+ bytes.
      # At zero tolerance, fixing a 4-character typo in one description took
      # i18n from 116 to 117 tokens and exited 1, freezing every description in
      # the marketplace at its current byte length.
      #
      # A bundle SUMS its members, so a flat 2 would re-create the friction this
      # removes: three +1 leaf typos all pass, then `everything` fails at +3
      # naming plugins nobody edited. The bundle allowance is therefore the sum
      # of its members' allowances.
      #
      # LIMITATION (honest scope): this converts "any typo is a blocking budget
      # failure" into "only real surface growth is". It does NOT bound aggregate
      # drift — every leaf drifting its full +2 is ~150 tokens across the
      # marketplace that no run reports, and a bundle's scaled allowance widens
      # in proportion. Accepted, not covered; the ratchet is per-plugin, and
      # that is exactly what it means.
      tolerance=$((2 * members))
      if [ "$delta" -gt "$tolerance" ]; then
        warn_lines="${warn_lines}FAIL: $bname +$delta tok over baseline (tolerance $tolerance; intentional? re-baseline via --update-baseline)
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

# Honesty note: per-prompt/per-tool hook output is dynamic and NOT metered.
unmetered=$(for h in plugins/*/hooks/hooks.json; do
  [ -f "$h" ] || continue
  jq -e '.hooks | keys - ["SessionStart"] | length > 0' "$h" >/dev/null 2>&1 \
    && basename "$(dirname "$(dirname "$h")")"
done | sort | tr '\n' ' ')
[ -n "$unmetered" ] && echo "note: per-prompt/per-tool hook output not metered: $unmetered"

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
