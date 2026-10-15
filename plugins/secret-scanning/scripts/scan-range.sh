#!/bin/bash
# scan-range.sh <base>..<head> | <path>… — applies hooks/patterns.tsv, the file the write guard and the redaction mod read, to the
#   lines a git range ADDED, or to whole files: a file path as given, a directory's git-tracked files (every file under it outside git).
#   Prints one `<file>:<line> <label> (<first 4 characters>****, <n> chars)` per matching line, never a whole value; a count to stderr.
# Exit: 0 nothing matched · 1 a match · 2 nothing was scanned (no argument, a missing path, a range git cannot diff, an unusable
#   patterns.tsv: missing, a carriage return, a row not four TAB-separated fields, an unknown kind or flag, no secret row, a row grep -E rejects).
# Matching is scan.sh's: secret and assigned rows in file order, the first non-placeholder match names the line; an assigned row's value
#   is what follows the first : or =; a placeholder row, or a value of one repeated character, releases a match.
# Misses: a secret split across lines (each line is matched alone), a shape patterns.tsv does not list, a real value holding a placeholder
#   word, binary files, a line a range removed (the secret is still in history), history outside the range, untracked files under a
#   directory in git. Not checked: the regex dialect scan.sh enforces on the same file (grep is the only engine here).
set -u
export LC_ALL=C
pat_file="$(cd "$(dirname "$0")/.." && pwd)/hooks/patterns.tsv"
die() { printf 'scan-range: %s\n' "$1" >&2; exit 2; }
[ $# -gt 0 ] || die "usage: scan-range.sh <base>..<head> | <path>..."

kinds=(); labels=(); flags=(); res=(); ph_i=""; ph_c=""; nsecret=0; n=0; tab=$'\t'
[ -f "$pat_file" ] && [ -r "$pat_file" ] || die "$pat_file is missing or unreadable"
while IFS= read -r line || [ -n "$line" ]; do
  n=$((n + 1))
  case "$line" in *$'\r'*) die "$pat_file line $n carries a carriage return" ;; '' | '#'*) continue ;; esac
  tabs=${line//[!$tab]/}
  [ "${#tabs}" -eq 3 ] || die "$pat_file line $n has $((${#tabs} + 1)) fields, not 4"
  kind=${line%%"$tab"*}; rest=${line#*"$tab"}; label=${rest%%"$tab"*}; rest=${rest#*"$tab"}; fl=${rest%%"$tab"*}; re=${rest#*"$tab"}
  [ -n "$label" ] && [ -n "$re" ] || die "$pat_file line $n has an empty label or pattern"
  case "$fl" in - | i) ;; *) die "$pat_file line $n has flags '$fl', not - or i" ;; esac
  case "$kind" in
    placeholder) if [ "$fl" = i ]; then ph_i="$ph_i${ph_i:+|}($re)"; else ph_c="$ph_c${ph_c:+|}($re)"; fi ;;
    secret | assigned) [ "$kind" = secret ] && nsecret=$((nsecret + 1))
      kinds+=("$kind"); labels+=("$label"); flags+=("$fl"); res+=("$re") ;;
    *) die "$pat_file line $n has kind '$kind', not secret, assigned or placeholder" ;;
  esac
done < "$pat_file"
[ "$nsecret" -gt 0 ] || die "$pat_file has no secret row"

placeholder() { # <value> — 0 when the value announces itself as fake (scan.sh's rule)
  [ -n "$ph_i" ] && printf '%s' "$1" | grep -qiE -- "$ph_i" && return 0
  [ -n "$ph_c" ] && printf '%s' "$1" | grep -qE -- "$ph_c" && return 0
  [ "$(printf '%s' "$1" | fold -w1 | sort -u | wc -l | tr -d ' ')" -le 1 ]
}

