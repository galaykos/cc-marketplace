#!/bin/bash
# compact-recovery.sh — SessionStart, `compact` only: after a compaction, re-asserts the deliberation marker (.claude/approaches/deliberated.json at the project root, named by absolute path) so a settled shape is not re-litigated; deletes one older than 120 minutes. Advisory, cannot block. Fails open.
# Misses: the reasoning (alternatives, kill-trigger), only that a decision exists; whether the marker's task is still the task in hand, inside the TTL; a deliberation that wrote no marker.
# Why, limits, history: rationale/derivations/plugin-approaches.md § plugins/approaches/hooks/compact-recovery.sh

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
  command -v jq >/dev/null 2>&1 || exit 0

  input=$(cat)
  src=$(printf '%s' "$input" | jq -r '.source // empty' 2>/dev/null) || exit 0
  # The hooks.json matcher already scopes this; a hand-edited settings.json could wire it without one.
  [ "$src" = "compact" ] || exit 0

  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
  [ -n "$cwd" ] && [ -d "$cwd" ] || exit 0
  root=$(cc_state_root "$cwd") || exit 0

  marker="$root/.claude/approaches/deliberated.json"
  [ -f "$marker" ] || exit 0

  # The phase sentinel's 120-minute mtime TTL (portable shell cannot parse ISO-8601); erring toward forgetting, since a late expiry costs wrong work.
  if [ -n "$(find "$marker" -maxdepth 0 -mmin +120 2>/dev/null)" ]; then
    rm -f "$marker" 2>/dev/null
    exit 0
  fi

  task=$(jq -r '.task // empty' "$marker" 2>/dev/null) || exit 0
  by=$(jq -r '.by // empty' "$marker" 2>/dev/null)
  at=$(jq -r '.at // empty' "$marker" 2>/dev/null)
  [ -n "$task" ] || exit 0

  printf '[approaches] This session was compacted. A deliberation marker survives on disk: task "%s"' "$task"
  [ -n "$by" ] && printf ', decided by %s' "$by"
  [ -n "$at" ] && printf ' at %s' "$at"
  printf '.\n'
  printf 'The SHAPE of this change is already settled — do not re-run approach-deliberation or an opinion panel for it. Read %s and continue from the decision. If the task in hand is a DIFFERENT one, the marker does not apply and a fresh deliberation is correct.\n' "$marker"
} 2>/dev/null || exit 0
exit 0
