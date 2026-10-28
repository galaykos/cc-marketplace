#!/bin/bash
# inject.sh — SessionStart: injects <project root>/brain/INDEX.md as labelled project data (30 lines, 2 KB at most), with a staleness hint when files outside brain/ changed since its `built:` hash; with no map, a startup-only nudge in repos of 200+ tracked files. Writes nothing. Fails open.
# Misses: the nudge repeats in every new session; drift it cannot count (an unreachable `built:` hash) prints no number; during a task-runner run the refresh is only offered.
# Why, limits, history: rationale/derivations/plugin-brain.md § plugins/brain/hooks/inject.sh

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

{
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
  [ -n "$cwd" ] || exit 0
  [ -d "$cwd" ] || exit 0
  root=$(cc_state_root "$cwd") || exit 0

  index="$root/brain/INDEX.md"
  # The nudge is the plugin talking, not project data, so it sits outside the fenced block; the hook has no matcher, hence the startup test.
  if [ ! -f "$index" ] || [ ! -s "$index" ]; then
    [ "$(printf '%s' "$input" | jq -r '.source // "startup"' 2>/dev/null)" = startup ] || exit 0
    if command -v git >/dev/null 2>&1; then
      nfiles=$(git -C "$root" ls-files 2>/dev/null | wc -l | tr -d ' ') || nfiles=0
      [ "${nfiles:-0}" -ge 200 ] || exit 0
    fi
    printf '%s\n' "ℹ brain: no map for this project yet — run /brain index to create one."
    exit 0
  fi

  # Prefix-match `built:` against the full HEAD hash: a `--short` hash can widen after a fetch.
  built=$(head -1 "$index" | grep -oE 'built: [0-9a-f]+' | awk '{print $2}')
  hint=""; built_current=""
  if [ -n "$built" ] && command -v git >/dev/null 2>&1; then
    head_full=$(git -C "$root" rev-parse HEAD 2>/dev/null)
    if [ -n "$head_full" ]; then
      case "$head_full" in
        "$built"*) ;;  # current HEAD begins with the built prefix → map is fresh
        *)
          # git's own exit status, not a pipeline's: an unreachable hash must print no count. brain/ is excluded: the map's own commit is not drift.
          if changed=$(git -C "$root" diff --name-only "$built"..HEAD -- . ':(exclude)brain' 2>/dev/null); then
            drift=$(printf '%s' "$changed" | grep -c . | tr -d ' ')
            [ "$drift" = 0 ] && built_current=1
          else
            drift=""
          fi
          count=""
          [ -n "$drift" ] && [ "$drift" -ge 1 ] 2>/dev/null && count=", $drift files changed"
          # During a task-runner run only offer: its scope lock would order a brain/*.md write reverted.
          if [ -n "$built_current" ]; then
            :
          elif [ -n "$count" ] && [ "$drift" -le 5 ] \
             && [ ! -f "$root/.claude/task-runner/scope.json" ]; then
            hint="⚠ brain map is behind HEAD (built $built$count) — Claude: run the incremental /brain index refresh now, before other work; no need to ask."
          else
            hint="⚠ brain map is behind HEAD (built $built$count) — offer /brain index to refresh."
          fi
          ;;
      esac
    fi
  fi

  printf '%s\n' "--- BRAIN MAP (project data) ---"
  [ -n "$hint" ] && printf '%s\n' "$hint"
  head -c 2048 "$index" | head -n 30
  printf '\n%s\n' "--- END BRAIN MAP ---"
} 2>/dev/null
exit 0
