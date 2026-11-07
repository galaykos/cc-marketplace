#!/usr/bin/env bash
# Fixture tests for card-set-lint.sh — ordering across a card set.
# Load-bearing: a consumer scheduled beside its producer (no <depends-on> path) must fail, and a
# transitive dependency (03 → 02 → 01) must pass; the silent neighbours are "none" and a card's own file.
set -u
here=$(cd "$(dirname "$0")" && pwd)
L="$here/../card-set-lint.sh"
[ -x "$L" ] || { printf 'FAIL: card-set-lint.sh not executable\n'; exit 1; }
pass=0; fail=0
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
ok()  { printf 'PASS: %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$((fail+1)); }

# card <dir> <NN> <facts> <must> <verify> <depends-on>
card() {
  mkdir -p "$1"
  printf '# %s — title\n\n<card id="%s">\n<goal>g</goal>\n<facts>\n%s\n</facts>\n<must>\n%s\n</must>\n<proof>\n<criterion>c</criterion>\n<verify>%s</verify>\n</proof>\n<depends-on>%s</depends-on>\n<agent>generic</agent>\n</card>\n' \
    "$2" "$2" "$3" "$4" "$5" "$6" > "$1/$2-card.md"
}
expect() { # name dir rc reason
  err=$(bash "$L" --dir "$2" 2>&1 >/dev/null); rc=$?
  if [ "$rc" = "$3" ] && { [ -z "$4" ] || printf '%s' "$err" | grep -q "card-set: $4:"; }; then ok "$1"
  else bad "$1 (rc=$rc err=$err)"; fi
}

D="$T/clean"
card "$D" 01 '<file path="src/a.ts" mode="create"/>' '<interface consumer="03">a(): number</interface>' 'npm test -- src/a.test.ts' 'none'
card "$D" 02 '<file path="src/b.ts" mode="edit" line="3">x</file>' '<change>x</change>' 'npm test' '01'
card "$D" 03 '<file path="src/a.ts" mode="edit" line="1">x</file>' '<change>use a()</change>' 'npm test -- src/a.ts' '02'
printf '# index\n' > "$D/00-INDEX.md"
expect "transitive dependency satisfies interface and create order" "$D" 0 ""

D="$T/iface"
card "$D" 01 '' '<interface consumer="02">a()</interface>' 'npm test' 'none'
card "$D" 02 '' '<change>x</change>' 'npm test' 'none'
expect "consumer with no path to its producer fails" "$D" 2 interface-unordered

D="$T/consumer-missing"
card "$D" 01 '' '<interface consumer="07">a()</interface>' 'npm test' 'none'
expect "interface for a card that does not exist fails" "$D" 2 interface-consumer-missing

D="$T/create"
card "$D" 01 '<file path="src/new.ts" mode="create"/>' '<change>x</change>' 'npm test' 'none'
card "$D" 02 '' '<change>x</change>' 'npx vitest run src/new.ts' 'none'
expect "verify on a sibling-created file without the dependency fails" "$D" 2 create-unordered

D="$T/own"
card "$D" 01 '<file path="src/new.ts" mode="create"/>' '<change>x</change>' 'npx vitest run src/new.ts' 'none'
expect "a card using the file it creates itself passes" "$D" 0 ""

D="$T/ondisk"; mkdir -p "$D/src"; git -C "$D" init -q; : > "$D/src/new.ts"
card "$D/cards" 01 '<file path="src/new.ts" mode="create"/>' '<change>x</change>' 'npm test' 'none'
card "$D/cards" 02 '' '<change>x</change>' 'npx vitest run src/new.ts' 'none'
expect "a follow-up card using a file already on disk passes" "$D/cards" 0 ""

D="$T/missing"
card "$D" 01 '' '<change>x</change>' 'npm test' '04'
expect "depends-on a card that does not exist fails" "$D" 2 depends-missing

D="$T/self"
card "$D" 01 '' '<change>x</change>' 'npm test' '01'
expect "depends on itself fails" "$D" 2 depends-self

D="$T/cycle"
card "$D" 01 '' '<change>x</change>' 'npm test' '02'
card "$D" 02 '' '<change>x</change>' 'npm test' '01'
expect "two-card cycle fails" "$D" 2 depends-cycle

D="$T/badref"
card "$D" 01 '' '<change>x</change>' 'npm test' 'card two'
expect "a non-number dependency fails" "$D" 2 bad-ref

D="$T/glob"
card "$D" 01 '' '<change>x</change>' 'npm test' '*'
err=$(cd "$D" && bash "$L" --dir . 2>&1 >/dev/null); rc=$?
if [ "$rc" = 2 ] && printf '%s' "$err" | grep -qF 'bad-ref: card 1 names "*"'; then ok "a * dependency is a bad-ref, not glob-expanded"
else bad "a * dependency is a bad-ref, not glob-expanded (rc=$rc err=$err)"; fi

D="$T/cycle-memo"
card "$D" 01 '' '<change>x</change>' 'npm test' '02, 03'
card "$D" 02 '' '<change>x</change>' 'npm test' '01'
card "$D" 03 '' '<interface consumer="01">a()</interface><interface consumer="02">b()</interface>' 'npm test' 'none'
err=$(bash "$L" --dir "$D" 2>&1 >/dev/null); rc=$?
if [ "$rc" = 2 ] && printf '%s' "$err" | grep -q 'depends-cycle' && ! printf '%s' "$err" | grep -q 'interface-unordered'; then ok "a reach cut short by a cycle is not memoised as unreachable"
else bad "a reach cut short by a cycle is not memoised as unreachable (rc=$rc err=$err)"; fi

D="$T/empty"; mkdir -p "$D"
expect "a dir with no cards is a usage error" "$D" 3 ""
expect "no --dir is a usage error" "$T/nope" 3 ""

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
