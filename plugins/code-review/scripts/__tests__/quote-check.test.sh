#!/usr/bin/env bash
# Fixtures for plugins/code-review/scripts/quote-check.sh, run by CI through the plugins/*/scripts/__tests__/*.test.sh glob.
# Every case that must fire has a control beside it that must not, on the same file.
set -u
QC="$(cd "$(dirname "$0")/.." && pwd)/quote-check.sh"
rc=0
FX=$(mktemp -d); trap 'rm -rf "$FX"' EXIT
mkdir -p "$FX/src" "$FX/lib"

check() { # check <label> <want exit> <want line> <findings> [quote-check args...]
  local label=$1 want_rc=$2 want=$3 in=$4 out got; shift 4
  out=$(cd "${QROOT:-$FX}" && printf '%s\n' "$in" | bash "$QC" --root "${QROOT:-$FX}" "$@" 2>&1); got=$?
  if [ "$got" = "$want_rc" ] && printf '%s\n' "$out" | grep -qF -- "$want"; then
    echo "PASS: $label"
  else
    echo "FAIL: $label — want exit $want_rc and '$want'; got exit $got:"; printf '%s\n' "$out" | sed 's/^/    /'; rc=1
  fi
}

printf '%s\n' 'import { db } from "./db";' '' 'export function total(items) {' \
  '  return items.reduce((sum, item) => sum + item.price, 0);' '}' '' 'export function first(items) {' \
  '  return items[0].name;' '}' '' '// end' > "$FX/src/cart.js"
printf 'export\tfunction  total( items )\r\n{\r\n  return items.reduce(\r\n    (sum,item) => sum + item.price,\r\n    0);\r\n}\r\n' > "$FX/src/crlf.js"

check "a quote copied from the cited line is ok" 0 "ok src/cart.js:4 high" \
  'src/cart.js:4 — high — empty cart crashes — default to [] — quote: `return items.reduce((sum, item) => sum + item.price, 0);`'
check "a quote the file does not hold is a mismatch, exit 1" 1 "mismatch src/cart.js:4 high" \
  'src/cart.js:4 — high — empty cart crashes — default to [] — quote: `return items.map((item) => item.price);`'

check "drift: the quoted line 3 below the cited line is ok" 0 "ok src/cart.js:5 medium" \
  'src/cart.js:5 — medium — smell — fix — quote: `return items[0].name;`'
check "drift: the quoted line 3 above the cited line is ok" 0 "ok src/cart.js:7 medium" \
  'src/cart.js:7 — medium — smell — fix — quote: `return items.reduce((sum, item)`'
check "drift: the quoted line 4 below the cited line is a mismatch" 1 "mismatch src/cart.js:4 medium — quote is not in lines 1-7" \
  'src/cart.js:4 — medium — smell — fix — quote: `return items[0].name;`'

check "whitespace: tabs, doubled spaces, CRLF and a call wrapped over three lines are ok" 0 "ok src/crlf.js:3 high" \
  'src/crlf.js:3 — high — x — y — quote: `export function total(items) { return items.reduce((sum, item) => sum + item.price, 0);`'
check "whitespace: the same quote with one token changed is a mismatch" 1 "mismatch src/crlf.js:3 high" \
  'src/crlf.js:3 — high — x — y — quote: `export function total(items) { return items.reduce((sum, item) => sum - item.price, 0);`'

check "a leading … marks a suffix: ok" 0 "ok src/cart.js:4 low" \
  'src/cart.js:4 — low — x — y — quote: `…item.price, 0);`'
check "a trailing ... marks a prefix: ok" 0 "ok src/cart.js:4 low" \
  'src/cart.js:4 — low — x — y — quote: `return items.reduce(...`'
check "a leading … before text the file does not hold is a mismatch" 1 "mismatch src/cart.js:4 low" \
  'src/cart.js:4 — low — x — y — quote: `…item.cost, 0);`'
check "an inner … joins parts found in order: ok" 0 "ok src/cart.js:3 low" \
  'src/cart.js:3 — low — x — y — quote: `export function total(items) { … sum + item.price`'

printf '%s\n' 'let n = 0;' 'for (const x of xs) ++n; // counted' > "$FX/src/count.js"
check "a line copied from the patch with its leading + is ok" 0 "ok src/cart.js:4 high" \
  'src/cart.js:4 — high — x — y — quote: `+  return items.reduce((sum, item) => sum + item.price, 0);`'
