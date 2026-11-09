#!/usr/bin/env bash
# system-render.test.sh — node --check, the usage and missing-Playwright exits (through system-extract --source rendered too), clustering of a fixture sample dump with no browser
# (near colours merged, transparent/0px/generic/rare values dropped, byte-identical twice), its ingestion into design-system/, and, with a Chromium, a page whose JS adds a colour.
# Misses: SKIPs the browser half without a local Playwright (CI installs none); whether a cluster is the colour a designer meant is the reader's call.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
sr="$here/system-render.mjs"
ex="$here/system-extract.py"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*"; exit 1; }
command -v node >/dev/null 2>&1 || { echo "SKIP: node not installed — system-render.mjs did NOT run"; exit 0; }
run() { set +e; out="$(cd "$tmp" && env -u NODE_PATH HOME="$tmp" node "$sr" "$@" 2>&1)"; rc=$?; set -e; }

node --check "$sr" || fail "node --check system-render.mjs"
run; [ "$rc" = 2 ] || fail "no target must exit 2 (rc=$rc): $out"
run x.html --bogus; [ "$rc" = 2 ] && grep -q 'unknown flag' <<<"$out" || fail "an unknown flag must exit 2 (rc=$rc): $out"
run x.html --samples y.json; [ "$rc" = 2 ] || fail "a target with --samples must exit 2 (rc=$rc)"
run "$tmp/absent.html"; [ "$rc" = 2 ] || fail "a missing file must exit 2 (rc=$rc): $out"
printf 'not json' > "$tmp/bad.json"; run --samples "$tmp/bad.json"; [ "$rc" = 2 ] || fail "an unreadable --samples must exit 2 (rc=$rc)"
printf '{"x":1}' > "$tmp/bad.json"; run --samples "$tmp/bad.json"; [ "$rc" = 2 ] || fail "a --samples file with no samples array must exit 2 (rc=$rc)"

printf '<!doctype html><p>x</p>\n' > "$tmp/page0.html"
run "$tmp/page0.html" --project "$tmp"
[ "$rc" = 3 ] && grep -q 'NOT MEASURED — no Playwright resolvable' <<<"$out" || fail "no Playwright must exit 3 (rc=$rc): $out"
set +e; out="$(cd "$tmp" && env -u NODE_PATH HOME="$tmp" python3 "$ex" "$tmp/page0.html" --source rendered --out "$tmp/ds0" 2>&1)"; rc=$?; set -e
[ "$rc" = 3 ] && grep -q 'no Playwright' <<<"$out" || fail "system-extract --source rendered must pass exit 3 through (rc=$rc): $out"
[ ! -e "$tmp/ds0" ] || fail "a NOT MEASURED rendered run wrote design-system files"

python3 - "$tmp/samples.json" <<'PY'
import json, sys
s = []
def add(kind, value, el, n):
    s.extend([[kind, value, el]] * n)
