#!/usr/bin/env bash
# finish-lint.test.sh — finish-lint.mjs's syntax, arguments, missing-playwright exit, JSON shape, waivers and source half, then each DOM rule on fixture-finish.html: every
# defect line found, every silent nearest neighbour left alone, and zero findings on the clean twin derived by deleting the defect lines; fails if git status under plugins/craft-layer changes.
# Misses: the browser cases SKIP without a Playwright whose Chromium (bundled, or a system Chrome channel) launches, and CI installs none, so there only the static cases run.
# Why, limits, history: rationale/derivations/plugin-craft-layer.md § plugins/craft-layer/scripts/__tests__/finish-lint.test.sh
set -u

here=$(cd "$(dirname "$0")" && pwd)
LINT="$here/../../template/craft-gates/finish-lint.mjs"
FIXTURE="$here/fixtures/fixture-finish.html"
repo_root=$(cd "$here" && git rev-parse --show-toplevel 2>/dev/null || echo "")
[ -f "$LINT" ] || { printf 'FAIL: finish-lint.mjs not found at %s\n' "$LINT"; exit 1; }
[ -f "$FIXTURE" ] || { printf 'FAIL: fixture not found at %s\n' "$FIXTURE"; exit 1; }
command -v node >/dev/null 2>&1 || { printf 'SKIP: node not installed\n'; exit 0; }

WS=$(mktemp -d); trap 'rm -rf "$WS"' EXIT
pass=0; fail=0
ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); printf 'FAIL  %s\n      %s\n' "$1" "$2"; }
git_snap() { [ -n "$repo_root" ] && ( cd "$repo_root" && git status --porcelain -- plugins/craft-layer ) || true; }
SNAP_BEFORE=$(git_snap)
file_url() { node -p 'require("url").pathToFileURL(process.argv[1]).href' "$1"; }

if out=$(node --check "$LINT" 2>&1); then ok; else bad "node --check finish-lint.mjs" "$out"; fi

out=$( cd "$WS" && node "$LINT" --bogus 2>&1 ); rc=$?
if [ "$rc" -eq 2 ] && printf '%s\n' "$out" | grep -q '^usage:'; then ok; else bad "an unknown argument exits 2 with the usage line" "exit $rc: $out"; fi

mkdir -p "$WS/nopw"
out=$( cd "$WS/nopw" && NODE_PATH= BASE_URL= node "$LINT" --url "$(file_url "$FIXTURE")" --src "$WS/nopw" 2>&1 ); rc=$?
if [ "$rc" -eq 3 ] && printf '%s\n' "$out" | grep -q 'missing: the playwright package'; then ok; else
  bad "no playwright package exits 3 and names it" "exit $rc: $(printf '%s\n' "$out" | tail -2)"; fi

# The source half: a fetching file that maps with no state branch is a finding; its two neighbours are not.
proj="$WS/proj"; mkdir -p "$proj/src"
cat > "$proj/src/Invoices.tsx" <<'TSX'
export function Invoices() {
  const { data } = useQuery({ queryKey: ['invoices'], queryFn: () => fetch('/api/invoices').then((r) => r.json()) })
  return <ul>{data.map((i) => <li key={i.id}>{i.number}</li>)}</ul>
}
TSX
cat > "$proj/src/Plans.tsx" <<'TSX'
const PLANS = [{ id: 'skiff', name: 'Skiff' }, { id: 'ketch', name: 'Ketch' }]
export const Plans = () => <ul>{PLANS.map((p) => <li key={p.id}>{p.name}</li>)}</ul>
TSX
cat > "$proj/src/Orders.tsx" <<'TSX'
export function Orders() {
  const { data, isLoading } = useSWR('/api/orders', (u) => fetch(u).then((r) => r.json()))
  if (isLoading) return <Spinner />
  return <ul>{data.map((o) => <li key={o.id}>{o.ref}</li>)}</ul>
}
TSX
out=$( cd "$proj" && BASE_URL= node "$LINT" 2>&1 ); rc=$?
lines=$(printf '%s\n' "$out" | grep -E '^ +FAIL +stateless-collection +no-state-branch' || true)
if [ "$rc" -eq 2 ] && [ "$(printf '%s\n' "$lines" | grep -c 'src/Invoices.tsx:3')" -eq 1 ] && ! printf '%s\n' "$lines" | grep -qE 'Plans|Orders'; then ok; else
  bad "source half: Invoices.tsx:3 alone is found, and with no URL the run exits 2" "exit $rc: $(printf '%s\n' "$out" | grep -E 'FAIL|NOT MEASURED' | head -4)"; fi

