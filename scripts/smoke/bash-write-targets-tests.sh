#!/usr/bin/env bash
# Behavioural harness for templates/blocks/bash-write-targets.md (cc_bash_write_targets):
# one case table run against the template AND every hook that pastes the block, so a copy
# that drifted, or kept an old definition beside the new one, fails here by file name.
# A second table runs templates/blocks/bash-write-chunks.md (cc_bash_write_chunks) the same
# way, each chunk paired with its file by the content guards' own loop.
set -u
cd "$(dirname "$0")/../.." || exit 2   # repo root
TPL=templates/blocks/bash-write-targets.md
DEF='^[[:space:]]*cc_bash_write_targets\(\)[[:space:]]*\{'
rc=0
pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; rc=1; }

T=$(mktemp -d) || exit 2
trap 'rm -rf "$T"' EXIT

carriers=()
while IFS= read -r f; do [ -n "$f" ] && carriers+=("$f"); done <<EOF_C
$(grep -rlE "$DEF" plugins --include='*.sh' | sort)
EOF_C
if [ "${#carriers[@]}" -eq 0 ]; then
  fail "no hook under plugins/ defines cc_bash_write_targets"
else
  once=1
  for f in "${carriers[@]}"; do
    n=$(grep -cE "$DEF" "$f")
    [ "$n" -eq 1 ] || { fail "$f defines cc_bash_write_targets $n times, want 1"; once=0; }
  done
  [ "$once" = 0 ] || pass "every carrying hook (${#carriers[@]}) defines cc_bash_write_targets once"
fi

srcs=("$TPL" ${carriers[@]+"${carriers[@]}"})
fn_file() { printf '%s/%s' "$T" "$(printf '%s' "$1" | tr / _)"; }
for s in "${srcs[@]}"; do
  awk '/^cc_bash_write_targets\(\) \{$/ { p = 1 } p { print } p && /^}$/ { exit }' "$s" > "$(fn_file "$s")"
  [ -s "$(fn_file "$s")" ] || fail "$s: no cc_bash_write_targets() { … } to extract"
done

targets() { # <source> <command>: that source's function alone in a fresh bash, one line out
  bash -c '. "$1" && cc_bash_write_targets "$2"' _ "$(fn_file "$1")" "$2" | tr '\n' ' ' | sed 's/ $//'
}

check() { # <want, space-separated> <command> [<label>]
  local want="$1" cmd="$2" label="${3:-$2}" s got ok=1
  for s in "${srcs[@]}"; do
    got=$(targets "$s" "$cmd")
    [ "$got" = "$want" ] || { fail "$s: $label -> got [$got], want [$want]"; ok=0; }
  done
  [ "$ok" = 0 ] || pass "$label -> [$want] in all ${#srcs[@]} copies"
}

check "tsconfig.json" "sed -i 's/a/b/' tsconfig.json 2>/dev/null"
check "f.json"        "sed -i '' s/a/b/ f.json"
check "f.json"        "sed -i'' s/a/b/ f.json"
check "f.json"        "sed -i.bak s/a/b/ f.json"
check "f.json"        "sed -i .bak s/a/b/ f.json"
check "f.json"        "sed -i -e s/a/b/ -e s/c/d/ f.json"
check "f.json"        "sed -i -f fix.sed f.json"
check ".eslintrc.json" "sed -e s/a/b/ -i .eslintrc.json"
check "./x.json y.json" "sed -e s/a/b/ -i ./x.json y.json"
check ".eslintrc.json" "sed --in-place 's/a/b/' .eslintrc.json"
check "tsconfig.json" "sed --in-place=.bak -e s/a/b/ tsconfig.json"
check "tsconfig.json" "sed -I '' 's/a/b/' tsconfig.json"
check "a.json b.json" "sed -i 's/a/b/' a.json b.json"
check ""              "sed -n 's/a/b/p' f.json"
check "x.yml"         "perl -i -pe 's/a/b/' x.yml > /dev/null"
check ""              "perl -Mstrict -ne 'print' f.pl"
check "f"             "echo x > f"
check "f"             "echo x >> f"
check "f g"           "tee -a f g"
check "f.json"        "echo x & sed -i s/a/b/ f.json"
check "f.txt"         "sed -i s/a/b/ f.txt & cat t.json"
check "f.json"        "sed -i s/a/b/ f.json &"
check "f.json"        "sed -i 's/a/&b/' f.json"
check "f.json"        "sed -i s/a/\&b/ f.json"
check "a.json"        "tee a.json & cat b.json"
check "f.json"        "cmd |& tee f.json"
check "f.json"        "cmd |&>f.json"
check "f.txt"         "sed -i s/a/b/ f.txt && cat t.json"
check "f.json"        "sed -i s/a/b/ f.json &> log.txt"
check "f.json"        "sed -i s/a/b/ >&2 f.json"
check "f.json"        "sed -i s/a/b/ <&3 f.json"
check "f.json"        "sed -i s/a/b/ 2>&1 f.json"
check "f.json"        "sed -i --expression s/a/b/ f.json"
check "f.json"        "sed -i --expression=s/a/b/ f.json"
check "f.json"        "sed -i --file fix.sed f.json"
check "f.json"        "sed -i --file=fix.sed f.json"
check "f.json"        "sed -i -- s/a/b/ f.json"
check "-f.json"       "sed -i -e s/a/b/ -- -f.json"
check "-f.json"       "perl -i -pe s/a/b/ -- -f.json"
check "f.json -g.json" "perl -i -pe s/a/b/ f.json -g.json"
check "f.json"        "perl -i -I lib -pe s/a/b/ f.json"
check "f.json"        "perl -l012 -i -pe s/a/b/ f.json"
check "f.json"        "perl -0777pi -e s/a/b/ f.json"
check "f.json"        "perl -Mlocale -i -pe s/a/b/ f.json"
check "f.json"        "perl -i -xbase -pe s/a/b/ f.json"
check "f.json"        "perl -d:Trace -i -pe s/a/b/ f.json"
check "f.json"        "perl -COE -i -pe s/a/b/ f.json"
check "out f.json"    "sed -i s/a/b/ f.json>out"
check "f.json"        "sed s/a/b/ f.json -i"
check "f.json"        "sed -i -l 5 s/a/b/ f.json"
check "out.txt"       $'cat > out.txt <<EOF\necho y > inner.txt\nEOF' \
  "heredoc body dropped: cat > out.txt <<EOF / echo y > inner.txt / EOF"

