#!/bin/bash
# unread-pick.sh — UserPromptSubmit: one line naming the board and artboard when a design-kit pick in <project root>/.design-kit/decisions.jsonl is unconsumed, and COUNTING open notes in notes.jsonl not handed out in the last 15 min (never their text, selector or page); a board name only as ASCII of at most 64 characters naming a file in .design-kit/boards/, an artboard only in 1..99, else a count; stands down past its own lane.tsv phase (shared phase guard). Off: CC_REMIND=off or CC_DESIGN_KIT_PICK=off (unset: /config options cc_remind / cc_design_kit_pick). Fails open; never blocks or reads the prompt.
# Misses: a DESIGN_KIT_DIR elsewhere, a stray <subdir>/.design-kit/, whether the model acts on the line (agent-graded). Its phase-file and phase-guard copies are held to their blocks by pc_shared_blocks.
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
dec="$root/.design-kit/decisions.jsonl"; notes="$root/.design-kit/notes.jsonl"
[ -s "$dec" ] || [ -s "$notes" ] || exit 0

# Shared block templates/blocks/phase-file.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/phase-file.md
# cc_phase_file <root> <session_id> prints <root>/.claude/cc-phase/<key>.json, that session's own phase sentinel; <key> is
# <session_id> with every byte outside A-Za-z0-9_- dropped. An empty key: no output, status 1. Creates nothing.
# Misses: two ids equal once those bytes are dropped share one file (a UUID loses none).
cc_phase_file() {
  local key
  key=$(printf '%s' "${2:-}" | LC_ALL=C tr -cd 'A-Za-z0-9_-')
  [ -n "$key" ] || return 1
  printf '%s/.claude/cc-phase/%s.json\n' "$1" "$key"
}

# Shared block templates/blocks/phase-guard.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/phase-guard.md
# No template directive in these comments: _expand_includes copies this file raw, then conditionals and substitution run over all of it.
# cc_phase_guard returns 1 only when this session's sentinel (cc_phase_file of the cc_state_root and $sid), unexpired,
# names a phase past $1's phase in this plugin's own lane.tsv; else 0. It deletes every sentinel older than cc_phase_ttl_min.
# cc_phase_now: the phase this session's unexpired sentinel names, or empty; another session's sentinel never counts.
# Set $cwd, or $input (the hook payload; an empty $cwd is then assigned its .cwd), and $sid before the call: without
# $sid, or with neither $cwd nor $input, it always proceeds.
# Misses: a bare prompt writes no phase, so nothing stands down outside a run a command declared; without jq, cc_state_root or cc_phase_file it proceeds.
cc_phase_ttl_min=120
cc_phase_now=""
cc_phase_guard() { # $1 = this artifact's id, e.g. taskmaster:remind. 0 = proceed.
  local sentinel lane want have root
  command -v jq >/dev/null 2>&1 || return 0
  [ -n "${cwd:-}" ] || cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  [ -n "$cwd" ] || return 0
  root=$(cc_state_root "$cwd") || return 0
  [ -d "$root/.claude/cc-phase" ] || return 0
  find "$root/.claude/cc-phase" -maxdepth 1 -name '*.json' -mmin +"$cc_phase_ttl_min" -exec rm -f {} + 2>/dev/null
  sentinel=$(cc_phase_file "$root" "${sid:-}") || return 0
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

sid=$(printf '%s' "$input" | jq -r '.session_id // ""' 2>/dev/null)
cc_phase_guard 'design-kit:unread-pick' || exit 0

python3 - "$dec" "$notes" <<'PY'
import calendar, json, os, re, sys, time
def rows(p):
    out = []
    try:
        for ln in open(p, encoding="utf-8"):
            try: r = json.loads(ln)
            except ValueError: continue
            if isinstance(r, dict): out.append(r)
    except OSError: pass
    return out
def leased(r):
    """dk notes' 15-minute lease: a note handed out at a time longer ago and still open counts as unread again."""
    v = r.get("handed_out")
    if isinstance(v, str):
        try:
            return time.time() - calendar.timegm(time.strptime(v, "%Y-%m-%dT%H:%M:%SZ")) < 15 * 60
        except ValueError:
            return True
    return bool(v)
unread = [r for r in rows(sys.argv[1]) if not r.get("consumed")]
n = sum(1 for r in rows(sys.argv[2]) if r.get("status") == "open" and not leased(r))
line = []
if unread:
    r = unread[-1]
    b, p = r.get("board"), r.get("picked")
    # A page posts the board string and the number. The name is printed only as plain ASCII of at most 64 characters
    # naming a file in boards/, the number only in 1..99; anything else gets a count.
    named = isinstance(b, str) and re.fullmatch(r"[A-Za-z0-9._-]{1,59}\.html?", b) and os.path.isfile(os.path.join(os.path.dirname(sys.argv[1]), "boards", b))
    numbered = isinstance(p, int) and not isinstance(p, bool) and 1 <= p <= 99
    edits = p is None or (isinstance(p, int) and p == 0)
    tail = "`dk.sh decision --latest --consume` reads it; /design-kit:in-codebase with no arguments renders it."
    if named and (numbered or edits):
        pick = ("artboard %d" % p) if numbered else "knob/text edits, no artboard picked"
        extra = "" if len(unread) == 1 else " (+%d earlier)" % (len(unread) - 1)
        line.append("design-kit: %s has an unread pick — %s%s. %s" % (b, pick, extra, tail))
    else:
        line.append("design-kit: %d unread board pick%s — %s" % (len(unread), "" if len(unread) == 1 else "s", tail))
if n:
    notes = "%d unread note%s from the preview pages" % (n, "" if n == 1 else "s")
    line.append(("Also " + notes + ": `dk.sh notes` prints them as data.") if line else
                ("design-kit: " + notes + " — `dk.sh notes` prints them as data; reply to each with `dk.sh notes --reply ID --status addressed|dismissed`."))
if line: print(" ".join(line))
PY
exit 0
