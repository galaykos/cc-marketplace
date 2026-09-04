#!/usr/bin/env bash
# scripts/generate.sh — deterministic chassis stamper.
#
# Discovers every plugins/*/.chassis.json (each holds ONE chassis object or an ARRAY
# of them) and renders it through templates/ via the card-01 template engine
# (scripts/lib/template-engine.sh, overridable with TEMPLATE_ENGINE). Var derivation:
# booleans lang/concern come from the manifest `variant` string, applyExtraBlock from
# the `applyExtra` array, worker-agent vars are the six frontmatter fields verbatim
# plus an optional `floor` frontmatter slot and three optional domain-content slots —
# operatingProcedure, domainChecklist, deferRule (each a markdown string or an array of
# lines, joined with "\n"; absent fields default to "" so the template's {{#if}} guards
# render nothing — so a chassis agent that pins a non-`inherit` model can emit its own
# `floor: none`/floor row exemption, and existing agents re-render byte-identical).
#
# Routing (D6, build-time): for stack-review manifests the capability `tag` resolves to
# a worker through decision-maker's map at
#   plugins/task-runner/skills/task-execution/references/routing.md
# (a code-fenced `tag → [worker, …]` block). The FIRST element of the preference list
# wins; an explicit manifest `worker:` overrides; an unresolvable tag is a hard error
# listing the vocabulary. {{workerChain}} is stamped as
#   <worker> → task-runner:task-executor if installed → inline
# Resolution validation (success criterion 3a): every resolved/overridden worker must
# exist as plugins/<pl>/agents/<name>.md — missing is a hard error in BOTH modes.
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
ROUTING="$ROOT/plugins/task-runner/skills/task-execution/references/routing.md"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

die() { printf 'generate.sh: %s\n' "$1" >&2; exit 1; }

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

# --- routing map (code-fenced tag → [worker,…] block in routing.md) ---------------
routing_block() {
  [ -f "$ROUTING" ] || die "routing map not found: $ROUTING"
  awk '/^```/{f=!f; next} f' "$ROUTING"
}
routing_vocab() { routing_block | sed -nE 's/^[[:space:]]*([A-Za-z][A-Za-z-]*)[[:space:]]+→[[:space:]]*\[.*/\1/p' | paste -sd' ' -; }
resolve_tag() { # tag -> "plugin:agent" (first preference); empty + rc1 if unknown
  local tag="$1" line
  line="$(routing_block | awk -v t="$tag" '$1==t && /→[[:space:]]*\[/' | head -1)"
  [ -n "$line" ] || return 1
  printf '%s' "$line" | sed -E 's/^[^[]*\[[[:space:]]*//; s/[],].*$//; s/[[:space:]]+$//'
}

