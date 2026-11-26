#!/usr/bin/env bash
# Drives snapshot.sh: the argument errors (1), the unreachable exits (2, NOT MEASURED), the --storage-state refusals, review over fixture sets in both diff-engine branches (no Pillow: forced by a stub), from a subdirectory, against a git ref (its shots in the new folder or the old one) and over sets outside shots/ (copies the page's own policy lets it load, where the help says, no symlink's, none left of a route that is gone); with a Chromium-family browser, two routes at two sizes, a cookie-guarded one through a state file (the server logs the cookie and the localStorage beacon), an expired session's WARN, and the review page's images drawn.
# Misses: that a shot looks right; a change of part of a page (the fixtures are 4x4 colour fields, 0 or 100%); a state file Playwright saved (hand-written here); without a browser the shoots, and it says so; the two dead-URL picks ($port_dead, $port_free) trust bind-then-close.
# Why, limits, history: rationale/derivations/plugin-design-kit.md § plugins/design-kit/scripts/__tests__/snapshot.test.sh
set -euo pipefail
unset CLAUDE_PROJECT_DIR DESIGN_KIT_DIR   # a live session exports the first
here="$(cd "$(dirname "$0")/.." && pwd)"
snap="$here/snapshot.sh"
tmp="$(mktemp -d)"
stop_all() {
  bash "$here/preview.sh" --docroot "$tmp/proj/.cc-artifacts/design-kit" --stop >/dev/null 2>&1 || true
  bash "$here/preview.sh" --docroot "$tmp/repo/.cc-artifacts/design-kit" --stop >/dev/null 2>&1 || true
}
trap 'stop_all; rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*"; exit 1; }
free_port() { python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()'; }

proj="$tmp/proj"; mkdir -p "$proj"
run() { ( cd "$proj" && bash "$snap" "$@" ); }
rc_of() { set +e; out="$( "$@" 2>&1 )"; rc=$?; set -e; }
# review_fresh <cmd>...: rc_of on a fresh DESIGN_KIT_PORT; rc 2 with "busy?" is preview.sh's exit 4, a lost port
review_fresh() {
  local try
  for try in 1 2 3 4 5; do
    export DESIGN_KIT_PORT="$(free_port)"
    rc_of "$@"
    [ "$rc" = 2 ] && grep -q 'busy?' <<<"$out" || return 0
  done
  fail "the preview server failed to start 5 times in a row, each on a fresh port — that points to a crashed server, not a busy port (preview.sh discards its stderr); last output: $out"
}
# serve_bg <pid-var> <port-var> <start-fn>: a server dead after the readiness poll lost its bind, so retry on a new port
serve_bg() {
  local try err="$tmp/$3.err"
  for try in 1 2 3 4 5; do
    printf -v "$2" '%s' "$(free_port)"
    "$3" "${!2}" 2>"$err"; printf -v "$1" '%s' "$!"; disown "${!1}" 2>/dev/null || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      kill -0 "${!1}" 2>/dev/null || break
      python3 -c 'import sys,urllib.request;urllib.request.urlopen(sys.argv[1],timeout=1)' "http://127.0.0.1:${!2}/" 2>/dev/null && break
      python3 -c 'import time;time.sleep(0.3)'
    done
    kill -0 "${!1}" 2>/dev/null && return 0
  done
  fail "$3 failed to start 5 times in a row, each on a fresh port (last ${!2}) — that points to a crashed server, not a busy port; its last stderr:"$'\n'"$(tail -n 5 "$err")"
}

# --- arguments: every one of these is a 1, never a 2 (2 means "unmeasured") ------
rc_of run bogus;                          [ "$rc" = 1 ] || fail "unknown mode should exit 1, got $rc: $out"
rc_of run snapshot --nope;                [ "$rc" = 1 ] || fail "unknown flag should exit 1, got $rc: $out"
rc_of run snapshot --device phablet --base-url http://127.0.0.1:1
[ "$rc" = 1 ] || fail "a bad --device should exit 1, got $rc: $out"
grep -q 'desktop, mobile or both' <<<"$out" || fail "the --device error should name the accepted values: $out"
rc_of run review;                         [ "$rc" = 1 ] || fail "review with no --base should exit 1, got $rc: $out"
rc_of run review --base /nope/not/a/ref;  [ "$rc" = 1 ] || fail "a base that is neither dir nor ref should exit 1, got $rc: $out"

# --- --storage-state: checked before any browser, so all of these run without one ---
port_dead="$(free_port)"
state_ok='{"cookies":[{"name":"dk_session","value":"ok123","domain":"127.0.0.1","path":"/","expires":-1,"httpOnly":true,"secure":false,"sameSite":"Lax"}],"origins":[]}'
rc_of run snapshot --storage-state
[ "$rc" = 1 ] || fail "--storage-state with no file should exit 1, got $rc: $out"
rc_of run snapshot --storage-state "$tmp/absent.json" --base-url "http://127.0.0.1:$port_dead"
[ "$rc" = 1 ] && grep -q 'no such readable file' <<<"$out" || fail "a missing state file should exit 1 and say so, got $rc: $out"
printf '[1,2]' > "$tmp/list.json"
rc_of run snapshot --storage-state "$tmp/list.json" --base-url "http://127.0.0.1:$port_dead"
[ "$rc" = 1 ] && grep -q 'not a Playwright storageState' <<<"$out" || fail "a malformed state file should exit 1, got $rc: $out"
printf '{"cookies":[],"origins":[]}' > "$tmp/empty.json"
rc_of run snapshot --storage-state "$tmp/empty.json" --base-url "http://127.0.0.1:$port_dead"
[ "$rc" = 1 ] || fail "a state file with nothing in it should exit 1, got $rc: $out"
# inside a repo: refused unless git ignores it, and a TRACKED file never counts as ignored
repo="$tmp/repo"; mkdir -p "$repo/app/Models" "$repo/.cc-artifacts/design-kit/auth"; git -C "$repo" init -q
printf '.cc-artifacts/design-kit/\n' > "$repo/.gitignore"
printf '%s' "$state_ok" > "$repo/auth.json"; printf '%s' "$state_ok" > "$repo/.cc-artifacts/design-kit/auth/walk.json"
rc_of bash -c "cd '$repo' && bash '$snap' snapshot --storage-state auth.json --base-url http://127.0.0.1:$port_dead"
[ "$rc" = 1 ] && grep -q 'REFUSED' <<<"$out" && grep -q 'session token' <<<"$out" \
  || fail "an un-ignored state file inside a repo must be REFUSED with the reason, got $rc: $out"
# ignored: it passes every check and reaches the browser layer — exit 2 at the dead URL (or
# at the missing browser), never the 1 a refusal is
rc_of bash -c "cd '$repo/app/Models' && bash '$snap' snapshot --storage-state ../../.cc-artifacts/design-kit/auth/walk.json --base-url http://127.0.0.1:$port_dead"
[ "$rc" = 2 ] || fail "an ignored state file should pass the checks and stop at the browser layer (2), got $rc: $out"
git -C "$repo" add -f .cc-artifacts/design-kit/auth/walk.json
rc_of bash -c "cd '$repo' && bash '$snap' snapshot --storage-state .cc-artifacts/design-kit/auth/walk.json --base-url http://127.0.0.1:$port_dead"
[ "$rc" = 1 ] && grep -q 'REFUSED' <<<"$out" || fail "a TRACKED state file must be refused even when a pattern ignores it, got $rc: $out"
git -C "$repo" rm -q --cached .cc-artifacts/design-kit/auth/walk.json

# --- unreachable: the browser or the server, both NOT MEASURED, both exit 2 ------
port_free="$(free_port)"
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
sets="$proj/.cc-artifacts/design-kit/shots"
mkfix "$sets/aaa111" "255,255,255" desktop:index desktop:pricing mobile:index
mkfix "$sets/bbb222" "255,255,255" desktop:index mobile:index          # unchanged pair
mkfix "$tmp/red" "255,0,0" desktop:pricing                              # the changed one
cp "$tmp/red/desktop/pricing.png" "$sets/bbb222/desktop/pricing.png"
mkfix "$tmp/red" "255,0,0" desktop:new-route
cp "$tmp/red/desktop/new-route.png" "$sets/bbb222/desktop/new-route.png"
touch "$sets/bbb222"   # newest → the default --current

has_pillow=0; python3 -c 'import PIL' >/dev/null 2>&1 && has_pillow=1
review_fresh run review --base "$sets/aaa111"
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
  [ -f "$proj/.cc-artifacts/design-kit/reviews/diff/desktop__pricing.png" ] || fail "no heatmap written"
  echo "snapshot.test.sh: Pillow $(python3 -c 'import PIL;print(PIL.__version__)') — heatmap branch exercised"
else
  grep -q 'no diff engine: install Pillow' <<<"$out" || fail "without Pillow the table must say so: $out"
fi

# --- sets outside shots/ (a walk's, an --out elsewhere): a review page may load images from shots/ and reviews/diff/ alone, so it shows copies
dkd="$proj/.cc-artifacts/design-kit"; copies="$dkd/reviews/diff/walk-vs-walk-before"
mkfix "$dkd/walk-before" "255,255,255" desktop:index desktop:gone mobile:index
mkfix "$dkd/walk" "255,0,0" desktop:index mobile:index
printf 'SECRET' > "$tmp/secret"; ln -s "$tmp/secret" "$dkd/walk/desktop/link.png"
# loaded <url>: the number of images its page shows, each one answered at the page's own content URL; a refused one is an error
loaded() { python3 - "$1" <<'PY'
import re, sys, urllib.request
from urllib.parse import urljoin
page = urllib.request.urlopen(urllib.request.Request(sys.argv[1] + "?static=1", headers={"User-Agent": "HeadlessChrome"}))
shown = [s for s in re.findall(r'<img src="([^"]+)"', page.read().decode()) if "link.png" not in s]
for s in shown: assert urllib.request.urlopen(urljoin(page.url, s)).read(4) == b"\x89PNG", s
print(len(shown))
PY
}
review_fresh run review --base "$dkd/walk-before" --current "$dkd/walk"
[ "$rc" = 0 ] || fail "a review of sets outside shots/ should exit 0, got $rc: $out"
walk_url="$(sed -n 's/^url=//p' <<<"$out")"; heats=0; [ "$has_pillow" = 0 ] || heats=2
got="$(loaded "$walk_url" 2>&1)" || true
[ "$got" = "$((5 + heats))" ] || fail "a review page of sets outside shots/ should load every image it shows: $got"
grep -q "base <code>$dkd/walk-before</code> → current <code>$dkd/walk</code>" "$dkd/reviews/walk-vs-walk-before.html" || fail "the review page should still name the sets it compares"
! grep -rq SECRET "$dkd/reviews" || fail "what a symlink in a set points to was copied into the served folder"
said="$(run --help | grep -oE 'reviews/[a-z]+/<review>/' | head -n 1)" || true
[ -n "$said" ] && [ -f "$dkd/${said/<review>/walk-vs-walk-before}before__desktop__index.png" ] || fail "the help should name the folder these copies are in, it names: ${said:-none}"
if [ "$have_browser" = 1 ]; then
  set +e; seen="$(python3 - "$here/__tests__" "$walk_url?static=1" <<'PY'
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, sys.argv[1])
import browser_lib
with browser_lib.browser(40) as b:
    tab = b.page(sys.argv[2])
    print(tab.evaluate("self.origin"), *tab.evaluate("[...document.images].filter((i) => !/link\\.png$/.test(i.src)).map((i) => i.naturalWidth)"))
