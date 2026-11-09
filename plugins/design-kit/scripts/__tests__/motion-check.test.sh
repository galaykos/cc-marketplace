#!/usr/bin/env bash
# motion-check.test.sh — node --check, the usage and missing-Playwright exits, --static on a page breaking every rule, on the nearest page breaking none
# (a 0.01ms reduce override, a static width, will-change) and on a still page; with a Playwright whose Chromium launches, the recorder on the same three kinds plus a __start/__tick page.
# Misses: SKIPs the browser half without a local Playwright (CI installs none); that the frames LOOK right is the capture's contact sheet, not this file.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
mc="$here/motion-check.mjs"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*"; exit 1; }
command -v node >/dev/null 2>&1 || { echo "SKIP: node not installed — motion-check.mjs did NOT run"; exit 0; }
run() { set +e; out="$(cd "$tmp" && env -u NODE_PATH HOME="$tmp" node "$mc" "$@" 2>&1)"; rc=$?; set -e; }

node --check "$mc" || fail "node --check motion-check.mjs"
node --check "$here/chromium.mjs" || fail "node --check chromium.mjs"

run; [ "$rc" = 2 ] && grep -q 'needs a URL or an HTML file' <<<"$out" || fail "no target must exit 2 (rc=$rc): $out"
run --static; [ "$rc" = 2 ] || fail "--static with no file must exit 2 (rc=$rc)"
run x.html --bogus; [ "$rc" = 2 ] && grep -q 'unknown flag --bogus' <<<"$out" || fail "an unknown flag must exit 2 (rc=$rc): $out"
run x.html --min-ms abc; [ "$rc" = 2 ] || fail "a non-numeric --min-ms must exit 2 (rc=$rc)"
run x.html --min-ms 900 --max-ms 100; [ "$rc" = 2 ] || fail "--min-ms above --max-ms must exit 2 (rc=$rc)"
run --static "$tmp/absent.html"; [ "$rc" = 2 ] || fail "an unreadable --static file must exit 2 (rc=$rc)"
run "$tmp/absent.html"; [ "$rc" = 2 ] || fail "a missing file target must exit 2 (rc=$rc): $out"
run --help; [ "$rc" = 0 ] && grep -q '3 NOT MEASURED' <<<"$out" || fail "--help must print the exit codes (rc=$rc)"

cat > "$tmp/clean.html" <<'EOF'
<!doctype html><html><head><style>
.card { width: 320px; will-change: transform; opacity: 0; transform: translateY(24px);
  transition: transform 1.05s cubic-bezier(0.16, 1, 0.3, 1), opacity .7s; }