add("text", "rgb(31, 41, 55)", "p.lead", 5)
add("text", "rgb(31, 41, 56)", "span.meta", 2)
add("background", "rgba(0, 0, 0, 0)", "div", 10)
add("background", "rgb(15, 118, 110)", "button.btn", 3)
add("border", "rgb(226, 232, 240)", "div.card", 1)
add("background", "oklch(0.5 0.1 200)", "div.chip", 2)
add("background", "rgba(0, 0, 0, 0.5)", "div.scrim", 2)
add("text", "lab(50 40 30)", "em", 2)
add("family", '"Inter", system-ui, sans-serif', "p.lead", 3)
add("family", "system-ui, sans-serif", "small", 4)
add("size", "16px", "p.lead", 4)
add("size", "15.5px", "span.meta", 2)
add("spacing", "0px", "div", 20)
add("spacing", "16px", "div.card", 6)
add("spacing", "-8px", "div.pull", 2)
add("radius", "8px", "button.btn", 3)
add("radius", "50%", "img.avatar", 2)
add("radius", "8px 4px", "div.odd", 1)
json.dump({"elements": 12, "samples": s, "label": "fixture.html", "viewport": "1440x900"}, open(sys.argv[1], "w"))
PY
run --samples "$tmp/samples.json"; [ "$rc" = 0 ] || fail "--samples on the fixture must exit 0 (rc=$rc): $out"
printf '%s\n' "$out" > "$tmp/t1.json"
run --samples "$tmp/samples.json"; printf '%s\n' "$out" > "$tmp/t2.json"
cmp -s "$tmp/t1.json" "$tmp/t2.json" || fail "two clusterings of one dump differ"
python3 - "$tmp/t1.json" <<'PY' || fail "the clustered tokens are wrong: $(cat "$tmp/t1.json")"
import json, sys
t = json.load(open(sys.argv[1]))
c = t["color"]
dk = lambda n: n["$extensions"]["design-kit"]
assert c["1f2937"]["$value"] == "#1f2937" and dk(c["1f2937"])["uses"] == 7 and dk(c["1f2937"])["merged"] == 2, c["1f2937"]
assert dk(c["1f2937"])["sources"] == ["rendered fixture.html p.lead", "rendered fixture.html span.meta"], dk(c["1f2937"])
assert dk(c["0f766e"])["roles"] == ["background"], c["0f766e"]
assert "e2e8f0" not in c, "a single-use colour must fall under --min-uses 2"
assert c["000000-a50"]["$value"] == "rgba(0, 0, 0, 0.5)", c.get("000000-a50")
assert c["lab-50-40-30"]["$value"] == "lab(50 40 30)", "a lab() colour must be kept as written, under a slug name"
assert not any(n["$value"] in ("rgba(0, 0, 0, 0)", "transparent") for n in c.values()), "transparent kept"
oklch = [k for k, n in c.items() if dk(n)["sources"] == ["rendered fixture.html div.chip"]]
assert oklch and c[oklch[0]]["$value"].startswith("#"), "oklch() must be converted to hex"
fam = t["typography"]["family"]
assert list(fam) == ["inter"] and fam["inter"]["$value"] == "Inter", fam
size = t["typography"]["size"]
assert size["15_5px"]["$value"] == "15.5px" and size["16px"]["$type"] == "dimension", size
assert list(t["spacing"]) == ["16px"] and dk(t["spacing"]["16px"])["uses"] == 6, t["spacing"]
assert t["radius"]["50pct"]["$value"] == "50%" and dk(t["radius"]["8px"])["uses"] == 4, t["radius"]  # "8px 4px" reads its first radius
assert t["$extensions"]["design-kit"]["rendered"]["source"] == "fixture.html"
PY
run --samples "$tmp/samples.json" --min-uses 1
grep -q '"e2e8f0"' <<<"$out" || fail "--min-uses 1 must bring the single-use colour back"

python3 - "$tmp/blank.json" <<'PY'
import json, sys
json.dump({"elements": 3, "samples": [["background", "rgba(0, 0, 0, 0)", "div"]] * 5 + [["spacing", "0px", "div"]] * 9
           + [["family", "system-ui, sans-serif", "p"]] * 4, "label": "blank.html"}, open(sys.argv[1], "w"))
PY
run --samples "$tmp/blank.json" --out "$tmp/blank-tokens.json"
[ "$rc" = 1 ] && grep -q 'no value survived' <<<"$out" || fail "an all-transparent, all-zero, generic-only dump must exit 1 (rc=$rc): $out"
[ ! -e "$tmp/blank-tokens.json" ] || fail "an exit-1 run wrote --out"

# system-extract's ingestion, fed by the real clustering through a stand-in node that swaps the page for the dump.
mkdir -p "$tmp/bin"
printf '#!/bin/sh\nexec "%s" "$1" --samples "%s" --out -\n' "$(command -v node)" "$tmp/samples.json" > "$tmp/bin/node"; chmod +x "$tmp/bin/node"
( cd "$tmp" && PATH="$tmp/bin:$PATH" python3 "$ex" "https://example.test/" --source rendered --out "$tmp/ds" >"$tmp/ex.out" 2>&1 ) \
  || fail "system-extract --source rendered failed on the dump: $(cat "$tmp/ex.out")"