check "a leading + before text the file does not hold is a mismatch" 1 "mismatch src/cart.js:4 high" \
  'src/cart.js:4 — high — x — y — quote: `+  return items.map((item) => item.price);`'
check "real code that opens with ++ matches as typed" 0 "ok src/count.js:2 high" \
  'src/count.js:2 — high — x — y — quote: `++n; // counted`'
check "real code that opens with ++ is still judged: mismatch" 1 "mismatch src/count.js:2 high" \
  'src/count.js:2 — high — x — y — quote: `++total; // counted`'

printf '%s\n' 'ps aux | grep -v grep' 'grep "warn\|error" app.log' > "$FX/src/pipe.sh"
check "a table cell's escaped \\| matches a | in the file" 0 "ok src/pipe.sh:1 high" \
  'src/pipe.sh:1 — high — x — y — quote: `ps aux \| grep -v grep`'
check "an escaped \\| before text the file does not hold is a mismatch" 1 "mismatch src/pipe.sh:1 high" \
  'src/pipe.sh:1 — high — x — y — quote: `ps aux \| grep -v sed`'
check "a real \\| in the file matches as typed" 0 "ok src/pipe.sh:2 high" \
  'src/pipe.sh:2 — high — x — y — quote: `grep "warn\|error" app.log`'

printf '%s\n' "grep -E 'warn\\|error' app.log | sort -u | head -n 20" > "$FX/src/run.sh"
check "a real \\| with a … cut is tried as typed: ok" 0 "ok src/run.sh:1 high" \
  'src/run.sh:1 — high — x — y — quote: `grep -E '"'warn\\|error'"' app.log …`'
check "a real \\| with a leading + is tried as typed: ok" 0 "ok src/run.sh:1 high" \
  'src/run.sh:1 — high — x — y — quote: `+grep -E '"'warn\\|error'"' app.log | sort -u`'
check "a real \\| with a … cut before text the file lacks is a mismatch" 1 "mismatch src/run.sh:1 high" \
  'src/run.sh:1 — high — x — y — quote: `grep -E '"'warn\\|fatal'"' app.log …`'
printf '%s\n' "grep -n 'TODO\\|FIXME' \"\$1\" | wc -l" > "$FX/src/check.sh"
check "a table cell mixing the file's \\| with an escaped pipe: ok" 0 "ok src/check.sh:1 high" \
  'src/check.sh:1 — high — x — y — quote: `grep -n '"'TODO\\|FIXME'"' "$1" \| wc -l`'
check "the same mix with text the file lacks is a mismatch" 1 "mismatch src/check.sh:1 high" \
  'src/check.sh:1 — high — x — y — quote: `grep -n '"'TODO\\|XXX'"' "$1" \| wc -l`'
check "a patch - line of code the file still holds: ok" 0 "ok src/cart.js:8 high" \
  'src/cart.js:8 — high — x — y — quote: `-  return items[0].name;`'
check "a patch - line of code the file lacks is a mismatch" 1 "mismatch src/cart.js:8 high" \
  'src/cart.js:8 — high — x — y — quote: `-  return items[1].name;`'
printf 'const\302\240total = sum(rows);\n' > "$FX/src/nbsp.js"
check "a no-break space in the file against a typed space: ok" 0 "ok src/nbsp.js:1 high" \
  'src/nbsp.js:1 — high — x — y — quote: `const total = sum(rows);`'
check "the same with one token changed is a mismatch" 1 "mismatch src/nbsp.js:1 high" \
  'src/nbsp.js:1 — high — x — y — quote: `const total = sum(cols);`'
check "a wrong quote of 6 Cyrillic letters (12 bytes) is not judged" 0 "ok src/cart.js:4 high" \
  'src/cart.js:4 — high — x — y — quote: `привет`'
check "a wrong quote of 8 Cyrillic letters is judged: mismatch" 1 "mismatch src/cart.js:4 high" \
  'src/cart.js:4 — high — x — y — quote: `приветик`'

check "a range: the quote anywhere in lines 1-11 is ok" 0 "ok src/cart.js:1 medium" \
  'src/cart.js:1-11 — medium — x — y — quote: `return items[0].name;`'
