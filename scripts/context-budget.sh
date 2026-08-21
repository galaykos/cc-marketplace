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
#   ACTIVATED (scripts/context-budget-activated-baseline.json) — the always-on
#   surface again, but with the state its hooks are WAITING FOR. Added
#   2026-08-20 because the always-on pass runs against an empty HOME and no env,
#   which meters the OFF state: terse's SessionStart hook emits 4,171 B once a
#   level is set and 0 in the sandbox, brain's emits ~2 kB once brain/INDEX.md
#   exists and 75 B without it. That is ~1.5k tokens a real user pays and no
#   baseline saw. This channel is a SEPARATE column, not folded into always-on,
#   because "installed and idle" and "installed and switched on" are two honest
#   numbers and averaging them would describe neither.
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
ACT_BASELINE=scripts/context-budget-activated-baseline.json
OFFICIAL=scripts/context-budget-official.json
update=0
reconcile=0
update_official=0
for arg in "$@"; do
  case "$arg" in
    --update-baseline)  update=1 ;;
    # Reconciliation against `claude plugin details`, the host's OWN meter.
    # LOCAL ONLY, WARN ONLY, and not a CI step: `details` resolves a plugin by
    # INSTALLED NAME (it rejects a path, and its own `--plugin-dir` hint is not
    # an option of that subcommand), so a checkout with nothing installed cannot
    # run it. Claiming it as a gate would be claiming a check CI can never
    # execute.
    --reconcile)        reconcile=1 ;;
    --update-official)  reconcile=1; update_official=1 ;;
  esac
done

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

# Stdout bytes a plugin's SessionStart hooks inject in the ACTIVATED state — the
# same hooks, run against a sandbox carrying the state they wait for. The fixture
# turns on everything this repo knows how to turn on; a hook waiting for some
# OTHER state still measures its OFF value here, and that residual is the reason
# this is a floor and not a ceiling.
#
# Fixture contents, each with the hook it exists for:
#   CC_TERSE=full            → terse/hooks/activate.sh (env beats its state file)
#   brain/INDEX.md           → brain/hooks/inject.sh (clamped at 2048 B by :65)
#   package.json + composer.json + a src tree
#                            → skill-router/hooks/prime.sh, which sniffs manifests
ACT_SANDBOX=$(mktemp -d)
trap 'rm -rf "$HOOK_SANDBOX" "$ACT_SANDBOX"' EXIT
mkdir -p "$ACT_SANDBOX/brain" "$ACT_SANDBOX/src" "$ACT_SANDBOX/app"
cat > "$ACT_SANDBOX/brain/INDEX.md" <<'ACTEOF'
# Project brain map

| Area | Path | What lives here |
| --- | --- | --- |
| api | app/Http | controllers, form requests, resources |
| domain | app/Domain | entities, value objects, domain services |
| ui | src/components | React components and their stories |
| data | database/migrations | schema history |

Generated by /brain index. Areas below carry their own file, one per area, and
each names the entry points a reader should start from rather than listing every
file in the directory.
ACTEOF
printf '{"name":"ctx-fixture","dependencies":{"react":"^19.0.0","next":"^15.4.0"},"devDependencies":{"vite":"^7.0.0","vitest":"^3.0.0"}}\n' > "$ACT_SANDBOX/package.json"
printf '{"require":{"php":"^8.3","laravel/framework":"^12.0"}}\n' > "$ACT_SANDBOX/composer.json"
printf 'export const x = 1\n' > "$ACT_SANDBOX/src/example.ts"

