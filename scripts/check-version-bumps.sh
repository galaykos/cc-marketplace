#!/usr/bin/env bash
# Fail if a plugin's files changed vs a base ref but its plugin.json version did
# NOT strictly INCREASE (sort -V) — rejects both a missing bump (version equal to
# base) and a downgrade (version below base). Complements scripts/validate.sh
# (which is static/structural and does not look at history). Runs in CI on pull
# requests; also runnable locally before
# pushing:  bash scripts/check-version-bumps.sh [base-ref]   (default: origin/master)
#
# New plugins (no manifest at base) are exempt — a first release needs no bump.
#
# DOC-ONLY changes are exempt too: a typo fix in a plugin's root README.md,
# CHANGELOG.md or ROADMAP.md does not force a semver bump. Before this filter,
# correcting one character in plugins/i18n/README.md failed the gate.
# The exclusions use :(glob) so `*` does NOT cross a directory separator —
# plugins/x/template/README.md is shipped code and still forces a bump.
#
# LIMITATION (honest scope): this converts "a doc typo silently demands a
# version bump" into "only functional changes demand one". It cannot tell a
# substantive README rewrite from a typo — a real documentation change now ships
# without a bump unless the author bumps deliberately.
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
    # CHANGELOG COVERAGE (added 2026-08-02). A bump the consumer cannot read is a
    # version number, not a release. Verified before this landed: 0 git tags across
    # the repository and 0 of 58 leaves shipping a CHANGELOG.md, while validate.sh
    # has always ALLOWED one and this script already excludes it from triggering a
    # bump. So a user upgrading `laravel` 0.3.1 -> 0.4.0 had no artifact anywhere
    # naming what changed.
    #
    # Deliberately WARN, not FAIL, and the reason is the same one that kept the
    # version-stamp gate a warning until its verification pass ran: making it hard
    # today would demand 58 backfilled changelogs describing releases nobody
    # recorded at the time, i.e. invented history in the file whose whole job is
    # history. It hardens per plugin: once a plugin HAS a CHANGELOG.md, an entry
    # for the new version is required, so adopting the file opts that plugin in.
    if [ -f "$dir/CHANGELOG.md" ]; then
      if ! grep -qF "$cur" "$dir/CHANGELOG.md" 2>/dev/null; then
        echo "FAIL: plugin '$name' bumped to $cur but $dir/CHANGELOG.md has no entry for it" >&2
        fail=1
      fi
    else
      echo "WARN: plugin '$name' bumped $base_ver -> $cur with no CHANGELOG.md — the consumer has no artifact naming what changed" >&2
    fi
  fi
done

[ "$fail" -eq 0 ] && echo "OK: every changed plugin bumped its version" || exit 1
