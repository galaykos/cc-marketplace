#!/usr/bin/env bash
# Harness for plan-overlap.sh. Load-bearing: the same group is clean with disjoint files and red once one
# path is shared, so the clean verdict is not vacuous; a dependency or an unlisted file set also refuses it.
set -u
here=$(cd "$(dirname "$0")" && pwd)
C="$here/../plan-overlap.sh"
[ -x "$C" ] || { printf 'FAIL: plan-overlap.sh not executable\n'; exit 1; }
pass=0; fail=0
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
ok()  { printf 'PASS: %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$((fail+1)); }

card() { # <id> <depends-on> <file element>...
  local id=$1 deps=$2; shift 2
  {
    printf '<card id="%s">\n<depends-on>%s</depends-on>\n<facts>\n' "$id" "$deps"
    printf '%s\n' "$@"
    printf '</facts>\n<must-not>\n<file path="src/forbidden.ts" reason="another card owns it"/>\n</must-not>\n</card>\n'
  } > "$T/$id-card.md"
}
expect() { # name rc grep absent-grep -- args...
  local name=$1 want=$2 has=$3 lacks=$4; shift 5
  out=$(bash "$C" --dir "$T" "$@" 2>&1); rc=$?
  if [ "$rc" = "$want" ] && { [ -z "$has" ] || printf '%s' "$out" | grep -q -- "$has"; } \
     && { [ -z "$lacks" ] || ! printf '%s' "$out" | grep -q -- "$lacks"; }; then ok "$name"; else bad "$name (rc=$rc out=$out)"; fi
}
reset() { rm -f "$T"/*.md; }

card 01 none '<file path="src/a.ts" line="3" mode="edit">x</file>'
card 02 none '<file path="src/b.ts" mode="create"/>'
card 03 none '<file path="./src/c.ts" line="9" mode="edit">x</file>'
card 04 '01, 02' '<file path="src/a.ts" line="7" mode="edit">x</file>'
printf '# Index\n' > "$T/00-INDEX.md"
expect "levels follow <depends-on>" 0 "level 0: 01 02 03" "" --
expect "a dependent card sits one level down" 0 "level 1: 04" "" --
expect "a path shared across levels is not an overlap" 0 "" "overlap:" --
expect "a disjoint group is clean" 0 "" "." -- --group 01,02,03
expect "a forbidden file every card names is not a written file" 0 "" "forbidden" -- --group 01,02

card 03 none '<file path="src/a.ts" line="9" mode="edit">x</file>'
expect "the same group with one shared path is refused" 1 "overlap: cards 01 and 03 both write src/a.ts" "" -- --group 01,02,03
expect "the plan lists the same-level overlap and still exits 0" 0 "overlap: cards 01 and 03 both write src/a.ts" "" --
expect "a leading ./ and leading zeros do not hide it" 1 "overlap: cards 01 and 03" "" -- --group 1,3

card 03 none '<file path="./src/a.ts" line="9" mode="edit">x</file>'
expect "./src/a.ts is src/a.ts" 1 "both write src/a.ts" "" -- --group 01,03

card 03 none '<file path="src/" mode="create"/>'
expect "a directory entry covers the files under it" 1 "overlap: cards 01 and 03 both write src/a.ts" "" -- --group 01,03
card 03 none '<file path="src/ab.ts" mode="create"/>'
expect "a path that only starts with the same letters is disjoint" 0 "" "." -- --group 01,03

expect "a group holding a card and its dependency is refused" 1 "dependent: card 04 depends on card 02" "" -- --group 02,04
card 05 04 '<file path="src/e.ts" mode="create"/>'
expect "a dependency through another card counts" 1 "dependent: card 05 depends on card 02" "" -- --group 02,05

printf '**Files:** src/z.ts\n**Verify:** true\n' > "$T/06-legacy.md"
expect "a card with no moded <file> cannot be proven disjoint" 1 "no-files: card 06" "" -- --group 02,06
expect "the plan names it too" 0 "no-files: card 06" "" --

expect "a group naming a missing card is a usage error" 3 "no card 09" "" -- --group 01,09
expect "a one-card group is a usage error" 3 "at least two" "" -- --group 01
expect "a non-numeric group is a usage error" 3 "card numbers" "" -- --group 01,x

reset
card 01 02 '<file path="a" mode="create"/>'
card 02 01 '<file path="b" mode="create"/>'
expect "a dependency cycle is exit 3, not a plan" 3 "cycle" "level" --

reset
expect "an empty directory is a usage error" 3 "no cards" "" --

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
