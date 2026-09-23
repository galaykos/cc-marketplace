#!/usr/bin/env bash
# Drives snapshot.sh: the argument errors (exit 1), the unreachable exit (exit 2,
# NOT MEASURED — never a green), the pairing of two fixture shot sets through
# `review` in BOTH diff-engine branches (Pillow present → a heatmap and a
# percentage; Pillow absent → `no diff engine: install Pillow` and the pair alone,
# forced with a PYTHONPATH stub so the branch runs on a machine that has Pillow),
# and — only when a Chromium-family browser is installed — one real shoot of two
# routes at two device sizes off a throwaway python3 -m http.server.
#
# WHAT THIS DOES NOT PROVE. That a shot LOOKS right: nothing here opens a browser
# at a pixel and judges it, which is the agent-graded half snapshot.sh's header
# claims. The fixture PNGs are flat 4x4 colour fields, so the percentage they
# produce is 0 or 100 and never exercises a partial-page change. With no browser
# installed the shoot is skipped and this file says so on stdout.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
snap="$here/snapshot.sh"
tmp="$(mktemp -d)"; trap 'bash "$here/preview.sh" --docroot "$tmp/proj/.design-kit" --stop >/dev/null 2>&1 || true; rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*"; exit 1; }

proj="$tmp/proj"; mkdir -p "$proj"
run() { ( cd "$proj" && bash "$snap" "$@" ); }
rc_of() { set +e; out="$( "$@" 2>&1 )"; rc=$?; set -e; }

# --- arguments: every one of these is a 1, never a 2 (2 means "unmeasured") ------
rc_of run bogus;                          [ "$rc" = 1 ] || fail "unknown mode should exit 1, got $rc: $out"
rc_of run snapshot --nope;                [ "$rc" = 1 ] || fail "unknown flag should exit 1, got $rc: $out"
rc_of run snapshot --device phablet --base-url http://127.0.0.1:1
[ "$rc" = 1 ] || fail "a bad --device should exit 1, got $rc: $out"
grep -q 'desktop, mobile or both' <<<"$out" || fail "the --device error should name the accepted values: $out"
rc_of run review;                         [ "$rc" = 1 ] || fail "review with no --base should exit 1, got $rc: $out"
rc_of run review --base /nope/not/a/ref;  [ "$rc" = 1 ] || fail "a base that is neither dir nor ref should exit 1, got $rc: $out"

# --- unreachable: the browser or the server, both NOT MEASURED, both exit 2 ------
port_free="$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')"
rc_of run snapshot --base-url "http://127.0.0.1:$port_free" --routes /
[ "$rc" = 2 ] || fail "an unreachable base URL should exit 2, got $rc: $out"
grep -q 'NOT MEASURED' <<<"$out" || fail "the unreachable exit must say NOT MEASURED: $out"
have_browser=0
if bash "$here/board-export.sh" --which >/dev/null 2>&1; then
  have_browser=1
  grep -q 'unreachable' <<<"$out" || fail "with a browser installed the exit-2 reason must be the URL: $out"
else
  grep -q 'no Chromium-family browser' <<<"$out" || fail "with no browser the exit-2 reason must say so: $out"
fi

# --- pairing: two fixture sets, one route identical, one changed, one added ------
mkfix() { # mkfix <dir> <r,g,b> <route>...
  python3 - "$@" <<'PY'
import os, struct, sys, zlib
d, rgb, *routes = sys.argv[1:]
rgb = bytes(int(x) for x in rgb.split(","))
def png(path, w=4, h=4):
    raw = b"".join(b"\x00" + rgb * w for _ in range(h))
    def chunk(t, data):
        c = t + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xffffffff)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "wb").write(b"\x89PNG\r\n\x1a\n"
                           + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
                           + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))
for r in routes:
    dev, name = r.split(":")
    png(os.path.join(d, dev, name + ".png"))
PY
}
sets="$proj/.design-kit/shots"
mkfix "$sets/aaa111" "255,255,255" desktop:index desktop:pricing mobile:index
mkfix "$sets/bbb222" "255,255,255" desktop:index mobile:index          # unchanged pair
mkfix "$tmp/red" "255,0,0" desktop:pricing                              # the changed one
cp "$tmp/red/desktop/pricing.png" "$sets/bbb222/desktop/pricing.png"
mkfix "$tmp/red" "255,0,0" desktop:new-route
cp "$tmp/red/desktop/new-route.png" "$sets/bbb222/desktop/new-route.png"
touch "$sets/bbb222"   # newest → the default --current

