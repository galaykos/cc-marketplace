#!/usr/bin/env bash
# Stray-directory harness: proves validate.sh draws ONE FAIL for a plugins/<x>/ that has
# no .claude-plugin/plugin.json, no tracked file and no *.md / *.json outside dot-dirs,
# and that the README-presence and plugin-table checks skip it — and that a directory
# with a TRACKED file but no manifest, or an UNTRACKED one carrying a README.md, still
# draws the three original FAILs, so the skip cannot hide a half-made plugin.
# Cause: plugins/design-studio/ held only a hook's marker files and drew three FAILs about
# a plugin that never existed (rationale/marketplace-trend-audit-2026-09-16.md E1).
# CI step: .github/workflows/validate.yml "stray-directory gate harness".
#
# RUN AGAINST A MIRROR, NEVER THE LIVE TREE (deference-check.sh's rule). The mirror gets
# its own git index because the gate reads `git ls-files`; the stray dir is planted AFTER
# the index is built, which is exactly how scratch lands in a real checkout.
set -u
LIVE="$(cd "$(dirname "$0")/../../.." && pwd)" || exit 2
cd "$LIVE" || exit 2
command -v jq >/dev/null 2>&1 || {
  [ -n "${CI:-}" ] && { echo "FAIL: jq missing on the CI runner"; exit 1; }
  echo "SKIP: jq not installed"; exit 0
}
rc=0
T=$(mktemp -d) || exit 2
cleanup() {
  bad=0
  for f in "$LIVE"/plugins/zz-*; do
    [ -e "$f" ] && { echo "FAIL: probe leaked into the live tree: $f"; bad=1; }
  done
  cd / 2>/dev/null || true
  rm -rf "$T"
  [ "$bad" -eq 0 ] || exit 1
}
trap cleanup EXIT INT TERM HUP

MIRROR="$T/mirror"; mkdir -p "$MIRROR"
for _d in plugins scripts templates .claude-plugin; do
  [ -e "$LIVE/$_d" ] && cp -R "$LIVE/$_d" "$MIRROR/" 2>/dev/null
done
for _f in CLAUDE.md README.md skills-lock.json; do
  [ -f "$LIVE/$_f" ] && cp "$LIVE/$_f" "$MIRROR/" 2>/dev/null
done
git -C "$MIRROR" init -q && git -C "$MIRROR" add -A || { echo "FAIL: could not build the mirror index"; exit 1; }

# 1. FAIL path — an untracked, manifest-less directory draws the stray message and nothing else
mkdir -p "$MIRROR/plugins/zz-stray/.claude/scratch" && : > "$MIRROR/plugins/zz-stray/.claude/scratch/marker"
vout=$( cd "$MIRROR" && bash scripts/validate.sh 2>&1 ) || true
hits=$(printf '%s\n' "$vout" | grep -c 'zz-stray' || true)
if printf '%s\n' "$vout" | grep -qF 'FAIL: stray directory plugins/zz-stray has no tracked files — delete it (a hook or editor left scratch here)' && [ "$hits" -eq 1 ]; then
  echo "PASS: stray dir — one FAIL, the stray message, and no other line names it"
else
  echo "FAIL: stray dir drew $hits line(s):"; printf '%s\n' "$vout" | grep 'zz-stray' | head -5; rc=1
fi
rm -rf "$MIRROR/plugins/zz-stray"

# 2. NOT-stray path — a manifest-less directory WITH a tracked file is a broken plugin,
#    not scratch: the three original FAILs fire and the stray message does not
mkdir -p "$MIRROR/plugins/zz-half" && : > "$MIRROR/plugins/zz-half/notes.txt"
git -C "$MIRROR" add plugins/zz-half/notes.txt
vout=$( cd "$MIRROR" && bash scripts/validate.sh 2>&1 ) || true
want() { printf '%s\n' "$vout" | grep -qF "$2" && echo "PASS: $1" || { echo "FAIL: $1 did not fire"; rc=1; }; }
want "tracked half-plugin — marketplace listing FAIL still fires" "directory plugins/zz-half not listed in marketplace.json"
want "tracked half-plugin — README-presence FAIL still fires" "missing README.md: zz-half"
want "tracked half-plugin — plugin-table FAIL still fires" "plugin 'zz-half' has no README.md plugin-table ROW"
if printf '%s\n' "$vout" | grep -q 'stray directory plugins/zz-half'; then
  echo "FAIL: a directory with a tracked file was called stray"; rc=1
else
  echo "PASS: tracked half-plugin — not called stray"
fi

rm -rf "$MIRROR/plugins/zz-half"

# 3. NOT-stray path — an untracked directory holding a README.md outside its dot-dirs is a
#    half-scaffolded plugin (2026-09-17 review H7): the checklist FAILs fire, "delete it"
#    does not. The dot-dir marker beside it is exactly the scratch case 1 catches alone.
mkdir -p "$MIRROR/plugins/zz-new/.claude/scratch" && : > "$MIRROR/plugins/zz-new/.claude/scratch/marker"
printf '# zz-new\n' > "$MIRROR/plugins/zz-new/README.md"
vout=$( cd "$MIRROR" && bash scripts/validate.sh 2>&1 ) || true
want "untracked half-plugin — marketplace listing FAIL still fires" "directory plugins/zz-new not listed in marketplace.json"
want "untracked half-plugin — plugin-table FAIL still fires" "plugin 'zz-new' has no README.md plugin-table ROW"
if printf '%s\n' "$vout" | grep -q 'stray directory plugins/zz-new'; then
  echo "FAIL: an untracked directory with a README.md was called stray"; rc=1
else
  echo "PASS: untracked half-plugin — not called stray"
fi

[ "$rc" -eq 0 ] && echo "stray-dir-check: all PASS"
exit $rc
