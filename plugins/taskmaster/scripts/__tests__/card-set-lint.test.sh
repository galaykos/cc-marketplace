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

# --- invariants: each card's <invariant> must match the spec's Shared state & invariants row ---
# Replay of a real miss: card 09 dispatched a fingerprint job unconditionally, card 10 polled
# every 3 s, and together they queued a job per poll. The spec row I2 names the rule both cards must carry.
spec_with() { # <dir> <rows...>: a spec under <dir>/specs and an index pointing at it
  mkdir -p "$1/specs"; git -C "$1" init -q; local d=$1; shift
  { printf '# Spec\n\n## Shared state & invariants\n\n| ID | Entity / flow | States & transitions | Writer(s) | Invariant | Error meaning |\n|---|---|---|---|---|---|\n'
    printf '%s\n' "$@"; printf '\n## Success criteria\n- x\n'; } > "$d/specs/s.md"
  printf '# index\nSpec: specs/s.md\n' > "$d/cards/00-INDEX.md"
}
I1='| I1 | Fingerprint | queued → done · queued → failed | FingerprintJob | dispatched once per repo per rules version | `RulesStale` = re-queue once |'
I2='| I2 | Import status poll | GET /imports/{id} | none (read-only) | a GET or poll never enqueues work; polling stops at done/failed | 404 = stop polling |'
D="$T/inv-ok"
card "$D/cards" 09 '' '<invariant id="I1">dispatched once per repo per rules version</invariant>' 'npm test' 'none'
card "$D/cards" 10 '' '<invariant id="I2">a GET or poll never enqueues work;  polling stops at done/failed</invariant>' 'npm test' '09'
spec_with "$D" "$I1" "$I2"
err=$(bash "$L" --dir "$D/cards" 2>&1 >/dev/null); rc=$?
if [ "$rc" = 0 ] && [ -z "$err" ]; then ok "cards citing spec invariants verbatim pass silently (whitespace-normalised)"
else bad "cards citing spec invariants verbatim pass silently (rc=$rc err=$err)"; fi

D="$T/inv-drift"
card "$D/cards" 09 '' '<invariant id="I1">dispatched once per repo per rules version</invariant>' 'npm test' 'none'
card "$D/cards" 10 '' '<invariant id="I2">the poll refreshes the fingerprint</invariant>' 'npm test' '09'
spec_with "$D" "$I1" "$I2"
expect "poll-and-dispatch replay: card 10 paraphrasing I2 is invariant-drift" "$D/cards" 2 invariant-drift

D="$T/inv-unknown"
card "$D/cards" 01 '' '<invariant id="I9">x</invariant>' 'npm test' 'none'
spec_with "$D" "$I1"
expect "an invariant id the spec does not hold is invariant-unknown" "$D/cards" 2 invariant-unknown

D="$T/inv-orphan"
card "$D/cards" 09 '' '<invariant id="I1">dispatched once per repo per rules version</invariant>' 'npm test' 'none'
spec_with "$D" "$I1" "$I2"
err=$(bash "$L" --dir "$D/cards" 2>&1 >/dev/null); rc=$?
if [ "$rc" = 0 ] && printf '%s' "$err" | grep -q 'WARN invariant-orphan: spec invariant I2'; then ok "a spec invariant no card cites warns, exit 0"
else bad "a spec invariant no card cites warns, exit 0 (rc=$rc err=$err)"; fi

D="$T/inv-nospec"
card "$D" 01 '' '<invariant id="I1">x</invariant>' 'npm test' 'none'
err=$(bash "$L" --dir "$D" 2>&1 >/dev/null); rc=$?
if [ "$rc" = 0 ] && printf '%s' "$err" | grep -q 'NOTE cards cite <invariant> but no spec'; then ok "invariants with no findable spec NOTE and pass"
else bad "invariants with no findable spec NOTE and pass (rc=$rc err=$err)"; fi

D="$T/inv-flag"
card "$D/cards" 01 '' '<invariant id="I1">wrong text</invariant>' 'npm test' 'none'
spec_with "$D" "$I1"; rm "$D/cards/00-INDEX.md"
err=$(bash "$L" --dir "$D/cards" --spec "$D/specs/s.md" 2>&1 >/dev/null); rc=$?
if [ "$rc" = 2 ] && printf '%s' "$err" | grep -q 'invariant-drift'; then ok "--spec overrides the index lookup"
else bad "--spec overrides the index lookup (rc=$rc err=$err)"; fi

D="$T/inv-pipe"
card "$D/cards" 01 '' '<invariant id="I1">`enabled \|\| forced` stays true while held</invariant>' 'npm test' 'none'
spec_with "$D" '| I1 | Flag | on → off | FlagSvc | `enabled \|\| forced` stays true while held | none |'
err=$(bash "$L" --dir "$D/cards" 2>&1 >/dev/null); rc=$?
if [ "$rc" = 0 ] && [ -z "$err" ]; then ok "an escaped pipe inside the Invariant cell is one cell, not two"
else bad "an escaped pipe inside the Invariant cell is one cell, not two (rc=$rc err=$err)"; fi

D="$T/inv-case"
card "$D/cards" 09 '' '<invariant id="I1">dispatched once per repo per rules version</invariant>' 'npm test' 'none'
spec_with "$D" "$I1"; sed -i.bak 's/^## Shared state & invariants/## Shared State \& Invariants/' "$D/specs/s.md"
err=$(bash "$L" --dir "$D/cards" 2>&1 >/dev/null); rc=$?
if [ "$rc" = 0 ] && [ -z "$err" ]; then ok "the section heading matches in any case"
else bad "the section heading matches in any case (rc=$rc err=$err)"; fi

D="$T/inv-nocol"
card "$D/cards" 01 '' '<invariant id="I1">x</invariant>' 'npm test' 'none'
mkdir -p "$D/specs"; git -C "$D" init -q
printf '# Spec\n## Shared state & invariants\n| ID | E | S | Writer(s) | Rule | Err |\n|---|---|---|---|---|---|\n| I1 | a | b | c | x | e |\n' > "$D/specs/s.md"
printf 'Spec: specs/s.md\n' > "$D/cards/00-INDEX.md"
expect "a table with no Invariant column names the header, not the cards" "$D/cards" 2 invariant-header

D="$T/empty"; mkdir -p "$D"
expect "a dir with no cards is a usage error" "$D" 3 ""
expect "no --dir is a usage error" "$T/nope" 3 ""

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
