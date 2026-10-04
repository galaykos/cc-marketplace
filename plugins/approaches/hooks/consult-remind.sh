#!/bin/bash
# generated from templates/reminder-hook.sh.tmpl by scripts/generate.sh — edit the template or .chassis.json, not this file
# Fail open: never block the prompt. Print a reminder only when the prompt reads
# like the work it nudges about — a mere mention of the words stays silent.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/reminder-hook.sh.tmpl
command -v jq >/dev/null 2>&1 || exit 0
# Shared block templates/blocks/state-root.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/state-root.md
# cc_state_root <cwd> prints the root that holds hook state: the git toplevel above <cwd>, else
# CLAUDE_PROJECT_DIR when <cwd> is under it, else <cwd>. A <cwd> that no longer exists: no output, status 1.
# --show-cdup, not --show-toplevel: git resolves a symlinked /tmp there, breaking the caller's path-prefix compares.
cc_state_root() {
  [ -n "$1" ] && [ -d "$1" ] || return 1
  local up pd="${CLAUDE_PROJECT_DIR:-}"; pd="${pd%/}"
  if up=$(git -C "$1" rev-parse --show-cdup 2>/dev/null); then
    [ -n "$up" ] || { printf '%s\n' "$1"; return 0; }
    (CDPATH= cd -- "$1/$up" 2>/dev/null && pwd) && return 0
  fi
  if [ -n "$pd" ] && [ -d "$pd" ]; then
    case "$1/" in "$pd"/*) printf '%s\n' "$pd"; return 0 ;; esac
  fi
  printf '%s\n' "$1"
}

# Shared block templates/blocks/phase-guard.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/phase-guard.md
# No template directive of any kind in these comments: _expand_includes copies this file raw, then conditionals and
# substitution run over the whole text.
# cc_phase_guard returns 1 only when <cc_state_root>/.claude/cc-phase.json, unexpired (one older than cc_phase_ttl_min is deleted)
# and not another session's, names a phase past $1's phase in this plugin's own lane.tsv; else 0.
# cc_phase_now: the phase any unexpired sentinel names, whichever session wrote it, or empty.
# Set $cwd, or $input (the hook payload; an empty $cwd is then assigned its .cwd), and $sid before the call: with
# neither $cwd nor $input it always proceeds; without $sid another session's sentinel counts.
# Misses: a bare prompt writes no phase, so nothing stands down outside a run a command declared; without jq or cc_state_root it proceeds.
cc_phase_ttl_min=120
cc_phase_now=""
cc_phase_guard() { # $1 = this artifact's id, e.g. taskmaster:remind. 0 = proceed.
  local sentinel lane want have ssid root
  command -v jq >/dev/null 2>&1 || return 0
  [ -n "${cwd:-}" ] || cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  [ -n "$cwd" ] || return 0
  root=$(cc_state_root "$cwd") || return 0
  sentinel="$root/.claude/cc-phase.json"
  [ -r "$sentinel" ] || return 0

  if [ -n "$(find "$sentinel" -maxdepth 0 -mmin +"$cc_phase_ttl_min" 2>/dev/null)" ]; then
    rm -f "$sentinel" 2>/dev/null
    return 0
  fi

  have=$(jq -r '.phase // empty' "$sentinel" 2>/dev/null) || return 0
  [ -n "$have" ] || return 0
  cc_phase_now="$have"

  ssid=$(jq -r '.session_id // empty' "$sentinel" 2>/dev/null)
  if [ -n "$ssid" ]; then
    if [ -n "${sid:-}" ]; then
      case "$ssid" in "$sid") ;; *) return 0 ;; esac
    fi
  fi

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

# Shared block templates/blocks/option-resolver.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/option-resolver.md
# cc_option <ENV_NAME> <default> [<level-file>] prints, status 0, the first non-empty of: variable ENV_NAME,
# <level-file>'s first word, option CLAUDE_PLUGIN_OPTION_<ENV_NAME> (true/false as on/off), <default>.
# The host exports only SAVED options, so <default> must equal the manifest's default.
# A non-empty variable beats the option: the environment is shared, so one export before launch
# switches every plugin that reads it.
# Misses: a malformed name, which yields <default>; a variable passed instead of a literal name; a value outside the vocabulary.
cc_option() {
  local v="" opt
  case "${1:-}" in '' | [0-9]* | *[!A-Za-z0-9_]*) printf '%s\n' "${2:-}"; return 0 ;; esac
  v="${!1:-}"
  if [ -z "$v" ] && [ -n "${3:-}" ] && [ -f "$3" ] && [ -r "$3" ]; then
    read -r v _ 2>/dev/null < "$3" || :
  fi
  if [ -z "$v" ]; then
    opt="CLAUDE_PLUGIN_OPTION_$1"; v="${!opt:-}"
    case "$v" in true) v=on ;; false) v=off ;; esac
  fi
  [ -n "$v" ] || v="${2:-}"
  printf '%s\n' "$v"
  return 0
}

{
  is_machinery_prompt() {
    printf '%s' "$head" | grep -qiE 'hook (success|feedback|output)|task-notification|SYSTEM NOTIFICATION|UserPromptSubmit'
  }
  # The noun must start a word or directly follow the verb, else `fix the webhook handler` counts as a hook change.
  is_about_hooks() {
    printf '%s' "$head" | grep -qiE '(delete|remove|uninstall|disable|install|list|which|audit|fix|update|change|write|rewrite|edit)([a-z -]{0,39}[ -])?(plugin|hook|reminder|trigger)'
  }
  is_own_echo() {
    printf '%s' "$head" | grep -qF '/approaches:consult'
  }
  # Asking whether to do the work is not asking for it; one imperative trigger clause is enough to speak.
  is_question_only() {
    clauses=$(printf '%s' "$head" | awk '{gsub(/\?/," __Q__\n"); gsub(/\. /,"\n"); print}')
    if printf '%s\n' "$clauses" | grep -qiE '(tried everything|third time|drop table|force.push|rm -rf|reset --hard|migrate:fresh|delete all)'; then
      printf '%s\n' "$clauses" | grep -iE '(tried everything|third time|drop table|force.push|rm -rf|reset --hard|migrate:fresh|delete all)' \
        | grep -qvE '(__Q__|^[[:space:]]*(can|could|should|would|shall|is|are|was|were|do|does|did|am|will|what|why|how|when|where|which|who|whether)[^a-z])' \
        || return 0
    fi
    return 1
  }
  # Flat, never nested under a per-key dir: the sweep's rmdir at -maxdepth 1 cannot clear a nested one.
  claim_rank() {
    mkdir "${TMPDIR:-/tmp}/cc-remind-$key-rank-20" 2>/dev/null
  }
  best_rank() {
    ls -d "${TMPDIR:-/tmp}/cc-remind-$key-rank-"* 2>/dev/null \
      | sed 's/.*-rank-//' | sort -n | head -1
  }
  sweep_stale_markers() {
    find "${TMPDIR:-/tmp}" -maxdepth 1 \( -name 'cc-remind-*' -o -name 'cc-workprompt-*' \) -type d -mmin +1440 -exec rmdir {} + 2>/dev/null
  }

  input=$(cat)
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  case "$prompt" in "" | "/"*) exit 0 ;; esac # empty, or slash commands manage their own flow
  # CC_REMIND=off silences every reminder hook, the cc_remind /config option only this plugin's; a non-empty CC_REMIND wins.
  case "$(cc_option CC_REMIND on)" in off) exit 0 ;; esac
  # Only the head outside fences and backtick spans counts: a pasted log or quote buries its keywords.
  scrub=$(printf '%s' "$prompt" | awk '/^```/{f=!f; next} !f' | sed 's/`[^`]*`//g')
  head=$(printf '%s' "$scrub" | tr '\n' ' ' | cut -c1-400)
  is_machinery_prompt && exit 0
  is_about_hooks && exit 0
  is_own_echo && exit 0
  is_question_only && exit 0
  # sid before cc_phase_guard: its session check reads it.
  sid=$(printf '%s' "$input" | jq -r '.session_id // ""' 2>/dev/null)
  cc_phase_guard 'approaches:consult-remind' || exit 0
  if printf '%s' "$head" | grep -qiE '(tried everything|third time|drop table|force.push|rm -rf|reset --hard|migrate:fresh|delete all)'; then
    # MONOTONIC PRECEDENCE: the best rank eligible this turn always speaks; a worse rank that reads before it claims also prints.
    key=$(printf '%s%s%s' "$sid" "$prompt" "$cc_phase_now" | cksum | cut -d' ' -f1)
    claim_rank
    best=$(best_rank)
    if [ -z "$best" ] || [ "$best" = '20' ]; then
      printf '%s (%s).\n' 'ℹ approaches: this prompt names an irreversible command or a repeated failed attempt — a blind second opinion is available if the moment warrants one (advisory)' '/approaches:consult'
    fi
    sweep_stale_markers
  fi
} 2>/dev/null
exit 0
