#!/usr/bin/env bash
# codebase-cleanup.sh — remove every scratch file codebase-scaffold.sh wrote.
#
# WHAT IT CATCHES. Any path containing `__design-kit__` under the project (skipping
# node_modules, vendor, .git, .design-kit) is deleted, and every line carrying the
# `__design-kit__ scratch` marker is stripped from routes/web.php and from any .css
# file (the scaffold's Tailwind v4 `@source` line), restoring each file's bytes —
# including a missing final newline. `--verify` only lists leftovers and exits 1 if
# any exist — the gate a command runs after the pick, so "cleaned up" is proven, not
# asserted.
#
# WHAT IT DOES NOT CATCH. A scratch import the model added to an EXISTING file
# (a provider registered in app.tsx, a route in a file other than routes/web.php)
# carries no marker and survives; the skill forbids that edit and `git status`
# is the check. A marked line in a .css under node_modules or vendor is not searched.
# Standing: scripts/__tests__/codebase.test.sh drives remove and --verify on its
# fixtures and cmp's the stylesheet and routes file against their originals.
set -euo pipefail

MARK="__design-kit__ scratch"
verify=0
case "${1:-}" in --verify) verify=1 ;; "") ;; -h|--help) sed -n '2,16p' "$0"; exit 0 ;; *) echo "codebase-cleanup.sh: unknown argument $1" >&2; exit 2 ;; esac

leftovers=()
while IFS= read -r p; do leftovers+=("$p"); done < <(
  find . \( -name node_modules -o -name vendor -o -name .git -o -name .design-kit \) -prune -o -path '*__design-kit__*' -print 2>/dev/null | sort
)
marked=()  # real files carrying marked lines: the route file and an entry stylesheet
while IFS= read -r f; do marked+=("${f#./}"); done < <(
  { [ -f routes/web.php ] && grep -lF "$MARK" routes/web.php
    grep -rlF --include='*.css' --exclude-dir=node_modules --exclude-dir=vendor --exclude-dir=.git \
      --exclude-dir=.design-kit --exclude-dir=__design-kit__ "$MARK" . ; } 2>/dev/null | sort -u
)
hits=0
for f in "${marked[@]:-}"; do [ -n "$f" ] && hits=$(( hits + $(grep -cF "$MARK" "$f") )); done

if [ "$verify" = 1 ]; then
  n=$(( ${#leftovers[@]} + hits ))
  if [ "$n" -eq 0 ]; then echo "cleanup: clean"; exit 0; fi
  for p in "${leftovers[@]:-}"; do [ -n "$p" ] && echo "leftover=$p"; done
  for f in "${marked[@]:-}"; do [ -n "$f" ] && echo "leftover=$f ($(grep -cF "$MARK" "$f") marked line(s))"; done
  echo "cleanup: $n leftover(s)"; exit 1
fi

for p in "${leftovers[@]:-}"; do
  [ -n "$p" ] || continue
  [ -e "$p" ] || continue
  rm -rf "$p"; echo "removed=$p"
done
for f in "${marked[@]:-}"; do
  [ -n "$f" ] || continue
  n=$(grep -cF "$MARK" "$f")
  # the scaffold wrote "\n<line>" into a file that ended without a newline; drop that "\n" too
  python3 - "$f" "$MARK" <<'PY'
import sys
p, mark = sys.argv[1], sys.argv[2].encode()
ls = open(p, "rb").read().splitlines(keepends=True)
out = b"".join(l for l in ls if mark not in l)
if ls and mark in ls[-1] and not ls[-1].endswith(b"\n") and out.endswith(b"\n"):
    out = out[:-1]
open(p, "wb").write(out)
PY
  echo "stripped=$f ($n line(s))"
done
echo "cleanup: done"
