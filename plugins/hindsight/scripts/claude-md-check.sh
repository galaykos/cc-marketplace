#!/usr/bin/env bash
# claude-md-check.sh [repo-root] — the mechanical half of a CLAUDE.md audit: per CLAUDE.md, .claude.md and .claude.local.md (node_modules, vendor, .git skipped), lines, bytes and each stale backticked path (resolving from neither the repo root nor the file's dir) or `npm run X` / `composer X` / `make X` with no declared target. Exit 0 always.
# Misses: prose paths, a command holding a variable, other runners, architecture claims; a root-anchored path gone stale while a same-named suffix exists elsewhere in the tree (read as an illustrative fragment).
# Why, limits, history: rationale/derivations/plugin-hindsight.md § plugins/hindsight/scripts/claude-md-check.sh
set -u
root="${1:-$PWD}"
[ -d "$root" ] || { echo "claude-md-check: not a directory: $root"; exit 0; }
cd "$root" || exit 0

files=$(find . \( -name node_modules -o -name vendor -o -name .git \) -prune -o \
  \( -name CLAUDE.md -o -name .claude.md -o -name .claude.local.md \) -type f -print 2>/dev/null | sort)
[ -n "$files" ] || { echo "claude-md-check: no CLAUDE.md under $root"; exit 0; }

is_extension_only() { # `.md`, `.json` — a suffix, never a path
  case "$1" in .*) case "${1#.}" in *.*|*/*) return 1 ;; *) return 0 ;; esac ;; *) return 1 ;; esac
}
exists_anywhere() { # exists_anywhere <path-fragment>: any file or dir in the tree ends in it
  case "$1" in ../*) return 1 ;; esac
  [ -n "$(find . \( -name node_modules -o -name vendor -o -name .git \) -prune -o -path "*/$1" -print -quit 2>/dev/null)" ]
}
has_script() { # has_script <runner> <name>
  case "$1" in
    npm|pnpm|yarn|bun)
      [ -f package.json ] && command -v jq >/dev/null 2>&1 \
        && jq -e --arg n "$2" '.scripts[$n] // empty' package.json >/dev/null 2>&1 ;;
    composer)
      [ -f composer.json ] && command -v jq >/dev/null 2>&1 \
        && jq -e --arg n "$2" '.scripts[$n] // empty' composer.json >/dev/null 2>&1 ;;
    make)
      [ -f Makefile ] && grep -qE "^$2[[:space:]]*:" Makefile ;;
    *) return 0 ;;
  esac
}

total_stale=0
while IFS= read -r f; do
  dir=$(dirname "$f")
  lines=$(wc -l < "$f" | tr -d ' '); bytes=$(wc -c < "$f" | tr -d ' ')
  printf '%s  %s lines  %s bytes\n' "$f" "$lines" "$bytes"
  stale=0
  # Backticked tokens, one per line, with the line number they came from.
  while IFS=$'\t' read -r ln tok; do
    [ -n "$tok" ] || continue
    case "$tok" in
      # script runners: `npm run X`, `pnpm X`, `composer X`, `make X` (first two words only)
      "npm run "*|"pnpm run "*|"yarn run "*|"bun run "*)
        r=${tok%% *}; rest=${tok#* run }; name=${rest%% *}
        has_script "$r" "$name" || { printf '  L%s  stale script  %s  (no "%s" in package.json scripts)\n' "$ln" "$tok" "$name"; stale=$((stale+1)); } ;;
      "composer "*|"make "*)
        r=${tok%% *}; rest=${tok#* }; name=${rest%% *}
        case "$name" in install|update|require|remove|dump-autoload|-*|"") continue ;; esac
        has_script "$r" "$name" || { printf '  L%s  stale script  %s  (no "%s" target declared)\n' "$ln" "$tok" "$name"; stale=$((stale+1)); } ;;
      # path-like: contains a slash or ends in a file extension, no spaces, no glob, no variable
      *" "*|*'*'*|*'$'*|*'<'*|*'{'*|http*|-*) continue ;;
      */*|*.sh|*.md|*.json|*.ts|*.js|*.php|*.py|*.yml|*.yaml|*.toml|*.env|*.tsv)
        p=${tok#./}; p=${p%/}; p=$(printf '%s' "$p" | sed -E 's/:[0-9]+(-[0-9]+)?$//')  # `file:12` and `file:12-20` are line refs
        is_extension_only "$p" && continue
        [ -e "$p" ] || [ -e "$dir/$p" ] || exists_anywhere "$p" || { printf '  L%s  stale path    %s\n' "$ln" "$tok"; stale=$((stale+1)); } ;;
      *) continue ;;
    esac
  done < <(grep -no '`[^`]*`' "$f" 2>/dev/null | sed -E 's/^([0-9]+):`(.*)`$/\1\t\2/')
  [ "$stale" -eq 0 ] && printf '  (no stale backticked references)\n'
  total_stale=$((total_stale+stale))
done <<< "$files"

printf '\nstale references: %s  — only backticked paths and npm/pnpm/yarn/bun/composer/make scripts were checked; prose references and architecture claims are not.\n' "$total_stale"
exit 0
