#!/bin/bash
# SessionStart (startup|resume|clear): one advisory line naming a registered run at the project root (slug, branch, open cards, phase), so a cold session knows it before candor's Stop gate refuses a clean stop.
# Misses: a live run from an abandoned one (no TTL), work the index's status column does not record, an index without `| NN |` rows (no count), a run registered this session. CC_REMIND=off, else /config cc_remind; fails open.
# Why, limits, history: rationale/derivations/plugin-task-runner.md § plugins/task-runner/hooks/announce.sh

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

{
  case "$(cc_option CC_REMIND on)" in off) exit 0 ;; esac
  command -v jq >/dev/null 2>&1 || exit 0
  input=$(cat)
  src=$(printf '%s' "$input" | jq -r '.source // empty' 2>/dev/null) || exit 0
  case "$src" in startup|resume|clear|'') ;; *) exit 0 ;; esac
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
  [ -n "$cwd" ] && [ -d "$cwd" ] || exit 0
  root=$(cc_state_root "$cwd") || exit 0

  sentinel="$root/.claude/task-runner/active-run.json"
  [ -r "$sentinel" ] || exit 0
  slug=$(jq -r '.slug // empty' "$sentinel" 2>/dev/null) || exit 0
  branch=$(jq -r '.branch // empty' "$sentinel" 2>/dev/null)
  index=$(jq -r '.index_path // empty' "$sentinel" 2>/dev/null)

  cards=""
  if [ -n "$index" ]; then
    abs="$index"
    case "$abs" in /*) ;; *) abs="$root/$abs" ;; esac
    if [ -r "$abs" ]; then
      cards=$(awk -F'|' '
        /^[[:space:]]*\|[[:space:]]*[0-9][0-9][[:space:]]*\|/ {
          total++
          s = $NF; if (s ~ /^[[:space:]]*$/ && NF > 1) s = $(NF - 1)
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); s = tolower(s)
          if (s ~ /^(done|parked|skipped)/) closed++
          else if (s != "" && s !~ /^(pending|in[ _-]?progress|blocked)/) odd++
        }
        END {
          if (total > 0) printf "%d of %d cards still open", total - closed, total
          if (odd > 0) printf " (%d with a status outside pending, in_progress, done, parked, blocked: counted open)", odd
        }
      ' "$abs" 2>/dev/null)
    fi
  fi

  phase=""
  f="$root/.claude/cc-phase.json"
  if [ -r "$f" ]; then
    p=$(jq -r '.phase // empty' "$f" 2>/dev/null)
    o=$(jq -r '.owner // empty' "$f" 2>/dev/null)
    [ -n "$p" ] && phase=", phase \`$p\`${o:+ set by $o}"
  fi

  # symbolic-ref, not --abbrev-ref: a tag named like the branch makes that print heads/<branch>. Exit 1 is a detached HEAD; other failures are never compared.
  here=$(git -C "$root" symbolic-ref -q HEAD 2>/dev/null)
  case $? in 0) here=${here#refs/heads/} ;; 1) here=HEAD ;; *) here="" ;; esac
  elsewhere=""
  [ -n "$branch" ] && [ -n "$here" ] && [ "$branch" != "$here" ] \
    && elsewhere=" (you are on \`$here\`)"

  msg=$(printf '[task-runner] Run in progress: `%s`%s%s%s%s. Continue it with /task-runner:run%s; do not delete .claude/task-runner/active-run.json until the run is finished.' \
    "$slug" "${branch:+ on branch \`$branch\`}" "$elsewhere" "${cards:+ — $cards}" "$phase" "${index:+ (cards in $index)}")
  jq -cn --arg m "$msg" \
    '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$m}}' 2>/dev/null
} 2>/dev/null
exit 0
