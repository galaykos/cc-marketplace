#!/usr/bin/env bash
# codebase-cleanup.sh — remove every scratch file codebase-scaffold.sh wrote; --verify only lists leftovers and exits 1. dk.sh runs both from the project root.
# Catches: any path holding `__design-kit__`, and every marked line in a .css or a routes/web.php, outside node_modules, vendor, .git, .cc-artifacts, .design-kit; each file's bytes come back.
# Misses: a scratch edit to an unmarked existing file (a provider in app.tsx, a route in another file), which `git status` shows; a mark under node_modules or vendor; anything above the cwd.
# Why, limits, history: rationale/derivations/plugin-design-kit.md § plugins/design-kit/scripts/codebase-cleanup.sh
set -euo pipefail

MARK="__design-kit__ scratch"
verify=0
case "${1:-}" in --verify) verify=1 ;; "") ;; -h|--help) sed -n '2,5p' "$0"; exit 0 ;; *) echo "codebase-cleanup.sh: unknown argument $1" >&2; exit 2 ;; esac

leftovers=()
while IFS= read -r p; do leftovers+=("$p"); done < <(
  find . \( -name node_modules -o -name vendor -o -name .git -o -name .cc-artifacts -o -name .design-kit \) -prune -o -path '*__design-kit__*' -print 2>/dev/null | sort
)
marked=()  # real files carrying marked lines: a routes/web.php at any depth (an app in a subdirectory) and an entry stylesheet
while IFS= read -r f; do marked+=("${f#./}"); done < <(
  { grep -rlF --include=web.php --exclude-dir=node_modules --exclude-dir=vendor --exclude-dir=.git \
      --exclude-dir=.cc-artifacts --exclude-dir=.design-kit --exclude-dir=__design-kit__ "$MARK" . | grep -E '(^|/)routes/web\.php$'
    grep -rlF --include='*.css' --exclude-dir=node_modules --exclude-dir=vendor --exclude-dir=.git \
      --exclude-dir=.cc-artifacts --exclude-dir=.design-kit --exclude-dir=__design-kit__ "$MARK" . ; } 2>/dev/null | sort -u
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