check "a range: the quote 3 past lines 1-2 is a mismatch" 1 "mismatch src/cart.js:1 medium — quote is not in lines 1-5" \
  'src/cart.js:1-2 — medium — x — y — quote: `return items[0].name;`'
check "the last quote: span is the one checked: ok" 0 "ok src/cart.js:4 high" \
  'src/cart.js:4 — high — the reviewer wrote quote: `nothing like this here` — fix — quote: `return items.reduce((sum, item)`'
check "the last quote: span is the one checked: mismatch" 1 "mismatch src/cart.js:4 high" \
  'src/cart.js:4 — high — the reviewer wrote quote: `return items.reduce((sum, item)` — fix — quote: `nothing like this here`'
check "a was: inside the problem clause is not a was: field" 1 "missing-quote src/cart.js:4 critical" \
  'src/cart.js:4 — critical — the default was: `0` and is now gone — restore it'
check "HIGH, [high], a bold path and a heading are read" 1 "missing-quote src/cart.js:4 high" \
  '### **src/cart.js:4** — [HIGH] — x — y'
check "a path list: the quote at the second location is ok" 0 "ok src/cart.js:4 high" \
  'src/cart.js:4, src/count.js:2 — high — x — y — quote: `++n; // counted`'
check "a path list: a quote at neither location is a mismatch" 1 "mismatch src/cart.js:4 high" \
  'src/cart.js:4, src/count.js:2 — high — x — y — quote: `--n; // uncounted`'
mkdir -p "$FX/app/blog/[slug]"
printf '%s\n' 'export default function Page({ params }) {' '  return <h1>{params.slug}</h1>;' '}' > "$FX/app/blog/[slug]/page.tsx"
check "a dynamic-route path with [ ] parses: ok" 0 "ok app/blog/[slug]/page.tsx:2 high" \
  'app/blog/[slug]/page.tsx:2 — high — x — y — quote: `return <h1>{params.slug}</h1>;`'
check "a dynamic-route path with [ ] parses: mismatch" 1 "mismatch app/blog/[slug]/page.tsx:2 high" \
  'app/blog/[slug]/page.tsx:2 — high — x — y — quote: `return <h2>{params.id}</h2>;`'
printf '%s\n' 'export default function Item({ id }) { return id; }' > "$FX/[id].tsx"
check "a path that opens with a balanced [ keeps it: ok" 0 "ok [id].tsx:1 high" \
  '[id].tsx:1 — high — x — y — quote: `export default function Item({ id })`'
check "a path that opens with a balanced [ keeps it: mismatch" 1 "mismatch [id].tsx:1 high" \
  '[id].tsx:1 — high — x — y — quote: `export default function Other({ id })`'
check "an en-dash range 6–8 is read as a range: ok" 0 "ok src/cart.js:6 medium" \
  'src/cart.js:6–8 — medium — x — y — quote: `return items[0].name;`'
check "an en-dash range 1–2 does not reach line 8: mismatch" 1 "mismatch src/cart.js:1 medium — quote is not in lines 1-5" \
  'src/cart.js:1–2 — medium — x — y — quote: `return items[0].name;`'
check "a trailing (symbol) after the location parses: ok" 0 "ok src/cart.js:4 high" \
  'src/cart.js:4 (total) — high — x — y — quote: `return items.reduce((sum, item)`'
check "a trailing (symbol) after the location parses: mismatch" 1 "mismatch src/cart.js:4 high" \
  'src/cart.js:4 (total) — high — x — y — quote: `return items.map((item) => item.price);`'
check "a Markdown link around the location parses: ok" 0 "ok src/cart.js:4 high" \
  '[src/cart.js:4](https://example.com:443/src/cart.js#L4) — high — x — y — quote: `return items.reduce((sum, item)`'
check "a Markdown link around the location parses: mismatch" 1 "mismatch src/cart.js:4 high" \
  '[src/cart.js:4](https://example.com:443/src/cart.js#L4) — high — x — y — quote: `return items.map((item) => item.price);`'
check "locations joined by and: the quote at the second is ok" 0 "ok src/cart.js:4 high" \
  'src/cart.js:4 and src/count.js:2 — high — x — y — quote: `++n; // counted`'
