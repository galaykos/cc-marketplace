#!/usr/bin/env bash
# codebase-cleanup.sh — remove every scratch file codebase-scaffold.sh wrote.
#
# WHAT IT CATCHES. Any path containing `__design-kit__` under the project (skipping
# node_modules, vendor, .git, .design-kit) is deleted, and every line carrying the
# `__design-kit__ scratch` marker is stripped from routes/web.php. `--verify` only
# lists leftovers and exits 1 if any exist — the gate a command runs after the
# pick, so "cleaned up" is proven, not asserted.
#
# WHAT IT DOES NOT CATCH. A scratch import the model added to an EXISTING file
# (a provider registered in app.tsx, a route in a file other than routes/web.php)
# carries no marker and survives; the skill forbids that edit and `git status`
# is the check. Standing: scripts/__tests__/codebase.test.sh drives remove and
# --verify on two fixtures.
set -euo pipefail

MARK="__design-kit__ scratch"
verify=0
case "${1:-}" in --verify) verify=1 ;; "") ;; -h|--help) sed -n '2,16p' "$0"; exit 0 ;; *) echo "codebase-cleanup.sh: unknown argument $1" >&2; exit 2 ;; esac

leftovers=()
while IFS= read -r p; do leftovers+=("$p"); done < <(
  find . \( -name node_modules -o -name vendor -o -name .git -o -name .design-kit \) -prune -o -path '*__design-kit__*' -print 2>/dev/null | sort
)
route_hits=0
[ -f routes/web.php ] && route_hits=$(grep -c "$MARK" routes/web.php || true)

if [ "$verify" = 1 ]; then
  n=$(( ${#leftovers[@]} + route_hits ))
  if [ "$n" -eq 0 ]; then echo "cleanup: clean"; exit 0; fi
  for p in "${leftovers[@]:-}"; do [ -n "$p" ] && echo "leftover=$p"; done
  [ "$route_hits" -gt 0 ] && echo "leftover=routes/web.php ($route_hits marked line(s))"
  echo "cleanup: $n leftover(s)"; exit 1
fi

for p in "${leftovers[@]:-}"; do
  [ -n "$p" ] || continue
  [ -e "$p" ] || continue
  rm -rf "$p"; echo "removed=$p"
done
if [ "$route_hits" -gt 0 ]; then
  tmp="$(mktemp)"; grep -v "$MARK" routes/web.php > "$tmp" || true
  cat "$tmp" > routes/web.php; rm -f "$tmp"
  echo "stripped=routes/web.php ($route_hits line(s))"
fi
echo "cleanup: done"
