#!/usr/bin/env bash
# scan-range.test.sh — fixture cases for scripts/scan-range.sh in a throwaway git repo: a token on an added line is found, named by
#   file:line and masked; the same token on a removed line, a clean range, a placeholder and a binary file are silent; a path is read
#   whole; the patterns come from hooks/patterns.tsv through scan.sh's reader, hooks/patterns.sh (a temp copy without the row finds nothing,
#   a row only scan.sh's checks reject exits 2); names git pads or quotes keep file:line; --cached reads the index; bad input exits 2.
#   Secret shapes are assembled at runtime: the write guard would deny a write of this file.
set -u
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scan-range.sh"
PAT="$(cd "$(dirname "$0")/../.." && pwd)/hooks/patterns.tsv"
command -v git >/dev/null 2>&1 || { echo "SKIP: git is required"; exit 0; }
pass=0; fail=0
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
ok()  { pass=$((pass+1)); printf 'PASS  %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL  %s\n      %s\n' "$1" "$2"; }

TOK=$(printf 'AK%s%s' 'IA' 'Q7ZT9WM2RP4LX8VN')
R="$T/repo"; mkdir -p "$R"
g() { git -C "$R" -c user.email=t@t -c user.name=t "$@" >/dev/null 2>&1; }
g init -q
printf 'one\nkey=%s\nthree\n' "$TOK" > "$R/old.txt"; printf 'clean\n' > "$R/keep.txt"
g add -A; g commit -qm base
# The token leaves old.txt and lands on new.txt's third line; a `++` content line and a binary file ride along.
printf 'one\nthree\n' > "$R/old.txt"
printf '++ not a header\nb\nconst k = "%s";\n' "$TOK" > "$R/new.txt"
printf 'x\000%s\n' "$TOK" > "$R/blob.bin"
printf 'api_key = "%s"\n' "example_Kq7Zt9WmRp4Lx8Vn3Bc6Yd" > "$R/fixture.txt"
g add -A; g commit -qm add
printf 'more\n' >> "$R/keep.txt"; g add -A; g commit -qm clean
printf 'a\nb\n' > "$R/new.txt"; g add -A; g commit -qm remove

run() { out=$(cd "$R" && bash "$SCRIPT" "$@" 2>"$T/err"); rc=$?; }

run HEAD~3..HEAD~2
case "$out" in *"new.txt:3 an AWS access key ID"*) ok "a token on an added line is named by file:line and label" ;;
  *) bad "a token on an added line is named by file:line and label" "rc=$rc out=${out:-<none>}" ;; esac
[ "$rc" -eq 1 ] && ok "a match exits 1" || bad "a match exits 1" "rc=$rc"
case "$out" in *"$TOK"*) bad "the value is masked, never printed whole" "$out" ;;
  *"(AKIA****, 20 chars)"*) ok "the value is masked, never printed whole" ;;
  *) bad "the value is masked, never printed whole" "${out:-<none>}" ;; esac
case "$out" in *old.txt*) bad "the same token on a removed line is not reported" "$out" ;; *) ok "the same token on a removed line is not reported" ;; esac
[ "$(printf '%s\n' "$out" | grep -c .)" -eq 1 ] && ok "a placeholder value, a binary file and a ++ content line add nothing" \
  || bad "a placeholder value, a binary file and a ++ content line add nothing" "$out"

run HEAD~1..HEAD
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok "a range that only removes the token exits 0, silent" || bad "a range that only removes the token exits 0, silent" "rc=$rc out=$out"
run HEAD~2..HEAD~1
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok "a clean range exits 0, silent" || bad "a clean range exits 0, silent" "rc=$rc out=$out"
grep -q '1 line(s) scanned, 0 matched' "$T/err" && ok "the count on stderr says what was read" || bad "the count on stderr says what was read" "$(cat "$T/err")"

g checkout -q HEAD~1
run new.txt
case "$out" in "new.txt:3 an AWS access key ID (AKIA****, 20 chars)") [ "$rc" -eq 1 ] ;; *) false ;; esac \
  && ok "a file path is read whole" || bad "a file path is read whole" "rc=$rc out=$out"
mkdir -p "$R/sub"; cp "$R/new.txt" "$R/sub/untracked.txt"
run .
case "$out" in *"new.txt:3"*) case "$out" in *untracked*|*blob.bin*) false ;; *) true ;; esac ;; *) false ;; esac \
  && ok "a directory in git reads its tracked text files only" || bad "a directory in git reads its tracked text files only" "rc=$rc out=$out"

# One source: a copy of the plugin layout whose patterns.tsv lacks the AWS row finds nothing; without the file, nothing runs.
C="$T/copy"; mkdir -p "$C/scripts" "$C/hooks"; cp "$SCRIPT" "$C/scripts/"
cp "$PAT" "$C/hooks/patterns.tsv"
out=$(cd "$R" && bash "$C/scripts/scan-range.sh" new.txt 2>&1); rc=$?
[ "$rc" -eq 2 ] && ok "a missing hooks/patterns.sh, scan.sh's reader, exits 2" || bad "a missing hooks/patterns.sh, scan.sh's reader, exits 2" "rc=$rc out=$out"
cp "$(dirname "$PAT")/patterns.sh" "$C/hooks/"
grep -v 'an AWS access key ID' "$PAT" > "$C/hooks/patterns.tsv"
out=$(cd "$R" && bash "$C/scripts/scan-range.sh" new.txt 2>/dev/null); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok "the patterns are hooks/patterns.tsv's (without the row, no match)" \
  || bad "the patterns are hooks/patterns.tsv's (without the row, no match)" "rc=$rc out=$out"
