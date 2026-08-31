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

# Same walk, counting CHARACTERS instead of bytes (`wc -m`). The listing channel
# needs this and the token channels do not: a token estimate is bytes/4, but the
# listing cap is documented in CHARS and this corpus is em-dash heavy, so the two
# diverge by ~3%. Measured 2026-08-31 on taskmaster-suite: 15,016 bytes against
# 14,581 chars — 435 bytes of multi-byte punctuation, enough to report a bundle
# OVER a cap it is 419 chars UNDER. That is the whole reason this function exists.
#
# HONEST LIMITATION, and it is the important half: nobody here has verified which
# unit the HOST counts. Chars is the unit its documentation states, so chars is
# what this compares — but an install within ~3% of the cap cannot be called under
# or over with confidence on either measure, and the channel says so when it lands
# in that band rather than printing a verdict it has not earned.
# Listing entry cost: delegated to pc_listing_entry_cost in scripts/lib/plugin-checks.sh
# — the SINGLE implementation, shared with the pc_listing_declaration gate, after the
# two by-value copies were measured disagreeing by their separator models (9 chars on
# taskmaster-suite) while every bundle README told readers to reconcile one against the
# other. This wrapper returns chars-without-separators and stashes the entry count in
# The call sites read "chars entries" via `set --` and add the CLI's n-1
# separator term once per install (a $()-wrapper cannot return the count: the
# subshell drops any variable it sets).
# Unit note (inherited from the helper): LC_ALL=C bytes — a deterministic ~1% overcount
# of the chars the CLI counts, conservative for a floor warning. Agents excluded: they
# render in a separate system-prompt section (unverified whether it shares this budget).
. "$(dirname "$0")/lib/plugin-checks.sh"

# Stdout bytes a plugin's SessionStart hooks inject each session, measured by
# executing them in a throwaway sandbox (empty CLAUDE_PROJECT_DIR/HOME, minimal
# SessionStart JSON on stdin, fail-open per hook). Deterministic lower bound.
HOOK_SANDBOX=$(mktemp -d)
# File-shape fixtures for the per-tool probe live in their OWN sandbox, never in
# HOOK_SANDBOX. The always-on channel measures SessionStart stdout against an
# EMPTY project — put a src/ and a migrations/ next to it and the stack-sniffing
# SessionStart hooks find a project to describe, which moves the always-on figure
# for a reason that has nothing to do with always-on cost. First attempt did
# exactly that: +36 tokens on four bundles, pure fixture contamination.
EDIT_SANDBOX=$(mktemp -d)
mkdir -p "$EDIT_SANDBOX/src/components" "$EDIT_SANDBOX/src/styles" \
         "$EDIT_SANDBOX/tests" "$EDIT_SANDBOX/database/migrations" 2>/dev/null