python3 - "$tmp/ds" <<'PY' || fail "the ingested design-system/ is wrong"
import json, os, sys
d = sys.argv[1]
t = json.load(open(os.path.join(d, "tokens.json")))
n = t["color"]["1f2937"]
assert n["$value"] == "#1f2937" and n["$extensions"]["design-kit"]["uses"] == 7, n
assert t["typography"]["size"]["16px"]["$type"] == "dimension", t["typography"]
md = open(os.path.join(d, "DESIGN-SYSTEM.md")).read()
assert "# Design system — example.test" in md and "the rendered element it was read from" in md and "- Type sizes: " in md, md[:600]
assert "rendered mode:" in md, "the rendered note is missing"
kit = open(os.path.join(d, "kit.html")).read()
assert "font-size:16px" in kit and "font-family:'16px'" not in kit, "a size token rendered as a typeface card"
PY

pw_launches() { # <node_modules> -> 0 when chromium.mjs launches a browser through it
  NODE_PATH="$1" node --input-type=module -e '
    const t = setTimeout(() => process.exit(3), 40000)
    const m = await import(process.argv[1])
    m.launchChromium({ project: process.argv[2] }).then((r) => r.browser.close())
      .then(() => { clearTimeout(t); process.exit(0) }, () => process.exit(1))
  ' "$here/chromium.mjs" "$tmp" >/dev/null 2>&1
}
PW=""
for nm in ${DESIGN_KIT_PLAYWRIGHT:-} $(ls -dt "$HOME"/.npm/_npx/*/node_modules 2>/dev/null); do
  [ -f "$nm/playwright/package.json" ] || [ -f "$nm/playwright-core/package.json" ] || continue
  if pw_launches "$nm"; then PW="$nm"; break; fi
done
if [ -z "$PW" ]; then
  echo "SKIP: no Playwright whose Chromium launches (looked in \$DESIGN_KIT_PLAYWRIGHT and ~/.npm/_npx) — no page was rendered; usage, exit 3, clustering and ingestion ran"
  echo "PASS system-render.test.sh"
  exit 0
fi

cat > "$tmp/page.html" <<'EOF'
<!doctype html><html><head><style>
body { margin: 0; font-family: "Fraunces", Georgia, serif; color: #1f2937; background: #ffffff; }
.card { padding: 24px; border-radius: 12px; background: #f8fafc; margin: 16px; }
.hidden { display: none; color: #ff0000; padding: 24px; }
</style></head><body>
<div class="card"><p>One</p><p>Two</p></div><div class="card"><p>Three</p><span class="hidden">x</span><span class="hidden">y</span></div>
<div id="late"></div>
<script>document.getElementById('late').innerHTML = '<p style="color:#7c3aed">JS one</p><p style="color:#7c3aed">JS two</p>'</script>
</body></html>
EOF
set +e; out="$(cd "$tmp" && NODE_PATH="$PW" node "$sr" "$tmp/page.html" --project "$tmp" --dump-samples "$tmp/dump.json" 2>&1)"; rc=$?; set -e
[ "$rc" = 0 ] || fail "rendering the fixture page must exit 0 (rc=$rc): $out"
grep -q '"7c3aed"' <<<"$out" || fail "the colour the page's JavaScript added is missing: $out"
grep -q '"ff0000"' <<<"$out" && fail "a display:none element's colour was read: $out"
grep -q '"fraunces"' <<<"$out" || fail "the body typeface is missing: $out"
printf '%s\n' "$out" > "$tmp/live.json"
set +e; again="$(cd "$tmp" && env -u NODE_PATH node "$sr" --samples "$tmp/dump.json" 2>&1)"; set -e
[ "$again" = "$out" ] || fail "re-clustering the --dump-samples file gave other tokens than the live run"
set +e; out="$(cd "$tmp" && NODE_PATH="$PW" python3 "$ex" "$tmp/page.html" --source rendered --out "$tmp/ds-live" 2>&1)"; rc=$?; set -e
[ "$rc" = 0 ] && grep -q '"7c3aed"' "$tmp/ds-live/tokens.json" || fail "system-extract --source rendered on the page (rc=$rc): $out"

echo "PASS system-render.test.sh"
