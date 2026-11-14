#!/bin/bash
# shape-guard.sh — PreToolUse on Edit|Write|MultiEdit: denies a write to a project file outside .cc-artifacts/, .claude/ and an older project's taskmaster-docs/ while this session's `shape` sentinel from /taskmaster:brainstorm (cc_phase_file, owner taskmaster:brainstorm, under 120 min old) is live; visual-decisions' __design-preview__ scratch writes pass. Fails open.
# Misses: writes through Bash (heredoc, sed -i, python) and NotebookEdit; a `..` path where realpath lacks -m -s (stock macOS); files outside the project root; the agent clearing the sentinel itself; taskmaster:task's own shape phase, which is not guarded. Standing: gate.
# Why, limits, history: rationale/derivations/plugin-taskmaster.md § plugins/taskmaster/hooks/shape-guard.sh

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

{
  command -v jq >/dev/null 2>&1 || exit 0
  input=$(cat)
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
  path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
  [ -n "$cwd" ] && [ -n "$path" ] || exit 0
  root=$(cc_state_root "$cwd") || exit 0
  sentinel=$(cc_phase_file "$root" "$sid") || exit 0
  # Plugins before 2026-11-14 wrote the sentinel under .claude/cc-phase/; read it when the new one is absent.
  [ -r "$sentinel" ] || sentinel=$(cc_phase_file_legacy "$root" "$sid") || exit 0
  [ -r "$sentinel" ] || exit 0
  [ -z "$(find "$sentinel" -maxdepth 0 -mmin +120 2>/dev/null)" ] || exit 0
  [ "$(jq -r '.phase // empty' "$sentinel" 2>/dev/null)" = shape ] || exit 0
  [ "$(jq -r '.owner // empty' "$sentinel" 2>/dev/null)" = taskmaster:brainstorm ] || exit 0

  case "$path" in /*) ;; *) path="$cwd/$path" ;; esac
  if r=$(realpath -m -s -- "$root") && p=$(realpath -m -s -- "$path"); then root=$r; path=$p; fi
  case "$path" in
    *__design-preview__*|"$root"/.cc-artifacts/*|"$root"/taskmaster-docs/*|"$root"/.claude/*) exit 0 ;;
    "$root"/*) ;;
    *) exit 0 ;;
  esac
  # visual-decisions' real-component rung loads its scratch route by one marker-carrying line in an existing file.
  printf '%s' "$input" | jq -r '[.tool_input.new_string, .tool_input.content, (.tool_input.edits // [] | .[].new_string)] | map(. // "") | join("\n")' 2>/dev/null \
    | grep -q '__design-preview__' && exit 0
  rel=${path#"$root"/}
  jq -cn --arg r "[taskmaster] Brainstorm is still shaping the design, so no implementation file yet: $rel. Write only the design doc under .cc-artifacts/taskmaster/ until the user approves the design; brainstorm clears this phase on approval or when the run is abandoned." \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
} 2>/dev/null
exit 0
