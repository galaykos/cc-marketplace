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

# --- per-chassis renderers --------------------------------------------------------
render_stack_review() { # obj plugin-dir
  local obj="$1" pdir="$2" rel="${2#$ROOT/}"
  local tag worker resolved wplugin wname workerChain aeb dfile rfile
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
  workerChain="$wname → task-runner:task-executor if installed → inline"
  aeb="$(printf '%s' "$obj" | jq -r 'if ((.applyExtra // [])|length)>0 then ([.applyExtra[] | " / " + .label]|add) else "" end')"
  dfile="$WORK/m.json"; rfile="$WORK/r.out"
  printf '%s' "$obj" | jq --arg wc "$workerChain" --arg aeb "$aeb" \
    '. + {lang:(.variant=="lang"), concern:(.variant=="concern"), workerChain:$wc, applyExtraBlock:$aeb, divergencePreamble:((.divergence // {}).preamble // "")}' > "$dfile"
  ensure_engine
  render_template "$TEMPLATES/review-command.md.tmpl" "$dfile" > "$rfile" || die "render failed: $rel review.md"
  emit "$rfile" "$pdir/commands/review.md" 0 "$pdir"
}

render_suite_uninstall() { # obj plugin-dir
  local obj="$1" pdir="$2" dfile="$WORK/m.json" rfile="$WORK/r.out"
  printf '%s' "$obj" > "$dfile"; ensure_engine
  render_template "$TEMPLATES/suite-uninstall.md.tmpl" "$dfile" > "$rfile" || die "render failed: ${2#$ROOT/} uninstall.md"
  emit "$rfile" "$pdir/commands/uninstall.md" 0 "$pdir"
}

render_reminder_hook() { # obj plugin-dir
  local obj="$1" pdir="$2" dfile="$WORK/m.json" rfile="$WORK/r.out"
  printf '%s' "$obj" > "$dfile"; ensure_engine
  render_template "$TEMPLATES/reminder-hook.sh.tmpl" "$dfile" > "$rfile" || die "render failed: ${2#$ROOT/} remind.sh"
  emit "$rfile" "$pdir/hooks/remind.sh" 1 "$pdir"
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
}

render_navigator() { # obj plugin-dir
  local obj="$1" pdir="$2" dfile="$WORK/m.json" rfile="$WORK/r.out"
  printf '%s' "$obj" > "$dfile"; ensure_engine
  render_template "$TEMPLATES/navigator-check.md.tmpl" "$dfile" > "$rfile" || die "render failed: ${2#$ROOT/} check.md"
  emit "$rfile" "$pdir/commands/check.md" 0 "$pdir"
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
    navigator)       render_navigator       "$obj" "$pdir" ;;
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

# --- main -------------------------------------------------------------------------
shopt -s nullglob
for manifest in "$ROOT"/plugins/*/.chassis.json; do
  [ -f "$manifest" ] || continue
  jq empty "$manifest" 2>/dev/null || die "invalid JSON: ${manifest#$ROOT/}"
  pdir="$(dirname "$manifest")"
  n="$(jq 'if type=="array" then length else 1 end' "$manifest")"
  i=0
  while [ "$i" -lt "$n" ]; do
    obj="$(jq -c "if type==\"array\" then .[$i] else . end" "$manifest")"
    render_chassis "$obj" "$pdir"
    i=$((i+1))
  done
done

render_catalog

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
