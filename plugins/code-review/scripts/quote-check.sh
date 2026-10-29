#!/usr/bin/env bash
# quote-check.sh [--root DIR] [--ref REF] [--close] [FILE]: per `path:line — severity —` finding in FILE or stdin, ok, mismatch (its last quote: `…` is within 3 lines, or the cited range, of neither the working file nor REF's copy), missing-quote (critical or high), unquoted, removed (a trailing was: `…`, never checked) or undecidable; exit 1 on mismatch or missing-quote, 2 when it cannot run or a critical/high line does not parse. --close: exit 1 while a finding lacks a fixed <path:line> or contested <reason> row.
# Misses: a true quote that proves nothing, one under 8 non-space characters, a medium or low line not in that shape, a file edited since the review, a was: quote of live code; --close takes the evidence column on trust.
# Why, limits, history: rationale/derivations/plugin-code-review.md § plugins/code-review/scripts/quote-check.sh

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

export LC_ALL=C
usage() { echo "usage: quote-check.sh [--root DIR] [--ref REF] [--close] [FILE]  (findings on stdin when no FILE)"; exit "$1"; }
root="" ref="" close=0 in=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root) [ $# -ge 2 ] || usage 2 >&2; root=$2; shift 2 ;;
    --ref) [ $# -ge 2 ] || usage 2 >&2; ref=$2; shift 2 ;;
    --close) close=1; shift ;;
    -h | --help) usage 0 ;;
    -*) usage 2 >&2 ;;
    *) [ -z "$in" ] || usage 2 >&2; in=$1; shift ;;
  esac
done
if [ -n "$in" ]; then
  [ -f "$in" ] && [ -r "$in" ] || { echo "quote-check: cannot read $in" >&2; exit 2; }
  text=$(cat -- "$in") || exit 2
else
  text=$(cat) || exit 2
fi
[ -n "$root" ] || root=$(git rev-parse --show-toplevel 2>/dev/null) || root=""
[ -n "$root" ] || root=$PWD
[ -d "$root" ] || { echo "quote-check: no directory $root" >&2; exit 2; }
if [ -n "$ref" ]; then
  git -C "$root" rev-parse --verify -q "$ref^{commit}" >/dev/null 2>&1 || { echo "quote-check: no commit $ref in $root" >&2; exit 2; }
  tmpd=$(mktemp -d) || exit 2
  trap 'rm -rf "$tmpd"' EXIT
fi

bt='`'
sev_re='[Cc][Rr][Ii][Tt][Ii][Cc][Aa][Ll]|[Hh][Ii][Gg][Hh]|[Mm][Ee][Dd][Ii][Uu][Mm]|[Ll][Oo][Ww]'
dash='(—|–|--|-)'
loc='[*'$bt'[]*[^[:space:]'$bt'|:*,]+:[0-9]+((–|[-:])[0-9]+)*[*'$bt']*(\]\([^)[:space:]]*\))?([[:space:]]+\([^)]*\))?'
sep='([[:space:]]*,[[:space:]]*(and[[:space:]]+)?|[[:space:]]+and[[:space:]]+)'
re_find='^[[:space:]]*(#+[[:space:]]+|>[[:space:]]*|[-*+][[:space:]]+|[0-9]+[.)][[:space:]]+)?('$loc'('$sep$loc')*)[[:space:]]+'$dash'[[:space:]]+[[*'$bt']*('$sev_re')([^A-Za-z]|$)'
re_link='\]\([^)[:space:]]*\)'
re_paren='[[:space:]]+\([^)]*\)'
re_and='[[:space:]]+and[[:space:]]+'
re_hi='[^[:space:]]:[0-9]+.*'$dash'[[:space:]]*[[*'$bt']*([Cc][Rr][Ii][Tt][Ii][Cc][Aa][Ll]|[Hh][Ii][Gg][Hh])[]*'$bt']*[[:space:]]*'$dash
re_q2='^[[:space:]]*'$bt$bt'(([^'$bt']|'$bt'[^'$bt'])+)'$bt$bt
re_q='^[[:space:]]*'$bt'([^'$bt']*)'$bt
re_was='(^|[^A-Za-z0-9_])was:[[:space:]]*('$bt$bt'([^'$bt']|'$bt'[^'$bt'])+'$bt$bt'|'$bt'[^'$bt']*'$bt')[[:space:]]*$'
re_key='([^[:space:]'$bt'|:]+):([0-9]+)'
re_rng='^([0-9]+)((–|-)([0-9]+))?'
nl='
'

suffix() { printf '%s\n' "$1" | QC_SUF="/$2" awk 'substr($0, length($0) - length(ENVIRON["QC_SUF"]) + 1) == ENVIRON["QC_SUF"]'; }