# The fixture CONTENT trips the hooks on purpose. A clean file measures a hook
# that fired and found nothing, which is not what a real edit costs — the point
# of the channel is what an edit that DOES trip a guard pays. Clean fixtures
# under-report by construction: `testing` read 0 on a well-formed test and 509
# bytes on one asserting internals, and both are "the hook ran".
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
  # A real transcript file, not just a path: hooks split two ways on this field —
  # most hash it as a context key, but some OPEN it — task-runner/hooks/drift.sh
  # (:61 readability guard, :73 `tail`) and comment-discipline/hooks/verbosity.sh.
  # An unreadable path would meter the second kind on its error branch, which is
  # the same defect one level down from the one sending the field at all fixes.
  : > "$HOOK_SANDBOX/transcript-$sid.jsonl" 2>/dev/null || true
  # UserPromptSubmit is measured against a CORPUS, scored MAX, not one string.
  #
  # WHY. This used to send exactly one prompt — "refactor the auth module, add
  # tests and review the diff". api-docs-first's remind.sh gates on
  # (sdk|endpoint|integrat\w*|webhook|oauth|graphql); none of those words is in
  # that sentence, so the hook baselined at 0 while emitting 206 bytes (~52 tok)
  # on a real integration prompt. A hook whose trigger vocabulary misses the one
  # probe is unmetered forever, and its growth with it. MAX rather than SUM
  # because a user sends one prompt, not five; the corpus asks "what is the worst
  # single prompt", which is the number the budget is about.
  #
  # LIMITATION: a hook whose trigger appears in no corpus entry still reads 0,
  # and that 0 is indistinguishable from "never fires". Extend the corpus when a
  # new trigger vocabulary ships; nothing here can detect that for you.
  for prompt in \
    "refactor the auth module, add tests and review the diff" \
    "implement a webhook endpoint that integrates the Stripe SDK" \
    "the deploy pipeline is failing and the container will not start" \
    "design the schema and write the migration for the orders table" \
    "write code to call the GitHub API using their client library"; do
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
        # transcript_path IS SENT, and that is load-bearing. Every context-keyed hook
        # in this marketplace reads `.transcript_path // .session_id` (a subagent
        # shares its parent's session_id, so keying on it dedups the worker against
        # nudges it never saw). A payload carrying only session_id therefore meters
        # every one of those hooks on its FALLBACK branch — the same
        # grade-the-branch-the-host-never-takes shape `pc_harness_payload` closes for
        # test harnesses, which scans only scripts/smoke/ and plugins/*/scripts/
        # __tests__/ and so never saw this meter.
        #
        # NO BASELINE MOVED when this landed, and that is the honest result: this
        # fixes WHICH BRANCH is metered, not any number. Hooks that merely hash the
        # field emit the same bytes either way; the ones this re-branches are the two
        # the probe runs that OPEN the transcript — comment-discipline's verbosity.sh
        # and task-runner's drift.sh, both of which exited at a no-transcript guard
        # under the old payload and now read the file. Both emit 0 bytes either way,
        # which is why no number moved. (NOT hindsight/hooks/collect.sh, which two
        # earlier drafts of this comment named: it is wired to SessionEnd, and this
        # meter executes only SessionStart, UserPromptSubmit and Pre/PostToolUse — so
        # it is not metered on any branch, error or otherwise.) An earlier version
        # of this comment also cited
        # testing/hooks/test-shape.sh's 0 as the evidence — wrong cause: that hook's
        # path gate (:81-84) exits before it ever reads a context key at :95, so it
        # reads 0 on `src/example.ts` with or without this field. That is the FILE
        # SHAPE gap, named separately in the closing notes at the bottom of this file.
        : ;;
    esac
    # FILE-SHAPE CORPUS. One synthetic Edit at one path used to be the whole probe,
    # and the closing notes named the consequence: a hook gated on any other path
    # shape read 0 "regardless of what it would emit". Six of the nine per-edit
    # hooks in this marketplace scored 0 for exactly that reason, not for silence —
    # testing's matcher wants a test file, comment-discipline has a CSS branch,
    # ui-ux's palette hook wants a stylesheet, database's guard wants a migration.
    # A channel that cannot see a hook fire cannot be reduced on purpose.
    #
    # Aggregation mirrors the prompt corpus deliberately: SUM across a plugin's
    # hooks for one shape (an edit that trips two of them pays both), MAX across
    # shapes (report the worst single edit, not a fictional session that edits
    # five files at once). The figure is what ONE edit can cost.
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
# LISTING CAP. Claude Code allocates a budget for the skill listing and drops
# descriptions past it, least-invoked-first, names surviving. One source
# documents the default as ~15,000 chars; the eviction was observed live on
# 2026-08-26 (rationale/marketplace-necessity-review-2026-08-26.md:262-287),
# where ~31 marketplace descriptions arrived stripped and the stripped set was
# nondeterministic at the margin across identical reloads.
#
# THE CAP IS NOT A CONSTANT AND NOT 15,000. This channel asserted `LISTING_CAP=15000`
# from its creation until 2026-08-31, sourced from a doc paraphrase nobody checked.
# Read out of the shipped CLI (2.1.251) the rule is:
#
#     budget_chars = contextWindowTokens * bytesPerToken * skillListingBudgetFraction
#
#   * `skillListingBudgetFraction` defaults to **0.01** and is a settings.json key.
#   * `bytesPerToken` is **4** for the older tokenizer set (through opus-4-6 /
#     sonnet-4-6 / haiku-4-5) and **3** for everything newer, opus-5 included.
#   * A SECOND, independent cap applies per skill: `skillListingMaxDescChars`,
#     default **1536**. Longer descriptions are truncated individually, always,
#     budget or not. This repo's own description linter caps at 500, so it never binds.
#
# So the real budget spans a 6.7x range depending on where you run:
#
#     opus-5    @200k = 6,000 chars     opus-5    @1M = 30,000 chars
#     opus-4-6  @200k = 8,000 chars     opus-4-6  @1M = 40,000 chars
#
# AND THE UNIT IS NOT DESCRIPTION TEXT. The CLI costs each entry as
# `name + 4 + min(desc, 1536)`, joined by one separator each — so the artifact NAME
# and a 4-char delimiter are charged per artifact. Artifact COUNT is in the measure
# directly, which is the mechanical reason "fewer artifacts" beats "shorter
# descriptions" and not merely an empirical one.
#
# Over budget, the CLI does not drop the tail: it reduces every non-protected entry
# to name-only, then buys descriptions back in PRIORITY order until the budget is
# spent (bundled-prompt skills are protected outright). So the survivors are the
# high-priority ones, and "least-invoked first" is the right intuition.
#
# WHAT THIS CHANNEL REPORTS: the worst realistic case, opus-5 at 200k = 6,000 chars,
# overridable with LISTING_CTX_TOKENS / LISTING_BYTES_PER_TOKEN / LISTING_FRACTION.
# A 1M-context session gets 5x that, so an install flagged here may be entirely fine
# where you personally run it — the row prints both. Report-only, never fails a build.
LISTING_CTX_TOKENS=${LISTING_CTX_TOKENS:-200000}
LISTING_BYTES_PER_TOKEN=${LISTING_BYTES_PER_TOKEN:-3}
# LISTING_FRACTION takes the same unit as the CLI's skillListingBudgetFraction
# (0.01, 0.02, ...) — the unit every bundle README teaches. awk, not $(( )): the
# first version read an undocumented integer-percent variable and crashed on
# exactly the values the READMEs recommend.
LISTING_FRACTION=${LISTING_FRACTION:-0.01}
LISTING_CAP=$(awk -v t="$LISTING_CTX_TOKENS" -v b="$LISTING_BYTES_PER_TOKEN" -v f="$LISTING_FRACTION" 'BEGIN{printf "%d", t*b*f}')
LISTING_CAP_1M=$(awk -v b="$LISTING_BYTES_PER_TOKEN" -v f="$LISTING_FRACTION" 'BEGIN{printf "%d", 1000000*b*f}')
case "$LISTING_CAP" in ''|*[!0-9]*|0) LISTING_CAP=6000; LISTING_CAP_1M=30000 ;; esac
LISTING_MAX_DESC=1536
listing_rows=""
leaf_tokens_total=0
leaf_dyn_total=0
leaf_act_total=0

