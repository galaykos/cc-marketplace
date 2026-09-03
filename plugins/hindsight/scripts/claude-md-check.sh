#!/usr/bin/env bash
# claude-md-check.sh — the mechanical half of a CLAUDE.md audit: which of the
# paths and scripts a CLAUDE.md names no longer exist.
#
# Usage: claude-md-check.sh [repo-root]   (defaults to $PWD)
# Finds: CLAUDE.md, .claude.md, .claude.local.md at any depth (node_modules,
#        vendor, .git skipped). Prints per file: lines, bytes, then one row per
#        stale reference — a backticked path that does not resolve from the repo
#        root or the file's own directory, or a backticked `npm run X` /
#        `composer X` / `make X` whose script target is not declared.
# Exit 0 always — a report, not a gate. Nothing here is edited.
#
# Residual (stated, per the has-teeth convention): only BACKTICKED references are
# read, and only three script runners are resolved. A path written in prose, a
# command with a variable in it, or a runner not listed is not checked and not
# reported as clean — it is simply not seen. Currency of ARCHITECTURE prose
# (a described module boundary that moved) is judgment, left to the command.
set -u
root="${1:-$PWD}"
[ -d "$root" ] || { echo "claude-md-check: not a directory: $root"; exit 0; }
cd "$root" || exit 0

files=$(find . \( -name node_modules -o -name vendor -o -name .git \) -prune -o \
  \( -name CLAUDE.md -o -name .claude.md -o -name .claude.local.md \) -type f -print 2>/dev/null | sort)
[ -n "$files" ] || { echo "claude-md-check: no CLAUDE.md under $root"; exit 0; }

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
        p=${tok#./}; p=${p%/}
        [ -e "$p" ] || [ -e "$dir/$p" ] || { printf '  L%s  stale path    %s\n' "$ln" "$tok"; stale=$((stale+1)); } ;;
      *) continue ;;
    esac
  done < <(grep -no '`[^`]*`' "$f" 2>/dev/null | sed -E 's/^([0-9]+):`(.*)`$/\1\t\2/')
  [ "$stale" -eq 0 ] && printf '  (no stale backticked references)\n'
  total_stale=$((total_stale+stale))
done <<< "$files"

printf '\nstale references: %s  — only backticked paths and npm/pnpm/yarn/bun/composer/make scripts were checked; prose references and architecture claims are not.\n' "$total_stale"
exit 0
