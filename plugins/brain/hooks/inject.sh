#!/bin/bash
# Absolute-path shebang (not `/usr/bin/env bash`): the fail-open guarantee must hold
# even under a stripped/broken PATH.
# SessionStart primer for the `brain` plugin. Injects the committed codebase map
# (brain/INDEX.md), delimited and labeled as project data and bounded to ~30 lines /
# ~2 KB, with a one-line staleness hint when the map predates the current commit.
# Fail-open: any error exits silently and emits nothing.
{
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
  [ -n "$cwd" ] || exit 0
  [ -d "$cwd" ] || exit 0

  index="$cwd/brain/INDEX.md"
  # Discoverability nudge: plugin enabled but no map yet → emit one short hint so it is
  # not silently forgettable. This is the plugin talking (not project data), so it is NOT
  # inside the fenced block. The nudge stops for good the moment a map exists. Still a pure
  # read — no state written.
  if [ ! -f "$index" ] || [ ! -s "$index" ]; then
    # Size-gate the nudge: a map only pays in repos with real surface area. Small
    # repos (<200 tracked source-ish files) never see the hint. Fast index read,
    # fail-open like everything else here.
    if command -v git >/dev/null 2>&1; then
      nfiles=$(git -C "$cwd" ls-files 2>/dev/null | wc -l | tr -d ' ') || nfiles=0
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
    head_full=$(git -C "$cwd" rev-parse HEAD 2>/dev/null)
    if [ -n "$head_full" ]; then
      case "$head_full" in
        "$built"*) ;;  # current HEAD begins with the built prefix → map is fresh
        *)
          drift=$(git -C "$cwd" diff --name-only "$built"..HEAD 2>/dev/null | wc -l | tr -d ' ') || drift=""
          if [ -n "$drift" ] && [ "$drift" -ge 1 ] 2>/dev/null && [ "$drift" -le 5 ]; then
            hint="⚠ brain map is behind HEAD (built $built, $drift files changed) — Claude: run the incremental /brain index refresh now, before other work; no need to ask."
          else
            hint="⚠ brain map is behind HEAD (built $built${drift:+, $drift files changed}) — offer /brain index to refresh."
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