rm -f "$C/hooks/patterns.tsv"
out=$(cd "$R" && bash "$C/scripts/scan-range.sh" new.txt 2>&1); rc=$?
[ "$rc" -eq 2 ] && ok "a missing patterns.tsv exits 2" || bad "a missing patterns.tsv exits 2" "rc=$rc out=$out"
printf 'secret\tx\t-\tab(\n' > "$C/hooks/patterns.tsv"
out=$(cd "$R" && bash "$C/scripts/scan-range.sh" new.txt 2>&1); rc=$?
[ "$rc" -eq 2 ] && ok "a row grep -E rejects exits 2" || bad "a row grep -E rejects exits 2" "rc=$rc out=$out"
{ cat "$PAT"; printf 'secret\tx\t-\tx\\d+\n'; } > "$C/hooks/patterns.tsv"
out=$(cd "$R" && bash "$C/scripts/scan-range.sh" new.txt 2>&1); rc=$?
case "$out" in *"escapes a character"*) [ "$rc" -eq 2 ] ;; *) false ;; esac && ok "a row scan.sh rejects for its dialect exits 2 here too" \
  || bad "a row scan.sh rejects for its dialect exits 2 here too" "rc=$rc out=$out"

run; [ "$rc" -eq 2 ] && ok "no argument exits 2" || bad "no argument exits 2" "rc=$rc"
run nope..nada; [ "$rc" -eq 2 ] && ok "a range git cannot diff exits 2" || bad "a range git cannot diff exits 2" "rc=$rc"
run missing.txt; [ "$rc" -eq 2 ] && ok "a missing path exits 2" || bad "a missing path exits 2" "rc=$rc"

# Names git quotes or pads: a space (git appends a tab to the +++ line), a quote, a tab, a newline. Each keeps its line number and
# prints in git's escapes, unquoted, in both modes; a newline in a path-mode name no longer shifts the rows after it.
Q="$T/names"; mkdir -p "$Q/sub"
q() { git -C "$Q" -c user.email=t@t -c user.name=t "$@" >/dev/null 2>&1; }
q init -q; q commit -q --allow-empty -m base
printf 'x\nk=%s\n' "$TOK" > "$Q/a b.txt"; printf 'k=%s\n' "$TOK" > "$Q/q\"uo.txt"
printf 'k=%s\n' "$TOK" > "$Q/$(printf 't\tab.txt')"; printf 'k=%s\n' "$TOK" > "$Q/nl
x.txt"; printf 'y\nk=%s\n' "$TOK" > "$Q/z.txt"
q add -A; q commit -qm names
want=$(printf '%s\n' 'a b.txt:2' 'nl\nx.txt:1' 'q\"uo.txt:1' 't\tab.txt:1' 'z.txt:2')
out=$(cd "$Q" && bash "$SCRIPT" HEAD~1..HEAD 2>/dev/null | sed 's/ an AWS access key ID.*//' | LC_ALL=C sort)
[ "$out" = "$want" ] && ok "a range names a padded or quoted file by file:line, without git's quotes or b/" \
  || bad "a range names a padded or quoted file by file:line, without git's quotes or b/" "$(printf '%s' "$out" | tr '\n' '|')"
out=$(cd "$Q" && bash "$SCRIPT" . 2>/dev/null | sed 's/ an AWS access key ID.*//' | sed 's#^\./##' | LC_ALL=C sort)
[ "$out" = "$want" ] && ok "path mode keeps one record per name holding a tab or newline, escaped as git would" \
  || bad "path mode keeps one record per name holding a tab or newline, escaped as git would" "$(printf '%s' "$out" | tr '\n' '|')"

# --cached reads what is staged, not the working tree, and works from a subdirectory.
printf 'clean\n' > "$Q/sub/s.txt"; q add -A; q commit -qm sub
printf 'k=%s\n' "$TOK" >> "$Q/sub/s.txt"; q add sub/s.txt; printf 'clean\n' > "$Q/sub/s.txt"
out=$(cd "$Q/sub" && bash "$SCRIPT" --cached 2>/dev/null); rc=$?
[ "$rc" -eq 1 ] && [ "$out" = "sub/s.txt:2 an AWS access key ID (AKIA****, 20 chars)" ] \
  && ok "--cached scans the staged added lines from a subdirectory, not the working tree" \
  || bad "--cached scans the staged added lines from a subdirectory, not the working tree" "rc=$rc out=${out:-<none>}"
q commit -qm staged
out=$(cd "$Q" && bash "$SCRIPT" --cached 2>/dev/null); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok "--cached with nothing staged exits 0, silent" || bad "--cached with nothing staged exits 0, silent" "rc=$rc out=$out"
out=$(cd "$T" && bash "$SCRIPT" --cached 2>/dev/null); rc=$?
[ "$rc" -eq 2 ] && ok "--cached outside a repository exits 2" || bad "--cached outside a repository exits 2" "rc=$rc out=$out"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