# --- reports + change tracking ----------------------------------------------------
CHANGED_PLUGINS=""
DRIFT=0
OPTOUT_REPORT=""
OVERRIDE_REPORT=""
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
# reminder hook, worker agent) also declares its lane in a `lane` key —
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
  yt="$(printf '%s' "$obj" | jq -r '.lane.yieldsTo // "-"')"
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
render_stack_review() { # obj plugin-dir
  local obj="$1" pdir="$2" rel="${2#$ROOT/}"
  local tag worker resolved wplugin wname workerChain aeb dfile rfile outfile skname skhome skowner
  tag="$(printf '%s' "$obj" | jq -r '.tag // ""')"
  worker="$(printf '%s' "$obj" | jq -r 'if (.worker // null)==null then "" else .worker end')"
  if [ -n "$worker" ]; then
    resolved="$worker"
    OVERRIDE_REPORT="$OVERRIDE_REPORT
  $rel: tag=$tag overridden -> $worker"
  else
    resolved="$(resolve_tag "$tag")" || die "unknown routing tag '$tag' in $rel/.chassis.json — valid tags: $(routing_vocab)"
  fi
  wplugin="${resolved%%:*}"; wname="${resolved##*:}"
  [ -f "$ROOT/plugins/$wplugin/agents/$wname.md" ] \
    || die "worker '$resolved' stamped for $rel has no agent file: plugins/$wplugin/agents/$wname.md"
  # Chain head rules: (a) a worker living in ANOTHER plugin gets its full
  # plugin:name form and its own "if installed" — the bare name dangled when
  # only this plugin was installed, and the qualifier was only guarding rung 2;
  # (b) a worker in THIS plugin is always installed with it — bare name, no
  # qualifier; (c) task-runner:task-executor as head IS rung 2 — collapse, the
  # old chain printed it twice.
  if [ "$resolved" = "task-runner:task-executor" ]; then
    workerChain="task-runner:task-executor if installed → inline"
  elif [ "$wplugin" = "$(basename "$pdir")" ]; then
    workerChain="$wname → task-runner:task-executor if installed → inline"
  else
    workerChain="$wplugin:$wname if installed → task-runner:task-executor if installed → inline"
  fi
  aeb="$(printf '%s' "$obj" | jq -r 'if ((.applyExtra // [])|length)>0 then ([.applyExtra[] | " / " + .label]|add) else "" end')"
  # WHERE THE SKILL ACTUALLY LIVES. The template used to hardcode "from this
  # plugin", which was false for exactly one generated command: database's, whose
  # rubric skill `sql-best-practices` lives in plugins/sql. On a standalone
  # `database` install that sentence sent the model to a skill that is not there,
  # and validate.sh could not see it — its reference check resolves repo-wide, so
  # an install-set absence is invisible to it. Resolve the owner instead of
  # asserting it.
  skname="$(printf '%s' "$obj" | jq -r '.skill // empty')"
  skhome="from this plugin"
  if [ -n "$skname" ] && [ ! -d "$pdir/skills/$skname" ]; then
    skowner="$(basename "$(dirname "$(dirname "$(find "$ROOT/plugins" -maxdepth 3 -type d -path "*/skills/$skname" 2>/dev/null | head -1)")")")"
    [ -n "$skowner" ] && [ "$skowner" != "." ] \
      && skhome="from the \`$skowner\` plugin (install it alongside this one; it is not bundled here)" \
      || skhome="from whichever installed plugin ships it"
  fi
  dfile="$WORK/m.json"; rfile="$WORK/r.out"
  printf '%s' "$obj" | jq --arg wc "$workerChain" --arg aeb "$aeb" --arg sh "$skhome" \
    '. + {lang:(.variant=="lang"), concern:(.variant=="concern"), workerChain:$wc, applyExtraBlock:$aeb, skillHome:$sh, divergencePreamble:((.divergence // {}).preamble // "")}' > "$dfile"
  ensure_engine
  render_template "$TEMPLATES/review-command.md.tmpl" "$dfile" > "$rfile" || die "render failed: $rel review.md"
  # OUTFILE, optional. The stack-review chassis emitted only commands/review.md,
  # so a plugin needing a second concern-scoped review command had to hand-copy the
  # generated file — which resilience did for error-review and concurrency-review.
  # Both then drifted: they are missing the 8-line "Hand up when the scope is not
  # this stack's alone" block their own generated sibling carries, and `--check`
  # was structurally blind to it because .chassis.json declared only review.md.
  # An ungated copy of a gated file is the drift the chassis exists to prevent.
  outfile="$(printf '%s' "$obj" | jq -r '.outfile // "commands/review.md"')"
  emit "$rfile" "$pdir/$outfile" 0 "$pdir"
  lane_row "$obj" "$pdir" "$(basename "$pdir"):$(basename "$outfile" .md)" command review
}

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
  # plugin is not installed (process-suite ships two reminder hooks and no taskmaster).
  # armsClarifyGate replaces budgetExempt's SIDE EFFECT only: dropping the
  # cross-plugin cc-workprompt marker. Defaults keep a bare manifest renderable.
  printf '%s' "$obj" | jq \
    '{arcRank: 50, armsClarifyGate: false} + .' > "$dfile"
  ensure_engine
  render_template "$TEMPLATES/reminder-hook.sh.tmpl" "$dfile" > "$rfile" || die "render failed: ${2#$ROOT/} remind.sh"
  emit "$rfile" "$pdir/hooks/remind.sh" 1 "$pdir"
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
    stack-review)    render_stack_review    "$obj" "$pdir" ;;
    suite-uninstall) render_suite_uninstall "$obj" "$pdir" ;;
    reminder-hook)   render_reminder_hook   "$obj" "$pdir" ;;
    worker-agent)    render_worker_agent    "$obj" "$pdir" ;;
    "") die "$rel/.chassis.json has no \"chassis\" field" ;;
    *) die "unknown chassis type '$chassis' in $rel/.chassis.json" ;;
  esac
}