check "locations joined by and: a quote at neither is a mismatch" 1 "mismatch src/cart.js:4 high" \
  'src/cart.js:4 and src/count.js:2 — high — x — y — quote: `--n; // uncounted`'
out=$(cd "$FX" && printf '%s\n' 'See src/cart.js:4 — high — x — y — quote: `ZZ_ECHO_PROBE fabricated text`' | bash "$QC" --root "$FX" 2>&1)
case $out in
  *"unparsed — See src/cart.js:4 — high — x — y — "*) echo "PASS: an unparsed line is echoed up to quote:" ;;
  *) echo "FAIL: an unparsed line is echoed up to quote: — got: $out"; rc=1 ;;
esac
case $out in
  *ZZ_ECHO_PROBE*) echo "FAIL: an unparsed line's quote is not echoed — got: $out"; rc=1 ;;
  *) echo "PASS: an unparsed line's quote is not echoed" ;;
esac
check "a high line that does not parse exits 2" 2 "unparsed — See src/cart.js:4 — high" \
  'See src/cart.js:4 — high — x — y — quote: `return items[0].name;`'
check "a medium line that does not parse is skipped, exit 0" 0 "0 findings" \
  'See src/cart.js:4 — medium — x — y — quote: `nothing like this here`'

check "a was: quote of deleted code is not checked, exit 0" 0 "removed src/cart.js:4 critical — quotes deleted code" \
  'src/cart.js:4 — critical — x — y — was: `if (!items) return 0;`'
check "the same text as a quote: is a mismatch" 1 "mismatch src/cart.js:4 critical" \
  'src/cart.js:4 — critical — x — y — quote: `if (!items) return 0;`'
check "a was: quote beside a wrong quote: does not hide it" 1 "mismatch src/cart.js:4 high" \
  'src/cart.js:4 — high — x — y — was: `if (!items) return 0;` — quote: `return items.map((item) => item.price);`'

qm() { ( eval "$(sed -n '/^cc_quote_match() {/,/^}/p' "$QC")"; cc_quote_match "$@" ) }
fn() { # fn <label> <want status> <cc_quote_match args...>
  local label=$1 want=$2 got; shift 2
  qm "$@"; got=$?
  if [ "$got" = "$want" ]; then echo "PASS: $label"; else echo "FAIL: $label — want status $want, got $got"; rc=1; fi
}
first='import { db } from "./db";'
fn "window: line 1's text cited at line 4 is status 0 with no window (3 back reaches it)" 0 "$FX/src/cart.js" 4 "$first"
fn "window: line 1's text cited at line 5 is status 1 with no window" 1 "$FX/src/cart.js" 5 "$first"
fn "window: line 1's text cited at line 11 is status 1 with no window (3)" 1 "$FX/src/cart.js" 11 "$first"
fn "window: the same with window all is status 0" 0 "$FX/src/cart.js" 11 "$first" all
fn "window: all on text the file does not hold is status 1" 1 "$FX/src/cart.js" 11 'import { cache } from "./cache";' all
fn "window: 10 reaches line 1 from line 11, status 0" 0 "$FX/src/cart.js" 11 "$first" 10
fn "window: 9 stops at line 2, status 1" 1 "$FX/src/cart.js" 11 "$first" 9
fn "window: a window that is neither a number nor all is status 2" 2 "$FX/src/cart.js" 11 "$first" wide
check "an inner … joining parts out of order is a mismatch" 1 "mismatch src/cart.js:3 low" \
  'src/cart.js:3 — low — x — y — quote: `sum + item.price … export function total(items)`'

check "a wrong quote of 7 non-space characters is not judged" 0 "ok src/cart.js:4 high" \
  'src/cart.js:4 — high — x — y — quote: `xy = z(1)`'
check "a wrong quote of 8 non-space characters is judged: mismatch" 1 "mismatch src/cart.js:4 high" \
  'src/cart.js:4 — high — x — y — quote: `xyz = w(1)`'

check "a file that does not exist is undecidable, exit 0" 0 "undecidable src/gone.js:4 high — file not found" \
  'src/gone.js:4 — high — x — y — quote: `return items.map((item) => item.price);`'
