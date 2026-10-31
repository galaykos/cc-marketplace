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