W=$(mktemp -d) || die "cannot make a temp dir"
trap 'rm -rf "$W"' EXIT
: > "$W/text"; : > "$W/loc"
# text holds one scanned line per row and loc its `<file>TAB<line>`, so a match's row number names its place.
if [ $# -eq 1 ] && [[ $1 == *..* ]] && [ ! -e "$1" ]; then
  git -c core.quotePath=false diff --no-color --no-ext-diff --no-textconv --src-prefix=a/ --dst-prefix=b/ -U0 "$1" -- > "$W/diff" 2>/dev/null \
    || die "git cannot diff the range '$1' here"
  # A ---/+++ pair is a header only between `diff --git` and the first hunk: an added line reading `++ x` shows as `+++ x`.
  awk -v text="$W/text" -v loc="$W/loc" '
    /^diff --git / { hdr = 1; f = ""; next }
    hdr && /^\+\+\+ / { f = substr($0, 5); if (f == "/dev/null") f = ""; else sub(/^b\//, "", f); next }
    /^@@ / { hdr = 0; match($0, /\+[0-9]+/); ln = substr($0, RSTART + 1, RLENGTH - 1) + 0; next }
    f != "" && /^\+/ { print substr($0, 2) >> text; print f "\t" ln >> loc; ln++ }
  ' "$W/diff"
else
  : > "$W/files"
  for p in "$@"; do
    if [ -d "$p" ]; then
      d=${p%/}; [ -n "$d" ] || d=/
      if git -C "$d" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        git -C "$d" -c core.quotePath=false ls-files -z | while IFS= read -r -d '' f; do printf '%s/%s\0' "$d" "$f"; done >> "$W/files"
      else
        find "$d" -type f ! -path '*/.git/*' -print0 >> "$W/files"
      fi
    elif [ -f "$p" ]; then
      printf '%s\0' "$p" >> "$W/files"
    else
      die "no such file or directory: $p"
    fi
  done
  # ./-led so awk reads a name like a=b as a file, not an assignment; grep -I drops binary files, -l '' empty ones.
  while IFS= read -r -d '' f; do
    [ -f "$f" ] || continue
    case "$f" in /*) printf '%s\0' "$f" ;; ./*) printf '%s\0' "$f" ;; *) printf './%s\0' "$f" ;; esac
  done < "$W/files" | xargs -0 grep -I -l -Z -e '' -- 2>/dev/null \
    | xargs -0 awk -v text="$W/text" -v loc="$W/loc" '{ print >> text; f = FILENAME; sub(/^\.\//, "", f); print f "\t" FNR >> loc }' 2>/dev/null
fi

scanned=$(wc -l < "$W/loc" | tr -d ' ')
: > "$W/hits"
for k in "${!res[@]}"; do
  opts=-noE; [ "${flags[$k]}" = i ] && opts=-noiE
  grep "$opts" -- "${res[$k]}" "$W/text" > "$W/m" 2>/dev/null
  [ $? -le 1 ] || die "$pat_file: grep -E rejects the pattern labelled '${labels[$k]}'"
  while IFS= read -r nm; do
    row=${nm%%:*}; m=${nm#*:}; v=$m
    [ "${kinds[$k]}" = assigned ] && v=$(printf '%s' "$m" | sed -E 's/^[^:=]*[:=]["'"'"' ]*//')
    v=${v:-$m}
    placeholder "$v" && continue
    printf '%s\t%s\t%s\t%s****, %s chars\n' "$row" "$k" "${labels[$k]}" "${v:0:4}" "${#v}" >> "$W/hits"
  done < "$W/m"
done

# One line per scanned row, its first row in file order naming it; rows print in the order they were read.
sort -t "$tab" -k1,1n -k2,2n "$W/hits" | awk -F '\t' '!seen[$1]++' > "$W/first"
awk -F '\t' 'NR == FNR { want[$1] = $3 " (" $4 ")"; next } FNR in want { print $1 ":" $2 " " want[FNR] }' "$W/first" "$W/loc"
found=$(wc -l < "$W/first" | tr -d ' ')
printf 'scan-range: %s line(s) scanned, %s matched hooks/patterns.tsv\n' "$scanned" "$found" >&2
[ "$found" -eq 0 ] || exit 1
exit 0
