#!/bin/bash
# Absolute-path shebang (not `/usr/bin/env bash`): the fail-open guarantee must
# hold even under a stripped/broken PATH.
#
# SessionStart, matcher `compact` ONLY. Re-asserts the deliberation marker after a
# compaction has taken the decision out of the model's context.
#
# WHY THIS HOOK EXISTS. approach-deliberation's own SKILL.md says, under "Double-run
# guard", "Check the MARKER, never memory" — a heading citation, not a line number,
# because the line number here was 4 rows stale by 2026-09-15. The marker is
# `.claude/approaches/deliberated.json` and
# it survives compaction perfectly well. What does NOT survive is the model's
# knowledge that a deliberation happened at all, so it never thinks to look. The
# documented failure is a compacted session re-litigating a shape that was already
# decided: the marker was on disk the whole time and nothing pointed at it.
#
# WHY SessionStart AND NOT PreCompact. PreCompact is the intuitive choice and it
# does not work: Claude Code writes PreCompact stdout to the debug log and never
# adds it to the model's context. The documented exceptions are UserPromptSubmit,
# UserPromptExpansion, SessionStart and PostModelSwitch. SessionStart is also the
# event that carries a `compact` source, so it is both the only channel that
# reaches the model and the only one that knows a compaction just happened.
#
# WHY IT COSTS NOTHING IN THE COMMON CASE. The matcher is `compact`, so this is
# silent on startup, resume, clear and fork. A session that never compacts never
# pays. A session that compacts pays ~40 tokens once per compaction — set against
# re-running a four-persona blind panel, which is what it prevents.
#
# LIMITATION (honest scope):
#   - Advisory. SessionStart stdout informs a turn; it cannot block one. If the
#     model re-deliberates anyway, nothing here stops it.
#   - It re-asserts THAT a decision exists and which task it was for. It does not
#     restore the REASONING — the alternatives weighed, the kill-trigger. Those
#     live in the transcript the compaction just summarized, and no hook can pull
#     them back.
#   - It cannot tell whether the marker's task is still the task in hand. A marker
#     from an abandoned task is announced exactly like a live one for as long as it
#     is inside the TTL below; the skill's own staleness rules still apply. What the
#     TTL removes is only the UNBOUNDED case — a marker with no writer left alive
#     announcing a decision forever, because nothing but this hook ever read it and
#     nothing at all ever deleted it (AR 11, 2026-09-22).
#   - Marker-shaped only. A deliberation that ran and never wrote the marker is
#     invisible here, the same blind spot the skill already carries.
#
# WHERE IT LOOKS: the project root (state-root block below), not the payload cwd. The
# cwd follows the model's `cd` (finding 2, rationale/2026-09-25-session-plugin-usage-
# review.md), so a compaction after `cd app/Models` looked for the marker in
# app/Models/.claude/ and announced nothing. The message names the absolute path it
# found, for the same reason.

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
  command -v jq >/dev/null 2>&1 || exit 0

  input=$(cat)
  src=$(printf '%s' "$input" | jq -r '.source // empty' 2>/dev/null) || exit 0
  # Belt and braces: the hooks.json matcher already scopes this to compaction, but
  # a hand-edited settings.json could wire it without one.
  [ "$src" = "compact" ] || exit 0

  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
  [ -n "$cwd" ] && [ -d "$cwd" ] || exit 0
  root=$(cc_state_root "$cwd") || exit 0

  marker="$root/.claude/approaches/deliberated.json"
  [ -f "$marker" ] || exit 0

  # TTL, mtime, 120 minutes — the same number and the same mechanism as the shared
  # phase sentinel (templates/blocks/phase-guard.md, cc_phase_ttl_min), deliberately,
  # because the two files have the same shape of problem: prose writes them, nothing
  # deletes them, and a silent reader that trusts a dead one has no remedy. mtime, not
  # a timestamp field: portable shell cannot parse ISO-8601, and the file is rewritten
  # whenever a new deliberation lands, so mtime IS the decision's age.
  #
  # Past the TTL: IGNORE and DELETE. Deleting is the point — leaving it would re-run
  # this find on every compaction of every future session for a decision nobody can
  # still act on. Expiring early degrades to today's pre-hook behaviour (the model
  # re-deliberates, which is a cost in tokens); expiring late re-asserts a decision the
  # session has moved past, which is a cost in WRONG WORK. The two are not symmetric,
  # so this errs toward forgetting.
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
