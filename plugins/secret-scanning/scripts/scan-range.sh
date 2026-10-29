#!/bin/bash
# scan-range.sh <base>..<head> | --cached | <path>… — applies hooks/patterns.tsv (scan.sh's matching, through hooks/patterns.sh) to the lines a range or the index ADDED, or to whole files (a directory: its git-tracked files); prints `<file>:<line> <label> (<first 4>****, <n> chars)` per match, never a value. Exit 0 none, 1 a match, 2 nothing scanned.
# Misses: a secret split across lines, a shape patterns.tsv does not list, a real value holding a placeholder word, binary files, a line a range removed (still in history), history outside the range, untracked files under a directory in git.
# Why, limits, history: rationale/derivations/plugin-secret-scanning.md § plugins/secret-scanning/scripts/scan-range.sh

# Output: a name holding a tab, newline, `"` or `\` prints in git's escapes, unquoted, in every mode (path mode prints other control characters raw); the count goes to stderr. Exit 2: no argument, a missing path, a range or index git cannot diff, an unusable patterns.tsv, no hooks/patterns.sh.
set -u
export LC_ALL=C
pat_file="$(cd "$(dirname "$0")/.." && pwd)/hooks/patterns.tsv"
die() { printf 'scan-range: %s\n' "$1" >&2; exit 2; }
[ $# -gt 0 ] || die "usage: scan-range.sh <base>..<head> | --cached | <path>..."

tab=$'\t'
. "$(dirname "$0")/../hooks/patterns.sh" 2>/dev/null || die "$(dirname "$0")/../hooks/patterns.sh is missing"
load_patterns "$pat_file" || die "$pat_file is unusable ($pat_bad)"

W=$(mktemp -d) || die "cannot make a temp dir"
trap 'rm -rf "$W"' EXIT
: > "$W/text"; : > "$W/loc"
# text holds one scanned line per row and loc its `<file>TAB<line>`, so a match's row number names its place.
if [ $# -eq 1 ] && { [ "$1" = --cached ] || { [[ $1 == *..* ]] && [ ! -e "$1" ]; }; }; then
  git -c core.quotePath=false diff --no-color --no-ext-diff --no-textconv --src-prefix=a/ --dst-prefix=b/ -U0 "$1" -- > "$W/diff" 2>/dev/null \
    || die "git cannot diff '$1' here"
  # A ---/+++ pair is a header only between `diff --git` and the first hunk: an added line reading `++ x` shows as `+++ x`.
  awk -v text="$W/text" -v loc="$W/loc" '
    /^diff --git / { hdr = 1; f = ""; next }
    # git pads a name holding a space with a tab and C-quotes one holding a control character, `"` or `\`: the escapes stay, the quotes go.
    hdr && /^\+\+\+ / { f = substr($0, 5); sub(/\t$/, "", f); if (f ~ /^".*"$/) f = substr(f, 2, length(f) - 2)
      if (f == "/dev/null") f = ""; else sub(/^b\//, "", f); next }
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
    | xargs -0 awk -v text="$W/text" -v loc="$W/loc" '
      # Escaped as git escapes a name, so a tab or newline in one cannot split its loc row.
      FNR == 1 { f = ""; n = FILENAME; sub(/^\.\//, "", n)
        for (i = 1; i <= length(n); i++) { c = substr(n, i, 1)
          f = f (c == "\\" ? "\\\\" : c == "\"" ? "\\\"" : c == "\t" ? "\\t" : c == "\n" ? "\\n" : c) } }
      { print >> text; print f "\t" FNR >> loc }' 2>/dev/null
fi

scanned=$(wc -l < "$W/loc" | tr -d ' ')
: > "$W/hits"
for k in "${!pat_re[@]}"; do
  opts=-noE; [ "${pat_flags[$k]}" = i ] && opts=-noiE
  grep "$opts" -- "${pat_re[$k]}" "$W/text" > "$W/m" 2>/dev/null
  [ $? -le 1 ] || die "grep failed on the pattern labelled '${pat_label[$k]}'"
  while IFS= read -r nm; do
    row=${nm%%:*}; pat_value "${pat_kind[$k]}" "${nm#*:}"; v=$pat_v
    placeholder "$v" && continue
    printf '%s\t%s\t%s\t%s****, %s chars\n' "$row" "$k" "${pat_label[$k]}" "${v:0:4}" "${#v}" >> "$W/hits"
  done < "$W/m"
done

# One line per scanned row, its first row in file order naming it; rows print in the order they were read.
sort -t "$tab" -k1,1n -k2,2n "$W/hits" | awk -F '\t' '!seen[$1]++' > "$W/first"
awk -F '\t' 'NR == FNR { want[$1] = $3 " (" $4 ")"; next } FNR in want { print $1 ":" $2 " " want[FNR] }' "$W/first" "$W/loc"
found=$(wc -l < "$W/first" | tr -d ' ')
printf 'scan-range: %s line(s) scanned, %s matched hooks/patterns.tsv\n' "$scanned" "$found" >&2
[ "$found" -eq 0 ] || exit 1
exit 0