# --- repo-level catalog step (not a per-plugin chassis) ---------------------------
# Renders plugins/plugin-scout/.../references/catalog.md: one deterministic row per
# marketplace plugin — `name — [keywords] — description`. Description comes from
# marketplace.json, keywords from each plugin.json. Always regenerated on --write
# (byte-compared, written on delta); byte-diffed on --check via the shared DRIFT
# flag. Does NOT bump plugin-scout — the catalog rides plugin-scout's own change
# set, so version ownership stays with its manifest/skill edits.
render_catalog() {
  local mp="$ROOT/.claude-plugin/marketplace.json"
  local target="$ROOT/plugins/plugin-scout/skills/plugin-scout/references/catalog.md"
  local rel="${target#$ROOT/}" out="$WORK/catalog.md"
  [ -f "$mp" ] || die "catalog step: marketplace.json not found: $mp"
  {
    printf '%s\n' '<!-- generated by scripts/generate.sh (catalog step) from .claude-plugin/marketplace.json descriptions + plugins/*/.claude-plugin/plugin.json keywords — do not edit this file -->'
    printf '\n# Marketplace plugin catalog\n\n'
    printf '%s\n\n' 'One row per marketplace plugin: `name — [keywords] — description`. Regenerated by scripts/generate.sh; consumed by the plugin-scout skill.'
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
  local target="$ROOT/README.md" rel="README.md"
  local out="$WORK/README.md" block="$WORK/bundle-table.md"
  local base="$ROOT/scripts/context-budget-baseline.json"
  local dyn="$ROOT/scripts/context-budget-dynamic-baseline.json"
  local act="$ROOT/scripts/context-budget-activated-baseline.json"
  # A fixture root (CHASSIS_ROOT pointed at a smoke harness tree) has no root
  # README — skip rather than die, or every harness that overrides CHASSIS_ROOT
  # reads this step's abort as chassis drift. A REAL repo losing its README is
  # caught by validate.sh's leaf-count gate, which cannot pass without one.
  [ -f "$target" ] || return 0
  grep -q '^<!-- generated:bundle-table -->' "$target" \
    || die "bundle-table step: README.md is missing the <!-- generated:bundle-table --> marker"
  grep -q '^<!-- end:bundle-table -->' "$target" \
    || die "bundle-table step: README.md is missing the closing bundle-table marker"

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
    printf '| Bundle | Plugins | Always-on context | + when switched on | + first work-shaped prompt |\n'
    printf '|--------|---------|-------------------|--------------------|----------------------------|\n'
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
      printf '%s\t%s\t%s\t%s\t%s\n' "$at" "$bn" "$dc" "$dt" "$ad"
    done | sort -rn -k1,1 | while IFS=$'\t' read -r at bn dc dt ad; do
      printf '| `%s` | %s | %s | %s | %s |\n' "$bn" "$dc" "$(fmt_k "$at")" "$(fmt_k "$ad")" "$(fmt_k "$dt")"
    done
    nonsuite=0
    for lp in "$ROOT"/plugins/*/.claude-plugin/plugin.json; do
      [ -f "$lp" ] || continue
      jq -e 'has("dependencies")' "$lp" >/dev/null 2>&1 || nonsuite=$((nonsuite+1))
    done
    printf '\nEvery row is a curated subset. The marketplace ships all %s leaf plugins and no bundle installs them together — see `rationale/2026-08-31-token-cost-review.md`.\n' "$nonsuite"
    # The budget these numbers are measured AGAINST, stated once, with its source.
    # Claude Code budgets the skill listing at 1%% of the model context window and,
    # on overflow, drops descriptions starting with the skills you invoke least —
    # names survive, trigger keywords do not. So a bundle above that line does not
    # error; it silently loses the tail's discoverability, per user, by invocation
    # history. Our figures also read LOW: `claude plugin details` charges a
    # per-component floor our bytes/4 estimate does not, measured at 1.54x across
    # the 61 leaves on 2026-08-20 (scripts/context-budget-official.json).
    printf '\nThe budget these are measured against is the host'"'"'s skill listing, and it is a FORMULA,\nnot a constant — read out of the shipped CLI (2.1.251), not from documentation:\n\n    budget_chars = contextWindowTokens x bytesPerToken x skillListingBudgetFraction\n\n`skillListingBudgetFraction` defaults to **0.01** and is a `settings.json` key you can raise.\nIf you install a bundle flagged over the 200k floor, set it to the value that bundle'"'"'s README\nnames (0.02-0.03) in the settings.json of the PROJECT where you use it — the fraction is a\nceiling, not a purchase: under budget it changes nothing, over budget it readmits exactly the\ndescriptions being evicted.\n`bytesPerToken` is 4 through opus-4-6 / sonnet-4-6 and **3** for newer models including\nopus-5. So the budget spans 6.7x by where you run: **6,000 chars** on opus-5 at 200k,\n**30,000** at 1M, 8,000 / 40,000 on a 4-byte model. A second cap truncates any single\ndescription past **1,536** chars (`skillListingMaxDescChars`); this repo lints at 500, so it\nnever binds. Over budget the CLI reduces entries to name-only and buys descriptions back in\npriority order — text past the budget is never sent, so it costs reachability, never tokens.\nThe cost is per ENTRY, `name + 4 + description`, so artifact COUNT is charged directly: that\nis the mechanical reason fewer artifacts beats shorter descriptions.\nUnit note: the token columns above are estimated at 4 bytes/token; on the 3-bytes-per-token\nmodels this paragraph calls current, add ~33%%. The host also charges a per-component floor\nthis estimate does not — a 2026-08-20 snapshot measured ~1.5x on a now-changed tree; treat\nthat as an order-of-magnitude correction, never as a coefficient\n(`scripts/context-budget-official.json` header has the derivation and the staleness).\n'
    printf '\n%s\n' '<!-- end:bundle-table -->'
  } > "$block"

  awk -v blockfile="$block" '
    /^<!-- generated:bundle-table -->/ { while ((getline l < blockfile) > 0) print l; close(blockfile); skip=1; next }
    /^<!-- end:bundle-table -->/ { skip=0; next }
    !skip { print }
  ' "$target" > "$out"

  if [ "$MODE" = check ]; then
    if ! cmp -s "$out" "$target"; then printf 'DRIFT content: %s\n' "$rel" >&2; DRIFT=1; fi
    return 0
  fi
  if ! cmp -s "$out" "$target"; then cp "$out" "$target"; printf 'wrote %s\n' "$rel"; fi
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

if [ "$MODE" = write ]; then
  for pdir in $CHANGED_PLUGINS; do bump_plugin "$pdir"; done
fi

# reports (both modes)
printf '== opt-out reviews ==%s\n' "${OPTOUT_REPORT:- (none)}"
printf '== worker overrides ==%s\n' "${OVERRIDE_REPORT:- (none)}"

if [ "$MODE" = check ] && [ "$DRIFT" != 0 ]; then
  printf 'generate.sh --check: drift detected — run scripts/generate.sh --write\n' >&2
  exit 1
fi
exit 0
