#!/usr/bin/env bash
# scripts/generate.sh — deterministic chassis stamper.
#
# Discovers every plugins/*/.chassis.json (each holds ONE chassis object or an ARRAY
# of them) and renders it through templates/ via the card-01 template engine
# (scripts/lib/template-engine.sh, overridable with TEMPLATE_ENGINE). Var derivation:
# booleans lang/concern come from the manifest `variant` string, applyExtraBlock from
# the `applyExtra` array, worker-agent vars are the six frontmatter fields verbatim
# plus an optional `floor` frontmatter slot, an optional `preloadSkills` slot (renders a
# `skills: [...]` frontmatter line — Claude Code preloads those bodies at spawn; set only
# where the cost per spawn is earned, see ui-ux's .chassis.json), and three optional
# domain-content slots —
# operatingProcedure, domainChecklist, deferRule (each a markdown string or an array of
# lines, joined with "\n"; absent fields default to "" so the template's {{#if}} guards
# render nothing — so a chassis agent that pins a non-`inherit` model can emit its own
# `floor: none`/floor row exemption, and existing agents re-render byte-identical).
#
# RETIRED 2026-09-22: the `stack-review` kind and templates/review-command.md.tmpl.
# It rendered ONE file in the whole marketplace (code-review/commands/comment-review.md)
# behind a 24-line template, four partials and nine opt-out justifications — more prose
# in the machinery than in the artifact (panel finding #64,
# rationale/specialist-panel-2026-09-22.md). That output is inlined and hand-maintained
# now; the `optout` kind stays, as the plain note it always was. The build-time worker
# routing through task-execution/references/routing.md went with it — nothing else read
# that map from here.
#
#   --write : byte-compare rendered vs tree; on a delta write the file (chmod +x for
#             .sh) and patch-bump that plugin's plugin.json ONCE per run. Idempotent.
#   --check : render to a temp file, byte-diff vs tree (incl. the mode bit on hooks),
#             print the opt-out + worker-override report, exit non-zero on any drift.
#             NEVER writes.
#
# hooks.json is never generated. Roots are overridable for fixtures via CHASSIS_ROOT
# (plugins tree to scan/stamp) and CHASSIS_TEMPLATES (templates dir).
# Spec: taskmaster-docs/specs/2026-07-13-fable-review-engine.md §generate.sh contract, D6, D7.
set -uo pipefail

MODE=""
case "${1:-}" in
  --write) MODE=write ;;
  --check) MODE=check ;;
  *) printf 'usage: %s --write|--check\n' "${0##*/}" >&2; exit 2 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${CHASSIS_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
TEMPLATES="${CHASSIS_TEMPLATES:-$(cd "$SCRIPT_DIR/../templates" 2>/dev/null && pwd || printf '%s' "$SCRIPT_DIR/../templates")}"
ENGINE="${TEMPLATE_ENGINE:-$SCRIPT_DIR/lib/template-engine.sh}"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

die() { printf 'generate.sh: %s\n' "$1" >&2; exit 1; }

# The README steps below cost the skill listing and quote the host's constants. Both
# come from the SINGLE implementations — pc_listing_entry_cost (shared with
# context-budget.sh's listing channel and the pc_listing_declaration gate) and
# scripts/host-constants.sh (re-read out of the pinned CLI by its own --check).
# Sourcing is read-only; nothing here runs context-budget.sh.
. "$SCRIPT_DIR/lib/plugin-checks.sh" || die "cannot source scripts/lib/plugin-checks.sh"

# --- template engine (loaded lazily; only rendering needs it) ---------------------
ENGINE_LOADED=0
ensure_engine() {
  [ "$ENGINE_LOADED" = 1 ] && return 0
  [ -f "$ENGINE" ] || die "template engine not found: $ENGINE (card 01 deliverable; set TEMPLATE_ENGINE to override)"
  # shellcheck source=/dev/null
  source "$ENGINE" || die "failed to source template engine: $ENGINE"
  command -v render_template >/dev/null 2>&1 || die "engine $ENGINE did not define render_template"
  ENGINE_LOADED=1
}

# --- reports + change tracking ----------------------------------------------------
CHANGED_PLUGINS=""
DRIFT=0
OPTOUT_REPORT=""
mark_changed() { case " $CHANGED_PLUGINS " in *" $1 "*) : ;; *) CHANGED_PLUGINS="$CHANGED_PLUGINS $1" ;; esac; }

emit() { # rendered-file target-path is_exec(0|1) plugin-dir
  local rendered="$1" target="$2" isexec="$3" pdir="$4" rel="${2#$ROOT/}"
  # Preserve blocks: transplant the tree's version of each
  # <!-- preserve:NAME --> body into the render before ANY comparison, so a
  # sanctioned local divergence is not drift in --check and is not clobbered by
  # --write. Everything outside those markers still refreshes from the template.
  # Both modes go through here, so they cannot disagree about what "the render"
  # is. No-op for the files that carry no markers, which today is all of them.
  if grep -q '^<!--[[:space:]]*preserve:' "$rendered" 2>/dev/null; then
    ensure_engine
    local merged="$WORK/merged.$$"
    if merge_preserve_blocks "$rendered" "$target" > "$merged" 2>/dev/null; then
      rendered="$merged"
    fi
  fi
  if [ "$MODE" = check ]; then
    if [ ! -f "$target" ] || ! cmp -s "$rendered" "$target"; then
      printf 'DRIFT content: %s\n' "$rel" >&2; DRIFT=1
    elif [ "$isexec" = 1 ] && [ ! -x "$target" ]; then
      printf 'DRIFT mode: %s not executable\n' "$rel" >&2; DRIFT=1
    fi
    return 0
  fi
  if [ ! -f "$target" ] || ! cmp -s "$rendered" "$target"; then
    mkdir -p "$(dirname "$target")"
    cp "$rendered" "$target"
    [ "$isexec" = 1 ] && chmod +x "$target"
    mark_changed "$pdir"
    printf 'wrote %s\n' "$rel"
  elif [ "$isexec" = 1 ] && [ ! -x "$target" ]; then
    chmod +x "$target"; mark_changed "$pdir"; printf 'chmod +x %s\n' "$rel"
  fi
}

