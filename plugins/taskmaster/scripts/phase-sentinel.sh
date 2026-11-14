#!/bin/bash
# phase-sentinel.sh write <phase> --owner <plugin:command> --session <id> [--cwd <dir>] | clear --session <id> [--cwd <dir>] — the one script writer of a session's own phase sentinel, <project root>/.cc-artifacts/cc-phase/<key>.json (cc_phase_file); refuses an unknown phase or no session (exit 3); clear removes only that session's file, at that path and at cc_phase_file_legacy. Exit 0 wrote or cleared (an absent one too), 3 usage. Removes a legacy repo-wide .claude/cc-phase.json that names no session, names this one, or is past the 120-minute TTL; readers ignore it.
# Misses: clearing on its own (each entry command removes what it wrote; readers delete files past the TTL); a caller passing another session's id; a command writing the JSON by hand (no gate; standing: recorded); whether a reader honours the verdict (agent-graded, pc_phase_guard).
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

# Shared block templates/blocks/phase-file.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/phase-file.md
# cc_phase_file <root> <session_id> prints <root>/.cc-artifacts/cc-phase/<key>.json, that session's own phase sentinel; <key> is
# <session_id> with every byte outside A-Za-z0-9_- dropped. An empty key: no output, status 1. Creates nothing.
# cc_phase_file_legacy: the same key under <root>/.claude/cc-phase/, where plugins wrote it before 2026-11-14; read it, never write it.
# Misses: two ids equal once those bytes are dropped share one file (a UUID loses none).
cc_phase_file() {
  local key
  key=$(printf '%s' "${2:-}" | LC_ALL=C tr -cd 'A-Za-z0-9_-')
  [ -n "$key" ] || return 1
  printf '%s/.cc-artifacts/cc-phase/%s.json\n' "$1" "$key"
}
cc_phase_file_legacy() {
  local key
  key=$(printf '%s' "${2:-}" | LC_ALL=C tr -cd 'A-Za-z0-9_-')
  [ -n "$key" ] || return 1
  printf '%s/.claude/cc-phase/%s.json\n' "$1" "$key"
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
    printf 'usage: %s write <phase> --owner <plugin:command> --session <id> [--cwd <dir>]\n' "$PROG" >&2
    printf '       %s clear --session <id> [--cwd <dir>]\n' "$PROG" >&2
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
# No session, no file: a sentinel every session reads is the cross-session leak this layout exists to close.
sentinel=$(cc_phase_file "$root" "$session") \
  || usage "$cmd requires --session <this session's id> (letters, digits, _ or -): each session reads and clears only its own sentinel"

if [ "$cmd" = write ]; then
  ok=0
  for p in $PHASES; do [ "$phase" = "$p" ] && ok=1; done
  [ "$ok" = 1 ] || usage "unknown phase '$phase' (want one of: $PHASES)"
  [ -n "$owner" ] || usage "write requires --owner <plugin:command>"
fi

# Legacy: one repo-wide file before taskmaster 0.56.0. No reader looks at it now; an old-version session may still own one.
legacy="$root/.claude/cc-phase.json"
if [ -f "$legacy" ]; then
  lsid=$(sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$legacy" 2>/dev/null | head -n 1)
  if [ -z "$lsid" ] || [ "$lsid" = "$session" ] || [ -n "$(find "$legacy" -maxdepth 0 -mmin +120 2>/dev/null)" ]; then
    rm -f "$legacy" 2>/dev/null
  fi
fi

if [ "$cmd" = clear ]; then
  # Plugins before 2026-11-14 wrote the sentinel under .claude/cc-phase/; readers fall back to it, so clear it too.
  rm -f "$sentinel" "$(cc_phase_file_legacy "$root" "$session")" 2>/dev/null
  printf '%s: cleared %s\n' "$PROG" "$sentinel" >&2
  exit 0
fi

dir=$(dirname "$sentinel")
mkdir -p "$dir" 2>/dev/null || usage "cannot create $dir"
[ -e "$dir/.gitignore" ] || printf '*\n' > "$dir/.gitignore" 2>/dev/null

started_at=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null) || started_at=""

# printf, not jq: a command body's machine may lack jq; quotes, backslashes and control characters are stripped so the reader can always parse it.
# Written beside the target, then renamed: a reader in another hook never sees half a file.
scrub() { printf '%s' "$1" | tr -d '"\\' | tr -d '\000-\037'; }
tmp="$sentinel.$$.tmp"
{
  printf '{"phase":"%s","owner":"%s","session_id":"%s"' "$(scrub "$phase")" "$(scrub "$owner")" "$(scrub "$session")"
  [ -n "$started_at" ] && printf ',"started_at":"%s"' "$started_at"
  printf '}\n'
} > "$tmp" 2>/dev/null && mv -f "$tmp" "$sentinel" 2>/dev/null \
  || { rm -f "$tmp" 2>/dev/null; usage "cannot write $sentinel"; }

printf '%s: wrote %s (phase=%s owner=%s)\n' "$PROG" "$sentinel" "$phase" "$owner" >&2
exit 0
