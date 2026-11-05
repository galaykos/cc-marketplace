#!/usr/bin/env bash
# card-paths-lint.sh — author-time FILESYSTEM lint for one task card: an unreplaced template token (__B__, {{x}}), a mode="edit" <file> that does not exist, a <verify> path that neither exists nor is created by this card or a sibling card. Exit 2 with one `card-paths: <reason>: <detail>` line per hit; 0 clean; 3 usage.
# Misses: a file the change needs but the card never lists, a stale card number in prose, a path built from a variable or a glob in <verify>, a sibling that creates the file only after this card runs (order is the index's job).
# Why, limits, history: rationale/session-retro-2026-11-05.md § 2 issue 9 (cards 08/10/11 halted on missing files, a verify target that did not exist, `__B__` left in verify lines).
set -uo pipefail

PROG=card-paths-lint
usage() { printf '%s: usage: %s --card <card.md> [--root <repo root>]\n' "$PROG" "$PROG" >&2; exit 3; }

card=""; root=""
while [ $# -gt 0 ]; do
  case "$1" in
    --card) [ $# -ge 2 ] || usage; card=$2; shift 2 ;;
    --root) [ $# -ge 2 ] || usage; root=$2; shift 2 ;;
    -h | --help) usage ;;
    *) usage ;;
  esac
done
[ -n "$card" ] && [ -f "$card" ] || usage
if [ -z "$root" ]; then
  root=$(git -C "$(dirname "$card")" rev-parse --show-toplevel 2>/dev/null) || root=$PWD
fi
[ -d "$root" ] || usage

# Run record (card-lint-record.sh), written on both outcomes: the lint ran and what it said, never that the card is good.
. "$(dirname "$0")/card-lint-record.sh" 2>/dev/null || true
record() { command -v cardlint_write >/dev/null 2>&1 && cardlint_write card-paths "$card" "$1"; return 0; }

hits=""
hit() { hits="${hits}card-paths: $1: $2"$'\n'; }

# 1. A template token the card writer never replaced. Backtick spans are code the card quotes, not the card's own text.
while IFS= read -r t; do
  [ -n "$t" ] && hit placeholder "$t"
# PHP's magic constants (__DIR__) and a Blade/Vue `{{ $x }}` are code, not tokens: only an all-caps {{NAME}} counts.
done < <(sed 's/`[^`]*`//g' "$card" | grep -oE '__[A-Z][A-Z0-9_]*__|\{\{ ?[A-Z][A-Z0-9_]{0,30} ?\}\}' \
         | grep -vxE '__(DIR|FILE|LINE|CLASS|FUNCTION|METHOD|NAMESPACE|TRAIT|COMPILER_HALT_OFFSET)__' | sort -u)

# Paths this card or any sibling card in the same directory creates: a verify target may be one of them.
created=$(grep -hoE '<file[^>]*mode="(create|new)"[^>]*>|<file[^>]*>' "$(dirname "$card")"/*.md 2>/dev/null \
  | grep -E 'mode="(create|new)"' | sed -nE 's/.*path="([^"]+)".*/\1/p' | sort -u)
is_created() { printf '%s\n' "$created" | grep -qxF "$1"; }
exists() { [ -e "$root/$1" ] || [ -e "$1" ]; }

# 2. An edited file that does not exist: the card describes a tree that is not this one.
while IFS= read -r p; do
  [ -n "$p" ] || continue
  exists "$p" || is_created "$p" || hit edit-missing "$p"
done < <(grep -oE '<file[^>]*mode="edit"[^>]*>' "$card" | sed -nE 's/.*path="([^"]+)".*/\1/p')

# 3. A path the verify command runs: it must exist now or be created by this card or a sibling.
vline=$(grep -m1 -oE '<verify>.*</verify>' "$card" | sed -e 's/<verify>//' -e 's#</verify>##')
[ -n "$vline" ] || vline=$(grep -m1 -E '^\*\*Verify:\*\*' "$card" | sed -E 's/^\*\*Verify:\*\*[[:space:]]*//')
if [ -n "$vline" ]; then
  while IFS= read -r p; do
    p=${p#./}
    [ -n "$p" ] || continue
    exists "$p" || is_created "$p" || hit verify-target-missing "$p"
  done < <(printf '%s\n' "$vline" | tr -d '`"'"'" | tr ' =' '\n\n' \
           | grep -E '^[A-Za-z0-9_.@-][A-Za-z0-9_./@-]*/[A-Za-z0-9_.@-]+\.[A-Za-z0-9]{1,6}$' \
           | grep -vE '^(https?|file):|^\.\./|^/|[*?]' | sort -u)
fi

if [ -n "$hits" ]; then
  printf '%s' "$hits" >&2
  record fail; exit 2
fi
record pass; exit 0
