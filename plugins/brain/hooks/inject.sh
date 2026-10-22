#!/bin/bash
# Absolute-path shebang (not `/usr/bin/env bash`): the fail-open guarantee must hold
# even under a stripped/broken PATH.
# SessionStart: injects brain/INDEX.md (≤30 lines / 2 KB, labelled project data) with a staleness hint; with no map, a one-line nudge
#   on a project's first startup only (≥200 tracked files), recorded by a marker in the plugin's data dir. Fail-open.
# Misses: a failed marker write repeats the nudge next session; a project moved to a new path is a new project.
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

{
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
  [ -n "$cwd" ] || exit 0
  [ -d "$cwd" ] || exit 0
  root=$(cc_state_root "$cwd") || exit 0

  index="$root/brain/INDEX.md"
  # No map: the plugin talking, outside the project-data fence, once per project on a startup.
  # Why, limits, history: rationale/derivations/plugin-brain.md § The no-map nudge
  if [ ! -f "$index" ] || [ ! -s "$index" ]; then
    [ "$(printf '%s' "$input" | jq -r '.source // "startup"' 2>/dev/null)" = startup ] || exit 0
    # Size-gate the nudge: a map only pays in repos with real surface area. Small
    # repos (<200 tracked source-ish files) never see the hint. Fast index read,
    # fail-open like everything else here.
    if command -v git >/dev/null 2>&1; then
      nfiles=$(git -C "$root" ls-files 2>/dev/null | wc -l | tr -d ' ') || nfiles=0
      [ "${nfiles:-0}" -ge 200 ] || exit 0
    fi
    seen="$(cc_plugin_state "$root" brain)/nudged"
    [ -e "$seen" ] && exit 0
    mkdir -p "${seen%/*}" 2>/dev/null && : > "$seen" 2>/dev/null
    printf '%s\n' "ℹ brain: no map for this project yet — run /brain index to create one. (Shown once per project.)"
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
  hint=""; built_current=""
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
          # count.
          # brain/ itself is excluded: committing the map advances HEAD past its own
          # `built:` stamp, so counting it ordered an unasked refresh every session after,
          # which the indexer answered "already current" and restamped
          # (rationale/marketplace-taskforce-review-2026-10-11.md). Zero files changed
          # outside brain/ — the map's own commit, an empty or a reverted one — means the
          # map is current: no hint at all.
          if changed=$(git -C "$root" diff --name-only "$built"..HEAD -- . ':(exclude)brain' 2>/dev/null); then
            drift=$(printf '%s' "$changed" | grep -c . | tr -d ' ')
            [ "$drift" = 0 ] && built_current=1
          else
            drift=""
          fi
          count=""
          [ -n "$drift" ] && [ "$drift" -ge 1 ] 2>/dev/null && count=", $drift files changed"
          # An active task-runner run advances HEAD per card; its scope-lock hook would
          # flag a brain/*.md write as out-of-scope and order it reverted. During a run,
          # demote the "refresh now" imperative to the passive offer so the two hooks
          # never issue opposite instructions on the same edit.
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
