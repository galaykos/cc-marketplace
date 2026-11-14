# Shared block templates/blocks/phase-guard.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/phase-guard.md
# No template directive in these comments: _expand_includes copies this file raw, then conditionals and substitution run over all of it.
# cc_phase_guard returns 1 only when this session's sentinel (cc_phase_file of the cc_state_root and $sid, else cc_phase_file_legacy), unexpired,
# names a phase past $1's phase in this plugin's own lane.tsv; else 0. It deletes every sentinel older than cc_phase_ttl_min.
# cc_phase_now: the phase this session's unexpired sentinel names, or empty; another session's sentinel never counts.
# Set $cwd, or $input (the hook payload; an empty $cwd is then assigned its .cwd), and $sid before the call: without
# $sid, or with neither $cwd nor $input, it always proceeds.
# Misses: a bare prompt writes no phase, so nothing stands down outside a run a command declared; without jq, cc_state_root or cc_phase_file it proceeds.
cc_phase_ttl_min=120
cc_phase_now=""
cc_phase_guard() { # $1 = this artifact's id, e.g. taskmaster:remind. 0 = proceed.
  local sentinel lane want have root d
  command -v jq >/dev/null 2>&1 || return 0
  [ -n "${cwd:-}" ] || cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  [ -n "$cwd" ] || return 0
  root=$(cc_state_root "$cwd") || return 0
  [ -d "$root/.cc-artifacts/cc-phase" ] || [ -d "$root/.claude/cc-phase" ] || return 0
  for d in "$root/.cc-artifacts/cc-phase" "$root/.claude/cc-phase"; do
    if [ -d "$d" ]; then find "$d" -maxdepth 1 -name '*.json' -mmin +"$cc_phase_ttl_min" -exec rm -f {} + 2>/dev/null; fi
  done
  sentinel=$(cc_phase_file "$root" "${sid:-}") || return 0
  [ -r "$sentinel" ] || sentinel=$(cc_phase_file_legacy "$root" "${sid:-}") || return 0
  [ -r "$sentinel" ] || return 0
  [ -z "$(find "$sentinel" -maxdepth 0 -mmin +"$cc_phase_ttl_min" 2>/dev/null)" ] || return 0

  have=$(jq -r '.phase // empty' "$sentinel" 2>/dev/null) || return 0
  [ -n "$have" ] || return 0
  cc_phase_now="$have"

  lane="${CLAUDE_PLUGIN_ROOT:-}/lane.tsv"
  [ -r "$lane" ] || return 0
  want=$(awk -F'\t' -v a="$1" '$1==a {print $3; exit}' "$lane" 2>/dev/null)
  [ -n "$want" ] || return 0
  [ "$want" = any ] && return 0

  cc_phase_ix() { case "$1" in
    understand) echo 1 ;; shape) echo 2 ;; decide) echo 3 ;; plan) echo 4 ;;
    build) echo 5 ;; verify) echo 6 ;; review) echo 7 ;; ship) echo 8 ;; *) echo 0 ;;
  esac; }
  local wi hi; wi=$(cc_phase_ix "$want"); hi=$(cc_phase_ix "$have")
  { [ "$wi" = 0 ] || [ "$hi" = 0 ]; } && return 0
  [ "$hi" -gt "$wi" ] && return 1
  return 0
}