for pj in plugins/*/.claude-plugin/plugin.json; do
  [ -f "$pj" ] || continue
  bname=$(jq -r '.name' "$pj" 2>/dev/null)
  [ -n "$bname" ] || continue

  if jq -e 'has("dependencies")' "$pj" >/dev/null 2>&1; then
    # Bundle: sum member plugins' always-on and dynamic bytes, PLUS the bundle's
    # own surface. That last clause was missing and it is not a rounding error: a
    # bundle ships its own `commands/uninstall.md`, whose description loads like
    # any other command's. Ten bundles × ~69 tok were metered in no channel at
    # all — 0.6% of `everything`, but 25% of product-suite, 16% of db-suite,
    # 12% of php-suite. The script's own closing notes name three unmetered
    # surfaces by name; this one was not among them, so the residual was not
    # stated anywhere either.
    total_bytes=$(plugin_desc_bytes "plugins/$bname")
    dyn_bytes=0
    act_bytes=$(plugin_desc_bytes "plugins/$bname")
    set -- $(pc_listing_entry_cost "plugins/$bname")
    listing_chars=$1; listing_n=$2
    while IFS= read -r member; do
      [ -n "$member" ] || continue
      mdir="plugins/$member"
      [ -d "$mdir" ] || continue
      bytes=$(( $(plugin_desc_bytes "$mdir") + $(plugin_sessionstart_bytes "$mdir") + $(plugin_mcp_bytes "$mdir") ))
      total_bytes=$((total_bytes + bytes))
      dyn_bytes=$((dyn_bytes + $(plugin_dynamic_hook_bytes "$mdir") ))
      act_bytes=$((act_bytes + $(plugin_desc_bytes "$mdir") + $(plugin_sessionstart_activated_bytes "$mdir") + $(plugin_mcp_bytes "$mdir") ))
      set -- $(pc_listing_entry_cost "$mdir")
      listing_chars=$((listing_chars + $1)); listing_n=$((listing_n + $2))
    done < <(jq -r '.dependencies[]?' "$pj" 2>/dev/null)
    is_leaf=0
    members=$(jq -r '.dependencies | length' "$pj" 2>/dev/null || echo 1)
  else
    # Leaf: measure the plugin's own dir.
    pdir="${pj%/.claude-plugin/plugin.json}"
    total_bytes=$(( $(plugin_desc_bytes "$pdir") + $(plugin_sessionstart_bytes "$pdir") + $(plugin_mcp_bytes "$pdir") ))
    dyn_bytes=$(plugin_dynamic_hook_bytes "$pdir")
    act_bytes=$(( $(plugin_desc_bytes "$pdir") + $(plugin_sessionstart_activated_bytes "$pdir") + $(plugin_mcp_bytes "$pdir") ))
    set -- $(pc_listing_entry_cost "$pdir")
    listing_chars=$1; listing_n=$2
    is_leaf=1
    members=1
  fi
  tokens=$(( (total_bytes + 2) / 4 ))
  dyn_tokens=$(( (dyn_bytes + 2) / 4 ))
  act_tokens=$(( (act_bytes + 2) / 4 ))
  # LISTING CHANNEL (report-only). Descriptions ONLY — deliberately not the
  # always-on sum. The host's skill listing is built from description text; a
  # SessionStart hook's stdout and an MCP tools/list are injected by other
  # means and survive the listing budget, which is the whole distinction this
  # channel exists to draw. Hooks are eviction-proof; descriptions are not.
  # NEAR band: within 3% of the cap EITHER WAY — [97%, 103%]. The unit the host
  # counts is unverified (this measures LC_ALL=C bytes, a ~1% overcount of chars),
  # so inside that band neither "under" nor "over" is a claim this channel has
  # earned. The first version checked `-gt cap` before the band, so 100-103%
  # printed a confident OVER — the exact unearned verdict the band was added to
  # avoid. The order below is the fix: band first, OVER only past 103%.
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

# Emit the listing channel. Report-only by construction: no `fail=1`, no ceiling
# comparison that can red a build. It answers a question the token table cannot —
# not "what does the catalogue weigh" but "what will the host actually load".
#
# AN `OVER` STATUS IS A REACHABILITY WARNING AND NEVER A COST WARNING, and the
# channel now says so on every run because the number looks exactly like a bill.
# The host DROPS description text past the cap, so that text is never sent and
# never charged: an over-cap install pays the same description cost as any install
# sitting at the cap. Trimming descriptions above the cap therefore saves ~nothing
# (measured twice: 2.8% catalogue-wide at distillation-2026-08-23.md:206-214, 1.8%
# for taskmaster-suite specifically). What overflow costs is DISPATCH — the dropped
# descriptions arrive name-only and the surviving set is nondeterministic across
# reloads (observed live, marketplace-necessity-review-2026-08-26.md:262-287). That
# is the reasoning that retired the `everything` bundle on 2026-08-31, and it is a
# membership argument, not a token one: the only route under the cap is fewer
# artifacts. Full derivation: rationale/2026-08-31-token-cost-review.md.
echo
echo "listing channel (CLI entry cost: name + 4 + min(desc,${LISTING_MAX_DESC}), skills + commands)"
echo "  budget = ctxTokens x bytesPerToken x fraction; showing ${LISTING_CTX_TOKENS} tok x ${LISTING_BYTES_PER_TOKEN} x ${LISTING_FRACTION} = ${LISTING_CAP} chars (a 1M-context session gets ${LISTING_CAP_1M})"
if [ -n "$listing_rows" ]; then
  printf '%-24s %9s  %s\n' "install" "chars" "status"
  printf '%s' "$listing_rows"
  echo "  every install not listed above is under the cap and loses nothing to eviction"
  echo "  OVER = a REACHABILITY warning, never a cost one: over budget the CLI reduces entries"
  echo "  to name-only and buys descriptions back in PRIORITY order, so the text is never sent"
  echo "  and never charged. Artifact NAME + 4 chars is charged per artifact, which is why the"
  echo "  fix is fewer artifacts and not shorter descriptions."
  echo "  Both numbers are real: the same install can be OVER at 200k and comfortably under at 1M."
  echo "  Levers, in settings.json: skillListingBudgetFraction (default 0.01), skillListingMaxDescChars (1536)."
else
  echo "  no install exceeds the cap"
fi

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
# THAT SNAPSHOT'S POPULATION IS STALE AND THE RATIO INHERITS IT. The 61 leaves it
# sums were measured before `cfef9c1`, and include nine plugins since deleted
# (i18n, livewire, mysql, node-backend, nuxt, php, postgresql, react, vue3) and
# none of the bundles. Today's tree is 52 leaves. Re-measuring needs an install,
# because `details` resolves by installed name — so 1.54 is carried forward as a
# HISTORICAL figure, not a current one. Treat it as an order-of-magnitude
# correction, never as a coefficient to multiply today's numbers by. (This
# paragraph lived in CLAUDE.md until 2026-08-31 and was deleted there on the
# premise that this header carried it. It did not. Verifying that claim per fact,
# rather than per file, is the only reason it is here.)
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
echo "note: the listing cap is a FORMULA read out of CLI 2.1.251 (ctxTokens x bytesPerToken x skillListingBudgetFraction, default fraction 0.01, configurable in settings.json) — derivation in this script's LISTING_* header; the channel is report-only and never fails the build"
echo "note: the listing channel costs entries the way the CLI does (name + 4 + capped desc, skills + commands). SessionStart stdout and MCP tools/list are always-on but not part of this listing, so they are eviction-proof and excluded. AGENTS are excluded too, and that one is UNVERIFIED rather than known: they render in a separate system-prompt listing and whether it draws on the same budget was not established"
echo "note: the activated channel turns on what THIS fixture knows (terse level, brain/INDEX.md, manifests); a hook waiting for other state still reads its OFF value"
# EVENT AND TOOL SHAPE. The dynamic channel executes UserPromptSubmit and
# Pre/PostToolUse-as-Edit, and nothing else. Two whole categories therefore read
# 0, and a 0 here is indistinguishable from "emits nothing" — the same failure
# the corpus comment above names for prompt vocabulary, one level up:
#   - Stop hooks. Three plugins ship one (candor, code-architecture, task-runner)
#     and their block reasons are model-visible text, measured at roughly
#     211 / 127 / 742 tokens upper bound across branches. Never executed here.
#   - PreToolUse matched on Bash. command-guard's deny reason is ~175 tokens per
#     denied call and its dynamic baseline reads 0.
# Naming it is the honest floor; metering it means teaching this loop the other
# event and tool shapes, which is a real change and not one this note makes.
echo "note: Stop hooks and Bash-matched PreToolUse are never executed by the dynamic probe (candor, code-architecture, task-runner, command-guard read 0 for that reason, not because they are silent)"
# FILE SHAPE. The synthetic Edit targets src/example.ts, so a hook gated on a
# path pattern it does not match scores 0 for a reason that has nothing to do
# with its size — testing/hooks/test-shape.sh emits ~146 tokens on a real test
# file and baselines 0 here.
echo "note: the per-tool probe now drives five file shapes (source, component, test, stylesheet, migration) with content chosen to trip the guards; MAX across shapes, SUM across a plugin's hooks for one shape"
echo "note: a per-edit hook still reading 0 is NOT necessarily silent, and the cause is no longer path shape. Measured 2026-08-31: of six plugins reading 0, the file-shape corpus moved ONE (testing, 0 -> 127). The rest are gated on state this probe does not create (an active task-runner run), on a Bash matcher the probe never fires, or on content narrower than a generic fixture (a secret-shaped string, a comment body, a project theme file). Widening the fixture until every guard trips would measure a worst case no real edit reaches."

[ "$no_baseline" -eq 1 ] && echo "WARN: no baseline" >&2
[ "$no_dyn_baseline" -eq 1 ] && echo "WARN: no dynamic baseline" >&2
[ "$no_act_baseline" -eq 1 ] && echo "WARN: no activated baseline" >&2

if [ "$update" -eq 1 ]; then
  # Updating IS the remedy — suppress the FAIL/remedy lines on this path.
  # But an unmeasurable MCP plugin must not have its zero WRITTEN: the delta
  # check above exempts it, so a baseline zeroed here passes locally and then
  # fails CI by the full tool-surface amount (+475 on registry-source,
  # 2026-08-26, written by an --update-baseline run on a node-less machine).
  # Preserve the old value for the plugin and add the deficit back into every
  # bundle that sums it, in both the always-on and activated channels.
  for mu in $MCP_UNMEASURABLE; do
    old_val=$(jq -r --arg p "$mu" '.[$p] // empty' "$BASELINE" 2>/dev/null)
    new_val=$(printf '%s\n' "$new_baseline" | jq -r --arg p "$mu" '.[$p] // empty')
    [ -n "$old_val" ] && [ -n "$new_val" ] && [ "$old_val" -gt "$new_val" ] 2>/dev/null || continue
    deficit=$((old_val - new_val))
    echo "WARN: --update-baseline keeping '$mu' at $old_val (measured $new_val without its MCP runtime; +$deficit restored to containing bundles)" >&2
    new_baseline=$(printf '%s\n' "$new_baseline" | jq --arg p "$mu" --argjson v "$old_val" '.[$p] = $v')
    for bj in plugins/*/.claude-plugin/plugin.json; do
      jq -e --arg p "$mu" '(.dependencies // []) | index($p)' "$bj" >/dev/null 2>&1 || continue
      bnm=$(basename "$(dirname "$(dirname "$bj")")")
      new_baseline=$(printf '%s\n' "$new_baseline" | jq --arg b "$bnm" --argjson d "$deficit" \
        'if has($b) then .[$b] += $d else . end')
      new_act_baseline=$(printf '%s\n' "$new_act_baseline" | jq --arg b "$bnm" --argjson d "$deficit" \
        'if has($b) then .[$b] += $d else . end')
    done
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