bump_plugin() { # plugin-dir : patch-bump plugin.json once
  local pj="$1/.claude-plugin/plugin.json" v newv tmp
  [ -f "$pj" ] || { printf 'note: no plugin.json to bump for %s\n' "${1#$ROOT/}" >&2; return 0; }
  v="$(jq -r '.version // "0.0.0"' "$pj")"
  printf '%s' "$v" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$' || die "cannot bump non-semver version '$v' in $pj"
  newv="$(printf '%s' "$v" | awk -F. '{printf "%s.%s.%d",$1,$2,$3+1}')"
  tmp="$(mktemp)"
  jq --arg v "$newv" '.version=$v' "$pj" > "$tmp" && mv "$tmp" "$pj"
  printf 'bumped %s: %s -> %s\n' "${pj#$ROOT/}" "$v" "$newv"
}

# --- lane rows: the generated block in <plugin>/lane.tsv ---------------------------
# Every chassis object that renders an ARTIFACT (review command, suite uninstall,
# reminder hook, boost hook, worker agent) also declares its lane in a `lane` key —
#   {"owns": "<territory>", "trigger": "<definite trigger>", "yieldsTo": "a:b,c:d" | "-",
#    "phase": "<optional override>"}
# — and generate.sh renders one six-field lane.tsv row per artifact into a block
# between `# generated:start` and `# generated:end`. --check byte-diffs that block
# like any other generated file; --write rewrites it and patch-bumps the plugin.
#
# WHY. Until 2026-09-03 the rows for generated artifacts were typed by hand
# (every generated worker agent, chassis command and reminder hook — recount with
# `grep -l 'generated from templates' plugins/*/agents/*.md plugins/*/commands/*.md
# plugins/*/hooks/*.sh`), so one property was split across a generator and a
# hand-edited file — exactly the drift the chassis exists to prevent
# (collective-taskforce-backlog #8). A missing `lane` key is a hard error in both
# modes: every manifest has carried one since the 2026-09-03 sweep.
# Phase: commands default (review command → review, suite uninstall → ship);
# hooks and agents MUST declare `lane.phase` explicitly — a hook's phase is what
# pc_phase_guard reads (`any` exempts it from the sentinel), and the shipped rows
# disagree with any default (api-design:remind build, taskmaster:remind shape,
# testing:test-engineer verify), so a default there would silently disarm a gate.
# owns/trigger/yieldsTo carry the SAME values the hand rows carried, lifted verbatim.
# A hand row for an artifact the block now owns is a hard error: two rows for one
# artifact only trip pc_lanes_schema when their `owns` match verbatim.
# RESIDUAL (named): a deleted `lane` KEY strips its block on the next run, but a
# deleted MANIFEST is never visited, so its plugin's generated block would rot with
# --check silent. Delete the block by hand with the manifest; nothing checks it.
LANE_ROWS=""
LANE_HEADER='# lane declaration — who owns which territory, at which phase, and who outranks them.
# artifact	kind	phase	owns	definite_trigger	yields_to
# kind: command|hook|agent|skill · phase: understand|shape|decide|plan|build|verify|review|ship|any
# yields_to: comma-list of artifacts that outrank this one on THEIR territory, or -
# Contract and gates: scripts/lib/plugin-checks.sh (pc_lanes_*).'
LANE_START='# generated:start — rows rendered by scripts/generate.sh from .chassis.json `lane` keys; edit the manifest, not these rows'
LANE_END='# generated:end'

lane_row() { # obj plugin-dir artifact kind default-phase
  local obj="$1" pdir="$2" art="$3" kind="$4" dphase="$5" rel="${2#$ROOT/}" owns trig yt phase
  # Every manifest carries a lane key since the 2026-09-03 sweep; a new chassis
  # object without one is a hard error — the generator owns the artifact, so it
  # owns the row, and pc_lanes_coverage would fail the build on a row nobody writes.
  printf '%s' "$obj" | jq -e '(.lane // null) | type == "object"' >/dev/null 2>&1 \
    || die "$rel/.chassis.json: object for $art has no \"lane\" key — {\"owns\",\"trigger\",\"yieldsTo\"[,\"phase\"]}; generated artifacts declare their lane in the manifest, never by hand in lane.tsv"
  [ -n "$art" ] || die "$rel/.chassis.json: a $kind object has a lane but no artifact name (reminder hooks need \"artifact\")"
  owns="$(printf '%s' "$obj" | jq -r '.lane.owns // empty')"
  trig="$(printf '%s' "$obj" | jq -r '.lane.trigger // empty')"
  yt="$(printf '%s' "$obj" | jq -r 'if (.lane.yieldsTo // "") == "" then "-" else .lane.yieldsTo end')"
  phase="$(printf '%s' "$obj" | jq -r --arg d "$dphase" '.lane.phase // $d')"
  [ -n "$owns" ] && [ -n "$trig" ] || die "$rel/.chassis.json: lane for $art needs non-empty owns and trigger"
  [ -n "$phase" ] || die "$rel/.chassis.json: lane for $art ($kind) must declare \"phase\" explicitly — hooks and agents have no default (pc_phase_guard reads it; 'any' exempts a hook from the sentinel)"
  local tab=$'\t' nl=$'\n'   # $(printf '\n') would strip its own newline into an empty, match-everything pattern
  case "$art$owns$trig$yt$phase" in *"$tab"*|*"$nl"*) die "$rel/.chassis.json: lane for $art contains a tab or newline" ;; esac
  LANE_ROWS="${LANE_ROWS}$(printf '%s\t%s\t%s\t%s\t%s\t%s' "$art" "$kind" "$phase" "$owns" "$trig" "$yt")