tracked="" tracked_read=0
resolve() {
  local p=$1 hits
  rf=""
  case $p in /*) [ -f "$p" ] && rf=$p; [ -n "$rf" ]; return ;; esac
  p=${p#./}
  if [ -f "$root/$p" ]; then rf=$root/$p; return 0; fi
  if [ -f "$PWD/$p" ]; then rf=$PWD/$p; return 0; fi
  if [ "$tracked_read" = 0 ]; then
    tracked=$(git -C "$root" -c core.quotePath=false ls-files 2>/dev/null); tracked_read=1
  fi
  [ -n "$tracked" ] || return 1
  hits=$(suffix "$tracked" "$p")
  case $hits in '') return 1 ;; *"$nl"*) return 3 ;; esac
  [ -f "$root/$hits" ] || return 1
  rf=$root/$hits
}

reftree="" reftree_read=0
ref_show() { # ref_show <path as written> <resolve status>: the file at --ref into $rq
  local p=${1#./} hits
  [ "$2" = 0 ] && case $rf in "$root"/*) p=${rf#"$root"/} ;; esac
  case $p in /*) case $p in "$root"/*) p=${p#"$root"/} ;; *) return 1 ;; esac ;; esac
  if ! git -C "$root" cat-file -e "$ref:$p" 2>/dev/null; then
    if [ "$reftree_read" = 0 ]; then
      reftree=$(git -C "$root" -c core.quotePath=false ls-tree -r --name-only "$ref" 2>/dev/null); reftree_read=1
    fi
    hits=$(suffix "$reftree" "$p")
    case $hits in '') return 1 ;; *"$nl"*) return 3 ;; esac
    p=$hits
  fi
  git -C "$root" show "$ref:$p" > "$tmpd/ref" 2>/dev/null || return 1
  rq=$tmpd/ref
}

trim() { t=$1; t=${t#"${t%%[![:space:]]*}"}; t=${t%"${t##*[![:space:]]}"}; }

severity() {
  case $1 in [Cc][Rr]*) sev=critical ;; [Hh]*) sev=high ;; [Mm]*) sev=medium ;; *) sev=low ;; esac
}

quote_of() { # the last quote: followed by a backtick span on the line, into $q
  local s=$1 tail
  q=""
  while :; do
    case $s in *quote:*) ;; *) return ;; esac
    tail=${s##*quote:}; s=${s%quote:*}
    if [[ $tail =~ $re_q2 ]] || [[ $tail =~ $re_q ]]; then q=${BASH_REMATCH[1]}; return; fi
  done
}

locations() { # split a finding's path:line list into lp (path), lc (line), lr (window), ll..lh (lines read); first in $key
  local s=$1 part a b c r o
  nloc=0 key=""
  while [[ $s =~ $re_link ]]; do s=${s/"${BASH_REMATCH[0]}"/}; done
  while [[ $s =~ $re_paren ]]; do s=${s/"${BASH_REMATCH[0]}"/}; done
  while [[ $s =~ $re_and ]]; do s=${s/"${BASH_REMATCH[0]}"/,}; done
  IFS=, read -r -a parts <<< "$s"
  for part in "${parts[@]}"; do
    trim "$part"; part=${t//[*$bt]/}
    o=${part//[!\[]/}; c=${part//[!\]]/}
    case $part in '['*) [ "${#o}" -gt "${#c}" ] && part=${part#?} ;; esac
    [[ ${part#*:} =~ $re_rng ]] || continue
    a=$((10#${BASH_REMATCH[1]})); b=${BASH_REMATCH[4]}; c=$a; r=3
    if [ -n "$b" ] && [ "${#b}" -lt 10 ] && [ $((10#$b)) -gt "$a" ]; then c=$(( (a + 10#$b) / 2 )); r=$((10#$b - c + 3)); fi
    [ -n "$key" ] || key=${part%%:*}:$a
    lp[$nloc]=${part%%:*}; lc[$nloc]=$c; lr[$nloc]=$r
    ll[$nloc]=$((c > r ? c - r : 1)); lh[$nloc]=$((c + r))
    nloc=$((nloc + 1))
  done
}

if [ "$close" = 1 ]; then
  keys="" closed="" rows=0 open=0
  while IFS= read -r line; do
    trim "$line"
    case $t in
      '|'*) ;;
      *)
        if [[ $line =~ $re_find ]]; then
          locations "${BASH_REMATCH[2]}"; k=$key
          [ -n "$k" ] && case "$nl$keys" in *"$nl$k$nl"*) ;; *) keys="$keys$k$nl" ;; esac
        fi
        continue ;;
    esac
    IFS='|' read -r -a cells <<< "$line"
    i=0 k=""
    while [ "$i" -lt "${#cells[@]}" ]; do
      if [[ ${cells[$i]} =~ $re_key ]]; then k="${BASH_REMATCH[1]}:${BASH_REMATCH[2]}"; break; fi
      i=$((i + 1))
    done
    [ -n "$k" ] || continue
    rows=$((rows + 1))
    trim "${cells[$((i + 1))]}"; st=${t//[*$bt]/}
    trim "${cells[$((i + 2))]}"; ev=$t
    why=""
    case $st in
      [Ff]ixed) [[ $ev =~ $re_key ]] || why="fixed names no changed path:line" ;;
      [Cc]ontested) case $ev in '' | - | — | –) why="contested gives no reason" ;; esac ;;
      *) why="status '$st' is neither fixed nor contested" ;;
    esac
    if [ -n "$why" ]; then
      open=$((open + 1)); echo "open $k — $why"
    else
      echo "closed $k $st"; closed="$closed$k$nl"
    fi
  done <<EOF_QC
$text
EOF_QC
  norow=0
  while IFS= read -r k; do
    [ -n "$k" ] || continue
    case "$nl$closed" in *"$nl$k$nl"*) continue ;; esac
    norow=$((norow + 1)); echo "open $k — no closing row closes it"
  done <<EOF_QC
$keys
EOF_QC
  if [ "$rows" = 0 ] && [ "$norow" = 0 ]; then
    echo "quote-check --close: no closing rows read"; exit 1
  fi
  echo "quote-check --close: $rows rows — $((rows - open)) closed, $open open; $norow findings with no closing row"
  [ $((open + norow)) -eq 0 ]
  exit
fi

ok=0 bad=0 miss=0 unq=0 rmv=0 und=0 unp=0
while IFS= read -r line; do
  head=${line%%quote:*}; head=${head:0:120}
  if ! [[ $line =~ $re_find ]]; then
    if [[ $line =~ $re_hi ]]; then unp=$((unp + 1)); echo "unparsed — $head"; fi
    continue
  fi
  severity "${BASH_REMATCH[$((${#BASH_REMATCH[@]} - 2))]}"
  locations "${BASH_REMATCH[2]}"
  [ "$nloc" -gt 0 ] || { unp=$((unp + 1)); echo "unparsed — $head"; continue; }
  quote_of "$line"
  why=""
  if [ -n "${q//[[:space:]]/}" ]; then
    got=2 i=0
    while [ "$i" -lt "$nloc" ]; do
      p=${lp[$i]}; st=2
      resolve "$p"; rs=$?
      [ "$rs" = 0 ] && { cc_quote_match "$rf" "${lc[$i]}" "$q" "${lr[$i]}"; st=$?; }
      if [ "$st" != 0 ] && [ -n "$ref" ] && ref_show "$p" "$rs"; then
        cc_quote_match "$rq" "${lc[$i]}" "$q" "${lr[$i]}"
        case $? in 0) st=0 ;; 1) st=1 ;; esac
      fi
      case $st in
        0) got=0; break ;;
        1) [ "$got" = 1 ] || { got=1; why="quote is not in lines ${ll[$i]}-${lh[$i]} of $p${ref:+ or of $ref:$p}"; } ;;
        *) if [ "$got" = 2 ] && [ -z "$why" ]; then
             case $rs in
               0) why="not judged: binary, over 1 MiB or unreadable" ;;
               3) why="ambiguous: several tracked files end in /$p" ;;
               *) why="file not found under $root${ref:+ or in $ref}" ;;
             esac
           fi ;;
      esac
      i=$((i + 1))
    done
    case $got in 0) v=ok why="" ;; 1) v=mismatch ;; *) v=undecidable ;; esac
  elif [[ $line =~ $re_was ]]; then v=removed; why="quotes deleted code (was:), not checked"
  else
    case $sev in critical | high) v=missing-quote; why="a $sev finding carries no quote" ;; *) v=unquoted ;; esac
  fi
  case $v in
    ok) ok=$((ok + 1)) ;; mismatch) bad=$((bad + 1)) ;; missing-quote) miss=$((miss + 1)) ;;
    unquoted) unq=$((unq + 1)) ;; removed) rmv=$((rmv + 1)) ;; *) und=$((und + 1)) ;;
  esac
  echo "$v $key $sev${why:+ — $why}"
done <<EOF_QC
$text
EOF_QC
echo "quote-check: $((ok + bad + miss + unq + rmv + und)) findings — $ok ok, $bad mismatch, $miss missing-quote, $unq unquoted, $rmv removed, $und undecidable, $unp unparsed"
[ "$unp" -eq 0 ] || exit 2
[ $((bad + miss)) -eq 0 ]