.in .card { opacity: 1; transform: none; }
.bar { animation: wipe 900ms cubic-bezier(0.65, 0, 0.35, 1) both; }
@keyframes wipe { from { clip-path: inset(0 100% 0 0); filter: blur(6px); } to { clip-path: inset(0); filter: blur(0); } }
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after { animation-duration: 0.01ms !important; transition-duration: 0.01ms !important; }
  .card { transition: none; }
}
</style></head><body><div id="stage"><div class="card" style="transition: opacity 600ms">x</div><div class="bar">y</div></div>
<script>setTimeout(() => document.getElementById('stage').classList.add('in'), 50)</script></body></html>
EOF
printf '.panel { transition: width 300ms ease; }\n' > "$tmp/broken.css"
cat > "$tmp/broken.html" <<'EOF'
<!doctype html><html><head><link rel="stylesheet" href="broken.css">
<style>
.panel { width: 10px; height: 40px; background: #a33; }
.in .panel { width: 300px; }
.grow { animation: grow 2s linear infinite; }
@keyframes grow { 0% { height: 0; filter: blur(20px); } 100% { height: 120px; filter: blur(0); } }
.dot { position: absolute; top: 80px; left: 0; width: 10px; height: 10px; background: #33a; }
</style></head><body><div id="stage"><div class="panel"></div><div class="grow"></div><div class="dot"></div></div>
<script>
setTimeout(() => document.getElementById('stage').classList.add('in'), 50)
const dot = document.querySelector('.dot'); let x = 0
function f() { x += 2; dot.style.left = x + 'px'; if (x < 200) requestAnimationFrame(f) }
requestAnimationFrame(f)
</script></body></html>
EOF
cat > "$tmp/still.html" <<'EOF'
<!doctype html><html><head><style>.a { width: 10px; transition: none; }</style></head><body><p class="a">static</p></body></html>
EOF

run --static "$tmp/clean.html"
[ "$rc" = 0 ] || fail "--static must stay silent on the clean page (rc=$rc): $out"
grep -q '0 failed, 0 warning' <<<"$out" || fail "--static clean page summary: $out"
run --static "$tmp/broken.html"
[ "$rc" = 1 ] || fail "--static must exit 1 on the broken page (rc=$rc): $out"
for want in '| layout-property | fail | .*broken.html:5 .grow' '| layout-property | fail | .*broken.css:1 .panel' \
            '| duration | fail | .*broken.css:1 .panel | 300 ms' '| duration | fail | .*broken.html:5 .grow.*2000 ms.*JS clock' \
            '| blur | fail | .*broken.html:5 .grow' '| reduced-motion | fail |'; do
  grep -q -- "$want" <<<"$out" || fail "--static broken page lacks /$want/:
$out"
done
run --static "$tmp/broken.html" --min-ms 0 --max-ms 5000 --max-blur 40
grep -q '| duration |' <<<"$out" && fail "--min-ms/--max-ms did not move the duration bound: $out"
grep -q '| blur |' <<<"$out" && fail "--max-blur did not move the blur bound: $out"
run --static "$tmp/still.html"
[ "$rc" = 4 ] && grep -q 'NOT MEASURED' <<<"$out" || fail "a page with no motion must be NOT MEASURED, exit 4 (rc=$rc): $out"
run --static "$tmp/broken.html" --json
[ "$rc" = 1 ] || fail "--json must keep the exit code (rc=$rc)"
python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d["mode"]=="static" and any(f["rule"]=="reduced-motion" for f in d["findings"]), d' "$out" \
  || fail "--json is not the findings document: $out"

# The missing-browser exit: an empty project, no NODE_PATH, HOME pointed away from any ~/.node_modules.
run "$tmp/clean.html" --project "$tmp"
[ "$rc" = 3 ] && grep -q 'NOT MEASURED — no Playwright resolvable' <<<"$out" || fail "no Playwright must exit 3 naming it (rc=$rc): $out"
grep -q 'installs nothing' <<<"$out" || fail "the missing-Playwright line must say nothing is installed: $out"

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
  echo "SKIP: no Playwright whose Chromium launches (looked in \$DESIGN_KIT_PLAYWRIGHT and ~/.npm/_npx) — the recorder did NOT run; usage, the exit-3 path and --static did"
  echo "PASS motion-check.test.sh"
  exit 0
fi
brun() { set +e; out="$(cd "$tmp" && NODE_PATH="$PW" node "$mc" "$@" --project "$tmp" 2>&1)"; rc=$?; set -e; }

brun "$tmp/clean.html" --ms 1500
[ "$rc" = 0 ] || fail "the recorder must stay silent on the clean page (rc=$rc): $out"
grep -q '2 animation(s)' <<<"$out" || fail "the recorder did not see the clean page's two transitions: $out"
brun "$tmp/broken.html" --ms 1500
[ "$rc" = 1 ] || fail "the recorder must exit 1 on the broken page (rc=$rc): $out"
for want in '| layout-property | fail | div.panel (CSSTransition width)' '| duration | fail | div.panel' \
            '| layout-property | fail | div.dot (inline style' '| blur | fail | div.grow' '| reduced-motion | fail |'; do
  grep -q -- "$want" <<<"$out" || fail "the recorder's broken page lacks /$want/:
$out"
done
brun "$tmp/still.html" --ms 500
[ "$rc" = 4 ] && grep -q 'nothing animated' <<<"$out" || fail "a still page must be NOT MEASURED, exit 4 (rc=$rc): $out"
brun "$tmp/absent-host.html" ; [ "$rc" = 2 ] || fail "a missing file with a browser present must still exit 2 (rc=$rc)"

cat > "$tmp/contract.html" <<'EOF'
<!doctype html><html><head><style>
#stage { position: relative; width: 400px; height: 200px; background: #eee; }
.chip { position: absolute; left: 20px; top: 20px; width: 40px; height: 40px; background: #36c; opacity: 0; transition: opacity .7s; }
#stage.in .chip { opacity: 1; }
@media (prefers-reduced-motion: reduce) { .chip { transition: none; } }
</style></head><body><div id="stage"><div class="chip"></div></div>
<script>
const stage = document.getElementById('stage'); window.__lt = 0
const still = matchMedia('(prefers-reduced-motion: reduce)').matches
window.__start = () => { stage.classList.add('in'); window.__mark = performance.now() }
window.__tick = (dt) => { window.__lt += dt; if (!still) document.querySelector('.chip').style.transform = `translateX(${Math.round(window.__lt * 40)}px)` }
</script></body></html>
EOF
brun "$tmp/contract.html?capture&static=1" --ms 1000 --pre 5 --selector '#stage' --frames "$tmp/frames"
[ "$rc" = 0 ] || fail "the __start/__tick page must pass (rc=$rc): $out"
grep -q "drove the page's __start/__tick" <<<"$out" || fail "the recorder did not drive the page contract: $out"
n="$(ls "$tmp/frames" | grep -c '\.png$')"; [ "$n" = 65 ] || fail "--frames wrote $n PNGs, want 65 (60 + 5 pre)"
python3 - "$tmp/frames" <<'PY' || fail "frames are not element-sized PNGs, or loop-time.json is off"
import json, os, struct, sys
d = sys.argv[1]
head = open(os.path.join(d, "00030.png"), "rb").read(24)
assert head[:8] == b"\x89PNG\r\n\x1a\n" and struct.unpack(">II", head[16:24]) == (400, 200), head
lt = json.load(open(os.path.join(d, "loop-time.json")))
assert len(lt) == 65 and lt[4] == 0 and abs(lt[-1] - 1.0) < 0.02, (len(lt), lt[:6], lt[-1])
PY

echo "PASS motion-check.test.sh"
