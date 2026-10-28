# cite.sh — sourced, never run, by hooks/gate.sh (clause 1) and scripts/candor-scan.sh: one citation lookup. cite_extract: stdin filter printing each file:line once, sorted, with URLs, versions, times, host:port and elided paths dropped.
# cite_miss <file:line> <root> <cwd>: prints why a citation does not resolve, nothing when it does or cannot be decided. Misses a name like .env.local:3, a file only under dist, build or .venv or past the depth caps (read as missing), a wrong line in a shared basename, a wrong directory with a unique one.
# Why, limits, history: rationale/derivations/plugin-candor.md § plugins/candor/hooks/cite.sh

cite_extract() {
  sed -E 's#[a-zA-Z][a-zA-Z0-9+.-]*://[^[:space:])"]*##g' \
    | grep -oE '[/A-Za-z0-9_.~][A-Za-z0-9_./-]*\.[A-Za-z][A-Za-z0-9]{0,9}:[0-9]+' 2>/dev/null \
    | grep -vEi '\.(com|net|org|io|co|ai|app|gg|me|localhost|test|local|internal|example|invalid|lan):[0-9]+$' \
    | grep -vF '...' \
    | sort -u
}

# Pruned and depth-capped: a Stop hook must stay cheap on a large repo.
cite_find() { # <root> <find predicate...>
  local r="$1"; shift
  find "$r" -maxdepth 8 \( -name node_modules -o -name .git -o -name vendor -o -name dist -o -name build -o -name .venv \) -prune \
    -o "$@" -type f -print 2>/dev/null
}

cite_miss() {
  local p="${1%:*}" l="${1##*:}" root="$2" cwd="$3" f="" m b n
  case "$p" in "~/"*) p="${HOME:-}/${p#\~/}" ;; esac
  case "$p" in /*) [ -f "$p" ] && f="$p" ;; esac
  # Abbreviated paths outnumber invented ones (measured), so only a basename found nowhere is fabricated.
  [ -n "$f" ] || { [ -f "$cwd/$p" ] && f="$cwd/$p"; }
  [ -n "$f" ] || { [ -f "$root/$p" ] && f="$root/$p"; }
  [ -n "$f" ] || f=$(cite_find "$root" -path "*/$p" | head -1)
  if [ -z "$f" ]; then
    b=${p##*/}
    m=$(cite_find "$root" -name "$b" | head -2)
    n=$(printf '%s\n' "$m" | grep -c .)
    if [ "$n" -eq 0 ]; then
      # A basename found only under node_modules or vendor is real but undecidable.
      [ -n "$(find "$root/node_modules" "$root/vendor" -maxdepth 6 -name "$b" -print -quit 2>/dev/null)" ] && return 0
      printf 'no file named %s found under %s (8 deep; node_modules and vendor 6 deep; dist, build, .venv, .git not searched)\n' "$b" "$root"
      return 0
    fi
    [ "$n" -eq 1 ] || return 0
    f="$m"
  fi
  n=$(wc -l < "$f" 2>/dev/null | tr -d ' ')
  case "$n" in '' | *[!0-9]*) return 0 ;; esac
  # +1: a final line with no trailing newline is not counted by wc -l.
  [ "$l" -gt $((n + 1)) ] 2>/dev/null && printf '%s has %s lines\n' "$f" "$n"
  return 0
}