PY
)"; brc=$?; set -e
  if [ "$brc" = 4 ] && [ "${DESIGN_KIT_REQUIRE_BROWSER:-}" != 1 ]; then echo "$seen"
  else [ "$brc" = 0 ] && [ "$seen" = "null$(printf ' 4%.0s' $(seq $((5 + heats))))" ] || fail "a browser should draw every image of that page under its policy (exit $brc): $seen"; fi
fi
# written again: the copies of a route that is gone go too
rm "$dkd/walk-before/desktop/gone.png" "$dkd/walk/desktop/link.png"
review_fresh run review --base "$dkd/walk-before" --current "$dkd/walk"
[ "$(cd "$copies" && ls | tr '\n' ' ')" = "after__desktop__index.png after__mobile__index.png before__desktop__index.png before__mobile__index.png " ] \
  || fail "a review written again should hold its own copies alone: $(ls "$copies" 2>&1)"
# a planted preview address prints as one JSON string, never as a line of its own
cp "$dkd/.preview.url" "$tmp/url.kept"; printf 'http://x/\nshots=forged\n' > "$dkd/.preview.url"
rc_of run review --base "$dkd/walk-before" --current "$dkd/walk"; cp "$tmp/url.kept" "$dkd/.preview.url"
[ "$rc" = 0 ] && ! grep -qx 'shots=forged' <<<"$out" && grep -qxF 'url="http://x/\nshots=forged"/reviews/walk-vs-walk-before.html' <<<"$out" \
  || fail "a planted preview address should print as one JSON string (rc=$rc): $out"