CTPL=templates/blocks/bash-write-chunks.md
csrcs=("$CTPL")
while IFS= read -r f; do [ -n "$f" ] && csrcs+=("$f"); done <<EOF_C
$(grep -rlE '^[[:space:]]*cc_bash_write_chunks\(\)[[:space:]]*\{' plugins --include='*.sh' | sort)
EOF_C
[ "${#csrcs[@]}" -gt 1 ] || fail "no hook under plugins/ defines cc_bash_write_chunks"
for s in "${csrcs[@]}"; do
  awk '/^cc_bash_write_chunks\(\) \{$/ { p = 1 } p { print } p && /^}$/ { exit }' "$s" > "$(fn_file "$s").chunks"
  [ -s "$(fn_file "$s").chunks" ] || fail "$s: no cc_bash_write_chunks() { … } to extract"
done

chunks() { # <source> <command>: "<file>: <text line>" per kept line, joined by " / "
  local tf="$1"; [ "$1" = "$CTPL" ] && tf=$TPL
  bash -c '. "$1" && . "$2" || exit
    sep=$(printf "\036"); keep=0
    cc_bash_write_chunks "$3" | while IFS= read -r l; do
      case "$l" in
        "$sep"*) tgt=$(cc_bash_write_targets "${l#?}" | head -n 1); [ -n "$tgt" ] && keep=1 || keep=0 ;;
        *) [ "$keep" = 1 ] && printf "%s: %s\n" "$tgt" "$l" ;;
      esac
    done' _ "$(fn_file "$tf")" "$(fn_file "$1").chunks" "$2" | awk 'NR > 1 { printf " / " } { printf "%s", $0 }'
}

check_chunks() { # <want> <command> [<label>]
  local want="$1" cmd="$2" label="${3:-$2}" s got ok=1
  for s in "${csrcs[@]}"; do
    got=$(chunks "$s" "$cmd")
    [ "$got" = "$want" ] || { fail "$s: chunks: $label -> got [$got], want [$want]"; ok=0; }
  done
  [ "$ok" = 0 ] || pass "chunks: $label -> [$want] in all ${#csrcs[@]} copies"
}

check_chunks ''                                  'echo "DROP TABLE t"; sed -i s/a/b/ x.sql'
check_chunks 'x.sql: "DROP TABLE t" > x.sql '    'echo "DROP TABLE t" > x.sql && cat y'
check_chunks 'x.sql: "DROP TABLE t" '            'echo "DROP TABLE t" | tee x.sql'
check_chunks 'x.sql: "DROP TABLE t" '            'echo "DROP TABLE t" |& tee x.sql'
check_chunks 'x.sql: "DROP TABLE t" > x.sql 2>&1' 'echo "DROP TABLE t" > x.sql 2>&1'
check_chunks 'x.sql: "DROP TABLE t" &>/dev/null > x.sql' 'echo "DROP TABLE t" &>/dev/null > x.sql'
check_chunks 'x.sql: "DROP TABLE t" <&3 > x.sql' 'echo "DROP TABLE t" <&3 > x.sql'
check_chunks 'x.sql: "a=1&b=2" > x.sql'          'echo "a=1&b=2" > x.sql'
check_chunks ''                                  'echo "DROP TABLE t" & sed -i s/a/b/ x.sql'
check_chunks 'x.sql: "DROP TABLE t" > x.sql '    'echo "DROP TABLE t" > x.sql & cat y'
check_chunks 'x.sql: DROP TABLE t'               $'cat > x.sql <<EOF &\nDROP TABLE t\nEOF' \
  'cat > x.sql <<EOF & / DROP TABLE t / EOF'
check_chunks 'log.txt: done > log.txt'           $'cat <<EOF & echo done > log.txt\nDROP TABLE t\nEOF' \
  'cat <<EOF & echo done > log.txt / DROP TABLE t / EOF'

exit "$rc"
