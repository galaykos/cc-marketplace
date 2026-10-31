#!/usr/bin/env bash
# context-budget.sh [--update-baseline | --reconcile | --update-official] — BLOCKING: a plugin more than 2 tokens (bytes/4) over its committed baseline in the always-on (descriptions, SessionStart stdout, local MCP tools/list), activated (the same with the state hooks wait for) or dynamic (prompt and per-Edit hook stdout, worst case) channel fails, as does a declared ceiling; the listing channel only reports.
# Misses: skill bodies a routing rule loads, remote MCP servers, a local MCP server's `instructions`, Stop and Bash-matched hooks, state the fixtures lack; sandboxed output is a lower bound. A missing jq or baseline file, and --update-baseline, exit 0.
# Why, limits, history: rationale/derivations/scripts.md § scripts/context-budget.sh
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
    # Local and WARN-only, never CI: `claude plugin details` resolves a plugin by installed name only.
    --reconcile)        reconcile=1 ;;
    --update-official)  reconcile=1; update_official=1 ;;
  esac
done

command -v jq >/dev/null 2>&1 || { echo "WARN: jq not found, skipping context-budget"; exit 0; }

# Frontmatter description bytes (+ " - " + when_to_use, as the CLI joins them) over skills, commands and agents, read through pc_listing_fields.
plugin_desc_bytes() {
  local pdir="$1" total=0 f fields desc wtu bytes
  for f in "$pdir"/skills/*/SKILL.md "$pdir"/commands/*.md "$pdir"/agents/*.md; do
    [ -f "$f" ] || continue
    fields=$(pc_listing_fields "$f")
    # `disable-model-invocation: true` keeps the description out of context altogether
    # (code.claude.com/docs/en/skills, "Description not in context"); a flagged entry costs 0.
    case "$fields" in *$'\t'true) continue ;; esac
    desc=${fields%%$'\t'*}
    wtu=${fields#*$'\t'}; wtu=${wtu%%$'\t'*}
    bytes=$(printf '%s%s' "$desc" "${wtu:+ - $wtu}" | wc -c | tr -d ' ')
    total=$((total + bytes))
  done
  printf '%s' "$total"
}

# Listing entry cost is pc_listing_entry_cost's (LC_ALL=C bytes, ~1% over the CLI's chars; agents excluded); call sites add the n-1 separators.
. "$(dirname "$0")/lib/plugin-checks.sh"
# The host's own listing constants, defined once in scripts/host-constants.sh and
# re-read out of the pinned CLI by `host-constants.sh --check`. Sourcing only assigns.
. "$(dirname "$0")/host-constants.sh"

# SessionStart stdout per plugin, run in an empty sandbox (CLAUDE_PROJECT_DIR = HOME = the sandbox): a deterministic lower bound.
HOOK_SANDBOX=$(mktemp -d)
# Edit fixtures get their own sandbox: a src/ beside the SessionStart one lets stack-sniffing hooks move the always-on figure.
EDIT_SANDBOX=$(mktemp -d)
mkdir -p "$EDIT_SANDBOX/src/components" "$EDIT_SANDBOX/src/styles" \
         "$EDIT_SANDBOX/tests" "$EDIT_SANDBOX/database/migrations" 2>/dev/null
# The fixture content trips the guards on purpose: a clean file measures a hook that ran and found nothing.
printf 'export const a = 2\nexport const b = a\n' > "$EDIT_SANDBOX/src/example.ts"
printf 'export const W = () => <div style={{color:"#3366ff"}} onClick={()=>{}} />\n' \
  > "$EDIT_SANDBOX/src/components/Widget.tsx"
{ printf 'test("a", () => { expect(svc._internal).toBe(1); expect(svc._cache.size).toBe(0) })\n'
  printf 'test("b", () => { expect(svc._internal).toBe(1); expect(svc._cache.size).toBe(0) })\n'
  printf 'test("c", () => { expect(svc._internal).toBe(1); expect(svc._cache.size).toBe(0) })\n'
} > "$EDIT_SANDBOX/tests/example.test.ts"
printf '.btn { color: #3366ff; margin: 13px; }\n.card { color: #3366ff; padding: 7px; }\n' \
  > "$EDIT_SANDBOX/src/styles/theme.css"
printf '<?php return new class extends Migration { public function up(): void { Schema::create("orders", fn($t) => $t->id()); } };\n' \
  > "$EDIT_SANDBOX/database/migrations/2026_01_01_000000_create_orders_table.php"
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

# The same SessionStart hooks against a sandbox holding the state they wait for (CC_TERSE=full, brain/INDEX.md, manifests); other state still reads OFF, so a floor.
ACT_SANDBOX=$(mktemp -d)
trap 'rm -rf "$HOOK_SANDBOX" "$ACT_SANDBOX" "$EDIT_SANDBOX"' EXIT
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

# UserPromptSubmit and Pre/PostToolUse stdout, same sandbox: a work-shaped prompt corpus, and a synthetic Edit per file shape.
plugin_dynamic_hook_bytes() {
  local pdir="$1" total=0 cmd resolved out bytes ev payload sid tmp prompt ptmp ups_max=0 ups_sum=0
  local hj="$pdir/hooks/hooks.json"
  [ -f "$hj" ] || { printf '0'; return; }
  # A fresh session id and TMPDIR per measurement (mktemp: a counter would not survive this subshell), or once-per-session hooks read 0 after the first run.
  tmp=$(mktemp -d "$HOOK_SANDBOX/dyn.XXXXXX" 2>/dev/null) || { printf '0'; return; }
  sid="ctx-budget-$(basename "$tmp")"
  # A real, empty transcript file: some hooks open transcript_path, and an unreadable one meters their error branch.
  : > "$HOOK_SANDBOX/transcript-$sid.jsonl" 2>/dev/null || true
  # UserPromptSubmit is scored MAX over a prompt corpus; a hook whose trigger is in no entry reads 0 — extend the corpus when a new trigger vocabulary ships.
  for prompt in \
    "refactor the auth module, add tests and review the diff" \
    "implement a webhook endpoint that integrates the Stripe SDK" \
    "the deploy pipeline is failing and the container will not start" \
    "design the schema and write the migration for the orders table" \
    "write code to call the GitHub API using their client library"; do
    # Fresh sid + TMPDIR per corpus entry, for the same once-per-session reason.
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
        # transcript_path is sent: context-keyed hooks read `.transcript_path // .session_id`, so session_id alone would meter their fallback branch.
        : ;;
    esac
    # File-shape corpus: SUM across a plugin's hooks for one shape, MAX across shapes — what ONE edit can cost.
    shape_max=0
    for shape in \
      "src/example.ts" \
      "src/components/Widget.tsx" \
      "tests/example.test.ts" \
      "src/styles/theme.css" \
      "database/migrations/2026_01_01_000000_create_orders_table.php"; do
      payload=$(jq -nc --arg cwd "$EDIT_SANDBOX" --arg ev "$ev" --arg sid "$sid" \
        --arg tp "$HOOK_SANDBOX/transcript-$sid.jsonl" --arg f "$EDIT_SANDBOX/$shape" \
        '{hook_event_name:$ev,tool_name:"Edit",session_id:$sid,transcript_path:$tp,cwd:$cwd,
          tool_input:{file_path:$f,old_string:"const a = 1",new_string:"const a = 2"},
          tool_response:{filePath:$f,success:true}}' 2>/dev/null)
      [ -n "$payload" ] || continue
      shape_sum=0
      while IFS= read -r cmd; do
        [ -n "$cmd" ] || continue
        resolved=${cmd//'${CLAUDE_PLUGIN_ROOT}'/$pdir}
        out=$(printf '%s' "$payload" \
          | CLAUDE_PLUGIN_ROOT="$pdir" CLAUDE_PROJECT_DIR="$EDIT_SANDBOX" HOME="$HOOK_SANDBOX" TMPDIR="$tmp" \
            $TIMEOUT_CMD bash -c "$resolved" 2>/dev/null) || true
        bytes=$(printf '%s' "$out" | wc -c | tr -d ' ')
        shape_sum=$((shape_sum + bytes))
      done < <(jq -r --arg ev "$ev" '.hooks[$ev][]?.hooks[]?.command // empty' "$hj" 2>/dev/null)
      [ "$shape_sum" -gt "$shape_max" ] && shape_max=$shape_sum
    done
    total=$((total + shape_max))
  done
  printf '%s' "$total"
}

# tools/list bytes of a plugin's local stdio MCP servers; remote (http/sse) ones count 0 here and are named in the closing notes.
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

# A stdio MCP server whose runtime is missing measures 0: exempt that plugin's always-on delta rather than fail on the checker's toolchain.
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
# LISTING CAP (report-only): budget_chars = ctxTokens x bytesPerToken x skillListingBudgetFraction, entry = name + 4 + min(desc + " - " + when_to_use, 1536); shown at opus-5 200k = 6,000 chars.
# The derivation (CLI 2.1.251, the 6.7x range, priority buy-back, SLASH_COMMAND_TOOL_CHAR_BUDGET): rationale/derivations/scripts.md § scripts/context-budget.sh
LISTING_CTX_TOKENS=${LISTING_CTX_TOKENS:-$HOST_LISTING_CTX_TOKENS}
LISTING_BYTES_PER_TOKEN=${LISTING_BYTES_PER_TOKEN:-3}
# The unit of skillListingBudgetFraction (0.01, 0.02 …), so awk, not $(( )).
LISTING_FRACTION=${LISTING_FRACTION:-$HOST_LISTING_FRACTION}
LISTING_CAP=$(awk -v t="$LISTING_CTX_TOKENS" -v b="$LISTING_BYTES_PER_TOKEN" -v f="$LISTING_FRACTION" 'BEGIN{printf "%d", t*b*f}')
LISTING_CAP_1M=$(awk -v b="$LISTING_BYTES_PER_TOKEN" -v f="$LISTING_FRACTION" 'BEGIN{printf "%d", 1000000*b*f}')
case "$LISTING_CAP" in ''|*[!0-9]*|0) LISTING_CAP=6000; LISTING_CAP_1M=30000 ;; esac
LISTING_MAX_DESC=$HOST_LISTING_MAX_DESC
listing_rows=""
union_chars=0
union_n=0
union_plugins=0
leaf_tokens_total=0
leaf_dyn_total=0
leaf_act_total=0

for pj in plugins/*/.claude-plugin/plugin.json; do
  [ -f "$pj" ] || continue
  bname=$(jq -r '.name' "$pj" 2>/dev/null)
  [ -n "$bname" ] || continue

  pdir="${pj%/.claude-plugin/plugin.json}"
  total_bytes=$(( $(plugin_desc_bytes "$pdir") + $(plugin_sessionstart_bytes "$pdir") + $(plugin_mcp_bytes "$pdir") ))
  dyn_bytes=$(plugin_dynamic_hook_bytes "$pdir")
  act_bytes=$(( $(plugin_desc_bytes "$pdir") + $(plugin_sessionstart_activated_bytes "$pdir") + $(plugin_mcp_bytes "$pdir") ))
  set -- $(pc_listing_entry_cost "$pdir")
  listing_chars=$1; listing_n=$2
  own_chars=$listing_chars; own_n=$listing_n
  tokens=$(( (total_bytes + 2) / 4 ))
  dyn_tokens=$(( (dyn_bytes + 2) / 4 ))
  act_tokens=$(( (act_bytes + 2) / 4 ))
  # Descriptions only (hook stdout and MCP survive eviction); NEAR is [97%, 103%] of the cap and is checked before OVER, since the host's unit is unverified.
  [ "${listing_n:-0}" -gt 1 ] && listing_chars=$((listing_chars + listing_n - 1))
  near_lo=$((LISTING_CAP * 97 / 100))
  near_hi=$((LISTING_CAP * 103 / 100))
  if [ "$listing_chars" -gt "$near_hi" ]; then
    listing_rows="${listing_rows}$(printf '%-24s %9s  OVER (%sx here, %sx at 1M)' "$bname" "$listing_chars" "$(awk -v a="$listing_chars" -v c="$LISTING_CAP" 'BEGIN{printf "%.1f", a/c}')" "$(awk -v a="$listing_chars" -v c="$LISTING_CAP_1M" 'BEGIN{printf "%.2f", a/c}')")
"
  elif [ "$listing_chars" -ge "$near_lo" ]; then
    listing_rows="${listing_rows}$(printf '%-24s %9s  NEAR (%s%% of cap, no headroom)' "$bname" "$listing_chars" "$(awk -v a="$listing_chars" -v c="$LISTING_CAP" 'BEGIN{printf "%.0f", 100*a/c}')")
"
  fi
  # UNION: the whole marketplace installed, computed only here and written down nowhere.
  union_chars=$((union_chars + own_chars)); union_n=$((union_n + own_n))
  union_plugins=$((union_plugins + 1))
  leaf_tokens_total=$((leaf_tokens_total + tokens))
  leaf_dyn_total=$((leaf_dyn_total + dyn_tokens))
  leaf_act_total=$((leaf_act_total + act_tokens))

  # Activated rows only where the state changes what a plugin emits.
  if [ "$act_tokens" -ne "$tokens" ]; then
    act_b=""
    [ "$no_act_baseline" -eq 0 ] && act_b=$(jq -r --arg b "$bname" '.[$b] // empty' "$ACT_BASELINE" 2>/dev/null)
    if [ -n "$act_b" ]; then
      act_delta=$((act_tokens - act_b))
      act_rows="${act_rows}$(printf '%-20s %8s %10s %10s' "$bname" "$act_tokens" "$act_b" "$act_delta")
"
      if [ "$act_delta" -gt 2 ]; then
        warn_lines="${warn_lines}FAIL: $bname +$act_delta activated tok over baseline (tolerance 2; intentional? re-baseline via --update-baseline)
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
      if [ "$dyn_delta" -gt 2 ]; then
        warn_lines="${warn_lines}FAIL: $bname +$dyn_delta dynamic tok over baseline (tolerance 2; intentional? re-baseline via --update-baseline)
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
      # Tolerance 2 tokens (an 8-byte edit): zero froze every description at its byte length; aggregate drift is the ceilings' job, not this ratchet's.
      tolerance=2
      # Exempt a plugin whose MCP runtime is absent.
      mcp_exempt=0
      for mu in $MCP_UNMEASURABLE; do
        [ "$bname" = "$mu" ] && mcp_exempt=1
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

# OVER is a loading warning, never a cost one: text past the cap is never sent, and stripping a description was measured not to change firing.
echo
echo "listing channel (CLI entry cost: name + 4 + min(description + \" - \" + when_to_use,${LISTING_MAX_DESC}), skills + commands)"
echo "  budget = ctxTokens x bytesPerToken x fraction; showing ${LISTING_CTX_TOKENS} tok x ${LISTING_BYTES_PER_TOKEN} x ${LISTING_FRACTION} = ${LISTING_CAP} chars (a 1M-context session gets ${LISTING_CAP_1M})"
if [ -n "$listing_rows" ]; then
  printf '%-24s %9s  %s\n' "install" "chars" "status"
  printf '%s' "$listing_rows"
  listing_had_rows=1
fi
# THE WHOLE-MARKETPLACE ROW. Report-only, like every other line in this channel.
[ "${union_n:-0}" -gt 1 ] && union_chars=$((union_chars + union_n - 1))
echo
echo "  EVERYTHING INSTALLED (all ${union_plugins} plugins, ${union_n} entries): ${union_chars} chars"
# ceil3 rounds the recommended fraction UP at its printed precision; that ceiling is the margin.
awk -v a="$union_chars" -v c="$LISTING_CAP" -v c1="$LISTING_CAP_1M" -v f="$LISTING_FRACTION" -v b="$LISTING_BYTES_PER_TOKEN" 'BEGIN{
  printf "    %.2fx the %d-char cap here; %.2fx the %d-char cap at 1M\n", a/c, c, a/c1, c1;
  printf "    to fit WITHOUT eviction set skillListingBudgetFraction to %.3f here, or %.3f at 1M\n", ceil3((a/c)*f), ceil3((a/c1)*f);
  printf "    cost of doing so: about %d system-prompt tokens every turn\n", a/b }
  function ceil3(v,  t){ t = int(v * 1000); return (v * 1000 > t + 1e-9 ? t + 1 : t) / 1000 }'
