#!/usr/bin/env bash
# Fail if a plugin's files changed vs a base ref but its plugin.json version did
# NOT bump. Complements scripts/validate.sh (which is static/structural and does
# not look at history). Runs in CI on pull requests; also runnable locally before
# pushing:  bash scripts/check-version-bumps.sh [base-ref]   (default: origin/master)
#
# New plugins (no manifest at base) are exempt — a first release needs no bump.
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
changed=$(git diff --name-only "$base"...HEAD -- plugins/ | sed -nE 's#^(plugins/[^/]+)/.*#\1#p' | sort -u)

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
  if [ -n "$cur" ] && [ "$cur" = "$base_ver" ]; then
    echo "FAIL: plugin '$name' changed but version not bumped (still $cur) — bump $pj" >&2
    fail=1
  fi
done

[ "$fail" -eq 0 ] && echo "OK: every changed plugin bumped its version" || exit 1