"
}

write_lane_block() { # plugin-dir — called once per manifest after its objects rendered
  local pdir="$1" lf="$1/lane.tsv" out="$WORK/lane.out" blk="$WORK/lane.blk" s e art dup
  if [ -z "$LANE_ROWS" ]; then
    # No generated rows for this plugin. A block left behind by a deleted lane key
    # is stripped rather than left to rot — --check reports it as drift, --write removes it.
    if [ -f "$lf" ] && grep -q '^# generated:start' "$lf"; then
      s="$(grep -n '^# generated:start' "$lf" | head -1 | cut -d: -f1)"
      e="$(grep -n '^# generated:end' "$lf" | head -1 | cut -d: -f1)"
      [ -n "$e" ] && [ "$e" -gt "$s" ] || die "${lf#$ROOT/}: '# generated:start' without a matching '# generated:end'"
      { head -n "$((s-1))" "$lf"; tail -n "+$((e+1))" "$lf"; } > "$out"
      emit "$out" "$lf" 0 "$pdir"
    fi
    return 0
  fi
  { printf '%s\n' "$LANE_START"; printf '%s' "$LANE_ROWS"; printf '%s\n' "$LANE_END"; } > "$blk"
  # A hand row for an artifact the block owns is the split-property drift this block
  # exists to end — and pc_lanes_schema only sees it when `owns` matches verbatim.
  if [ -f "$lf" ]; then
    for art in $(cut -f1 "$blk" | grep -v '^#'); do
      dup="$(awk -v a="$art" -F'\t' '/^# generated:start/{g=1} /^# generated:end/{g=0} !g && !/^#/ && $1==a {print FNR}' "$lf")"
      [ -z "$dup" ] || die "${lf#$ROOT/}:$dup: hand-written row for $art, which is now generated from .chassis.json — delete the hand row"
    done
  fi
  if [ -f "$lf" ] && grep -q '^# generated:start' "$lf"; then
    s="$(grep -n '^# generated:start' "$lf" | head -1 | cut -d: -f1)"
    e="$(grep -n '^# generated:end' "$lf" | head -1 | cut -d: -f1)"
    [ -n "$e" ] && [ "$e" -gt "$s" ] || die "${lf#$ROOT/}: '# generated:start' without a matching '# generated:end'"
    { head -n "$((s-1))" "$lf"; cat "$blk"; tail -n "+$((e+1))" "$lf"; } > "$out"
  elif [ -f "$lf" ]; then
    { cat "$lf"; [ -n "$(tail -c1 "$lf")" ] && echo; cat "$blk"; } > "$out"
  else
    { printf '%s\n' "$LANE_HEADER"; cat "$blk"; } > "$out"
  fi
  emit "$out" "$lf" 0 "$pdir"
  LANE_ROWS=""
}

# --- per-chassis renderers --------------------------------------------------------
render_suite_uninstall() { # obj plugin-dir
  local obj="$1" pdir="$2" dfile="$WORK/m.json" rfile="$WORK/r.out"
  printf '%s' "$obj" > "$dfile"; ensure_engine
  render_template "$TEMPLATES/suite-uninstall.md.tmpl" "$dfile" > "$rfile" || die "render failed: ${2#$ROOT/} uninstall.md"
  emit "$rfile" "$pdir/commands/uninstall.md" 0 "$pdir"
  lane_row "$obj" "$pdir" "$(basename "$pdir"):uninstall" command ship
}

render_reminder_hook() { # obj plugin-dir
  local obj="$1" pdir="$2" dfile="$WORK/m.json" rfile="$WORK/r.out"
  # budgetShared/budgetExempt are GONE. They were derived complements standing in
  # for a two-branch template: one branch ran a first-come mkdir lottery, the other
  # was a privileged directive exempt from it. Both are replaced by a single ranked
  # path — a hook declares `arcRank` and yields to any better rank sharing its phase,
  # so no plugin is privileged and the protocol still works when the old exempt
  # plugin is not installed (approaches alone ships two reminder hooks and no taskmaster).
  # armsClarifyGate replaces budgetExempt's SIDE EFFECT only: dropping the
  # cross-plugin cc-workprompt marker. Defaults keep a bare manifest renderable.
  # `file` (optional, default hooks/remind.sh) names the target the way boost-hook's
  # does: a plugin carrying TWO reminder hooks with different phases renders each
  # to its own file (approaches: remind.sh for build-vs-buy at `decide`,
  # consult-remind.sh for the irreversible-command guard at `any`, since fresh-take
  # merged in on 2026-09-14). hooks.json must list both by hand.
  local file
  file="$(printf '%s' "$obj" | jq -r '.file // "hooks/remind.sh"')"
  printf '%s' "$obj" | jq \
    '{arcRank: 50, armsClarifyGate: false} + .' > "$dfile"
  ensure_engine
  render_template "$TEMPLATES/reminder-hook.sh.tmpl" "$dfile" > "$rfile" || die "render failed: ${2#$ROOT/} $file"
  emit "$rfile" "$pdir/$file" 1 "$pdir"
  lane_row "$obj" "$pdir" "$(printf '%s' "$obj" | jq -r '.artifact // empty')" hook ""
}

