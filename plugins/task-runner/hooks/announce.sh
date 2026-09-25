#!/bin/bash
# Absolute-path shebang (not `/usr/bin/env bash`): the fail-open guarantee must hold
# under a stripped or broken PATH.
#
# SessionStart, matcher `startup|resume|clear`. Says ONE line when this project has a
# REGISTERED task-runner run on disk, so a session that opens cold already knows the
# run exists before it does anything else.
#
# THE GAP IT CLOSES. `.claude/task-runner/active-run.json` survives the session that
# wrote it; the model's knowledge of it does not. candor's Stop gate (clause 4) reads
# that sentinel and refuses a clean stop until the run is closed, so a fresh session
# that has never heard of the run meets the block at the END of its first turn with no
# idea what it is about — and the cheapest-looking escape is deleting the sentinel of a
# run that is still live. skill-router's compact-capsule.sh covers the same files after
# a COMPACTION (matcher `compact`); this covers the cold session, and the two matchers
# do not overlap, so a project with both installed hears it once.
#
# WHAT IT READS, all three pure reads, nothing is written, from the project root (the
# state-root block below; a session started in a subdirectory still finds the run):
#   .claude/task-runner/active-run.json  slug, branch, index_path (run.md step 1)
#   .claude/cc-phase.json                phase and owner, when a phase is declared
#   <index_path>                         the card table's status column, for the count
#
# STANDING: advisory. SessionStart `additionalContext` informs a turn; it cannot block
# one, and nothing checks that the session acts on it. The teeth for an unclosed run
# are candor's Stop gate, not this line.
#
# HONEST LIMITATIONS, all four real:
#   1. It cannot tell a LIVE run from an abandoned one. There is no TTL on the sentinel
#      and this hook adds none: it reports the branch the run registered so a reader can
#      see at a glance whether the run belongs to the tree in front of them, and leaves
#      the judgement there.
#   2. The card count is the INDEX's bookkeeping, not the work. A row is "remaining"
#      when its status cell does not begin done/parked/skipped, so a run that never
#      updated its index reads as zero done, and a card marked done by hand reads as
#      done. It counts what was written down.
#   3. It parses the `| NN | … | status |` table task-cards writes. An index in some
#      other shape yields no counts and the line still names slug and branch.
#   4. Matcher-scoped to startup|resume|clear. A run registered DURING a session is
#      never announced in that session — the session that registered it knows.
#
# Off switch: CC_REMIND=off (every reminder in this marketplace). Fail-open on missing
# jq, malformed payload, an unreadable sentinel or an unreadable index.
# --- state root ----------------------------------------------------------------
# Canonical copy: templates/blocks/state-root.md. Every hook defining cc_state_root must
# carry this block byte-for-byte (pc_shared_blocks); generated hooks include it.
# The payload's `cwd` is the SHELL's cwd and follows the model's `cd` — measured
# 2026-09-25: app/Enums, then app/Models, then the repo root in one session, each leaving
# its own `.claude/` state dir and each re-firing a "once per session" nudge. State lives
# at the project root instead (pc_state_root refuses a raw `$cwd/.claude` path in a hook):
# the git toplevel reached by walking UP from cwd (`--show-cdup`, so a symlinked /tmp keeps
# the caller's spelling and path-prefix comparisons still hold); outside git,
# CLAUDE_PROJECT_DIR when cwd sits under it; else cwd. A cwd that no longer exists yields
# nothing and status 1 — the caller exits rather than resurrect a deleted project.
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
  case "${CC_REMIND:-on}" in off) exit 0 ;; esac
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
        }
        END { if (total > 0) printf "%d of %d cards still open", total - closed, total }
      ' "$abs" 2>/dev/null)
    fi
  fi

  phase=""
  f="$root/.claude/cc-phase.json"
  if [ -r "$f" ]; then
    p=$(jq -r '.phase // empty' "$f" 2>/dev/null)
    o=$(jq -r '.owner // empty' "$f" 2>/dev/null)
    [ -n "$p" ] && phase=", arc phase \`$p\`${o:+ owned by $o}"
  fi

  # `HEAD` is what rev-parse prints for a detached or unborn head — not a branch name,
  # so it is never compared: a repo with no commits would otherwise be told it is "on
  # HEAD" and the line would look wrong at exactly the moment it should say nothing.
  here=$(git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null)
  elsewhere=""
  [ -n "$branch" ] && [ -n "$here" ] && [ "$here" != "HEAD" ] && [ "$branch" != "$here" ] \
    && elsewhere=" (you are on \`$here\`)"

  msg=$(printf '[task-runner] A run is registered on disk: `%s`%s%s%s%s. Read .claude/task-runner/active-run.json%s before starting anything else — candor'"'"'s Stop gate refuses a clean stop while this sentinel exists, and deleting it is how a LIVE run gets abandoned. Resume it with /task-runner:run, or remove the sentinel and .claude/cc-phase.json only once every card is done or parked.' \
    "$slug" "${branch:+ on branch \`$branch\`}" "$elsewhere" "${cards:+ — $cards}" "$phase" "${index:+ and $index}")
  jq -cn --arg m "$msg" \
    '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$m}}' 2>/dev/null
} 2>/dev/null
exit 0
