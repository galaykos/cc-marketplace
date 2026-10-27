#!/usr/bin/env bash
# check-version-bumps.sh [base-ref] — FAILs a plugin whose functional files changed in base...HEAD (base: origin/master, else master) without a strictly higher plugin.json version (sort -V), or whose CHANGELOG.md has no `##` entry for the new version.
# Exempt: new plugins and plugin-root README/CHANGELOG/ROADMAP edits (:(glob), so template/README.md counts). Misses: uncommitted work (it reads HEAD), a substantive README rewrite; no CHANGELOG.md is only a WARN.
# Why, limits, history: rationale/derivations/scripts.md § scripts/check-version-bumps.sh
set -u
cd "$(dirname "$0")/.."

base="${1:-}"
if [ -z "$base" ]; then
  if   git rev-parse --verify -q origin/master >/dev/null; then base=origin/master
  elif git rev-parse --verify -q master        >/dev/null; then base=master
  else echo "no base ref (origin/master|master) available; skipping version-bump check" >&2; exit 0
  fi
fi
git rev-parse --verify -q "$base" >/dev/null || { echo "base ref '$base' not found; skipping" >&2; exit 0; }
command -v jq >/dev/null 2>&1 || { echo "FAIL: jq is required" >&2; exit 1; }

fail=0
# Plugin dirs with any change since the merge-base with $base (three-dot diff).
changed=$(git diff --name-only "$base"...HEAD -- plugins/ \
  ':(exclude,glob)plugins/*/README.md' \
  ':(exclude,glob)plugins/*/CHANGELOG.md' \
  ':(exclude,glob)plugins/*/ROADMAP.md' \
  | sed -nE 's#^(plugins/[^/]+)/.*#\1#p' | sort -u)

[ -z "$changed" ] && { echo "OK: no plugin changes to version-check"; exit 0; }

for dir in $changed; do
  name=$(basename "$dir")
  pj="$dir/.claude-plugin/plugin.json"
  # Deleted plugin (no current manifest) → nothing to bump.
  [ -f "$pj" ] || { echo "note: plugin '$name' has no plugin.json (deleted?), skipping" >&2; continue; }
  cur=$(jq -r '.version // empty' "$pj" 2>/dev/null)
  base_pj=$(git show "$base:$pj" 2>/dev/null || true)
  # New plugin (no manifest at base) → first release, exempt.
  [ -z "$base_pj" ] && continue
  base_ver=$(printf '%s' "$base_pj" | jq -r '.version // empty' 2>/dev/null)
  if [ -n "$cur" ]; then
    # Strict increase: base_ver must sort-V strictly below cur. Equality (no bump)
    # and downgrades both fail. New plugins (no base manifest) exited above.
    smallest=$(printf '%s\n%s\n' "$base_ver" "$cur" | sort -V | head -1)
    if [ "$cur" = "$base_ver" ]; then
      echo "FAIL: plugin '$name' changed but version not bumped (still $cur) — bump $pj" >&2
      fail=1
    elif [ "$smallest" != "$base_ver" ]; then
      echo "FAIL: plugin '$name' version went backwards ($base_ver -> $cur) — must increase" >&2
      fail=1
    fi
    # CHANGELOG coverage: FAIL once a plugin ships CHANGELOG.md, else WARN — a hard rule for all would demand backfilled, invented history.
    if [ -f "$dir/CHANGELOG.md" ]; then
      # Anchored to a `##` heading: a substring matched an inherited changelog's old numbering and passed unreleased versions.
      if ! grep -Eq "^##[[:space:]]*\[?${cur//./\\.}\]?([[:space:]]|$)" "$dir/CHANGELOG.md" 2>/dev/null; then
        echo "FAIL: plugin '$name' bumped to $cur but $dir/CHANGELOG.md has no entry for it" >&2
        fail=1
      fi
    else
      echo "WARN: plugin '$name' bumped $base_ver -> $cur with no CHANGELOG.md — the consumer has no artifact naming what changed" >&2
    fi
  fi
done

[ "$fail" -eq 0 ] && echo "OK: every changed plugin bumped its version" || exit 1
