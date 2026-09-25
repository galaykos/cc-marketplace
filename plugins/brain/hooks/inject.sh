#!/bin/bash
# Absolute-path shebang (not `/usr/bin/env bash`): the fail-open guarantee must hold
# even under a stripped/broken PATH.
# SessionStart primer for the `brain` plugin. Injects the committed codebase map
# (brain/INDEX.md), delimited and labeled as project data and bounded to ~30 lines /
# ~2 KB, with a one-line staleness hint when the map predates the current commit.
# Fail-open: any error exits silently and emits nothing.
# Reads at the project root (state-root block below), not the payload cwd: the cwd
# follows the model's `cd` (finding 2, rationale/2026-09-25-session-plugin-usage-
# review.md), so a compaction's SessionStart after `cd app/Models` would look for
# app/Models/brain/INDEX.md, find none, and size-gate the nudge on that directory's
# files alone (`git ls-files` is cwd-relative).

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
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
  [ -n "$cwd" ] || exit 0
  [ -d "$cwd" ] || exit 0
  root=$(cc_state_root "$cwd") || exit 0

  index="$root/brain/INDEX.md"
  # Discoverability nudge: plugin enabled but no map yet → emit one short hint so it is
  # not silently forgettable. This is the plugin talking (not project data), so it is NOT
  # inside the fenced block. The nudge stops for good the moment a map exists. Still a pure
  # read — no state written.
  if [ ! -f "$index" ] || [ ! -s "$index" ]; then
    # Size-gate the nudge: a map only pays in repos with real surface area. Small
    # repos (<200 tracked source-ish files) never see the hint. Fast index read,
    # fail-open like everything else here.
    if command -v git >/dev/null 2>&1; then
      nfiles=$(git -C "$root" ls-files 2>/dev/null | wc -l | tr -d ' ') || nfiles=0
      [ "${nfiles:-0}" -ge 200 ] || exit 0
    fi
    printf '%s\n' "ℹ brain: no map for this project yet — run /brain index to create one."
    exit 0
  fi

  # Staleness hint: the header records `built: <short-hash>`. Prefix-match it against
  # the FULL current HEAD hash — robust to git's abbreviation length changing over time
  # (a bare `--short` can widen after a fetch and cause a spurious mismatch).
  # Small drift (≤5 changed files) self-heals: the hint instructs the MODEL to run the
  # incremental index right away — auto from the user's seat. Larger drift stays an
  # explicit offer (a big reindex spends real tokens; the user decides). The hook itself
  # still writes nothing — the model performs the refresh, visibly, in the session.
  built=$(head -1 "$index" | grep -oE 'built: [0-9a-f]+' | awk '{print $2}')
  hint=""
  if [ -n "$built" ] && command -v git >/dev/null 2>&1; then
    head_full=$(git -C "$root" rev-parse HEAD 2>/dev/null)
    if [ -n "$head_full" ]; then
      case "$head_full" in
        "$built"*) ;;  # current HEAD begins with the built prefix → map is fresh
        *)
          # The count must come from git's OWN exit status, not the pipeline's: piping to
          # `wc -l` made the status wc's, so a `built:` hash no longer reachable in the
          # repo (rebased, squashed, shallow clone, hand-edited stamp) fell through as
          # drift=0 and the hint read "behind HEAD (built <hash>, 0 files changed)" —
          # a number that contradicts the warning beside it. Unknown drift now prints no
          # count, and a real 0 (an empty or reverted commit) prints none either.
          if changed=$(git -C "$root" diff --name-only "$built"..HEAD 2>/dev/null); then
            drift=$(printf '%s' "$changed" | grep -c . | tr -d ' ')
          else
            drift=""
          fi
          count=""
          [ -n "$drift" ] && [ "$drift" -ge 1 ] 2>/dev/null && count=", $drift files changed"
          # An active task-runner run advances HEAD per card; its scope-lock hook would
          # flag a brain/*.md write as out-of-scope and order it reverted. During a run,
          # demote the "refresh now" imperative to the passive offer so the two hooks
          # never issue opposite instructions on the same edit.
          if [ -n "$count" ] && [ "$drift" -le 5 ] \
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
