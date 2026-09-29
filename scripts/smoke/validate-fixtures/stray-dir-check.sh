#!/usr/bin/env bash
# Stray-directory harness: proves pc_stray_dirs (scripts/lib/plugin-checks.sh) names a
# plugins/<x>/ with no .claude-plugin/plugin.json, no tracked file and no *.md / *.json
# outside dot-dirs, and does NOT name a dir with a TRACKED file or an UNTRACKED README.md —
# so the skip validate.sh builds from it cannot hide a half-made plugin. The wiring check
# greps the live validate.sh for the call, the message and the three is_stray readers.
# Cause: plugins/design-studio/ held only a hook's marker files and drew three FAILs about
# a plugin that never existed (rationale/marketplace-trend-audit-2026-09-16.md E1).
# CI step: .github/workflows/validate.yml "stray-directory gate harness".
#
# FIXTURE, NEVER THE LIVE TREE: a five-dir git repo under a temp dir — plugins/good
# (manifest, tracked), zz-half (a tracked notes.txt), then, AFTER the index is built, which
# is how scratch lands in a real checkout, zz-stray (only a dot-dir marker), zz-new (a
# README.md beside a dot-dir marker) and zz-manifest (only .claude-plugin/plugin.json, which
# the dot-dir prune hides, so only the manifest test keeps it off the list), all untracked.
# No validate.sh run.
#
# RESIDUAL: the three checklist FAILs a half-made plugin draws (`directory plugins/<x> not
# listed in marketplace.json`, `missing README.md: <x>`, `plugin '<x>' has no README.md
# plugin-table ROW`) are validate.sh's own checks and are no longer driven here. They are
# proven by composition: the classifier says such a dir is not stray, and is_stray reads
# only STRAY_DIRS, which only pc_stray_dirs' output feeds. The stray FAIL string and "only
# one output line names the dir" are proven end to end by parity-check.sh.
set -u
LIVE="$(cd "$(dirname "$0")/../../.." && pwd)" || exit 2
. "$LIVE/scripts/lib/plugin-checks.sh" || exit 2
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

FX="$T/fixture"
mkdir -p "$FX/plugins/good/.claude-plugin" "$FX/plugins/zz-half" || exit 2
printf '{"name":"good"}\n' > "$FX/plugins/good/.claude-plugin/plugin.json"
printf '# good\n' > "$FX/plugins/good/README.md"
: > "$FX/plugins/zz-half/notes.txt"
{ git -C "$FX" init -q && git -C "$FX" add plugins; } || { echo "FAIL: could not build the fixture index"; exit 1; }
mkdir -p "$FX/plugins/zz-stray/.claude/scratch" "$FX/plugins/zz-new/.claude/scratch" \
  "$FX/plugins/zz-manifest/.claude-plugin" || exit 2
printf '{"name":"zz-manifest"}\n' > "$FX/plugins/zz-manifest/.claude-plugin/plugin.json"
: > "$FX/plugins/zz-stray/.claude/scratch/marker"
: > "$FX/plugins/zz-new/.claude/scratch/marker"
printf '# zz-new\n' > "$FX/plugins/zz-new/README.md"

out=$(cd "$FX" && pc_stray_dirs plugins); src=$?
if [ "$out" = "stray zz-stray" ] && [ "$src" -eq 1 ]; then
  echo "PASS: stray dir — the classifier names it and nothing else"
else
  echo "FAIL: stray dir — want 'stray zz-stray' rc 1, got rc $src:"; printf '%s\n' "$out" | head -5; rc=1
fi
if printf '%s\n' "$out" | grep -qxF 'stray zz-half'; then
  echo "FAIL: a directory with a tracked file was called stray"; rc=1
else
  echo "PASS: tracked half-plugin — not called stray"
fi
if printf '%s\n' "$out" | grep -qxF 'stray zz-new'; then
  echo "FAIL: an untracked directory with a README.md was called stray"; rc=1
else
  echo "PASS: untracked half-plugin with a README.md — not called stray"
fi

rm -rf "$FX/plugins/zz-stray"
out=$(cd "$FX" && pc_stray_dirs plugins); src=$?
if [ -z "$out" ] && [ "$src" -eq 0 ]; then
  echo "PASS: a tree with no stray dir — rc 0, no output"
else
  echo "FAIL: a tree with no stray dir — want rc 0 and no output, got rc $src:"; printf '%s\n' "$out" | head -5; rc=1
fi

live_code=$(grep -v '^[[:space:]]*#' "$LIVE/scripts/validate.sh")
readers=$(printf '%s\n' "$live_code" | grep -c 'is_stray "' || true)
if printf '%s\n' "$live_code" | grep -qF 'pc_stray_dirs plugins' \
   && printf '%s\n' "$live_code" | grep -qF 'stray directory plugins/$name has no tracked files — delete it (a hook or editor left scratch here)' \
   && printf '%s\n' "$live_code" | grep -qF 'STRAY_DIRS="$STRAY_DIRS $name "' \
   && [ "$readers" -ge 3 ]; then
  echo "PASS: wiring — validate.sh calls pc_stray_dirs, carries the stray message, and still skips strays in its listing, README and table checks"
else
  echo "FAIL: wiring — validate.sh lacks the pc_stray_dirs call or the stray message, or has $readers is_stray reader(s), want >= 3"; rc=1
fi

[ "$rc" -eq 0 ] && echo "stray-dir-check: all PASS"
exit $rc