render_boost_hook() { # obj plugin-dir
  # Boost injectors (taskmaster ultra.sh, task-runner ultra-assess.sh, craft-layer
  # ultra-craft.sh) shared one hand-copied 35-line skeleton — off switch, fence
  # scrub, 200-char head, negation guard, enumerated self-echo guard — and differed
  # only in env var, token regex and directive text. The self-echo guard had been
  # fixed in three files once already (hook-guard-tests.sh pins the regression), so
  # the skeleton is one template now and the manifest carries the data. `file`
  # names the target (hooks/<name>.sh — the three shipped names differ); `regex2`/
  # `message2` render an elif branch when non-empty (taskmaster's ultra-goal) and
  # nothing otherwise. The directive goes out through a quoted heredoc, so the
  # manifest text is the wire text — no bash escaping in the manifest.
  local obj="$1" pdir="$2" dfile="$WORK/m.json" rfile="$WORK/r.out" file
  file="$(printf '%s' "$obj" | jq -r '.file // empty')"
  [ -n "$file" ] || die "${2#$ROOT/}/.chassis.json: boost-hook object needs \"file\" (hooks/<name>.sh)"
  printf '%s' "$obj" | jq '{intro: "", regex2: "", message2: ""} + .' > "$dfile"
  ensure_engine
  render_template "$TEMPLATES/boost-hook.sh.tmpl" "$dfile" > "$rfile" || die "render failed: ${2#$ROOT/} $file"
  emit "$rfile" "$pdir/$file" 1 "$pdir"
  lane_row "$obj" "$pdir" "$(printf '%s' "$obj" | jq -r '.artifact // empty')" hook ""
}

render_worker_agent() { # obj plugin-dir
  local obj="$1" pdir="$2" agentFile dfile="$WORK/m.json" rfile="$WORK/r.out"
  agentFile="$(printf '%s' "$obj" | jq -r '.agentFile')"
  [ -n "$agentFile" ] && [ "$agentFile" != null ] || die "worker-agent in ${2#$ROOT/} missing agentFile"
  # Optional slots (operatingProcedure, domainChecklist, deferRule, floor): each may be
  # a markdown string or an array of lines (joined with "\n"); absent -> "" so the
  # template's {{#if}} guards render nothing and existing agents (which carry none of
  # these fields) re-render byte-identical. `floor` is a scalar frontmatter value
  # ("none" for a breadth/mechanical exemption) — same absent->"" defaulting.
  printf '%s' "$obj" | jq \
    'reduce (["operatingProcedure","domainChecklist","deferRule","floor"][]) as $k
       (.;
        (.[$k] // null) as $orig
        | . + {($k): (if $orig == null then ""
                      elif ($orig | type) == "array" then ($orig | join("\n"))
                      else $orig end)})' > "$dfile"
  ensure_engine
  render_template "$TEMPLATES/worker-agent.md.tmpl" "$dfile" > "$rfile" || die "render failed: ${2#$ROOT/} $agentFile"
  emit "$rfile" "$pdir/$agentFile" 0 "$pdir"
  lane_row "$obj" "$pdir" "$(basename "$pdir"):$(basename "$agentFile" .md)" agent ""
}

render_chassis() { # obj plugin-dir
  local obj="$1" pdir="$2" rel="${2#$ROOT/}" chassis reason
  chassis="$(printf '%s' "$obj" | jq -r '.chassis // ""')"
  case "$chassis" in
    optout)
      reason="$(printf '%s' "$obj" | jq -r '.reason // "(no justification)"')"
      OPTOUT_REPORT="$OPTOUT_REPORT
  $rel: $reason" ;;
    suite-uninstall) render_suite_uninstall "$obj" "$pdir" ;;
    reminder-hook)   render_reminder_hook   "$obj" "$pdir" ;;
    boost-hook)      render_boost_hook      "$obj" "$pdir" ;;
    worker-agent)    render_worker_agent    "$obj" "$pdir" ;;
    "") die "$rel/.chassis.json has no \"chassis\" field" ;;
    *) die "unknown chassis type '$chassis' in $rel/.chassis.json" ;;
  esac
}

# --- repo-level catalog step (not a per-plugin chassis) ---------------------------
# Renders plugins/stack-scan/skills/plugin-scout/references/catalog.md (the scout
# lived in its own plugin until 2026-09-14): one deterministic row per marketplace
# plugin — `name — [keywords] — description`. Description comes from
# marketplace.json, keywords from each plugin.json. Always regenerated on --write
# (byte-compared, written on delta); byte-diffed on --check via the shared DRIFT
# flag. Does NOT bump stack-scan — the catalog rides the plugin's own change
# set, so version ownership stays with its manifest/skill edits.
render_catalog() {
  local mp="$ROOT/.claude-plugin/marketplace.json"
  local target="$ROOT/plugins/stack-scan/skills/plugin-scout/references/catalog.md"
  local rel="${target#$ROOT/}" out="$WORK/catalog.md"
  [ -f "$mp" ] || die "catalog step: marketplace.json not found: $mp"
  {
    printf '%s\n' '<!-- generated by scripts/generate.sh (catalog step) from .claude-plugin/marketplace.json descriptions + plugins/*/.claude-plugin/plugin.json keywords — do not edit this file -->'
    printf '\n# Marketplace plugin catalog\n\n'
    printf '%s\n\n' 'One row per marketplace plugin: `name — [keywords] — description`. Regenerated by scripts/generate.sh; consumed by the plugin-scout skill of stack-scan.'
    jq -r '.plugins[] | [.name, .description] | @tsv' "$mp" | LC_ALL=C sort \
    | while IFS=$'\t' read -r name desc; do
        pj="$ROOT/plugins/$name/.claude-plugin/plugin.json"; kws=""
        [ -f "$pj" ] && kws=$(jq -r '(.keywords // []) | join(", ")' "$pj")
        printf '%s — [%s] — %s\n' "$name" "$kws" "$desc"
      done
  } > "$out"
  if [ "$MODE" = check ]; then
    if [ ! -f "$target" ] || ! cmp -s "$out" "$target"; then
      printf 'DRIFT content: %s\n' "$rel" >&2; DRIFT=1
    fi
    return 0
  fi
  if [ ! -f "$target" ] || ! cmp -s "$out" "$target"; then
    mkdir -p "$(dirname "$target")"
    cp "$out" "$target"
    printf 'wrote %s\n' "$rel"
  fi
}

