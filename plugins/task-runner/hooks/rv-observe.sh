#!/bin/bash
# PostToolUse on Agent/Task/Skill in a registered run: records, at the project root, that a dispatch carrying RV-CARD, RV-RANGE, RT-LENS or RT-CRITIC was made (rv/, rt/ records the completion gate counts); silent, blocks nothing.
# Misses: whether the subagent read anything, acted on it or was the right one (its transcript is not visible here); a marker outside tool_input. Fails open.
# Why, limits, history: rationale/derivations/plugin-task-runner.md § plugins/task-runner/hooks/rv-observe.sh

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
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  [ -n "$cwd" ] || exit 0
  root=$(cc_state_root "$cwd") || exit 0

  # A closed-run.json is a run between its closing rename and candor's last read: a review then still counts.
  [ -r "$root/.claude/task-runner/active-run.json" ] || [ -r "$root/.claude/task-runner/closed-run.json" ] || exit 0

  # The whole tool_input, not `prompt` alone: a dispatch shape carrying the marker elsewhere still counts.
  blob=$(printf '%s' "$input" | jq -r '.tool_input // {} | tostring' 2>/dev/null)

  record() { # record <subdir> <prefix> <id> [<suffix>]
    case "$3" in '' | *[!a-zA-Z0-9._-]*) return 0 ;; esac
    case "${4:-}" in *[!a-zA-Z0-9._@-]*) return 0 ;; esac
    d="$root/.claude/task-runner/$1"
    mkdir -p "$d" 2>/dev/null || return 0
    [ -w "$d" ] || return 0
    # Idempotent by id: several reviewers dispatch per card, and the gate counts one record per card.
    printf '{"id":"%s","dispatched":true}\n' "$3" > "$d/$2-$3${4:-}.json" 2>/dev/null
  }

  m=$(printf '%s' "$blob" | grep -oE 'RV-CARD: ?[a-zA-Z0-9._-]{1,64}' | head -1)
  if [ -n "$m" ]; then
    v=${m#RV-CARD:}; record rv rv-seen "${v# }"
    # One file per card and reviewer type too: the completion clause asks for ui-ux-reviewer by name on a UI card.
    t=$(printf '%s' "$input" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null | tr ':' '.')
    [ -z "$t" ] || record rv rv-agent "${v# }" "@$t"
  fi

  m=$(printf '%s' "$blob" | grep -oE 'RV-RANGE: ?[0-9a-f]{7,40}' | head -1)
  [ -n "$m" ] && { v=${m#RV-RANGE:}; record rv range "${v# }"; }

  m=$(printf '%s' "$blob" | grep -oE 'RT-LENS: ?[a-zA-Z0-9._-]{1,64}' | head -1)
  [ -n "$m" ] && { v=${m#RT-LENS:}; record rt rt-lens "${v# }"; }

  m=$(printf '%s' "$blob" | grep -oE 'RT-CRITIC: ?[a-zA-Z0-9._-]{1,64}' | head -1)
  [ -n "$m" ] && { v=${m#RT-CRITIC:}; record rt rt-critic "${v# }"; }
} 2>/dev/null
exit 0
