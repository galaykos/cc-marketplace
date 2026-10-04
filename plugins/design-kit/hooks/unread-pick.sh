#!/bin/bash
# unread-pick.sh — UserPromptSubmit: one line, only when a board pick is waiting.
#
# WHAT IT CATCHES. The user picked an artboard on a design-kit board (the board
# posted it to the server's loopback /_decision route → .design-kit/decisions.jsonl)
# and then typed a prompt without telling the session. Prints ONE line naming the
# board and artboard so the session reads the pick instead of asking for it — the
# "session watching the board" half of the decision channel, without polling.
#
# WHAT IT DOES NOT DO. It never blocks, never reads the prompt, and says nothing
# when every row is consumed or no board exists. Turn-taking is not hand-rolled here:
# it runs the marketplace's shared phase guard (templates/blocks/phase-guard.md,
# inlined below) against its OWN lane.tsv row, so the phase list cannot drift from
# the declaration the way a hardcoded one did — that copy read build|verify|review|ship
# and spoke through `plan`, and had no TTL and no session check, so a sentinel left by
# a run that died muted this channel in every later session. Off with CC_REMIND=off or
# CC_DESIGN_KIT_PICK=off.
# CC_REMIND / CC_DESIGN_KIT_PICK unset: the /config options cc_remind / cc_design_kit_pick decide.
#
# WHERE IT LOOKS. The phase sentinel and .design-kit/decisions.jsonl are read at the
# project root, not the payload cwd, which follows the model's `cd` (finding 2,
# rationale/2026-09-25-session-plugin-usage-review.md) — so both shared blocks are
# inlined below: state-root (held byte-identical to templates/blocks/state-root.md by
# pc_shared_blocks) and phase-guard. dk.sh resolves its .design-kit/ with the same
# state-root block, so writer and reader agree from any directory. An explicit
# DESIGN_KIT_DIR elsewhere is not seen here. NO gate holds the phase-guard copy to its
# block — keeping the two identical is by hand, **recorded**.
#
# FAIL-OPEN, like every hook here: no python3, no jq, no readable sentinel, a foreign
# session or a stale one all mean "proceed" or "say nothing", never an error on the
# user's prompt. `set -e` is deliberately absent — an unset variable or a non-zero
# probe must not take the prompt down with it.
#
# Standing: scripts/__tests__/unread-pick.test.sh drives silent, one-line, consumed,
# phase-gated, stale-sentinel, subdirectory-cwd and no-python3 cases — **gate** (CI globs every
# plugins/*/scripts/__tests__/*.test.sh). Nothing proves the model ACTS on the line
# (agent-graded), and nothing here proves the guard is honoured on a branch the
# harness does not drive.

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

[ "$(cc_option CC_REMIND on)" = "off" ] && exit 0
[ "$(cc_option CC_DESIGN_KIT_PICK on)" = "off" ] && exit 0
command -v python3 >/dev/null 2>&1 || exit 0
input="$(cat 2>/dev/null || true)"
cwd=""
if command -v jq >/dev/null 2>&1; then cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)"; fi
[ -n "$cwd" ] || cwd="$PWD"
root=$(cc_state_root "$cwd") || exit 0
# The root's board only. dk.sh anchors .design-kit/ at this same root (the same
# cc_state_root), and `dk decision --consume` clears rows there — so a stray
# <subdir>/.design-kit/ left by a dk.sh before 0.5.1 is not announced: the consume this
# line tells the model to run could never clear it, and it would repeat on every prompt.
dec="$root/.design-kit/decisions.jsonl"
[ -s "$dec" ] || exit 0

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
