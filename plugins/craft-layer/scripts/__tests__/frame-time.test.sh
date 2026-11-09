#!/usr/bin/env bash
# frame-time.test.sh — gates.spec.ts's FRAME_BUDGET_MS equals the p95 figure tier-budgets.md states, then the cpu-throttle test runs on fixture-frames.html
# (WORK_MS 20, must fail and name its p95) and on the clean twin the harness derives by setting WORK_MS to 0 (must pass).
# Misses: the browser half SKIPs without a Playwright whose Chromium (bundled, or a system Chrome channel) launches, and CI installs none; GPU cost is never throttled.
# Why, limits, history: rationale/derivations/plugin-craft-layer.md § plugins/craft-layer/scripts/__tests__/frame-time.test.sh
set -u

here=$(cd "$(dirname "$0")" && pwd)
GATES="$here/../../template/craft-gates"
FIXTURE="$here/fixtures/fixture-frames.html"
BUDGETS="$here/../../skills/motion-tiers/references/tier-budgets.md"
for f in "$GATES/gates.spec.ts" "$FIXTURE" "$BUDGETS"; do [ -f "$f" ] || { printf 'FAIL: %s not found\n' "$f"; exit 1; }; done
pass=0; fail=0
verdict() { # label problems
  if [ -z "$2" ]; then pass=$((pass + 1)); printf 'PASS: %s\n' "$1"
  else fail=$((fail + 1)); printf 'FAIL: %s\n%s\n' "$1" "$(printf '%s\n' "$2" | sed 's/^/      /')"; fi
}

spec_ms=$(sed -n 's/^const FRAME_BUDGET_MS = \([0-9][0-9]*\)$/\1/p' "$GATES/gates.spec.ts")
doc_ms=$(sed -n 's/.*\*\*p95 frame time ≤ \([0-9][0-9]*\)ms under a 4x CPU throttle\*\*.*/\1/p' "$BUDGETS")
problems=""
[ -n "$spec_ms" ] && [ "$spec_ms" = "$doc_ms" ] || problems="gates.spec.ts FRAME_BUDGET_MS='$spec_ms', tier-budgets.md states '$doc_ms'"
verdict 'the spec budget is the one tier-budgets.md states' "$problems"

command -v node >/dev/null 2>&1 || { printf 'SKIP: node not installed, so no Chromium to launch\n'; exit 0; }
how_launches() { # node_modules-dir -> prints "bundled" or "chrome" for the first that starts
  node -e '
    const t = setTimeout(() => process.exit(3), 30000)
    const { chromium } = require(process.argv[1] + "/playwright")
    ;(async () => {
      for (const [how, o] of [["bundled", {}], ["chrome", { channel: "chrome" }]]) {
        try { const b = await chromium.launch(o); await b.close(); console.log(how); clearTimeout(t); process.exit(0) } catch {}
      }
      process.exit(1)
    })()
  ' "$1" 2>/dev/null
}
PW=""; HOW=""
for nm in ${CRAFT_GATES_PLAYWRIGHT:-} $(ls -dt "$HOME"/.npm/_npx/*/node_modules 2>/dev/null); do
  [ -f "$nm/playwright/cli.js" ] || continue
  if HOW=$(how_launches "$nm"); then PW="$nm"; break; fi
done
if [ -z "$PW" ]; then
  printf 'SKIP: no Playwright whose Chromium launches (looked in $CRAFT_GATES_PLAYWRIGHT and ~/.npm/_npx) — the frame-time fixture did NOT run\n'
else
  WS=$(mktemp -d); trap 'rm -rf "$WS"' EXIT
  shim="$WS/pw/node_modules"; mkdir -p "$shim/@playwright/test" "$shim/@axe-core/playwright"
  if [ -d "$PW/@playwright/test" ]; then
    rm -rf "$shim/@playwright/test"; ln -s "$PW/@playwright/test" "$shim/@playwright/test"
  else
    printf '{"name":"@playwright/test","main":"index.js"}\n' > "$shim/@playwright/test/package.json"
    printf 'module.exports = require(%s)\n' "\"$PW/playwright/test\"" > "$shim/@playwright/test/index.js"
  fi
  printf '{"name":"@axe-core/playwright","main":"index.js"}\n' > "$shim/@axe-core/playwright/package.json"
  printf 'class AxeBuilder { constructor() { throw new Error("axe stub: the frame-time test never runs axe") } }\nmodule.exports = AxeBuilder\nmodule.exports.default = AxeBuilder\n' \
    > "$shim/@axe-core/playwright/index.js"
  channel=""; [ "$HOW" = chrome ] && channel=chrome

  run_frames() { # page-file name -> "<status> <error text>" for the cpu-throttle test
    local url; url=$(node -p 'require("url").pathToFileURL(process.argv[1]).href' "$1")
    mkdir -p "$WS/$2"
    ( cd "$WS/$2" && BASE_URL="$url" CRAFT_EXPECT_TITLE='Tideline' CRAFT_BROWSER_CHANNEL="$channel" NODE_PATH="$shim" \
        PLAYWRIGHT_JSON_OUTPUT_NAME="$WS/$2.json" node "$PW/playwright/cli.js" test --config "$GATES/playwright.config.ts" \
        --grep 'cpu throttle' --reporter=json >/dev/null 2>"$WS/$2.stderr" )
    node -e '
      let r; try { r = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")) } catch { console.log("no-report"); process.exit() }
      const walk = (s) => [...(s.specs || []), ...(s.suites || []).flatMap(walk)]
      const res = (r.suites || []).flatMap(walk).find((s) => s.title.startsWith("cpu throttle"))?.tests?.[0]?.results?.at(-1)
      const err = (res?.errors || []).map((e) => e.message || "").join(" ").replace(/\x1b\[[0-9;]*m/g, "").replace(/\s+/g, " ")
      console.log(`${res?.status ?? "missing"} ${err}`)
    ' "$WS/$2.json"
  }

  out=$(run_frames "$FIXTURE" janky)
  problems=""
  case "$out" in failed*) ;; *) problems="want failed, got: $(printf '%s' "$out" | cut -c1-200) $(tail -2 "$WS/janky.stderr")" ;; esac
  printf '%s' "$out" | grep -qE "p95 [0-9.]+ms, median [0-9.]+ms over [0-9]+ frames.*budget p95 <= ${spec_ms}ms" \
    || problems=$(printf '%s\nthe failure does not name the p95, the frame count and the budget' "$problems")
  verdict 'a page doing 20ms of main-thread work per frame fails under the 4x throttle, naming its p95' "$(printf '%s' "$problems" | sed '/^$/d')"

  sed 's/const WORK_MS = 20 /const WORK_MS = 0  /' "$FIXTURE" > "$WS/fixture-frames-clean.html"
  grep -q 'const WORK_MS = 0 ' "$WS/fixture-frames-clean.html" || verdict 'the clean twin was derived' 'the WORK_MS line was not found'
  out=$(run_frames "$WS/fixture-frames-clean.html" clean)
  problems=""
  case "$out" in passed*) ;; *) problems="want passed, got: $(printf '%s' "$out" | cut -c1-200) $(tail -2 "$WS/clean.stderr")" ;; esac
  verdict 'the same page with no per-frame work passes' "$problems"
fi

printf '\nframe-time: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