# and so does a planted LAN key, on a server opened to the network
bash "$here/preview.sh" --docroot "$dkd" --lan >/dev/null; printf 'x\nshots=forged\n' > "$dkd/.preview.key"
rc_of run review --base "$dkd/walk-before" --current "$dkd/walk"; bash "$here/preview.sh" --docroot "$dkd" --stop >/dev/null
[ "$rc" = 0 ] && ! grep -qx 'shots=forged' <<<"$out" && [ "$(grep -cF '?key="x\nshots=forged"' <<<"$out")" = 2 ] \
  || fail "a planted LAN key should print as one JSON string (rc=$rc): $out"

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

# --- SUBDIRECTORY cwd: the review lands in the ROOT's .cc-artifacts/design-kit/ (finding 2 of the
# marketplace's rationale/2026-09-25-session-plugin-usage-review.md), and a git-ref base is
# read from the toplevel — `git archive` refuses a pathspec outside the cwd, so from a
# subdirectory the committed shots were never found.
rsets="$repo/.cc-artifacts/design-kit/shots"
mkfix "$rsets/aaa111" "255,255,255" desktop:index
mkfix "$rsets/bbb222" "255,0,0" desktop:index; touch "$rsets/bbb222"
review_fresh bash -c "cd '$repo/app/Models' && bash '$snap' review --base '$rsets/aaa111'"
[ "$rc" = 0 ] || fail "review from a subdirectory should exit 0, got $rc: $out"
rpage="$(sed -n 's/^review=//p' <<<"$out")"
case "$rpage" in "../../.cc-artifacts/design-kit/reviews/"*) ;; *) fail "the review page is not under the root's .cc-artifacts/design-kit/: $rpage" ;; esac
[ -f "$repo/app/Models/$rpage" ] && [ ! -e "$repo/app/Models/.cc-artifacts" ] || fail "a .cc-artifacts/ appeared under the subdirectory: $out"
git -C "$repo" add -f .cc-artifacts/design-kit/shots/aaa111 && git -C "$repo" -c user.name=t -c user.email=t@t commit -q -m shots
rc_of bash -c "cd '$repo/app/Models' && bash '$snap' review --base HEAD --current '$rsets/bbb222'"
[ "$rc" = 0 ] && grep -q '| index | desktop | .* | changed |' <<<"$out" \
  || fail "a git-ref base read from a subdirectory should pair the committed shots, got $rc: $out"