# --- repo-level README block applier ----------------------------------------------
# Three README regions are generated now, not one, so the substitute-and-diff that was
# inlined in the bundle-table step is a helper. Each block owns a marker pair and
# rewrites only its own region; applying them in sequence against the file on disk is
# safe because the regions do not overlap and --check never writes.
#
# A fixture root (CHASSIS_ROOT pointed at a smoke harness tree) has no root README —
# every caller returns early rather than dying, or each harness that overrides
# CHASSIS_ROOT would read this step's abort as chassis drift.
readme_apply() { # start-marker end-marker block-file
  local start="$1" end="$2" block="$3"
  local target="$ROOT/README.md" out="$WORK/README.out" rel="README.md"
  [ -f "$target" ] || return 0
  grep -qF "$start" "$target" || die "README.md is missing the $start marker"
  grep -qF "$end"   "$target" || die "README.md is missing the $end marker"
  awk -v blockfile="$block" -v s="$start" -v e="$end" '
    index($0, s) == 1 { while ((getline l < blockfile) > 0) print l; close(blockfile); skip=1; next }
    index($0, e) == 1 { skip=0; next }
    !skip { print }
  ' "$target" > "$out"
  if [ "$MODE" = check ]; then
    if ! cmp -s "$out" "$target"; then printf 'DRIFT content: %s (%s block)\n' "$rel" "$start" >&2; DRIFT=1; fi
    return 0
  fi
  if ! cmp -s "$out" "$target"; then cp "$out" "$target"; printf 'wrote %s (%s block)\n' "$rel" "$start"; fi
}

# --- repo-level off-switch table step ---------------------------------------------
# Every guard in this marketplace fails open and every one of them can be switched off
# with an environment variable — and on 2026-09-22 the root README named ZERO of them
# (UX 1, rationale/specialist-panel-2026-09-22.md #5). A user whose turn was just
# refused had no list to read. Generated rather than typed because the set moves with
# every hook added: the names are grepped out of plugins/*/hooks/*.sh in the two shapes
# the hooks actually use (a `${NAME:-default}` read, and the boost chassis' indirect
# `plugin_switch=NAME`), minus the four host-supplied CLAUDE_* path/session variables,
# which are not switches.
#
# THE THIRD COLUMN is the hook's OWN sentence about the variable — the first comment
# line in the file that writes `NAME=`, cut at its first sentence end. That is a
# deterministic read of prose somebody else wrote, so it is sometimes a fragment and
# says `…` when it was cut mid-sentence; a hook whose header never writes `NAME=` gets
# "see hook header", which is the honest answer rather than an invented one.
#
# WHAT THIS TABLE DOES NOT ESTABLISH: that a variable still works, that `off` is the
# value it takes (several take block/warn/off or a number), or that the hook prints the
# name when it refuses you — that last one is pc_offswitch_named's job and it is a WARN.
render_offswitch_table() {
  local block="$WORK/offswitch.md" f p v note
  [ -f "$ROOT/README.md" ] || return 0
  {
    printf '%s' '<!-- generated:offswitch-table -->'
    printf '%s\n\n' '<!-- generated by scripts/generate.sh (off-switch step) from the env reads in plugins/*/hooks/*.sh — do not edit these rows by hand -->'
    printf '| Variable | Plugins | What the hook says it does |\n'
    printf '|----------|---------|----------------------------|\n'
    for f in "$ROOT"/plugins/*/hooks/*.sh; do
      [ -f "$f" ] || continue
      p=$(basename "$(dirname "$(dirname "$f")")")
      {
        grep -ohE '\$\{(CC_[A-Z0-9_]+|CLAUDE_[A-Z0-9_]+|[A-Z0-9_]+_BOOST|[A-Z0-9_]+_STOP_GATE):-' "$f" | sed -E 's/^\$\{//; s/:-$//'
        grep -ohE '^[[:space:]]*plugin_switch=[A-Z0-9_]+' "$f" | sed -E 's/.*=//'
      } 2>/dev/null \
      | grep -vxE 'CLAUDE_PLUGIN_ROOT|CLAUDE_PROJECT_DIR|CLAUDE_CONFIG_DIR|CLAUDE_CODE_SESSION_ID' \
      | LC_ALL=C sort -u | while IFS= read -r v; do
          [ -n "$v" ] || continue
          note=$(grep -m1 -E "^[[:space:]]*#.*$v=" "$f" \
                 | sed -E "s/.*($v=)/\1/; s/[[:space:]]+/ /g; s/(\. | — ).*$//; s/[[:space:]]*[-—.;,]*[[:space:]]*$//")
          [ -n "$note" ] || note="see hook header"
          printf '%s\t%s\t%s\n' "$v" "$p" "$note"
        done
    done | LC_ALL=C sort -u | awk -F'\t' '
      function esc(x) { gsub(/\|/, "\\|", x); return x }
      { if (!($1 in seen)) { seen[$1]=1; order[++n]=$1 }
        if (!(($1 SUBSEP $2) in pseen)) { pseen[$1,$2]=1
          plugins[$1] = (plugins[$1] == "" ? $2 : plugins[$1] ", " $2) }
        if (note[$1] == "" || note[$1] == "see hook header") note[$1] = $3 }
      END { for (i = 1; i <= n; i++) {
              t = note[order[i]]
              if (length(t) > 104) t = substr(t, 1, 104) " …"
              printf "| `%s` | %s | %s |\n", order[i], plugins[order[i]], esc(t) } }'
    printf '\n%s\n' 'Set one in your shell, or in the `env` block of the settings.json for the project or
user scope you want it to apply to. `CC_REMIND=off` and `CC_BOOST=off` are the two
marketplace-wide mutes — every reminder and every boost injector respectively; the rest
silence one hook each. Several take `block` / `warn` / `off` rather than a bare `off`,
and the sentence in the third column is the hook'"'"'s own, read out of its header and cut
at the first sentence end — some rows are therefore a clause, not a sentence.
Turning a guard off is a session-scoped act, not a fix: the guards that can refuse a
tool call fail open on every error path already, so silence is what a clean install and
a broken one both look like — `/skill-doctor` and the three read-only checks above are
how you tell those apart.'
    printf '\n%s\n' '<!-- end:offswitch-table -->'
  } > "$block"
  readme_apply '<!-- generated:offswitch-table -->' '<!-- end:offswitch-table -->' "$block"
}

# --- repo-level no-suite-leaves step -----------------------------------------------
# The leaves that belong to no bundle, derived from marketplace.json and each
# plugin.json's `dependencies`. The hand-written paragraph this replaces warned in its
# own last sentence that the list goes stale, and it had: design-kit was named in no
# bundle and in no list (UX 6, rationale/specialist-panel-2026-09-22.md #39). A list
# that carries its own staleness warning is a list that should be generated.
render_no_suite_leaves() {
  local block="$WORK/nosuite.md" mp="$ROOT/.claude-plugin/marketplace.json"
  local deps names lp n
  [ -f "$ROOT/README.md" ] || return 0
  [ -f "$mp" ] || die "no-suite-leaves step: marketplace.json not found: $mp"
  deps=$(for lp in "$ROOT"/plugins/*/.claude-plugin/plugin.json; do
           [ -f "$lp" ] && jq -r '.dependencies[]?' "$lp" 2>/dev/null
         done | sed 's/@.*//' | LC_ALL=C sort -u)
  names=""
  for n in $(jq -r '.plugins[].name' "$mp" 2>/dev/null | LC_ALL=C sort); do
    [ -f "$ROOT/plugins/$n/.claude-plugin/plugin.json" ] || continue
    jq -e 'has("dependencies")' "$ROOT/plugins/$n/.claude-plugin/plugin.json" >/dev/null 2>&1 && continue
    printf '%s\n' "$deps" | grep -qxF "$n" && continue
    names="$names, \`$n\`"
  done
  names="${names#, }"
  [ -n "$names" ] || names="none — every leaf is in a bundle"
  {
    printf '%s' '<!-- generated:no-suite-leaves -->'
    printf '%s\n\n' '<!-- generated by scripts/generate.sh (no-suite-leaves step) from .claude-plugin/marketplace.json and each plugin.json'"'"'s dependencies — do not edit this list by hand -->'
    printf 'Suites are curated starting points, not coverage. These leaves belong to no bundle:\n\n%s.\n\n' "$names"
    printf '%s\n' 'The stack and domain ones are named by `/stack-scan:suggest` when the project'"'"'s
manifests earn them; the rest are per-project or per-user opt-ins. Install them by name.'
    printf '\n%s\n' '<!-- end:no-suite-leaves -->'
  } > "$block"
  readme_apply '<!-- generated:no-suite-leaves -->' '<!-- end:no-suite-leaves -->' "$block"
}

