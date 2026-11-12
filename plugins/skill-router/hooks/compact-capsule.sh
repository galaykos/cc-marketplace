#!/bin/bash
# SessionStart (matcher compact): lists the task state on disk at the project root a compaction summary may drop (this session's phase sentinel, task-runner run and scope lock, taskmaster ledgers) and logs whether a sentinel present is the payload session's. Advisory; fails open.
# Misses whether a ledger is still live (it prints started_at; each owner's TTL decides), state kept outside the paths named here, and the reasoning behind a phase or a card.
# Why, limits, history: rationale/derivations/plugin-skill-router.md § plugins/skill-router/hooks/compact-capsule.sh

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

# Shared block templates/blocks/plugin-state.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/plugin-state.md
# cc_plugin_state <root> <name> prints the plugin's own state dir for <root>, a cc_state_root result:
# CLAUDE_PLUGIN_DATA/<basename>-<cksum>/<name> if non-empty, else <root>/.claude/<name>. Status 0; creates nothing.
# The host keeps one data dir per plugin id, not per project (2.1.282); LC_ALL=C: a UTF-8 tr stops at an invalid byte.
# Misses: state another plugin, a skill or the user reads must not use it; an event lacking the variable uses the repo.
cc_plugin_state() {
  local key sum
  if [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
    key=$(printf '%s' "$(basename -- "$1")" | LC_ALL=C tr -c 'A-Za-z0-9_-' '-')
    sum=$(printf '%s' "$1" | cksum | cut -d' ' -f1)
    printf '%s/%s-%s/%s\n' "${CLAUDE_PLUGIN_DATA%/}" "$key" "$sum" "$2"
  else
    printf '%s/.claude/%s\n' "$1" "$2"
  fi
  return 0
}
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
{
  command -v jq >/dev/null 2>&1 || exit 0
  input=$(cat)
  src=$(printf '%s' "$input" | jq -r '.source // empty' 2>/dev/null) || exit 0
  [ "$src" = "compact" ] || exit 0
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
  [ -n "$cwd" ] && [ -d "$cwd" ] || exit 0
  # The ledgers live at the project root: under the payload cwd, a compaction after `cd app/Models` would find none of them.
  root=$(cc_state_root "$cwd") || exit 0
  sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)

  lines=""
  add() { lines="${lines}- $1
"; }

  # Only this session's phase: another session's sentinel is not this conversation's state.
  own=$(cc_phase_file "$root" "$sid") || own=""
  if [ -n "$own" ] && [ -f "$own" ]; then
    phase=$(jq -r '.phase // empty' "$own" 2>/dev/null)
    owner=$(jq -r '.owner // empty' "$own" 2>/dev/null)
    since=$(jq -r '.started_at // empty' "$own" 2>/dev/null)
    [ -n "$phase" ] && add "arc phase \`$phase\`${owner:+ owned by $owner}${since:+ since $since}, declared by this session — ${own#"$root"/} (reminder hooks outside this phase stand down; the owner clears it)"
  fi

  f="$root/.claude/task-runner/active-run.json"
  if [ -f "$f" ]; then
    slug=$(jq -r '.slug // empty' "$f" 2>/dev/null)
    branch=$(jq -r '.branch // empty' "$f" 2>/dev/null)
    idx=$(jq -r '.index_path // empty' "$f" 2>/dev/null)
    add "registered task-runner run${slug:+ \`$slug\`}${branch:+ on branch $branch}${idx:+, cards at $idx} — .claude/task-runner/active-run.json (the completion gate still requires a recorded behavioral-gate pass before this run may stop clean)"
  fi

  f="$root/.claude/task-runner/scope.json"
  [ -f "$f" ] && add "scope lock active — .claude/task-runner/scope.json (edits outside it are warned; the run owns the list)"

  names=""
  for f in "$root"/.claude/taskmaster/ledger-*.md; do
    [ -f "$f" ] || continue
    names="${names}${names:+, }${f##*/}"
  done
  [ -n "$names" ] && add "open taskmaster ambiguity ledger(s): $names — .claude/taskmaster/ (grill offers Resume / Start fresh; do not re-ask what a ledger already settled)"

  names=""
  for f in "$root"/.claude/taskmaster/goal-ledger-*.md; do
    [ -f "$f" ] || continue
    names="${names}${names:+, }${f##*/}"
  done
  [ -n "$names" ] && add "goal ledger(s) from a hands-off run: $names — .claude/taskmaster/ (every auto-take is audited there)"

  # A sentinel on disk but none under this session's key: the id changed across the compaction, or the file is another session's.
  if [ -n "$sid" ] && [ -n "$(find "$root/.claude/cc-phase" -maxdepth 1 -name '*.json' 2>/dev/null | head -n 1)" ]; then
    match=false; [ -n "$own" ] && [ -f "$own" ] && match=true
    dir=$(cc_plugin_state "$root" skill-router)
    mkdir -p "$dir" 2>/dev/null && { [ -e "$dir/.gitignore" ] || printf '*\n' > "$dir/.gitignore" 2>/dev/null; } && printf '{"event":"compact","sentinel_session_matches_payload":%s}\n' "$match" >> "$dir/compact-log.jsonl" 2>/dev/null
  fi

  [ -n "$lines" ] || exit 0

  printf '[skill-router] Context was compacted. Task state on disk that the summary may have dropped:\n%s' "$lines"
  printf 'Read each file before acting on it; a stale entry is bounded by its owner'"'"'s TTL, not by this notice.\n'
} 2>/dev/null || exit 0
exit 0