plugin_sessionstart_activated_bytes() {
  local pdir="$1" total=0 cmd resolved out bytes
  local hj="$pdir/hooks/hooks.json"
  [ -f "$hj" ] || { printf '0'; return; }
  while IFS= read -r cmd; do
    [ -n "$cmd" ] || continue
    resolved=${cmd//'${CLAUDE_PLUGIN_ROOT}'/$pdir}
    out=$(printf '{"hook_event_name":"SessionStart","source":"startup","cwd":"%s"}' "$ACT_SANDBOX" \
      | CLAUDE_PLUGIN_ROOT="$pdir" CLAUDE_PROJECT_DIR="$ACT_SANDBOX" HOME="$ACT_SANDBOX" \
        CC_TERSE=full \
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
  local pdir="$1" total=0 cmd resolved out bytes ev payload sid tmp prompt ptmp ups_max=0 ups_sum=0
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
  # UserPromptSubmit is measured against a CORPUS, scored MAX, not one string.
  #
  # WHY. This used to send exactly one prompt — "refactor the auth module, add
  # tests and review the diff". api-docs-first's remind.sh gates on
  # (sdk|endpoint|integrat\w*|webhook|oauth|graphql); none of those words is in
  # that sentence, so the hook baselined at 0 while emitting 206 bytes (~52 tok)
  # on a real integration prompt. A hook whose trigger vocabulary misses the one
  # probe is unmetered forever, and its growth with it. MAX rather than SUM
  # because a user sends one prompt, not four; the corpus asks "what is the worst
  # single prompt", which is the number the budget is about.
  #
  # LIMITATION: a hook whose trigger appears in no corpus entry still reads 0,
  # and that 0 is indistinguishable from "never fires". Extend the corpus when a
  # new trigger vocabulary ships; nothing here can detect that for you.
  for prompt in \
    "refactor the auth module, add tests and review the diff" \
    "implement a webhook endpoint that integrates the Stripe SDK" \
    "the deploy pipeline is failing and the container will not start" \
    "design the schema and write the migration for the orders table"; do
    # Fresh sid + TMPDIR per corpus entry: several prompt hooks are once-per
    # session behind a marker, so a reused id would score every entry after the
    # first at 0 and turn the corpus back into the single probe it replaces.
    ptmp=$(mktemp -d "$HOOK_SANDBOX/dynp.XXXXXX" 2>/dev/null) || continue
    payload=$(jq -nc --arg cwd "$HOOK_SANDBOX" --arg sid "ctx-budget-$(basename "$ptmp")" --arg p "$prompt" \
      '{hook_event_name:"UserPromptSubmit",prompt:$p,session_id:$sid,cwd:$cwd}')
    [ -n "$payload" ] || continue
    ups_sum=0
    while IFS= read -r cmd; do
      [ -n "$cmd" ] || continue
      out=$(printf '%s' "$payload" \
        | CLAUDE_PLUGIN_ROOT="$pdir" CLAUDE_PROJECT_DIR="$HOOK_SANDBOX" HOME="$HOOK_SANDBOX" TMPDIR="$ptmp" \
          $TIMEOUT_CMD bash -c "${cmd//'${CLAUDE_PLUGIN_ROOT}'/$pdir}" 2>/dev/null) || true
      bytes=$(printf '%s' "$out" | wc -c | tr -d ' ')
      # SUM across this plugin's prompt hooks — a prompt that trips two of them
      # pays both — then MAX across prompts.
      ups_sum=$((ups_sum + bytes))
    done < <(jq -r '.hooks.UserPromptSubmit[]?.hooks[]?.command // empty' "$hj" 2>/dev/null)
    [ "$ups_sum" -gt "$ups_max" ] && ups_max=$ups_sum
  done
  total=$((total + ups_max))

  for ev in PreToolUse PostToolUse; do
    case "$ev" in
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
no_act_baseline=0
[ -f "$ACT_BASELINE" ] || no_act_baseline=1
if [ "$no_act_baseline" -eq 0 ] && ! jq empty "$ACT_BASELINE" 2>/dev/null; then
  echo "FAIL: $ACT_BASELINE is not valid JSON — gate cannot run" >&2
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
new_act_baseline='{}'
warn_lines=""
dyn_rows=""
act_rows=""
fail=0
leaf_tokens_total=0
leaf_dyn_total=0
leaf_act_total=0

for pj in plugins/*/.claude-plugin/plugin.json; do
  [ -f "$pj" ] || continue
  bname=$(jq -r '.name' "$pj" 2>/dev/null)
  [ -n "$bname" ] || continue

  if jq -e 'has("dependencies")' "$pj" >/dev/null 2>&1; then
    # Bundle: sum member plugins' always-on and dynamic bytes.
    total_bytes=0
    dyn_bytes=0
    act_bytes=0
    while IFS= read -r member; do
      [ -n "$member" ] || continue
      mdir="plugins/$member"
      [ -d "$mdir" ] || continue
      bytes=$(( $(plugin_desc_bytes "$mdir") + $(plugin_sessionstart_bytes "$mdir") + $(plugin_mcp_bytes "$mdir") ))
      total_bytes=$((total_bytes + bytes))
      dyn_bytes=$((dyn_bytes + $(plugin_dynamic_hook_bytes "$mdir") ))
      act_bytes=$((act_bytes + $(plugin_desc_bytes "$mdir") + $(plugin_sessionstart_activated_bytes "$mdir") + $(plugin_mcp_bytes "$mdir") ))
    done < <(jq -r '.dependencies[]?' "$pj" 2>/dev/null)
    is_leaf=0
    members=$(jq -r '.dependencies | length' "$pj" 2>/dev/null || echo 1)
  else
    # Leaf: measure the plugin's own dir.
    pdir="${pj%/.claude-plugin/plugin.json}"
    total_bytes=$(( $(plugin_desc_bytes "$pdir") + $(plugin_sessionstart_bytes "$pdir") + $(plugin_mcp_bytes "$pdir") ))
    dyn_bytes=$(plugin_dynamic_hook_bytes "$pdir")
    act_bytes=$(( $(plugin_desc_bytes "$pdir") + $(plugin_sessionstart_activated_bytes "$pdir") + $(plugin_mcp_bytes "$pdir") ))
    is_leaf=1
    members=1
  fi
  tokens=$(( (total_bytes + 2) / 4 ))
  dyn_tokens=$(( (dyn_bytes + 2) / 4 ))
  act_tokens=$(( (act_bytes + 2) / 4 ))
  # TOTAL sums leaves only — bundles would double-count their members.
  [ "$is_leaf" -eq 1 ] && leaf_tokens_total=$((leaf_tokens_total + tokens))
  [ "$is_leaf" -eq 1 ] && leaf_dyn_total=$((leaf_dyn_total + dyn_tokens))
  [ "$is_leaf" -eq 1 ] && leaf_act_total=$((leaf_act_total + act_tokens))

  # Activated channel: only reported when the state actually changes what a
  # plugin emits. A plugin whose activated figure equals its always-on figure has
  # no waiting-for-state surface and would add a row saying nothing.
  if [ "$act_tokens" -ne "$tokens" ]; then
    act_b=""
    [ "$no_act_baseline" -eq 0 ] && act_b=$(jq -r --arg b "$bname" '.[$b] // empty' "$ACT_BASELINE" 2>/dev/null)
    if [ -n "$act_b" ]; then
      act_delta=$((act_tokens - act_b))
      act_rows="${act_rows}$(printf '%-20s %8s %10s %10s' "$bname" "$act_tokens" "$act_b" "$act_delta")
"
      if [ "$act_delta" -gt $((2 * members)) ]; then
        warn_lines="${warn_lines}FAIL: $bname +$act_delta activated tok over baseline (tolerance $((2 * members)); intentional? re-baseline via --update-baseline)
"
        fail=1
      fi
    else
      act_rows="${act_rows}$(printf '%-20s %8s %10s %10s' "$bname" "$act_tokens" "-" "-")
"
      if [ "$no_act_baseline" -eq 0 ]; then
        warn_lines="${warn_lines}FAIL: $bname has no activated baseline entry — add one via --update-baseline
"
        fail=1
      fi
    fi
    na_tmp=$(printf '%s' "$new_act_baseline" | jq --arg k "$bname" --argjson v "$act_tokens" '. + {($k): $v}' 2>/dev/null)
    [ -n "$na_tmp" ] && new_act_baseline="$na_tmp"
  fi

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
# Raised 12600 -> 12800 on 2026-08-15 for the `lean` plugin (73 tokens: one skill
# description, no command, no agent). The funding question was asked the other way
# first, and the answer is worth recording: the marketplace's fattest frontmatter
# description is 435 bytes against a 500-byte cap, so paying for `lean` by deletion
# meant trimming trigger phrasing out of five or six unrelated skills to buy 0.5% of
# this budget. Degrading dispatch quality across the catalogue to avoid a 200-token
# line edit is precisely the ratio-chasing `lean:cost-model` and testing's
# proportionality.md both reject — the cheaper artifact would have been the more
# expensive decision. Spending it deliberately and saying so is the honest form.
ALWAYS_ON_CEILING=12800
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
  # Raised 2600 -> 2800 on 2026-08-11 with the delivery-channel fixes: the
  # skill-router inline nudges moved to the metered additionalContext envelope
  # (previously unmetered dead stdout), plain-source routing rows were added,
  # and taskmaster's clarify directive widened. Those are deliberate spends the
  # owner chose; the old ceiling would have sat 1 token from failure. The
  # ceiling still exists to make the NEXT unplanned growth a conversation.
  # Raised 2800 -> 2900 on 2026-08-15. `lean`'s PostToolUse budget hook measures 85
  # tokens and PASSES the old ceiling — at 2798 of 2800. It is raised anyway, on this
  # block's own stated reasoning: the 2026-08-11 raise was justified partly because
  # "the old ceiling would have sat 1 token from failure", and 2 tokens is that case
  # again. Left alone, the next person to touch ANY hook in this marketplace gets a red
  # build naming a plugin they did not edit. Note what is NOT being bought: skill-router
  # alone is 2663 of the 2798 (95%), so this channel remains one plugin's command
  # catalog plus rounding. That is the number worth attacking next, not this ceiling.
  DYNAMIC_CEILING=2900
  if [ "$leaf_dyn_total" -gt "$DYNAMIC_CEILING" ]; then
    warn_lines="${warn_lines}FAIL: dynamic total $leaf_dyn_total exceeds the declared ceiling $DYNAMIC_CEILING — same rule as the always-on ceiling
"
    fail=1
  fi
fi

# Third metered channel: the same always-on surface with the state its hooks wait
# for. Only plugins whose emission actually CHANGES appear here.
if [ -n "$act_rows" ]; then
  echo
  printf '%-20s %8s %10s %10s\n' "plugin (activated)" "tokens" "baseline" "delta"
  printf '%s' "$act_rows"
  echo "TOTAL ACTIVATED: $leaf_act_total tokens (always-on surface with terse on, a brain map present, and manifests to sniff)"
  echo "  = always-on $leaf_tokens_total + $((leaf_act_total - leaf_tokens_total)) tokens no baseline saw before 2026-08-20"
fi

# RECONCILIATION against `claude plugin details` — the host's own meter.
#
# WHY. This script estimates always-on cost as description bytes / 4. The host
# charges a per-component floor on top of that (~60-130 tok even for a one-line
# description) and counts commands as skills, so our number reads LOW: measured
# 2026-08-20, summing `claude plugin details` over the 61 leaves gave 19,667
# tokens against our 12,789 — a factor of 1.54, and the gap scales with COMPONENT
# COUNT, which is exactly what a distillation is supposed to reduce. A meter that
# under-reads in proportion to the thing it exists to control is worth
# reconciling against.
#
# IT IS NOT GROUND TRUTH, measured 2026-08-21. `details` is a static estimate over
# the FILES: it charged a `disable-model-invocation: true` skill ~60 always-on
# tokens for a description the session listing provably does not contain (probes
# in rationale/host-lever-probes-2026-08-21.md). Read the gap it reports as a
# better model of the host's per-component floor, not as a measurement of what
# the harness actually loads.
#
# STANDING: local, WARN-only, NOT a CI step, and this comment is the reason.
# `claude plugin details` resolves a plugin by INSTALLED NAME — it rejects a path
# and its own `--plugin-dir` hint is not an option of that subcommand — so a
# fresh checkout with nothing installed cannot run it. Wiring it into CI would
# ship a check that can never execute there.
#
# --reconcile        compare live against the committed snapshot, WARN on drift
# --update-official  re-take the snapshot (records the date it was taken)
if [ "$reconcile" -eq 1 ]; then
  echo
  if ! command -v claude >/dev/null 2>&1; then
    echo "reconcile: SKIPPED — no \`claude\` on PATH (this is the local-only channel)"
  else
    printf '%-20s %10s %10s %8s\n' "plugin" "ours" "official" "gap"
    recon_json='{}'
    recon_ours=0; recon_off=0; recon_missing=""
    for rpj in plugins/*/.claude-plugin/plugin.json; do
      jq -e 'has("dependencies")' "$rpj" >/dev/null 2>&1 && continue   # leaves only
      rname=$(jq -r '.name' "$rpj" 2>/dev/null); [ -n "$rname" ] || continue
      rours=$(jq -r --arg b "$rname" '.[$b] // empty' "$BASELINE" 2>/dev/null)
      [ -n "$rours" ] || continue
      roff=$(claude plugin details "$rname" 2>/dev/null \
             | sed -n 's/.*Always-on:[[:space:]]*~\{0,1\}\([0-9,]*\).*/\1/p' | tr -d ',' | head -1)
      if [ -z "$roff" ]; then recon_missing="$recon_missing $rname"; continue; fi
      recon_ours=$((recon_ours + rours)); recon_off=$((recon_off + roff))
      gap=$((roff - rours))
      printf '%-20s %10s %10s %+8d\n' "$rname" "$rours" "$roff" "$gap"
      rt=$(printf '%s' "$recon_json" | jq --arg k "$rname" --argjson v "$roff" '. + {($k): $v}' 2>/dev/null)
      [ -n "$rt" ] && recon_json="$rt"
    done
    if [ "$recon_off" -gt 0 ]; then
      echo "RECONCILE TOTAL: ours $recon_ours vs official $recon_off (official/ours = $(awk -v a="$recon_off" -v b="$recon_ours" 'BEGIN{printf "%.2f", a/b}')x)"
    fi
    [ -n "$recon_missing" ] && echo "reconcile: not installed here, no official figure:$recon_missing"
    if [ "$update_official" -eq 1 ]; then
      printf '%s' "$recon_json" \
        | jq --arg d "$(date +%Y-%m-%d)" '{taken: $d, note: "claude plugin details, per leaf, installed-name resolution; local-only", plugins: .}' \
        > "$OFFICIAL" 2>/dev/null
      echo "official snapshot written: $OFFICIAL"
    elif [ -f "$OFFICIAL" ]; then
      # Drift against the last snapshot: >15% on any plugin is a WARN, because a
      # jump means either the host changed how it charges or we changed the
      # plugin without noticing what it costs a user.
      while IFS=$'\t' read -r dname dold; do
        [ -n "$dname" ] || continue
        dnew=$(printf '%s' "$recon_json" | jq -r --arg k "$dname" '.[$k] // empty' 2>/dev/null)
        [ -n "$dnew" ] || continue
        [ "$dold" -gt 0 ] || continue
        ddelta=$(( (dnew - dold) * 100 / dold ))
        if [ "$ddelta" -gt 15 ] || [ "$ddelta" -lt -15 ]; then
          echo "WARN: $dname official cost moved ${ddelta}% since the snapshot ($dold -> $dnew) — re-take with --update-official once understood"
        fi
      done < <(jq -r '.plugins | to_entries[] | "\(.key)\t\(.value)"' "$OFFICIAL" 2>/dev/null)
    fi
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
echo "note: skill BODIES loaded by skill-router rules are not metered in any channel"
echo "note: the activated channel turns on what THIS fixture knows (terse level, brain/INDEX.md, manifests); a hook waiting for other state still reads its OFF value"

[ "$no_baseline" -eq 1 ] && echo "WARN: no baseline" >&2
[ "$no_dyn_baseline" -eq 1 ] && echo "WARN: no dynamic baseline" >&2
[ "$no_act_baseline" -eq 1 ] && echo "WARN: no activated baseline" >&2

if [ "$update" -eq 1 ]; then
  # Updating IS the remedy — suppress the FAIL/remedy lines on this path.
  printf '%s\n' "$new_baseline" | jq '.' > "$BASELINE" 2>/dev/null
  printf '%s\n' "$new_dyn_baseline" | jq '.' > "$DYN_BASELINE" 2>/dev/null
  printf '%s\n' "$new_act_baseline" | jq '.' > "$ACT_BASELINE" 2>/dev/null
  echo "baseline updated: $BASELINE"
  echo "baseline updated: $DYN_BASELINE"
  echo "baseline updated: $ACT_BASELINE"
  exit 0
fi
[ -n "$warn_lines" ] && printf '%s' "$warn_lines" >&2

# Baseline missing entirely: warn-only, never block.
[ "$no_baseline" -eq 1 ] && exit 0

exit $fail