# --- repo-level bundle-table step -------------------------------------------------
# Rewrites the README region between <!-- generated:bundle-table --> and its closing
# marker from two committed sources: each bundle's plugin.json .dependencies length,
# and scripts/context-budget-{,dynamic-}baseline.json. Before this step the table was
# hand-maintained and wrong: it read `everything | 57 | ~10.6k tokens` against 58
# dependencies and a measured 11,998 + 2,399, and validate.sh's leaf-count grep
# matched the correct prose elsewhere in the file and never reached the row. The
# token column is not catalog trivia — it is the product's cost warning, and a cost
# warning nobody generates is a cost warning nobody updates. Enforced by the same
# blocking --check drift pass as every other generated file.
render_bundle_table() {
  local target="$ROOT/README.md" block="$WORK/bundle-table.md"
  local base="$ROOT/scripts/context-budget-baseline.json"
  local dyn="$ROOT/scripts/context-budget-dynamic-baseline.json"
  local act="$ROOT/scripts/context-budget-activated-baseline.json"
  # A fixture root (CHASSIS_ROOT pointed at a smoke harness tree) has no root
  # README — skip rather than die, or every harness that overrides CHASSIS_ROOT
  # reads this step's abort as chassis drift. A REAL repo losing its README is
  # caught by validate.sh's leaf-count gate, which cannot pass without one.
  [ -f "$target" ] || return 0

  # THE LISTING FLOOR, computed rather than typed: the host's own context window and
  # budget fraction (scripts/host-constants.sh) against the 3-bytes-per-token tokenizer,
  # which is the worst realistic case and the one context-budget.sh's listing channel
  # reports. Derivation and the NEAR band are in that script's LISTING_* header.
  local floor near_lo near_hi
  floor=$(awk -v t="$HOST_LISTING_CTX_TOKENS" -v f="$HOST_LISTING_FRACTION" 'BEGIN{printf "%d", t*3*f}')
  case "$floor" in ''|*[!0-9]*|0) floor=6000 ;; esac
  near_lo=$((floor * 97 / 100)); near_hi=$((floor * 103 / 100))

  # k-tokens, one decimal, from a raw token count. 0 renders as an em dash so an
  # empty cell reads as "measured zero", not "not measured".
  # k-tokens, one decimal, from a raw token count. 0 renders as an em dash so an
  # empty cell reads as "measured zero", not "not measured". Under 1k renders in
  # raw tokens: the first activated column produced `~0.0k tokens` for a real
  # 37-token cost, which reads as nothing and is worse than the number.
  fmt_k() {
    [ "$1" -eq 0 ] && { printf '%s' '—'; return; }
    [ "$1" -lt 1000 ] && { printf '~%s tokens' "$1"; return; }
    printf '~%s.%sk tokens' $(( ($1 + 50) / 1000 )) $(( ((($1 + 50) / 100) % 10) ))
  }

  {
    printf '%s' '<!-- generated:bundle-table -->'
    printf '%s\n\n' '<!-- generated by scripts/generate.sh (bundle-table step) from each bundle'"'"'s plugin.json dependencies + scripts/context-budget-*baseline.json — do not edit these rows by hand -->'
    printf '| Bundle | Plugins | Always-on context | + when switched on | + first work-shaped prompt | Skill listing vs the %s-char floor | Fraction its README names |\n' "$floor"
    printf '|--------|---------|-------------------|--------------------|----------------------------|------------------------------------|---------------------------|\n'
    for pj in "$ROOT"/plugins/*/.claude-plugin/plugin.json; do
      [ -f "$pj" ] || continue
      jq -e 'has("dependencies")' "$pj" >/dev/null 2>&1 || continue
      bn=$(jq -r '.name' "$pj"); dc=$(jq -r '.dependencies | length' "$pj")
      at=$(jq -r --arg b "$bn" '.[$b] // 0' "$base" 2>/dev/null); at=${at:-0}
      dt=$(jq -r --arg b "$bn" '.[$b] // 0' "$dyn" 2>/dev/null); dt=${dt:-0}
      # Activated = the same always-on surface once the state its hooks wait for
      # exists (a terse level set, a brain map present). Shown as the DELTA over
      # always-on, because that is the part no baseline saw before 2026-08-20 and
      # the part a user cannot predict from the install alone.
      ac=$(jq -r --arg b "$bn" '.[$b] // 0' "$act" 2>/dev/null); ac=${ac:-0}
      ad=0; [ "$ac" -gt "$at" ] && ad=$((ac - at))
      # LISTING COLUMN. Same walk the context-budget listing channel and the
      # pc_listing_declaration gate use — pc_listing_entry_cost, one implementation —
      # so the three figures agree by construction rather than by reconciliation.
      # Members plus the bundle's OWN uninstall command, plus the CLI's n-1 joins.
      lc=0; ln=0
      while IFS= read -r member; do
        [ -n "$member" ] && [ -d "$ROOT/plugins/$member" ] || continue
        set -- $(pc_listing_entry_cost "$ROOT/plugins/$member")
        lc=$((lc + $1)); ln=$((ln + $2))
      done < <(jq -r '.dependencies[]?' "$pj" 2>/dev/null)
      set -- $(pc_listing_entry_cost "$ROOT/plugins/$bn")
      lc=$((lc + $1)); ln=$((ln + $2))
      [ "$ln" -gt 1 ] && lc=$((lc + ln - 1))
      if   [ "$lc" -gt "$near_hi" ]; then ls_col="OVER ($(awk -v a="$lc" -v c="$floor" 'BEGIN{printf "%.1f", a/c}')x, $lc chars)"
      elif [ "$lc" -ge "$near_lo" ]; then ls_col="NEAR ($(awk -v a="$lc" -v c="$floor" 'BEGIN{printf "%.0f", 100*a/c}')%, $lc chars)"
      else                                ls_col="OK ($(awk -v a="$lc" -v c="$floor" 'BEGIN{printf "%.0f", 100*a/c}')%, $lc chars)"
      fi
      # The fraction that bundle's OWN README recommends, read out of it. Two of the
      # four were missing from the hand-written prose; a column cannot skip a row.
      fr=$(grep -oE '"skillListingBudgetFraction"[[:space:]]*:[[:space:]]*[0-9.]+' "$ROOT/plugins/$bn/README.md" 2>/dev/null \
           | head -1 | grep -oE '[0-9.]+$')
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$at" "$bn" "$dc" "$dt" "$ad" "$ls_col" "${fr:-—}"
    done | sort -rn -k1,1 | while IFS=$'\t' read -r at bn dc dt ad ls_col fr; do
      printf '| `%s` | %s | %s | %s | %s | %s | %s |\n' "$bn" "$dc" "$(fmt_k "$at")" "$(fmt_k "$ad")" "$(fmt_k "$dt")" "$ls_col" "$fr"
    done
    nonsuite=0
    for lp in "$ROOT"/plugins/*/.claude-plugin/plugin.json; do
      [ -f "$lp" ] || continue
      jq -e 'has("dependencies")' "$lp" >/dev/null 2>&1 || nonsuite=$((nonsuite+1))
    done
    printf '\nEvery row is a curated subset. The marketplace ships all %s leaf plugins and no bundle installs them together — see `rationale/2026-08-31-token-cost-review.md`. The `all-plugins` script does, and it also raises `skillListingBudgetFraction` in the scope it installs to, so the listing is sent whole — its README carries the arithmetic and the one measurement (2026-09-15, n=50) that found the overflow changes nothing detectable.\n' "$nonsuite"
    # The fraction each OVER bundle's own README names, READ OUT of those READMEs
    # rather than typed here. Two of the four were missing from the hand-written list
    # (craft-suite and frontend-suite, found 2026-09-22) — a reader who installed
    # either was told to use "the value that bundle's README names" and then shown a
    # parenthesis that did not name it. Deriving it means the sentence cannot go stale
    # when a bundle crosses the floor.
    frac_list=""
    for bp in "$ROOT"/plugins/*/README.md; do
      bj="$(dirname "$bp")/.claude-plugin/plugin.json"
      [ -f "$bj" ] || continue
      jq -e 'has("dependencies")' "$bj" >/dev/null 2>&1 || continue
      fv=$(grep -oE '"skillListingBudgetFraction"[[:space:]]*:[[:space:]]*[0-9.]+' "$bp" \
           | head -1 | grep -oE '[0-9.]+$')
      [ -n "$fv" ] || continue
      frac_list="$frac_list, $fv for $(jq -r '.name' "$bj")"
    done
    frac_list="${frac_list#, }"
    [ -n "$frac_list" ] || frac_list="no bundle currently declares one"

    # The budget these numbers are measured AGAINST, stated once, with its source.
    # Claude Code budgets the skill listing at 1%% of the model context window and,
    # on overflow, drops descriptions starting with the skills you invoke least —
    # names survive, trigger keywords do not. So a bundle above that line does not
    # error; it silently loses the tail's discoverability, per user, by invocation
    # history. Our figures also read LOW: `claude plugin details` charges a
    # per-component floor our bytes/4 estimate does not, measured at 1.54x across
    # the 61 leaves on 2026-08-20 (scripts/context-budget-official.json).
    printf '\nThe budget these are measured against is the host'"'"'s skill listing, and it is a FORMULA,\nnot a constant — read out of the shipped CLI, not from documentation, and re-read on every\nCI run by `scripts/host-constants.sh --check` against the pinned build:\n\n    budget_chars = contextWindowTokens x bytesPerToken x skillListingBudgetFraction\n\n`skillListingBudgetFraction` defaults to **0.01** and is a `settings.json` key you can raise.\nIf you install a bundle flagged over the 200k floor, set it to the value that bundle'"'"'s README\nnames (%s) in the settings.json of the PROJECT where you use it — the fraction is a\nceiling, not a purchase: under budget it changes nothing, over budget it readmits exactly the\ndescriptions being evicted.\n`bytesPerToken` is 4 through opus-4-6 / sonnet-4-6 and **3** for newer models including\nopus-5. So the budget spans 6.7x by where you run: **6,000 chars** on opus-5 at 200k,\n**30,000** at 1M, 8,000 / 40,000 on a 4-byte model. A second cap truncates any single\ndescription past **1,536** chars (`skillListingMaxDescChars`); this repo lints at 500, so it\nnever binds. Over budget the CLI reduces entries to name-only and buys descriptions back in\npriority order — text past the budget is never sent, so it costs reachability, never tokens.\nThe cost is per ENTRY, `name + 4 + description`, so artifact COUNT is charged directly: that\nis the mechanical reason fewer artifacts beats shorter descriptions.\nUnit note: the token columns above are estimated at 4 bytes/token; on the 3-bytes-per-token\nmodels this paragraph calls current, add ~33%%. The host also charges a per-component floor\nthis estimate does not — a 2026-08-20 snapshot measured ~1.5x on a now-changed tree; treat\nthat as an order-of-magnitude correction, never as a coefficient\n(`scripts/context-budget-official.json` header has the derivation and the staleness).\n' "$frac_list"
    # THE HOST'S OWN REMEDIES, ordered as the host orders them (`/skills` first) and
    # placed as the LAST word on the subject so it is what a reader leaves with: they
    # are the only lever that reduces the CHARGE rather than buying more ceiling.
    # Added 2026-09-22 — `/skills` and `/skill-doctor` appeared in zero shipped docs
    # while every bundle README taught the fraction, and the 2026-09-15 probe measured
    # the byte framing as the wrong first move.
    printf '\n%s\n' 'Before raising the fraction, use what the host already ships, in the order it names them:
**`/skills`** lists every skill the session can see with its source, and lets you turn off the
ones this project does not need — the cost is charged per ENTRY (`name + 4 + description`), so
fewer entries is the only lever that reduces it rather than buying more ceiling.
**`/skill-doctor`** then reports what is reachable and what is being evicted, which is how you
find out whether anything you rely on sits in the tail. Raise the fraction third.
And do not trim descriptions to fit: measured 2026-09-15, n=50 per arm
(`rationale/2026-09-15-listing-eviction-probe.md`), stripping a description changed firing by
nothing (47/50 both arms), while OVERLAP between skills contesting one territory dropped firing
from 100% to ~75%. What costs a marketplace is two skills that sound alike, not long text.'
    printf '\n%s\n' '<!-- end:bundle-table -->'
  } > "$block"
  readme_apply '<!-- generated:bundle-table -->' '<!-- end:bundle-table -->' "$block"
}

# --- main -------------------------------------------------------------------------
shopt -s nullglob
for manifest in "$ROOT"/plugins/*/.chassis.json; do
  [ -f "$manifest" ] || continue
  jq empty "$manifest" 2>/dev/null || die "invalid JSON: ${manifest#$ROOT/}"
  pdir="$(dirname "$manifest")"
  n="$(jq 'if type=="array" then length else 1 end' "$manifest")"
  i=0
  LANE_ROWS=""
  while [ "$i" -lt "$n" ]; do
    obj="$(jq -c "if type==\"array\" then .[$i] else . end" "$manifest")"
    render_chassis "$obj" "$pdir"
    i=$((i+1))
  done
  write_lane_block "$pdir"
done

render_catalog
render_bundle_table
render_offswitch_table
render_no_suite_leaves

if [ "$MODE" = write ]; then
  for pdir in $CHANGED_PLUGINS; do bump_plugin "$pdir"; done
fi

# reports (both modes)
printf '== opt-out reviews ==%s\n' "${OPTOUT_REPORT:- (none)}"

if [ "$MODE" = check ] && [ "$DRIFT" != 0 ]; then
  printf 'generate.sh --check: drift detected — run scripts/generate.sh --write\n' >&2
  exit 1
fi
exit 0