json=$( cd "$proj" && BASE_URL= node "$LINT" --json 2>/dev/null )
problems=$(printf '%s' "$json" | node -e '
  let r; try { r = JSON.parse(require("fs").readFileSync(0, "utf8")) } catch (e) { console.log(`not JSON: ${e.message}`); process.exit() }
  if (r.tool !== "finish-lint" || r.schema !== 1) console.log(`tool/schema ${r.tool}/${r.schema}`)
  if (r.dom?.measured !== false || r.exit !== 2) console.log(`dom.measured ${r.dom?.measured}, exit ${r.exit}`)
  if (r.static?.files !== 3) console.log(`static.files ${r.static?.files}, want 3`)
  const f = r.findings || []
  if (f.length !== 1 || f[0].rule !== "stateless-collection" || f[0].where !== "src/Invoices.tsx:3" || f[0].waived !== null) console.log(`findings ${JSON.stringify(f)}`)
')
if [ -z "$problems" ]; then ok; else bad "--json prints one parseable report with the finding and the not-measured DOM" "$problems"; fi

mkdir -p "$proj/.craft-layer"
printf '[{"check":"stateless-collection","value":"no-state-branch","reason":"the invoice list is always seeded by the import"},{"check":"focus-ring","value":"*"}]\n' > "$proj/.craft-layer/waivers.json"
out=$( cd "$proj" && BASE_URL= node "$LINT" 2>&1 )
if printf '%s\n' "$out" | grep -qE '^ +WAIVED +stateless-collection' && printf '%s\n' "$out" | grep -q "waiver for 'focus-ring' has no reason"; then ok; else
  bad "a waiver with a reason waives; one without is ignored and said so" "$(printf '%s\n' "$out" | grep -E 'WAIVED|FAIL|note' | head -3)"; fi

PW=""
for nm in ${CRAFT_GATES_PLAYWRIGHT:-} $(ls -dt "$HOME"/.npm/_npx/*/node_modules 2>/dev/null); do
  [ -f "$nm/playwright/cli.js" ] && { PW="$nm"; break; }
done
lint_dom() { # page-url report-name [expect-title] -> the CLI's exit status; JSON report in $WS/<name>.json
  ( cd "$WS/empty" && CRAFT_EXPECT_TITLE="${3-Harbourmaster}" NODE_PATH="$PW" node "$LINT" --url "$1" --src "$WS/empty" --json \
      > "$WS/$2.json" 2>"$WS/$2.stderr" )
}
mkdir -p "$WS/empty"
rc=4
[ -n "$PW" ] && { lint_dom "$(file_url "$FIXTURE")" defective; rc=$?; }
if [ -z "$PW" ] || [ "$rc" -eq 3 ] || [ "$rc" -eq 4 ]; then
  printf 'SKIP  browser cases: no Playwright whose Chromium launches (looked in $CRAFT_GATES_PLAYWRIGHT and ~/.npm/_npx%s) — fixture-finish.html did NOT run\n' "${PW:+; finish-lint exit $rc}"
else
  want='dead-control href-hash a#dc-hash
dead-control javascript-void a#dc-void
dead-control no-href a#dc-nohref
dead-control missing-target a#dc-missing
dead-control no-handler button#dc-button
dead-control no-handler div#dc-role
dead-control no-handler button#dc-react
placeholder-copy lorem-ipsum p#ph-lorem
placeholder-copy todo-marker h3#ph-todo
placeholder-copy coming-soon span#ph-soon
placeholder-copy placeholder-word img#ph-alt
placeholder-copy untitled h2#ph-untitled
placeholder-copy stand-in-name cite#ph-name
stateless-collection empty-table table#sc-table
stateless-collection empty-list ul#sc-list
focus-ring no-focus-indicator button#fr-none.bare
focus-ring no-focus-indicator a#fr-link.bare'
  got=$(node -e '
    const r = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"))
    for (const f of r.findings) console.log(`${f.rule} ${f.pattern} ${f.target}`)
  ' "$WS/defective.json" 2>/dev/null | sort)
  missing=$(comm -23 <(printf '%s\n' "$want" | sort) <(printf '%s\n' "$got"))
  extra=$(comm -13 <(printf '%s\n' "$want" | sort) <(printf '%s\n' "$got"))
  if [ "$rc" -eq 1 ] && [ -z "$missing" ]; then ok; else
    bad "every defect line in fixture-finish.html is found, exit 1" "exit $rc; missing: $(printf '%s' "$missing" | tr '\n' ';') $(tail -2 "$WS/defective.stderr")"; fi
  if [ -z "$extra" ]; then ok; else
    bad "no silent nearest neighbour is reported (#anchor with a real id, TODO in <code>, delegated and React handlers, No invoices yet, aria-busy, box-shadow ring)" \
      "$(printf '%s' "$extra" | tr '\n' ';')"; fi

  grep -v '<!-- defect -->' "$FIXTURE" > "$WS/fixture-finish-clean.html"
  lint_dom "$(file_url "$WS/fixture-finish-clean.html")" clean; rc=$?
  n=$(node -e 'const r = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")); console.log(r.findings.length, r.dom.tabStops, r.dom.measured)' "$WS/clean.json" 2>/dev/null)
  set -- $n
  if [ "$rc" -eq 0 ] && [ "${1:-x}" = 0 ] && [ "${2:-0}" -gt 5 ] && [ "${3:-}" = true ]; then ok; else
    bad "the clean twin has zero findings across its Tab stops, exit 0" "exit $rc; findings/stops/measured: ${n:-unreadable}"; fi

  lint_dom "$(file_url "$FIXTURE")" wrong 'not this page'; rc=$?
  if [ "$rc" -eq 2 ] && grep -q 'WRONG APPLICATION' "$WS/wrong.json"; then ok; else
    bad "an unmatched CRAFT_EXPECT_TITLE is not measured (exit 2), never a verdict" "exit $rc"; fi
fi

SNAP_AFTER=$(git_snap)
[ "$SNAP_BEFORE" = "$SNAP_AFTER" ] || bad "harness mutated the repository working tree" \
  "$(diff <(printf '%s\n' "$SNAP_BEFORE") <(printf '%s\n' "$SNAP_AFTER") | head -5)"

printf '\nfinish-lint: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
