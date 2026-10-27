#!/usr/bin/env bash
# generate.sh --write|--check — deterministic chassis stamper: renders each plugins/*/.chassis.json object (reminder-hook, boost-hook, worker-agent; optout is reported) through templates/, plus each plugin's lane.tsv generated block, stack-scan's scout catalog and the README off-switch table.
# --write writes deltas (+x on .sh) and patch-bumps each changed plugin once; --check byte-diffs (hook mode bits too) and never writes. Misses: hooks.json, a deleted manifest's lane block. Fixture roots: CHASSIS_ROOT, CHASSIS_TEMPLATES, TEMPLATE_ENGINE.
# Why, limits, history: rationale/derivations/scripts.md § scripts/generate.sh
set -uo pipefail

MODE=""
case "${1:-}" in
  --write) MODE=write ;;
  --check) MODE=check ;;
  *) printf 'usage: %s --write|--check\n' "${0##*/}" >&2; exit 2 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${CHASSIS_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
# pc_switch_reads: one switch-discovery source shared with pc_offswitch_named.
. "$SCRIPT_DIR/lib/plugin-checks.sh"
TEMPLATES="${CHASSIS_TEMPLATES:-$(cd "$SCRIPT_DIR/../templates" 2>/dev/null && pwd || printf '%s' "$SCRIPT_DIR/../templates")}"
ENGINE="${TEMPLATE_ENGINE:-$SCRIPT_DIR/lib/template-engine.sh}"

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

# --- reports + change tracking ----------------------------------------------------
CHANGED_PLUGINS=""
DRIFT=0
OPTOUT_REPORT=""
mark_changed() { case " $CHANGED_PLUGINS " in *" $1 "*) : ;; *) CHANGED_PLUGINS="$CHANGED_PLUGINS $1" ;; esac; }

emit() { # rendered-file target-path is_exec(0|1) plugin-dir
  local rendered="$1" target="$2" isexec="$3" pdir="$4" rel="${2#$ROOT/}"
  # Preserve blocks: each <!-- preserve:NAME --> body in the tree is transplanted into the render before any compare, so a sanctioned divergence is neither drift nor clobbered.
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

# Lane rows: a chassis object's `lane` key {owns, trigger, yieldsTo, phase} renders one six-field lane.tsv row in the generated block; there is no phase default, and a missing key dies.
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
  # A chassis object without a lane key dies: the generator owns the artifact, so it owns the row.
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
render_reminder_hook() { # obj plugin-dir
  local obj="$1" pdir="$2" dfile="$WORK/m.json" rfile="$WORK/r.out"
  # One ranked path: a hook declares `arcRank` and yields to a better rank in its phase; armsClarifyGate drops the cc-workprompt marker; `file` (default hooks/remind.sh) allows two per plugin.
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
  # One template for every boost injector: the manifest carries the env var, regex(es), `file` and directive, sent through a quoted heredoc as written.
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
  # Optional slots (operatingProcedure, domainChecklist, deferRule, floor): a string or an array of lines; absent renders "", so agents without them stay byte-identical.
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
    reminder-hook)   render_reminder_hook   "$obj" "$pdir" ;;
    boost-hook)      render_boost_hook      "$obj" "$pdir" ;;
    worker-agent)    render_worker_agent    "$obj" "$pdir" ;;
    "") die "$rel/.chassis.json has no \"chassis\" field" ;;
    *) die "unknown chassis type '$chassis' in $rel/.chassis.json" ;;
  esac
}