echo "    this is the union of every plugin dir, counted once each."
if [ -n "${listing_had_rows:-}" ]; then
  echo "  every install not listed above is under the cap and loses nothing to eviction"
  echo "  OVER = a LOADING warning, never a cost one: over budget the CLI reduces entries"
  echo "  to name-only and buys descriptions back in PRIORITY order, so the text is never sent"
  echo "  and never charged. Artifact NAME + 4 chars is charged per artifact, which is why the"
  echo "  fix is fewer artifacts and not shorter descriptions."
  echo "  It is NOT evidence anything became unreachable: stripping a description was measured"
  echo "  on 2026-09-15 to change firing by nothing (47/50 vs 47/50) — rationale/2026-09-15-listing-eviction-probe.md."
  echo "  Both numbers are real: the same install can be OVER at 200k and comfortably under at 1M."
  echo "  Levers, in settings.json: skillListingBudgetFraction (default 0.01), skillListingMaxDescChars (1536)."
else
  echo "  no install exceeds the cap"
fi

# A declared budget --update-baseline never moves: pay for new surface with a deletion, or raise it in a reviewed commit.
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
  # Same rule as ALWAYS_ON_CEILING: raise it only in a reviewed commit.
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
  echo "TOTAL ACTIVATED: $leaf_act_total tokens (always-on surface with a terse level on, a brain map present, and manifests to sniff)"
  echo "  = always-on $leaf_tokens_total + $((leaf_act_total - leaf_tokens_total)) tokens no baseline saw before 2026-08-20"