got="$(loaded "$(sed -n 's/^url=//p' <<<"$out")" 2>&1)" || true
[ "$got" = "$((2 + has_pillow))" ] || fail "a review page of a git-ref base should load every image it shows: $got"
# a ref from before 2026-11-14 committed its shots under .design-kit/shots: read there when the new path holds none
mkdir -p "$repo/.design-kit/shots"; cp -R "$rsets/aaa111" "$repo/.design-kit/shots/aaa111"
git -C "$repo" rm -r -q --cached .cc-artifacts/design-kit/shots/aaa111 && git -C "$repo" add -f .design-kit/shots/aaa111 \
  && git -C "$repo" -c user.name=t -c user.email=t@t commit -q -m legacy-shots
rc_of bash -c "cd '$repo/app/Models' && bash '$snap' review --base HEAD --current '$rsets/bbb222'"
[ "$rc" = 0 ] && grep -q '| index | desktop | .* | changed |' <<<"$out" \
  || fail "a git-ref base holding only .design-kit/shots should pair those, got $rc: $out"
got="$(loaded "$(sed -n 's/^url=//p' <<<"$out")" 2>&1)" || true
[ "$got" = "$((2 + has_pillow))" ] || fail "a review page of a git-ref base under .design-kit/shots should load every image it shows: $got"
bash "$here/preview.sh" --docroot "$repo/.cc-artifacts/design-kit" --stop >/dev/null 2>&1 || true; unset DESIGN_KIT_PORT

# --- the real surface: a throwaway server, a real browser, two devices ----------
if [ "$have_browser" = 0 ]; then
  echo "snapshot.test.sh: no Chromium-family browser on this machine — the SHOOT path and the signed-in shoot were NOT exercised (arguments, the state-file checks, exit 2 and pairing were)"
