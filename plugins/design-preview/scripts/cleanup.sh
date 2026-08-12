#!/usr/bin/env bash
# cleanup.sh — mechanical cleanup + verification for design-preview scratch
# artifacts. The skill's cleanup guarantee was prose ("a repo-wide search must
# come back empty"); this is the command that prose described.
#
# Usage: cleanup.sh [--verify] [project-root]
#   --verify  search only, remove nothing; exit 1 if any artifact remains.
# Default mode removes every known scratch artifact, strips any line referencing
# the marker from routes/web.php, then runs the same verification.
#
# Residual: removes only artifacts carrying the __design-preview__ marker. A
# hand-renamed scratch file without the marker is invisible to this script —
# which is why the skill forbids renaming scratch artifacts.
set -u
MARKER="__design-preview__"
verify_only=0
[[ "${1:-}" == "--verify" ]] && { verify_only=1; shift; }
root="${1:-.}"
cd "$root" || { echo "cleanup: bad root '$root'"; exit 2; }

list_hits() {
  # Tracked-or-not, every path or file content carrying the marker, excluding
  # VCS internals and this plugin's own shipped files.
  { find . -path ./.git -prune -o -name "*${MARKER}*" -print 2>/dev/null
    grep -rIl --exclude-dir=.git --exclude-dir=node_modules -- "$MARKER" . 2>/dev/null
  } | grep -v "plugins/design-preview" | sort -u
}

if [[ $verify_only -eq 0 ]]; then
  # Known artifact shapes from the skill: scratch HTML entries, scratch src dir,
  # Blade view, scratch route file.
  find . -path ./.git -prune -o -name "*${MARKER}*" -print 2>/dev/null \
    | grep -v "plugins/design-preview" \
    | while IFS= read -r p; do rm -rf "$p" && echo "removed: $p"; done
  # The one permitted touch of an existing file: the require/marker line in
  # routes/web.php (Laravel path).
  if [[ -f routes/web.php ]] && grep -q -- "$MARKER" routes/web.php; then
    tmp=$(mktemp) && grep -v -- "$MARKER" routes/web.php > "$tmp" \
      && mv "$tmp" routes/web.php && echo "stripped: routes/web.php marker line(s)"
  fi
fi

left=$(list_hits)
if [[ -n "$left" ]]; then
  echo "cleanup: artifacts REMAIN:"; printf '%s\n' "$left"
  exit 1
fi
echo "cleanup: verified clean — no ${MARKER} artifact remains"
exit 0
