#!/usr/bin/env bash
# Blocking per-plugin context-budget gate (D3/A5). TWO metered channels, each
# with its own committed baseline and its own ratchet:
#
#   ALWAYS-ON (scripts/context-budget-baseline.json) — surface every session
#   pays before a single file is read: the frontmatter `description:` byte
#   length of skills/*/SKILL.md, commands/*.md, agents/*.md (a bundle sums its
#   member plugins instead), PLUS the stdout of its SessionStart hooks, PLUS
#   the `tools/list` payload of any local MCP server the plugin declares.
#
#   DYNAMIC (scripts/context-budget-dynamic-baseline.json) — surface injected
#   per prompt and per tool call: the stdout of UserPromptSubmit and
#   Pre/PostToolUse hooks. This channel was UNMETERED until 2026-08-02 and the
#   omission was load-bearing: skill-router's UserPromptSubmit hook alone emits
#   ~9.4 kB (~2.4k tokens) of a second command catalog on any work-shaped
#   prompt, against an always-on baseline entry of 0. "Zero always-on tokens"
#   was true and irrelevant for every hook-bearing plugin. Measuring it does not
#   make it always-on — a per-tool hook fires per Edit, not once — so it is
#   reported and ratcheted SEPARATELY rather than folded into the always-on sum.
#
# All hook and MCP measurement runs sandboxed against an empty project with an
# empty HOME (a deterministic, repo-neutral LOWER bound; real output can grow
# with the user's project) and is fail-open per hook. chars/4. A plugin more
# than its tolerance over EITHER baseline fails (exit 1); --update-baseline, a
# missing jq, and a missing baseline file stay exit 0.
#
# STILL NOT METERED, by nature rather than by omission: skill BODIES loaded when
# a routing rule fires (a routed a11y-audit is ~1.8k tokens on top of its
# description), and remote MCP servers, whose tool surface cannot be read
# offline. Both are named in the run's closing notes rather than silently
# scored as zero.
set -u
cd "$(dirname "$0")/.."

BASELINE=scripts/context-budget-baseline.json
DYN_BASELINE=scripts/context-budget-dynamic-baseline.json
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

# Stdout bytes a plugin's per-prompt / per-tool hooks inject, measured the same
# sandboxed way as SessionStart. UserPromptSubmit gets a work-shaped prompt
# because several hooks gate on exactly that (skill-router's route-prompt.sh
# matches build|create|fix|review|refactor|... — a neutral prompt measures zero
# and would understate the channel by ~2.4k tokens). Pre/PostToolUse get a
# synthetic Edit payload, the hottest path in the product.
plugin_dynamic_hook_bytes() {
  local pdir="$1" total=0 cmd resolved out bytes ev payload sid tmp
  local hj="$pdir/hooks/hooks.json"
  [ -f "$hj" ] || { printf '0'; return; }
  # A FRESH session id and a FRESH TMPDIR per measurement. Several hooks are
  # once-per-session, keyed on a marker directory under $TMPDIR — reuse a session
  # id and the second run measures 0, which would make this gate order-dependent
  # and silently report a plugin's cost as zero on every run after the first.
  # Uniqueness comes from mktemp, not a counter: this function is called inside
  # command substitution, so a shell variable incremented here never survives.
  tmp=$(mktemp -d "$HOOK_SANDBOX/dyn.XXXXXX" 2>/dev/null) || { printf '0'; return; }
  sid="ctx-budget-$(basename "$tmp")"
  for ev in UserPromptSubmit PreToolUse PostToolUse; do
    case "$ev" in
      UserPromptSubmit)
        payload=$(jq -nc --arg cwd "$HOOK_SANDBOX" --arg sid "$sid" \
          '{hook_event_name:"UserPromptSubmit",prompt:"refactor the auth module, add tests and review the diff",session_id:$sid,cwd:$cwd}') ;;
      *)
        payload=$(jq -nc --arg cwd "$HOOK_SANDBOX" --arg ev "$ev" --arg sid "$sid" --arg f "$HOOK_SANDBOX/src/example.ts" \
          '{hook_event_name:$ev,tool_name:"Edit",session_id:$sid,cwd:$cwd,
            tool_input:{file_path:$f,old_string:"const a = 1",new_string:"const a = 2"},
            tool_response:{filePath:$f,success:true}}' 2>/dev/null) ;;
    esac
    [ -n "$payload" ] || continue
    while IFS= read -r cmd; do
      [ -n "$cmd" ] || continue
      resolved=${cmd//'${CLAUDE_PLUGIN_ROOT}'/$pdir}
      out=$(printf '%s' "$payload" \
        | CLAUDE_PLUGIN_ROOT="$pdir" CLAUDE_PROJECT_DIR="$HOOK_SANDBOX" HOME="$HOOK_SANDBOX" TMPDIR="$tmp" \
          $TIMEOUT_CMD bash -c "$resolved" 2>/dev/null) || true
      bytes=$(printf '%s' "$out" | wc -c | tr -d ' ')
      total=$((total + bytes))
    done < <(jq -r --arg ev "$ev" '.hooks[$ev][]?.hooks[]?.command // empty' "$hj" 2>/dev/null)
  done
  printf '%s' "$total"
}

