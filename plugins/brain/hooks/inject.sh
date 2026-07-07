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
  [ -f "$index" ] || exit 0
  [ -s "$index" ] || exit 0

  # Staleness hint: the header records `built: <short-hash>`. Prefix-match it against
  # the FULL current HEAD hash — robust to git's abbreviation length changing over time
  # (a bare `--short` can widen after a fetch and cause a spurious mismatch).
  built=$(head -1 "$index" | grep -oE 'built: [0-9a-f]+' | awk '{print $2}')
  hint=""
  if [ -n "$built" ] && command -v git >/dev/null 2>&1; then
    head_full=$(git -C "$cwd" rev-parse HEAD 2>/dev/null)
    if [ -n "$head_full" ]; then
      case "$head_full" in
        "$built"*) ;;  # current HEAD begins with the built prefix → map is fresh
        *) hint="⚠ brain map is behind HEAD (built $built) — run /brain index to refresh." ;;
      esac
    fi
  fi

  printf '%s\n' "--- BRAIN MAP (project data) ---"
  [ -n "$hint" ] && printf '%s\n' "$hint"
  head -c 2048 "$index" | head -n 30
  printf '\n%s\n' "--- END BRAIN MAP ---"
} 2>/dev/null
exit 0