else
  site="$tmp/site"; mkdir -p "$site"
  printf '<!doctype html><title>a</title><body style="background:#123456">A</body>\n' > "$site/index.html"
  printf '<!doctype html><title>b</title><body style="background:#abcdef">B</body>\n' > "$site/b.html"
  start_site() { ( cd "$site" && exec python3 -m http.server "$1" --bind 127.0.0.1 >/dev/null ) & }
  site_pid=""; guard_pid=""
  trap 'kill $site_pid $guard_pid 2>/dev/null || true; stop_all; rm -rf "$tmp"' EXIT
  serve_bg site_pid sport start_site
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

  # --- behind a login: a cookie-guarded route through a saved state, off the real browser.
  # The SERVER is the witness: it logs whether the cookie arrived, and the guarded page
  # beacons back the localStorage value the state seeded.
  cat > "$tmp/guard.py" <<'PY'
import http.server, sys
log = open(sys.argv[2], "a", buffering=1)
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        authed = "dk_session=ok123" in (self.headers.get("Cookie") or "")
        log.write("%s %s\n" % (self.path, "cookie" if authed else "none"))
        if self.path.startswith("/beacon"):
            self.send_response(204); self.end_headers(); return
        if self.path == "/secret" and not authed:
            self.send_response(302); self.send_header("Location", "/login"); self.end_headers(); return
        body = (b"<!doctype html><body style='background:#0a0'>in<script>fetch('/beacon?ls=' + localStorage.getItem('tok'))</script>"
                if self.path == "/secret" else b"<!doctype html><body style='background:#a00'>login")
        self.send_response(200); self.send_header("Content-Type", "text/html"); self.end_headers(); self.wfile.write(body)
http.server.ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
PY
  start_guard() { ( exec python3 "$tmp/guard.py" "$1" "$tmp/guard.log" >/dev/null ) & }
  serve_bg guard_pid gport start_guard
  printf '{"cookies":[{"name":"dk_session","value":"ok123","domain":"127.0.0.1","path":"/","expires":-1,"httpOnly":true,"secure":false,"sameSite":"Lax"}],"origins":[{"origin":"http://127.0.0.1:%s","localStorage":[{"name":"tok","value":"ls-ok"}]}]}' \
    "$gport" > "$repo/.cc-artifacts/design-kit/auth/walk.json"
  rc_of bash -c "cd '$repo/app/Models' && bash '$snap' snapshot --routes /secret --device both --base-url http://127.0.0.1:$gport --storage-state ../../.cc-artifacts/design-kit/auth/walk.json --out '$tmp/authshot'"
  [ "$rc" = 0 ] || fail "a signed-in shoot should exit 0, got $rc: $out"
  [ "$(grep -c '^/secret cookie$' "$tmp/guard.log")" = 2 ] || fail "the cookie did not reach the server on both shots: $(cat "$tmp/guard.log")"
  grep -q '^/beacon?ls=ls-ok cookie$' "$tmp/guard.log" || fail "localStorage was not seeded: $(cat "$tmp/guard.log")"
  ! grep -q '^/login' "$tmp/guard.log" || fail "a signed-in shoot was redirected to the login page: $(cat "$tmp/guard.log")"
  ! grep -q 'WARN' <<<"$out" || fail "a valid session should shoot without a WARN: $out"
  python3 - "$tmp/authshot/desktop/secret.png" "$tmp/authshot/mobile/secret.png" <<'PY' || fail "the signed-in shots have the wrong widths"
import struct, sys
w = [struct.unpack(">I", open(p, "rb").read(33)[16:20])[0] for p in sys.argv[1:3]]
assert w == [1440, 390], w
PY
  # an expired session is still shot, but never silently: the WARN names where it landed
  sed 's/ok123/expired/' "$repo/.cc-artifacts/design-kit/auth/walk.json" > "$repo/.cc-artifacts/design-kit/auth/stale.json"
  rc_of bash -c "cd '$repo' && bash '$snap' snapshot --routes /secret --base-url http://127.0.0.1:$gport --storage-state .cc-artifacts/design-kit/auth/stale.json --out '$tmp/staleshot'"
  [ "$rc" = 0 ] && grep -q "WARN /secret (desktop) ended on http://127.0.0.1:$gport/login" <<<"$out" \
    || fail "a stale session should shoot with a WARN naming the login URL, got $rc: $out"
  echo "snapshot.test.sh: shot a cookie-guarded route through --storage-state — the server saw the cookie and the seeded localStorage"
fi

echo "PASS snapshot.test.sh"