# Bytes of the tools/list result a plugin's LOCAL MCP servers put in context at
# session start. Always-on by nature: tool definitions are loaded once and stay.
# Remote servers (type http/sse) cannot be read offline — they are counted as 0
# here and enumerated separately in the closing notes, so the run reports the
# blind spot instead of scoring it as free.
plugin_mcp_bytes() {
  local pdir="$1" total=0 name cmd args resolved out res bytes
  local mj="$pdir/.mcp.json"
  [ -f "$mj" ] || { printf '0'; return; }
  while IFS=$'\t' read -r name cmd args; do
    [ -n "$name" ] || continue
    [ "$cmd" = "__remote__" ] && continue
    command -v "$cmd" >/dev/null 2>&1 || continue
    resolved=${args//'${CLAUDE_PLUGIN_ROOT}'/$PWD/$pdir}
    out=$(printf '%s\n%s\n%s\n' \
      '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"context-budget","version":"0"}}}' \
      '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
      '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' \
      | CLAUDE_PLUGIN_ROOT="$pdir" HOME="$HOOK_SANDBOX" \
        $TIMEOUT_CMD "$cmd" $resolved 2>/dev/null) || true
    res=$(printf '%s' "$out" | jq -c 'select(.id==2) | .result' 2>/dev/null | head -1)
    [ -n "$res" ] || continue
    bytes=$(printf '%s' "$res" | wc -c | tr -d ' ')
    total=$((total + bytes))
  done < <(jq -r '.mcpServers | to_entries[]
      | [ .key,
          (if (.value.type // "stdio") == "stdio" then (.value.command // "") else "__remote__" end),
          (if (.value.type // "stdio") == "stdio" then ((.value.args // []) | join(" ")) else (.value.url // "?") end)
        ] | @tsv' "$mj" 2>/dev/null)
  printf '%s' "$total"
}

no_baseline=0
[ -f "$BASELINE" ] || no_baseline=1
# A corrupt baseline would silently exempt every plugin — fail loudly instead.
if [ "$no_baseline" -eq 0 ] && ! jq empty "$BASELINE" 2>/dev/null; then
  echo "FAIL: $BASELINE is not valid JSON — gate cannot run" >&2
  exit 1
fi
no_dyn_baseline=0
[ -f "$DYN_BASELINE" ] || no_dyn_baseline=1
if [ "$no_dyn_baseline" -eq 0 ] && ! jq empty "$DYN_BASELINE" 2>/dev/null; then
  echo "FAIL: $DYN_BASELINE is not valid JSON — gate cannot run" >&2
  exit 1
fi

# A stdio MCP server needs its runtime to answer tools/list. On a machine
# without that runtime the measurement is 0, which against a non-zero baseline
# would read as "this plugin shrank by 475 tokens" and fail the build for a
# missing binary. Exempt those plugins from the always-on delta this run and say
# so — a gate that fires on the checker's toolchain rather than on the surface
# under test is worse than no gate.
MCP_UNMEASURABLE=""
for mj in plugins/*/.mcp.json; do
  [ -f "$mj" ] || continue
  mplug=$(basename "$(dirname "$mj")")
  while IFS= read -r mcmd; do
    [ -n "$mcmd" ] || continue
    command -v "$mcmd" >/dev/null 2>&1 && continue
    case " $MCP_UNMEASURABLE " in *" $mplug "*) ;; *) MCP_UNMEASURABLE="$MCP_UNMEASURABLE $mplug" ;; esac
  done < <(jq -r '.mcpServers[]? | select((.type // "stdio") == "stdio") | .command // empty' "$mj" 2>/dev/null)
done
[ -n "$MCP_UNMEASURABLE" ] && echo "WARN: MCP runtime missing, always-on delta exempted for:$MCP_UNMEASURABLE" >&2

printf '%-20s %8s %10s %10s\n' "plugin" "tokens" "baseline" "delta"

new_baseline='{}'
new_dyn_baseline='{}'
warn_lines=""
dyn_rows=""
fail=0
leaf_tokens_total=0
leaf_dyn_total=0

for pj in plugins/*/.claude-plugin/plugin.json; do
  [ -f "$pj" ] || continue
  bname=$(jq -r '.name' "$pj" 2>/dev/null)
  [ -n "$bname" ] || continue

  if jq -e 'has("dependencies")' "$pj" >/dev/null 2>&1; then
    # Bundle: sum member plugins' always-on and dynamic bytes.
    total_bytes=0
    dyn_bytes=0
    while IFS= read -r member; do
      [ -n "$member" ] || continue
      mdir="plugins/$member"
      [ -d "$mdir" ] || continue
      bytes=$(( $(plugin_desc_bytes "$mdir") + $(plugin_sessionstart_bytes "$mdir") + $(plugin_mcp_bytes "$mdir") ))
      total_bytes=$((total_bytes + bytes))
      dyn_bytes=$((dyn_bytes + $(plugin_dynamic_hook_bytes "$mdir") ))
    done < <(jq -r '.dependencies[]?' "$pj" 2>/dev/null)
    is_leaf=0
    members=$(jq -r '.dependencies | length' "$pj" 2>/dev/null || echo 1)
  else
    # Leaf: measure the plugin's own dir.
    pdir="${pj%/.claude-plugin/plugin.json}"
    total_bytes=$(( $(plugin_desc_bytes "$pdir") + $(plugin_sessionstart_bytes "$pdir") + $(plugin_mcp_bytes "$pdir") ))
    dyn_bytes=$(plugin_dynamic_hook_bytes "$pdir")
    is_leaf=1
    members=1
  fi
  tokens=$(( (total_bytes + 2) / 4 ))
  dyn_tokens=$(( (dyn_bytes + 2) / 4 ))
  # TOTAL sums leaves only — bundles would double-count their members.
  [ "$is_leaf" -eq 1 ] && leaf_tokens_total=$((leaf_tokens_total + tokens))
  [ "$is_leaf" -eq 1 ] && leaf_dyn_total=$((leaf_dyn_total + dyn_tokens))

  # Dynamic channel: same ratchet, own baseline, reported in its own table so
  # nothing parsing the always-on table sees a changed shape.
  if [ "$dyn_tokens" -gt 0 ]; then
    dyn_b=""
    [ "$no_dyn_baseline" -eq 0 ] && dyn_b=$(jq -r --arg b "$bname" '.[$b] // empty' "$DYN_BASELINE" 2>/dev/null)
    if [ -n "$dyn_b" ]; then
      dyn_delta=$((dyn_tokens - dyn_b))
      dyn_rows="${dyn_rows}$(printf '%-20s %8s %10s %10s' "$bname" "$dyn_tokens" "$dyn_b" "$dyn_delta")
"
      if [ "$dyn_delta" -gt $((2 * members)) ]; then
        warn_lines="${warn_lines}FAIL: $bname +$dyn_delta dynamic tok over baseline (tolerance $((2 * members)); intentional? re-baseline via --update-baseline)
"
        fail=1
      fi
    else
      dyn_rows="${dyn_rows}$(printf '%-20s %8s %10s %10s' "$bname" "$dyn_tokens" "-" "-")
"
      # Same rule as the always-on channel: new surface must not ship unseen.
      if [ "$no_dyn_baseline" -eq 0 ]; then
        warn_lines="${warn_lines}FAIL: $bname has no dynamic baseline entry — add one via --update-baseline
"
        fail=1
      fi
    fi
  fi
  nd_tmp=$(printf '%s' "$new_dyn_baseline" | jq --arg k "$bname" --argjson v "$dyn_tokens" '. + {($k): $v}' 2>/dev/null)
  [ -n "$nd_tmp" ] && new_dyn_baseline="$nd_tmp"

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
      # Exempt a plugin (or a bundle containing one) whose MCP runtime is absent.
      mcp_exempt=0
      for mu in $MCP_UNMEASURABLE; do
        [ "$bname" = "$mu" ] && mcp_exempt=1
        [ "$is_leaf" -eq 0 ] && jq -e --arg m "$mu" '.dependencies | index($m)' "$pj" >/dev/null 2>&1 && mcp_exempt=1
      done
      [ "$mcp_exempt" -eq 1 ] && delta=0 && delta_str="exempt"
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

# AGGREGATE CEILING. The per-plugin ratchet above says of itself, at :127-131, that
# it "does NOT bound aggregate drift" — every leaf may drift its full +2 and no run
# reports the sum, while --update-baseline accepts any growth on request. So the one
# number the README advertises to users as the cost of `everything` had nothing
# holding it anywhere. This does: a declared ceiling that fails the build, so a new
# leaf has to be paid for by a deletion or by an explicit, reviewable decision to
# raise the number in this file. That is the only version of the marketplace's own
# "new surfaces name their funding deletion" rule with teeth.
#
# Raising it is legitimate and deliberately visible: edit the line below in a commit
# someone reviews. --update-baseline does NOT move it, which is the point — the
# per-plugin ratchet is a convenience, this is a budget.
ALWAYS_ON_CEILING=12600
if [ "$leaf_tokens_total" -gt "$ALWAYS_ON_CEILING" ]; then
  warn_lines="${warn_lines}FAIL: always-on total $leaf_tokens_total exceeds the declared ceiling $ALWAYS_ON_CEILING — pay for the new surface with a deletion, or raise ALWAYS_ON_CEILING in scripts/context-budget.sh in a reviewed commit (--update-baseline does not move it)
"
  fail=1
fi

# Second metered channel, own table so the always-on table's shape is stable.
if [ -n "$dyn_rows" ]; then
  echo
  printf '%-20s %8s %10s %10s\n' "plugin (dynamic)" "tokens" "baseline" "delta"
  printf '%s' "$dyn_rows"
  echo "TOTAL DYNAMIC: $leaf_dyn_total tokens (per work-shaped prompt + per Edit, not per session)"
  DYNAMIC_CEILING=2600
  if [ "$leaf_dyn_total" -gt "$DYNAMIC_CEILING" ]; then
    warn_lines="${warn_lines}FAIL: dynamic total $leaf_dyn_total exceeds the declared ceiling $DYNAMIC_CEILING — same rule as the always-on ceiling
"
    fail=1
  fi
fi

# Remote MCP servers cannot be read offline. Naming them is the whole point:
# a plugin shipping one is an always-on context cost AND an outbound runtime
# dependency, and scoring it zero would say the opposite.
mcp_remote=$(for m in plugins/*/.mcp.json; do
  [ -f "$m" ] || continue
  p=$(basename "$(dirname "$m")")
  jq -r --arg p "$p" '.mcpServers | to_entries[]
    | select((.value.type // "stdio") != "stdio")
    | "\($p):\(.key)@\(.value.url // "?")"' "$m" 2>/dev/null
done | sort | tr '\n' ' ')
[ -n "$mcp_remote" ] && echo "note: remote MCP tool surface NOT measurable offline (counted 0): $mcp_remote"

# Still unmetered by nature: a routing rule fires a skill BODY, which is an
# order of magnitude above its description and depends on the user's files.
echo "note: skill BODIES loaded by skill-router rules are not metered in either channel"

[ "$no_baseline" -eq 1 ] && echo "WARN: no baseline" >&2
[ "$no_dyn_baseline" -eq 1 ] && echo "WARN: no dynamic baseline" >&2

if [ "$update" -eq 1 ]; then
  # Updating IS the remedy — suppress the FAIL/remedy lines on this path.
  printf '%s\n' "$new_baseline" | jq '.' > "$BASELINE" 2>/dev/null
  printf '%s\n' "$new_dyn_baseline" | jq '.' > "$DYN_BASELINE" 2>/dev/null
  echo "baseline updated: $BASELINE"
  echo "baseline updated: $DYN_BASELINE"
  exit 0
fi
[ -n "$warn_lines" ] && printf '%s' "$warn_lines" >&2

# Baseline missing entirely: warn-only, never block.
[ "$no_baseline" -eq 1 ] && exit 0

exit $fail
