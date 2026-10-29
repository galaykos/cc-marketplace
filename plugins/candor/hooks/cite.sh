# cite.sh — sourced, never run, by hooks/gate.sh (clauses 1 and 6) and scripts/candor-scan.sh: one citation lookup. cite_extract: stdin filter printing each file:line once, sorted, with URLs, versions, times, host:port and elided paths dropped.
# cite_miss <file:line> <root> <cwd>: prints why a citation does not resolve, nothing when it does or cannot be decided; cite_file <path> <root> <cwd>: the file one names. Misses a name like .env.local:3, a file only under dist, build or .venv or past the depth caps (read as missing), a wrong line in a shared basename, a wrong directory with a unique one.
# Why, limits, history: rationale/derivations/plugin-candor.md § plugins/candor/hooks/cite.sh

# Shared block templates/blocks/quote-match.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/quote-match.md
# cc_quote_match <file> <line> <quote> [<window>]: status 0 when <quote> is in lines <line>-<window>..<line>+<window> of <file>
# (<window> 3 when absent, `all` for the whole file), both read with ASCII whitespace and no-break spaces dropped: as typed, then
# with one leading + or - dropped (a patch line), then cut at each … or ... into parts that must appear in that order, under 8
# non-space characters outside the cuts being status 0 unjudged; failing all three, the same again with every \| read as | on both
# sides (a Markdown table cell's escape). Status 1: the file reads and the text is not there.
# Status 2, checked first: <file> not a readable regular file, over 1 MiB, a NUL in its first 8000 bytes, <line> not a whole number
# from 1, or <window> neither a whole number nor `all`. <file> is the path the caller resolved; an ambiguous name is the caller's 2.
# Misses: a true quote that proves nothing, and text found anywhere in the window, wherever the finding points.
cc_quote_match() {
  local n="$2" r="${4:-3}" lo=1 hi=0 sz
  case "$n" in '' | *[!0-9]* | ??????????*) return 2 ;; esac
  case "$r" in all) ;; *[!0-9]* | ??????????*) return 2 ;; *) r=$((10#$r)) ;; esac
  n=$((10#$n))
  [ "$n" -ge 1 ] && [ -f "$1" ] && [ -r "$1" ] || return 2
  sz=$(wc -c < "$1") && [ $((sz)) -le 1048576 ] || return 2
  sz=$(head -c 8000 -- "$1" | LC_ALL=C tr -cd '\000' | wc -c) && [ $((sz)) -eq 0 ] || return 2
  [ "$r" = all ] || { lo=$((n > r ? n - r : 1)); hi=$((n + r)); }
  CC_QM_Q=$3 LC_ALL=C awk -v lo="$lo" -v hi="$hi" '
    function found(x, y,   t, c, i, b, k, part, p, j) {
      if (index(y, x)) return 1
      b = substr(x, 1, 1)
      if (b == "+" || b == "-") { x = substr(x, 2); if (index(y, x)) return 1 }
      gsub(e, "\001", x); gsub(/\.\.\./, "\001", x)
      t = x; gsub(/\001/, "", t); c = length(t)
      if (c < 32) for (i = 1; i <= length(t); i++) { b = substr(t, i, 1); if (b >= "\200" && b <= "\277") c-- }
      if (c < 8) return 1
      k = split(x, part, "\001"); p = 1
      for (i = 1; i <= k; i++) {
        if (part[i] == "") continue
        j = index(substr(y, p), part[i]); if (!j) return 0
        p += j - 1 + length(part[i])
      }
      return 1
    }
    BEGIN { lo += 0; hi += 0 }
    hi && NR > hi { exit }
    NR >= lo { w = w $0 }
    END {
      e = "\342\200\246"; s = "\302\240"; q = ENVIRON["CC_QM_Q"]
      gsub(/[ \t\r\n\f\v]/, "", q); gsub(/[ \t\r\n\f\v]/, "", w); gsub(s, "", q); gsub(s, "", w)
      if (found(q, w)) exit 0
      if (gsub(/\\[|]/, "|", q)) { gsub(/\\[|]/, "|", w); if (found(q, w)) exit 0 }
      exit 1
    }' "$1"
  case $? in 0) return 0 ;; 1) return 1 ;; *) return 2 ;; esac
}

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

# Prints one file; status 1: no file carries the basename, 2: several do, or only node_modules or vendor does, 3: printed, but more paths end in it.
# A 4th argument `sole` also returns 2 when the path may name another file: a relative one a second file ends in, an absolute or ~/ one the file does not end in.
cite_file() {
  local p="$1" root="$2" cwd="$3" m n f="" s=0
  case "$p" in "~/"*) p="${HOME:-}/${p#\~/}" ;; esac
  case "$p" in /*) [ -f "$p" ] && f=$p ;; esac
  # Abbreviated paths outnumber invented ones (measured), so only a basename found nowhere is fabricated.
  [ -n "$f" ] || { [ -f "$cwd/$p" ] && f=$cwd/$p; }
  [ -n "$f" ] || { [ -f "$root/$p" ] && f=$root/$p; }
  if [ -z "$f" ]; then
    m=$(cite_find "$root" -path "*/$p" | head -2)
    if [ -n "$m" ]; then
      f=$(printf '%s\n' "$m" | head -1)
      [ "$(printf '%s\n' "$m" | grep -c .)" -eq 1 ] || s=3
    else
      m=$(cite_find "$root" -name "${p##*/}" | head -2)
      n=$(printf '%s\n' "$m" | grep -c .)
      if [ "$n" -eq 0 ]; then
        # A basename found only under node_modules or vendor is real but undecidable.
        [ -n "$(find "$root/node_modules" "$root/vendor" -maxdepth 6 -name "${p##*/}" -print -quit 2>/dev/null)" ] && return 2
        return 1
      fi
      [ "$n" -eq 1 ] || return 2
      f=$m
    fi
  fi
  if [ "${4:-}" = sole ]; then
    case "$p" in
      /*) case "$f" in *"$p") ;; *) return 2 ;; esac ;;
      *) [ "$(cite_find "$root" -path "*/$p" | head -2 | grep -c .)" -le 1 ] || return 2 ;;
    esac
  fi
  printf '%s\n' "$f"
  return "$s"
}

cite_miss() {
  local p="${1%:*}" l="${1##*:}" f n
  f=$(cite_file "$p" "$2" "$3")
  case $? in
    0 | 3) ;;
    1) printf 'no file named %s found under %s (8 deep; node_modules and vendor 6 deep; dist, build, .venv, .git not searched)\n' "${p##*/}" "$2"
       return 0 ;;
    *) return 0 ;;
  esac
  n=$(wc -l < "$f" 2>/dev/null | tr -d ' ')
  case "$n" in '' | *[!0-9]*) return 0 ;; esac
  # +1: a final line with no trailing newline is not counted by wc -l.
  [ "$l" -gt $((n + 1)) ] 2>/dev/null && printf '%s has %s lines\n' "$f" "$n"
  return 0
}
