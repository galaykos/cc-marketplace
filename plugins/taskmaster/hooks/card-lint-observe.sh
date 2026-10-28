#!/bin/bash
# card-lint-observe.sh — PostToolUse, main thread only: once per transcript and card set, warns (never blocks) when a card of the registered taskmaster-index run (.claude/task-runner/active-run.json at the project root) has no card-shape, verify-teeth or skills-stamp lint record. Off: CC_CARDLINT=off or CC_REMIND=off (unset: /config options cc_cardlint / cc_remind). Fails open.
# Misses: a set run without /task-runner:run, a recorded `block` verdict, hand-written records, spec-ledger records (written, not graded), cards past 60; in a fanned-out run the first main-thread write may follow the first card.
# Why, limits, history: rationale/derivations/plugin-taskmaster.md § plugins/taskmaster/hooks/card-lint-observe.sh

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
  case "$(cc_option CC_CARDLINT on)" in off) exit 0 ;; esac
  case "$(cc_option CC_REMIND on)" in off) exit 0 ;; esac
  command -v jq >/dev/null 2>&1 || exit 0

  input=$(cat)
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
  [ -n "$cwd" ] || exit 0
  aid=$(printf '%s' "$input" | jq -r '.agent_id // empty' 2>/dev/null)
  [ -z "$aid" ] || exit 0                        # a subagent: main thread only, see header
  root=$(cc_state_root "$cwd") || exit 0

  # Cheapest test first: a session with no registered run must cost one git rev-parse and one stat.
  sentinel="$root/.claude/task-runner/active-run.json"
  [ -r "$sentinel" ] || exit 0
  index=$(jq -r '.index_path // empty' "$sentinel" 2>/dev/null) || exit 0
  [ -n "$index" ] || exit 0                      # a non-index run has no card set
  case "$index" in /*) ;; *) index="$root/$index" ;; esac
  [ -r "$index" ] || exit 0

  # The relative fallback lets the harness drive this file directly; the warning quotes this root.
  tmroot="${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}"
  . "$tmroot/scripts/card-lint-record.sh" 2>/dev/null || exit 0
  command -v cardlint_has >/dev/null 2>&1 || exit 0

  set_dir=$(dirname "$index")
  total=0; miss_n=0; named=""
  for card in "$set_dir"/[0-9][0-9]-*.md; do
    [ -f "$card" ] || continue
    base=$(basename "$card")
    case "$base" in 00-*) continue ;; esac      # the index is not a card
    # A card: named by the index (basename, or its number opening a table row) or in a shape card-shape-lint accepts.
    grep -qF -- "$base" "$index" 2>/dev/null \
      || grep -Eq "^[[:space:]]*\|[[:space:]]*${base%%-*}[[:space:]]*\|" "$index" 2>/dev/null \
      || grep -Eq '^<card( |>)|\*\*Verify:\*\*' "$card" 2>/dev/null || continue
    total=$((total + 1))
    [ "$total" -gt 60 ] && break                # bounded: this runs inside the turn
    gaps=""
    cardlint_has card-shape "$card"   || gaps="card-shape"
    cardlint_has verify-teeth "$card" || gaps="${gaps:+$gaps+}verify-teeth"
    cardlint_has skills-stamp "$card" || gaps="${gaps:+$gaps+}skills-stamp"
    [ -n "$gaps" ] || continue
    miss_n=$((miss_n + 1))
    [ "$miss_n" -le 4 ] && named="${named:+$named; }$base ($gaps)"
  done
  [ "$miss_n" -gt 0 ] || exit 0                  # every card has a record — silent

  # The index path in the key lets a second card set in one transcript warn too.
  tp=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
  key=$(printf '%s|%s' "${tp:-no-transcript}" "$index" | cksum | cut -d' ' -f1)
  marker="${TMPDIR:-/tmp}/cc-cardlint-warned-$key"
  # A bound that cannot be recorded means no warning: one with no working one-shot repeats on every edit.
  mkdir "$marker" 2>/dev/null || exit 0
  find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'cc-cardlint-warned-*' -type d -mmin +1440 \
    -exec rmdir {} + 2>/dev/null

  [ "$miss_n" -gt 4 ] && named="$named; +$((miss_n - 4)) more"
  msg=$(printf '[taskmaster] card-lint: %s of %s card(s) in %s reached this run with no recorded lint — %s. Per card, before executing it: %s/scripts/card-shape-lint.sh --card <card> (blocks a role-tagged card missing a section or an attribute), %s/scripts/verify-teeth-lint.sh --card <card> (blocks a toothless Verify line) and %s/scripts/skills-stamp-lint.sh --card <card> (blocks a framework card stamped "none"). Warning only, nothing is blocked.' \
    "$miss_n" "$total" "$(basename "$set_dir")" "$named" "$tmroot" "$tmroot" "$tmroot")
  jq -cn --arg r "$msg" \
    '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$r}}'
} 2>/dev/null
exit 0