check "the same quote on a file that exists is a mismatch, exit 1" 1 "mismatch src/cart.js:4 high" \
  'src/cart.js:4 — high — x — y — quote: `return items.map((item) => item.price);`'

check "a critical finding with no quote is missing-quote, exit 1" 1 "missing-quote src/cart.js:4 critical" \
  'src/cart.js:4 — critical — data loss — fix'
check "a high finding whose only code is unmarked backtick text is missing-quote" 1 "missing-quote src/cart.js:4 high" \
  'src/cart.js:4 — high — `items` may be null — guard it'
check "a medium finding with no quote is unquoted, exit 0" 0 "unquoted src/cart.js:4 medium" \
  'src/cart.js:4 — medium — smell — fix'
check "unmarked backtick text that is wrong is never checked" 0 "unquoted src/cart.js:4 low" \
  'src/cart.js:4 — low — rename `items.map(fooBarBaz)` — fix'

printf 'line one\nAB\000CD return items.reduce\n' > "$FX/src/blob.js"
head -c 1048577 /dev/zero | tr '\000' 'a' > "$FX/src/huge.js"
check "a file holding a NUL byte is undecidable" 0 "undecidable src/blob.js:2 high — not judged" \
  'src/blob.js:2 — high — x — y — quote: `nothing like this here`'
check "a file over 1 MiB is undecidable" 0 "undecidable src/huge.js:1 high — not judged" \
  'src/huge.js:1 — high — x — y — quote: `nothing like this here`'
check "a line number of 0 is undecidable" 0 "undecidable src/cart.js:0 high — not judged" \
  'src/cart.js:0 — high — x — y — quote: `nothing like this here`'

printf '%s\n' 'const greet = (n) => `hi ${n}`;' > "$FX/src/tpl.js"
check "a double-backtick quote holding a backtick is read whole: ok" 0 "ok src/tpl.js:1 high" \
  'src/tpl.js:1 — high — x — y — quote: `` const greet = (n) => `hi ${n}`; ``'
check "a double-backtick quote holding a backtick is read whole: mismatch" 1 "mismatch src/tpl.js:1 high" \
  'src/tpl.js:1 — high — x — y — quote: `` const greet = (n) => `bye ${n}`; ``'

check "list markers, a backticked path:line and line:col are read" 1 "mismatch src/cart.js:4 high" \
  '1. `src/cart.js:4:12` – **high** — x — y — quote: `return items.flatMap(z)`'
check "a line not in the finding shape is not read" 0 "quote-check: 0 findings" \
  'See src/cart.js:4 — quote: `return items.flatMap(z)`'

if command -v git >/dev/null 2>&1; then
  cp "$FX/src/cart.js" "$FX/lib/cart.js"; cp "$FX/src/tpl.js" "$FX/lib/only.js"
  git -C "$FX" init -q && git -C "$FX" add -A >/dev/null 2>&1
  check "a bare name two tracked files end in is undecidable (ambiguous)" 0 "undecidable cart.js:4 high — ambiguous" \
    'cart.js:4 — high — x — y — quote: `return items.map((item) => item.price);`'
  check "a bare name one tracked file ends in is resolved and judged" 1 "mismatch only.js:1 high" \
    'only.js:1 — high — x — y — quote: `return items.map((item) => item.price);`'

  R="$FX/refrepo"; mkdir -p "$R/src"
  gc() { git -C "$R" -c user.name=t -c user.email=t@t -c commit.gpgsign=false "$@" >/dev/null 2>&1; }
  printf '%s\n' 'export function api(a, b) {' '  return a && b;' '}' > "$R/src/api.ts"
  gc init -q && gc checkout -q -b main && gc add -A && gc commit -qm base --no-verify
  gc checkout -q -b feature
  printf '%s\n' 'export function api(a, b) {' '  return a && b && featureFlagEnabledForTheTenant();' '}' > "$R/src/api.ts"
  printf '%s\n' 'export const added = computeTheAddedThing();' > "$R/src/added.ts"
  gc add -A && gc commit -qm feature --no-verify && gc checkout -q main
  pr='src/api.ts:2 — high — x — y — quote: `return a && b && featureFlagEnabledForTheTenant();`'
  QROOT=$R check "a PR quote of a branch not checked out is a mismatch without --ref" 1 "mismatch src/api.ts:2 high" "$pr"
  QROOT=$R check "the same quote with --ref feature is ok" 0 "ok src/api.ts:2 high" "$pr" --ref feature
  QROOT=$R check "a made-up quote with --ref feature is still a mismatch" 1 "mismatch src/api.ts:2 high — quote is not in lines 1-5 of src/api.ts or of feature:src/api.ts" \
    'src/api.ts:2 — high — x — y — quote: `return a && b && someFlagNobodyWrote();`' --ref feature
  QROOT=$R check "a file only the branch adds is undecidable without --ref" 0 "undecidable src/added.ts:1 high — file not found" \
    'src/added.ts:1 — high — x — y — quote: `export const added = computeTheAddedThing();`'
  QROOT=$R check "a file only the branch adds is judged with --ref: ok" 0 "ok src/added.ts:1 high" \
    'src/added.ts:1 — high — x — y — quote: `export const added = computeTheAddedThing();`' --ref feature
  QROOT=$R check "a bare name only the branch has is found in its tree with --ref: ok" 0 "ok added.ts:1 high" \
    'added.ts:1 — high — x — y — quote: `export const added = computeTheAddedThing();`' --ref feature
  QROOT=$R check "the same bare name with a made-up quote is a mismatch" 1 "mismatch added.ts:1 high" \
    'added.ts:1 — high — x — y — quote: `export const added = somethingElseEntirely();`' --ref feature
  QROOT=$R check "an unknown --ref exits 2" 2 "no commit nosuchref" "$pr" --ref nosuchref
