#!/usr/bin/env bash
# Behavioural harness for templates/blocks/bash-write-targets.md (cc_bash_write_targets):
# one case table run against the template AND every hook that pastes the block, so a copy
# that drifted, or kept an old definition beside the new one, fails here by file name.
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
check "out.txt"       $'cat > out.txt <<EOF\necho y > inner.txt\nEOF' \
  "heredoc body dropped: cat > out.txt <<EOF / echo y > inner.txt / EOF"

exit "$rc"
