#!/bin/bash
# unread-pick.sh — UserPromptSubmit: one line naming the board and artboard when a design-kit pick in <project root>/.design-kit/decisions.jsonl is unconsumed; stands down past its own lane.tsv phase (shared phase guard). Off: CC_REMIND=off or CC_DESIGN_KIT_PICK=off (unset: /config options cc_remind / cc_design_kit_pick). Fails open; never blocks or reads the prompt.
# Misses: a DESIGN_KIT_DIR elsewhere, a stray <subdir>/.design-kit/, whether the model acts on the line (agent-graded). No gate holds the phase-guard copy to its block: it is kept identical by hand.
# Why, limits, history: rationale/derivations/plugin-design-kit.md § plugins/design-kit/hooks/unread-pick.sh

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

# Shared block templates/blocks/option-resolver.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/option-resolver.md
# cc_option <ENV_NAME> <default> [<level-file>] prints, status 0, the first non-empty of: variable ENV_NAME,
# <level-file>'s first word, option CLAUDE_PLUGIN_OPTION_<ENV_NAME> (true/false as on/off), <default>.
# The host exports only SAVED options, so <default> must equal the manifest's default.
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

# No `set -e`: an unset variable or a failing probe must not take the prompt down.
[ "$(cc_option CC_REMIND on)" = "off" ] && exit 0
[ "$(cc_option CC_DESIGN_KIT_PICK on)" = "off" ] && exit 0
command -v python3 >/dev/null 2>&1 || exit 0
input="$(cat 2>/dev/null || true)"
cwd=""
if command -v jq >/dev/null 2>&1; then cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)"; fi
[ -n "$cwd" ] || cwd="$PWD"
root=$(cc_state_root "$cwd") || exit 0
# The root's board only: `dk decision --consume` clears rows there, so a <subdir>/.design-kit/ would repeat on every prompt.
dec="$root/.design-kit/decisions.jsonl"
[ -s "$dec" ] || exit 0

# Shared block templates/blocks/phase-guard.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/phase-guard.md
# No template directive in these comments: _expand_includes copies this file raw, then conditionals and substitution run over all of it.
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

sid=$(printf '%s' "$input" | jq -r '.session_id // ""' 2>/dev/null)
cc_phase_guard 'design-kit:unread-pick' || exit 0

python3 - "$dec" <<'PY'
import json, sys
rows = []
for ln in open(sys.argv[1], encoding="utf-8"):
    try: rows.append(json.loads(ln))
    except ValueError: pass
unread = [r for r in rows if not r.get("consumed")]
if not unread: sys.exit(0)
r = unread[-1]
who = r.get("board") or "a board"
pick = ("artboard %s" % r["picked"]) if r.get("picked") else "knob/text edits, no artboard picked"
extra = "" if len(unread) == 1 else " (+%d earlier)" % (len(unread) - 1)
print("design-kit: %s has an unread pick — %s%s. `dk.sh decision --latest --consume` reads it; /design-kit:in-codebase with no arguments renders it." % (who, pick, extra))
PY
exit 0
