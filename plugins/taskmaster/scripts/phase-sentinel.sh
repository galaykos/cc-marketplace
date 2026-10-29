#!/bin/bash
# phase-sentinel.sh write <phase> --owner <plugin:command> [--session <id>] [--cwd <dir>] | clear [--cwd <dir>] — the one script writer of <project root>/.claude/cc-phase.json; refuses an unknown phase (exit 3), which the reader (templates/blocks/phase-guard.md) would read as no sentinel. Exit 0 wrote or cleared (clearing an absent one too), 3 usage. Without --session the sentinel silences reminder hooks in every session sharing .claude/ (a warning, not a failure).
# Misses: clearing on its own (each entry command removes what it wrote; the reader's 120-minute mtime TTL is a backstop, not a lifecycle); whether the caller owns the phase it writes or clears; a command writing the JSON by hand (no gate; standing: recorded); whether a reader honours the verdict (agent-graded, pc_phase_guard).
# Why, limits, history: rationale/derivations/plugin-taskmaster.md § plugins/taskmaster/scripts/phase-sentinel.sh

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

PROG=phase-sentinel
usage() { printf '%s: usage error: %s\n' "$PROG" "$1" >&2; exit 3; }

# The arc, in order; must match cc_phase_ix in templates/blocks/phase-guard.md, or a phase in one list silently means nothing.
PHASES="understand shape decide plan build verify review ship"

cmd="${1:-}"; shift 2>/dev/null || true
phase=""; owner=""; session=""; cwd="$PWD"

case "$cmd" in
  write)
    phase="${1:-}"; shift 2>/dev/null || true
    [ -n "$phase" ] || usage "write requires a phase (one of: $PHASES)"
    case "$phase" in -*) usage "write requires a phase before its flags (got: $phase)" ;; esac
    ;;
  clear) ;;
  ""|-h|--help)
    printf 'usage: %s write <phase> --owner <plugin:command> [--session <id>] [--cwd <dir>]\n' "$PROG" >&2
    printf '       %s clear [--cwd <dir>]\n' "$PROG" >&2
    printf '       phases: %s\n' "$PHASES" >&2
    exit 3 ;;
  *) usage "unknown subcommand: $cmd (want write|clear)" ;;
esac

while [ $# -gt 0 ]; do
  case "$1" in
    --owner)   shift; [ $# -gt 0 ] || usage "--owner requires a value"; owner="$1"; shift ;;
    --owner=*)   owner="${1#--owner=}"; shift ;;
    --session) shift; [ $# -gt 0 ] || usage "--session requires a value"; session="$1"; shift ;;
    --session=*) session="${1#--session=}"; shift ;;
    --cwd)     shift; [ $# -gt 0 ] || usage "--cwd requires a value"; cwd="$1"; shift ;;
    --cwd=*)     cwd="${1#--cwd=}"; shift ;;
    *) usage "unknown argument: $1" ;;
  esac
done

[ -d "$cwd" ] || usage "--cwd is not a directory: $cwd"
root=$(cc_state_root "$cwd") || usage "cannot resolve a project root from: $cwd"
sentinel="$root/.claude/cc-phase.json"

if [ "$cmd" = clear ]; then
  rm -f "$sentinel" 2>/dev/null
  printf '%s: cleared %s\n' "$PROG" "$sentinel" >&2
  exit 0
fi

ok=0
for p in $PHASES; do [ "$phase" = "$p" ] && ok=1; done
[ "$ok" = 1 ] || usage "unknown phase '$phase' (want one of: $PHASES)"
[ -n "$owner" ] || usage "write requires --owner <plugin:command>"

[ -n "$session" ] || printf '%s: no --session given; the sentinel will apply to every session sharing %s/.claude/\n' "$PROG" "$root" >&2

mkdir -p "$root/.claude" 2>/dev/null || usage "cannot create $root/.claude"

started_at=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null) || started_at=""

# printf, not jq: a command body's machine may lack jq; quotes, backslashes and control characters are stripped so the reader can always parse it.
scrub() { printf '%s' "$1" | tr -d '"\\' | tr -d '\000-\037'; }
{
  printf '{"phase":"%s","owner":"%s"' "$(scrub "$phase")" "$(scrub "$owner")"
  [ -n "$session" ]    && printf ',"session_id":"%s"' "$(scrub "$session")"
  [ -n "$started_at" ] && printf ',"started_at":"%s"' "$started_at"
  printf '}\n'
} > "$sentinel" 2>/dev/null || usage "cannot write $sentinel"

printf '%s: wrote %s (phase=%s owner=%s)\n' "$PROG" "$sentinel" "$phase" "$owner" >&2
exit 0