else
  echo "SKIP: git not found — tracked-name resolution cases"
fi

two='src/cart.js:4 — high — empty cart crashes — default to [] — quote: `return items.reduce(`
src/cart.js:8 — medium — crashes on [] — guard'
check "--close: every finding fixed with a path:line or contested with a reason, exit 0" 0 "2 closed, 0 open; 0 findings" \
  "$two
| finding | status | evidence |
|---|---|---|
| src/cart.js:4 | fixed | src/cart.js:4 |
| \`src/cart.js:8\` | contested | every caller checks length first, src/a.js:12 |" --close
check "--close: a finding with no row is open, exit 1" 1 "open src/cart.js:8 — no closing row" \
  "$two
| src/cart.js:4 | fixed | src/cart.js:4 |" --close
check "--close: fixed with no changed path:line is open" 1 "open src/cart.js:4 — fixed names no changed path:line" \
  "| src/cart.js:4 | fixed | done |" --close
check "--close: contested with no reason is open" 1 "open src/cart.js:8 — contested gives no reason" \
  "| src/cart.js:8 | contested | - |" --close
check "--close: a status other than fixed or contested is open" 1 "open src/cart.js:8 — status 'deferred'" \
  "| src/cart.js:8 | deferred | later |" --close
check "--close: a bold **fixed** closes" 0 "closed src/cart.js:4 fixed" \
  "| src/cart.js:4 | **fixed** | src/cart.js:4 |" --close
check "--close: a bold **deferred** stays open" 1 "open src/cart.js:4 — status 'deferred'" \
  "| src/cart.js:4 | **deferred** | src/cart.js:4 |" --close
check "--close: nothing to close is not a close" 1 "no closing rows read" "" --close

ok_in='src/cart.js:4 — high — x — y — quote: `return items.map((item) => item.price);`'
printf '%s\n' "$ok_in" > "$FX/findings.txt"
a=$(cd "$FX" && bash "$QC" --root "$FX" findings.txt 2>&1)
b=$(cd "$FX" && printf '%s\n' "$ok_in" | bash "$QC" --root "$FX" 2>&1)
if [ "$a" = "$b" ] && [ -n "$a" ]; then echo "PASS: a findings file and stdin give the same verdicts"
else echo "FAIL: a findings file and stdin differ — file: $a / stdin: $b"; rc=1; fi
(cd "$FX" && bash "$QC" --root "$FX" no-such-file.txt >/dev/null 2>&1); got=$?
if [ "$got" = 2 ]; then echo "PASS: an unreadable findings file exits 2 (could not run)"
else echo "FAIL: an unreadable findings file — want exit 2, got $got"; rc=1; fi

[ "$rc" -eq 0 ] && echo "All quote-check fixtures passed."
exit "$rc"