# --- repo-level catalog step (not a per-plugin chassis) ---------------------------
# One row per marketplace plugin, `name — [keywords] — description`, from marketplace.json and each plugin.json; never bumps stack-scan.
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
# Rewrites only the region between one marker pair; a fixture CHASSIS_ROOT with no root README returns early rather than reading as drift.
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
# A row per upper-cased userConfig key plus each undeclared switch a hook or module reads; it does not establish that a switch works, matches its default, or is named on refusal.
render_offswitch_table() {
  local block="$WORK/offswitch.md" rows="$WORK/offswitch.tsv" pj f p v note
  [ -f "$ROOT/README.md" ] || return 0
  : > "$rows"
  for f in "$ROOT"/plugins/*/hooks/cc-kit.ts; do
    [ -f "$f" ] || continue
    grep -qF "\$.env.get('CC_SUGGEST')" "$f" \
      || die "${f#$ROOT/} no longer reads \$.env.get('CC_SUGGEST'), yet pc_switch_reads credits CC_SUGGEST to every registerSuggestion( caller — fix one or the other"
  done
  for pj in "$ROOT"/plugins/*/.claude-plugin/plugin.json; do
    [ -f "$pj" ] || continue
    p=$(basename "$(dirname "$(dirname "$pj")")")
    jq -r --arg p "$p" '(.userConfig // {}) | to_entries[]
      | [(.key | ascii_upcase), "d", $p,
         (.value.default | if . == true then "on" elif . == false then "off" elif . == null then "—" else tostring end),
         (.value.description // "" | gsub("\\s+"; " ") | sub("\\. .*$"; "") | sub("\\.$"; ""))]
      | @tsv' "$pj" >> "$rows" || die "invalid JSON: ${pj#$ROOT/}"
  done
  {
    for f in "$ROOT"/plugins/*/hooks/*.sh; do printf '%s\n' "$f"; done
    for d in "$ROOT"/plugins/*/hooks; do
      [ -d "$d" ] || continue
      find "$d" -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.mts' -o -name '*.cts' \
        -o -name '*.js' -o -name '*.mjs' \) ! -name cc-kit.ts
    done
  } | while IFS= read -r f; do
    [ -f "$f" ] || continue
    p=${f#"$ROOT"/plugins/}; p=${p%%/*}
    pc_switch_reads "$f" | while IFS= read -r v; do
        [ -n "$v" ] || continue
        note=$(grep -m1 -E "^[[:space:]]*(#|//|\*).*$v=" "$f" \
               | sed -E "s/.*($v=)/\1/; s/[[:space:]]+/ /g; s/(\. | — ).*$//; s/[[:space:]]*[-—.;,]*[[:space:]]*$//")
        [ -n "$note" ] || case $v in
          CC_SUGGEST) note="On unless CC_SUGGEST=off, which silences these plugins' next-step suggestions, not Claude Code's own" ;;
          *) note="see hook header" ;;
        esac
        printf '%s\th\t%s\t—\t%s\n' "$v" "$p" "$note"
      done
  done >> "$rows"
  {
    printf '%s' '<!-- generated:offswitch-table -->'
    printf '%s\n\n' '<!-- generated by scripts/generate.sh (off-switch step) from userConfig in plugins/*/.claude-plugin/plugin.json plus the undeclared env reads in plugins/*/hooks/*.sh and hooks modules — do not edit these rows by hand -->'
    printf '| Variable | Plugins | Default | What it does |\n'
    printf '|----------|---------|---------|--------------|\n'
    LC_ALL=C sort -u "$rows" | awk -F'\t' '
      function esc(x) { gsub(/\|/, "\\|", x); return x }
      function add(l, x, sep) { return l == "" ? x : l sep x }
      { v = $1; k = $2
        if (!(v in seen)) { seen[v]=1; order[++n]=v }
        if (k == "d") declared[v]=1
        if (!((v SUBSEP k SUBSEP $3) in pseen)) { pseen[v,k,$3]=1; plugins[v,k] = add(plugins[v,k], $3, ", ") }
        if (!((v SUBSEP k SUBSEP $4) in dseen)) { dseen[v,k,$4]=1; dflt[v,k] = add(dflt[v,k], $4, " / ") }
        if (note[v,k] == "" || note[v,k] == "see hook header") note[v,k] = $5 }
      END { for (i = 1; i <= n; i++) {
              v = order[i]; k = (v in declared) ? "d" : "h"; t = note[v,k]
              # A plugin reading a declared switch it does not declare gets no option: env only.
              if (k == "d" && plugins[v,"h"] != "") {
                m = split(plugins[v,"h"], hp, ", ")
                for (j = 1; j <= m; j++)
                  if (index(", " plugins[v,"d"] ", ", ", " hp[j] ", ") == 0 && index(plugins[v,"d"], hp[j] " (env only)") == 0)
                    plugins[v,"d"] = plugins[v,"d"] ", " hp[j] " (env only)" }
              if (length(t) > 104) t = substr(t, 1, 104) " …"
              printf "| `%s` | %s | %s | %s |\n", v, plugins[v,k], dflt[v,k], esc(t) } }'
    printf '\n%s\n' 'Each switch has two handles. The variable — set in your shell, or in the `env` block of
the settings.json for the project or user scope you want — overrides everything, and
`CC_REMIND` or `CC_BOOST` set that way mutes every reminder or every boost injector in
every plugin at once. The plugin'"'"'s own option under `/config` (or `/plugin configure
<plugin>`) scopes a switch to that one plugin; a plugin marked `(env only)` reads the
variable but declares no option. A hook resolves each switch as environment → `/config` option → the Default
column; `CC_TERSE` also reads the level file `/candor:level` writes, between the two. A
row whose Default is `—` is a variable no plugin declares: it has no `/config` option,
and its sentence is the hook'"'"'s own, read out of its header, or the generator'"'"'s for
a switch only the shared mod kit reads.
Turning a guard off is not a fix, and it lasts as long as the handle you used — a shell
export for that shell, a settings.json `env` entry or a `/config` option until you remove
it. The guards that can refuse a
tool call fail open on every error path already, so silence is what a clean install and
a broken one both look like — `/skill-doctor` and the three read-only checks above are
how you tell those apart.'
    printf '\n%s\n' '<!-- end:offswitch-table -->'
  } > "$block"
  readme_apply '<!-- generated:offswitch-table -->' '<!-- end:offswitch-table -->' "$block"
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
render_offswitch_table

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