fi

# --reconcile / --update-official: compare with `claude plugin details`, the host's own static estimate; local and WARN-only, since it resolves by installed name.
if [ "$reconcile" -eq 1 ]; then
  echo
  if ! command -v claude >/dev/null 2>&1; then
    echo "reconcile: SKIPPED — no \`claude\` on PATH (this is the local-only channel)"
  else
    printf '%-20s %10s %10s %8s\n' "plugin" "ours" "official" "gap"
    recon_json='{}'
    recon_ours=0; recon_off=0; recon_missing=""
    for rpj in plugins/*/.claude-plugin/plugin.json; do
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
      # >15% drift from the snapshot is a WARN: the host's charging or the plugin changed.
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

# Remote MCP servers cannot be read offline: name them rather than score them 0.
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
echo 'note: mod-injected text (tool.call `context`, `prompt.suggest`, `ui.status`, panes, `prompt.section`/`prompt.context`/`skill.prompt`) is unmetered by nature — modules are never executed by this gate'
echo "note: the listing cap is a FORMULA read out of CLI 2.1.251 (ctxTokens x bytesPerToken x skillListingBudgetFraction, default fraction 0.01, configurable in settings.json) — derivation in this script's LISTING_* header; the channel is report-only and never fails the build"
echo "note: the listing channel costs entries the way the CLI does (name + 4 + capped desc, skills + commands). SessionStart stdout and MCP tools/list are always-on but not part of this listing, so they are eviction-proof and excluded. AGENTS are excluded too, and that one is UNVERIFIED rather than known: they render in a separate system-prompt listing and whether it draws on the same budget was not established"
echo "note: the activated channel turns on what THIS fixture knows (terse level, brain/INDEX.md, manifests); a hook waiting for other state still reads its OFF value"
echo "note: Stop hooks and Bash-matched PreToolUse are never executed by the dynamic probe (candor, code-architecture, task-runner, command-guard read 0 for that reason, not because they are silent)"
echo "note: the per-tool probe now drives five file shapes (source, component, test, stylesheet, migration) with content chosen to trip the guards; MAX across shapes, SUM across a plugin's hooks for one shape"
echo "note: a per-edit hook still reading 0 is NOT necessarily silent, and the cause is no longer path shape. Measured 2026-08-31: of six plugins reading 0, the file-shape corpus moved ONE (testing, 0 -> 127). The rest are gated on state this probe does not create (an active task-runner run), on a Bash matcher the probe never fires, or on content narrower than a generic fixture (a secret-shaped string, a comment body, a project theme file). Widening the fixture until every guard trips would measure a worst case no real edit reaches."

[ "$no_baseline" -eq 1 ] && echo "WARN: no baseline" >&2
[ "$no_dyn_baseline" -eq 1 ] && echo "WARN: no dynamic baseline" >&2
[ "$no_act_baseline" -eq 1 ] && echo "WARN: no activated baseline" >&2

if [ "$update" -eq 1 ]; then
  # Keep an unmeasurable MCP plugin's old baseline: its written 0 would pass locally and fail CI by the whole tool surface.
  for mu in $MCP_UNMEASURABLE; do
    old_val=$(jq -r --arg p "$mu" '.[$p] // empty' "$BASELINE" 2>/dev/null)
    new_val=$(printf '%s\n' "$new_baseline" | jq -r --arg p "$mu" '.[$p] // empty')
    [ -n "$old_val" ] && [ -n "$new_val" ] && [ "$old_val" -gt "$new_val" ] 2>/dev/null || continue
    deficit=$((old_val - new_val))
    echo "WARN: --update-baseline keeping '$mu' at $old_val (measured $new_val without its MCP runtime; +$deficit not written)" >&2
    new_baseline=$(printf '%s\n' "$new_baseline" | jq --arg p "$mu" --argjson v "$old_val" '.[$p] = $v')
  done
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
