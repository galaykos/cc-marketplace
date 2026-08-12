#!/usr/bin/env bash
# cleanup.sh — guarded deletion of a shadcn-studio scratch tree. The skill's
# rule "a run that leaves a scratch tree behind is a failed run" had four prose
# steps and no shell; this is the shell, with the safety checks the prose
# could not enforce.
#
# Usage: cleanup.sh <scratch-dir>
# Refuses to delete anything that is not provably a studio scratch tree:
# the dir must contain components.json AND a vite.config.ts carrying the
# /__studio marker route. Refuses /, $HOME, and any git work tree root.
set -u
dir="${1:-}"
[[ -n "$dir" ]] || { echo "usage: cleanup.sh <scratch-dir>"; exit 2; }
dir="$(cd "$dir" 2>/dev/null && pwd)" || { echo "cleanup: '$1' not a directory (already clean?)"; exit 0; }

[[ "$dir" == "/" || "$dir" == "$HOME" ]] && { echo "cleanup: REFUSED — '$dir' is not a scratch tree"; exit 3; }
[[ -e "$dir/.git" ]] && { echo "cleanup: REFUSED — '$dir' is a git work tree, not a scratch tree"; exit 3; }
[[ -f "$dir/components.json" ]] || { echo "cleanup: REFUSED — no components.json in '$dir'"; exit 3; }
grep -q "__studio" "$dir/vite.config.ts" 2>/dev/null \
  || { echo "cleanup: REFUSED — '$dir/vite.config.ts' carries no /__studio marker"; exit 3; }

# Port 8124 still serving the marker means a dev server is live in this tree.
if command -v curl >/dev/null 2>&1 \
  && curl -sf --max-time 2 http://localhost:8124/__studio 2>/dev/null | grep -q "shadcn-studio"; then
  echo "cleanup: a studio dev server is still running on :8124 — stop it first"
  exit 4
fi

rm -rf "$dir" || { echo "cleanup: rm failed for '$dir'"; exit 1; }
[[ -e "$dir" ]] && { echo "cleanup: '$dir' still exists after rm"; exit 1; }
echo "cleanup: removed scratch tree $dir"
exit 0