has_pillow=0; python3 -c 'import PIL' >/dev/null 2>&1 && has_pillow=1
rc_of run review --base "$sets/aaa111"
[ "$rc" = 0 ] || fail "review over two fixture sets should exit 0, got $rc: $out"
grep -q '| index | desktop | .* | same |' <<<"$out" || fail "the identical route should read same:
$out"
grep -q '| pricing | desktop | .* | changed |' <<<"$out" || fail "the changed route should read changed:
$out"
grep -q '| new-route | desktop | .* | added |' <<<"$out" || fail "a route only in the current set is added:
$out"
grep -q '| index | mobile |' <<<"$out" || fail "the mobile device should pair too:
$out"
page="$(sed -n 's/^review=//p' <<<"$out")"
[ -f "$proj/$page" ] || fail "no review page written: $out"
grep -q '^url=http' <<<"$out" || fail "review must print the preview URL: $out"
grep -q 'shots/aaa111/desktop/pricing.png' "$proj/$page" || fail "the before image is not in the page"
grep -q 'shots/bbb222/desktop/pricing.png' "$proj/$page" || fail "the after image is not in the page"

if [ "$has_pillow" = 1 ]; then
  grep -q '| pricing | desktop | 100.00 | changed |' <<<"$out" \
    || fail "a wholly different 4x4 fixture should read 100.00%:
$out"
  grep -q '| index | desktop | 0.00 | same |' <<<"$out" || fail "an identical pair should read 0.00%:
$out"
  [ -f "$proj/.design-kit/reviews/diff/desktop__pricing.png" ] || fail "no heatmap written"
  echo "snapshot.test.sh: Pillow $(python3 -c 'import PIL;print(PIL.__version__)') — heatmap branch exercised"
else
  grep -q 'no diff engine: install Pillow' <<<"$out" || fail "without Pillow the table must say so: $out"
fi

# The no-engine branch, forced: a PIL that raises on import is what a machine
# without Pillow looks like to this script.
mkdir -p "$tmp/nopil"; printf 'raise ImportError("stubbed by snapshot.test.sh")\n' > "$tmp/nopil/PIL.py"
set +e; out="$( cd "$proj" && PYTHONPATH="$tmp/nopil" bash "$snap" review --base "$sets/aaa111" 2>&1 )"; rc=$?; set -e
[ "$rc" = 0 ] || fail "review without a diff engine should still exit 0, got $rc: $out"
grep -q 'no diff engine: install Pillow' <<<"$out" || fail "the no-engine table must name the missing engine:
$out"
grep -q '| pricing | desktop | no diff engine: install Pillow | changed |' <<<"$out" \
  || fail "without an engine the status still comes from the bytes:
$out"
grep -q 'no diff engine: install Pillow' "$proj/$page" || fail "the no-engine page must say so too"

# --- the real surface: a throwaway server, a real browser, two devices ----------
if [ "$have_browser" = 0 ]; then
  echo "snapshot.test.sh: no Chromium-family browser on this machine — the SHOOT path was NOT exercised (arguments, exit 2 and pairing were)"
else
  site="$tmp/site"; mkdir -p "$site"
  printf '<!doctype html><title>a</title><body style="background:#123456">A</body>\n' > "$site/index.html"
  printf '<!doctype html><title>b</title><body style="background:#abcdef">B</body>\n' > "$site/b.html"
  sport="$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')"
  ( cd "$site" && exec python3 -m http.server "$sport" --bind 127.0.0.1 >/dev/null 2>&1 ) &
  site_pid=$!; disown "$site_pid" 2>/dev/null || true
  trap 'kill "$site_pid" 2>/dev/null || true; bash "$here/preview.sh" --docroot "$tmp/proj/.design-kit" --stop >/dev/null 2>&1 || true; rm -rf "$tmp"' EXIT
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    python3 -c 'import sys,urllib.request;urllib.request.urlopen(sys.argv[1],timeout=1)' "http://127.0.0.1:$sport/" 2>/dev/null && break
    python3 -c 'import time;time.sleep(0.3)'
  done
  rc_of run snapshot --routes /,/b.html --device both --base-url "http://127.0.0.1:$sport" --out "$tmp/shot1"
  [ "$rc" = 0 ] || fail "a real shoot should exit 0, got $rc: $out"
  for f in desktop/index desktop/b-html mobile/index mobile/b-html; do
    [ -s "$tmp/shot1/$f.png" ] || fail "missing shot $f.png: $out"
  done
  python3 - "$tmp/shot1/desktop/index.png" "$tmp/shot1/mobile/index.png" <<'PY' || fail "the two devices produced the same width"
import struct, sys
def w(p):
    b = open(p, "rb").read(33)
    return struct.unpack(">I", b[16:20])[0]
a, m = (w(p) for p in sys.argv[1:3])
assert a == 1440 and m == 390, (a, m)
PY
  echo "snapshot.test.sh: shot 4 real PNGs through $(bash "$here/board-export.sh" --which)"
fi

echo "PASS snapshot.test.sh"
