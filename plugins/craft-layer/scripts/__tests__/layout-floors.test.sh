#!/usr/bin/env bash
# layout-floors.test.sh — runs gates.spec.ts's layout-floors test on a fixture breaking every floor and asserts the test passes,
# layout-floors.json records each break with a stamp audit.md step 8 can date, a floors test that dies leaves no file behind,
# and three probe pages that once produced false values (hidden nav items, grid decoration, a wrapper-painted dark page) read true.
# Misses: SKIPs without a local Playwright whose Chromium launches (CI installs none); the stale rule is audit.md's prose, restated here.
set -u

here=$(cd "$(dirname "$0")" && pwd)
GATES="$here/../../template/craft-gates"
FIXTURE="$here/fixtures/fixture-floors-broken.html"
[ -f "$GATES/gates.spec.ts" ] || { printf 'FAIL: gates.spec.ts not found under %s\n' "$GATES"; exit 1; }
[ -f "$FIXTURE" ] || { printf 'FAIL: fixture not found at %s\n' "$FIXTURE"; exit 1; }
command -v node >/dev/null 2>&1 || { printf 'SKIP: node not installed, so no Chromium to launch\n'; exit 0; }

pw_launches() { # node_modules-dir -> exit 0 when its chromium starts
  node -e '
    const t = setTimeout(() => process.exit(3), 20000)
    require(process.argv[1] + "/playwright").chromium.launch()
      .then((b) => b.close()).then(() => { clearTimeout(t); process.exit(0) }, () => process.exit(1))
  ' "$1" >/dev/null 2>&1
}
PW=""
for nm in ${CRAFT_GATES_PLAYWRIGHT:-} $(ls -dt "$HOME"/.npm/_npx/*/node_modules 2>/dev/null); do
  [ -f "$nm/playwright/cli.js" ] || continue
  if pw_launches "$nm"; then PW="$nm"; break; fi
done
[ -n "$PW" ] || {
  printf 'SKIP: no Playwright whose Chromium launches (looked in $CRAFT_GATES_PLAYWRIGHT and ~/.npm/_npx) — the floors fixture did NOT run\n'
  exit 0
}

WS=$(mktemp -d); trap 'rm -rf "$WS"' EXIT
pass=0; fail=0
verdict() { # label problems
  if [ -z "$2" ]; then pass=$((pass + 1)); printf 'PASS: %s\n' "$1"
  else fail=$((fail + 1)); printf 'FAIL: %s\n%s\n' "$1" "$(printf '%s\n' "$2" | sed 's/^/      /')"; fi
}

# The runner and the spec must share one Playwright instance; the spec imports axe at load and this test never runs it.
shim="$WS/pw/node_modules"; mkdir -p "$shim/@playwright/test" "$shim/@axe-core/playwright"
if [ -d "$PW/@playwright/test" ]; then
  rm -rf "$shim/@playwright/test"; ln -s "$PW/@playwright/test" "$shim/@playwright/test"
else
  printf '{"name":"@playwright/test","main":"index.js"}\n' > "$shim/@playwright/test/package.json"
  printf 'module.exports = require(%s)\n' "\"$PW/playwright/test\"" > "$shim/@playwright/test/index.js"
fi
printf '{"name":"@axe-core/playwright","main":"index.js"}\n' > "$shim/@axe-core/playwright/package.json"
printf 'class AxeBuilder { constructor() { throw new Error("axe stub: the floors test never runs axe") } }\nmodule.exports = AxeBuilder\nmodule.exports.default = AxeBuilder\n' \
  > "$shim/@axe-core/playwright/index.js"

file_url() { node -p 'require("url").pathToFileURL(process.argv[1]).href' "$1"; }
url=$(file_url "$FIXTURE")
TITLE='Floors fixture'
project="$WS/project"; mkdir -p "$project"
FLOORS="$project/.craft-layer/layout-floors.json"

run_floors() { # expect-title report-name [project-dir base-url] -> the CLI's exit status
  ( cd "${3:-$project}" && BASE_URL="${4:-$url}" CRAFT_EXPECT_TITLE="$1" CRAFT_PRIMARY_ACTION='Start the trial' NODE_PATH="$shim" \
      PLAYWRIGHT_JSON_OUTPUT_NAME="$WS/$2.json" node "$PW/playwright/cli.js" test \
      --config "$GATES/playwright.config.ts" --grep 'layout floors' --reporter=json >/dev/null 2>"$WS/$2.stderr" )
}
status_of() { # report-name -> the floors test's last result status
  node -e '
    let r; try { r = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")) } catch { console.log("no report"); process.exit() }
    const walk = (s) => [...(s.specs || []), ...(s.suites || []).flatMap(walk)]
    const spec = (r.suites || []).flatMap(walk).find((s) => s.title.startsWith("layout floors"))
    console.log(spec?.tests?.[0]?.results?.at(-1)?.status ?? "missing")
  ' "$WS/$1.json"
}

t0=$(node -p 'new Date().toISOString()')
run_floors "$TITLE" first; rc=$?
status=$(status_of first)

problems=$(node -e '
  const [file, t0, url, title] = process.argv.slice(1)
  let j; try { j = JSON.parse(require("fs").readFileSync(file, "utf8")) } catch (e) { console.log(`no readable file: ${e.message}`); process.exit() }
  const s = j.stamp || {}, at = Date.parse(s.started)
  if (!(at >= Date.parse(t0) && at <= Date.now())) console.log(`stamp.started ${s.started} is not inside this run (began ${t0})`)
  if (s.baseUrl !== url) console.log(`stamp.baseUrl ${s.baseUrl} is not the BASE_URL passed (${url})`)
  if (s.title !== title) console.log(`stamp.title ${s.title} is not CRAFT_EXPECT_TITLE (${title})`)
  const widths = Object.keys(j.breakpoints || {}).sort().join(",")
  if (widths !== "1280,390,768") console.log(`breakpoints ${widths}, want 390,768,1280`)
' "$FLOORS" "$t0" "$url" "$TITLE")
verdict 'floors file is written and stamped' "$problems"

problems=$(node -e '
  let j; try { j = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")) } catch (e) { console.log(`no readable file: ${e.message}`); process.exit() }
  const want = { headlineLines: 3, ctaInFirstViewport: false, emptyGridCells: 1, pagePolarity: "light",
                 sections: [{ index: 0, polarity: "light" }, { index: 1, polarity: "dark" }, { index: 2, polarity: "light" }] }
  for (const w of ["390", "768", "1280"]) {
    const b = (j.breakpoints || {})[w] || {}
    for (const [k, v] of Object.entries(want)) {
      if (JSON.stringify(b[k]) !== JSON.stringify(v)) console.log(`${w} ${k}: want ${JSON.stringify(v)}, got ${JSON.stringify(b[k])}`)
    }
    const inverted = (b.sections || [])[1]?.polarity
    if (!inverted || inverted === b.pagePolarity) console.log(`${w} inverted section ${inverted} does not differ from pagePolarity ${b.pagePolarity}`)
    const nav = w === "1280" ? 2 : undefined
    if (b.navLines !== nav) console.log(`${w} navLines: want ${nav ?? "absent"}, got ${JSON.stringify(b.navLines)}`)
  }
' "$FLOORS")
[ "$rc" -eq 0 ] && [ "$status" = passed ] || problems=$(printf 'test %s, CLI exit %s: %s\n%s' "$status" "$rc" "$(tail -3 "$WS/first.stderr")" "$problems")
verdict 'broken floors are recorded, test still passes' "$problems"

# audit.md step 8: measured only when stamp.started is at or after the audit's start AND stamp.baseUrl is its BASE_URL.
problems=$(node -e '
  const [file, t0, url] = process.argv.slice(1)
  let j; try { j = JSON.parse(require("fs").readFileSync(file, "utf8")) } catch (e) { console.log(`no readable file: ${e.message}`); process.exit() }
  const measured = (runStart, base) => Date.parse(j.stamp?.started) >= Date.parse(runStart) && j.stamp?.baseUrl === base
  if (!measured(t0, url)) console.log("control: the file this run wrote reads as not measured")
  if (measured(new Date(Date.now() + 1000).toISOString(), url)) console.log("a file stamped before a later audit began reads as measured")
  if (measured(t0, "http://localhost:9/")) console.log("a file naming another BASE_URL reads as measured")
' "$FLOORS" "$t0" "$url")
run_floors 'not the page at this url' second; rc=$?
status=$(status_of second)
[ "$rc" -ne 0 ] && [ "$status" = failed ] || problems=$(printf '%s\nwrong-identity run: test %s, CLI exit %s — expected it to fail' "$problems" "$status" "$rc")
[ ! -e "$FLOORS" ] || problems=$(printf '%s\nthe earlier run'\''s layout-floors.json survived a run that died before writing' "$problems")
verdict 'stale stamp reads as not measured' "$(printf '%s' "$problems" | sed '/^$/d')"

probe() { # label fixture field want-json widths — a page shape that once produced a false floor value
  local name=${2%.html} dir="$WS/${2%.html}" rc status problems
  [ -f "$here/fixtures/$2" ] || { verdict "$1" "fixture $2 missing"; return; }
  mkdir -p "$dir"
  run_floors "$TITLE" "$name" "$dir" "$(file_url "$here/fixtures/$2")"; rc=$?
  status=$(status_of "$name")
  problems=$(node -e '
    const [file, field, want, ...widths] = process.argv.slice(1)
    let j; try { j = JSON.parse(require("fs").readFileSync(file, "utf8")) } catch (e) { console.log(`no readable file: ${e.message}`); process.exit() }
    for (const w of widths) {
      const got = JSON.stringify(((j.breakpoints || {})[w] || {})[field])
      if (got !== want) console.log(`${w} ${field}: want ${want}, got ${got}`)
    }
  ' "$dir/.craft-layer/layout-floors.json" "$3" "$4" $5)
  [ "$rc" -eq 0 ] && [ "$status" = passed ] || problems=$(printf 'test %s, CLI exit %s: %s\n%s' "$status" "$rc" "$(tail -3 "$WS/$name.stderr")" "$problems")
  verdict "$1" "$problems"
}
probe 'hidden nav items are not counted' fixture-floors-nav-hidden.html navLines 1 '1280'
probe 'positioned decoration is not an empty cell' fixture-floors-grid-decoration.html emptyGridCells 0 '390 768 1280'
probe 'wrapper-painted dark page reads dark' fixture-floors-dark-wrapper.html pagePolarity '"dark"' '390 768 1280'

printf '\nlayout-floors: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
