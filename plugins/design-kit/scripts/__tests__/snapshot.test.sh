#!/usr/bin/env bash
# Drives snapshot.sh: the argument errors (exit 1), the unreachable exit (exit 2,
# NOT MEASURED — never a green), the pairing of two fixture shot sets through
# `review` in BOTH diff-engine branches (Pillow present → a heatmap and a
# percentage; Pillow absent → `no diff engine: install Pillow` and the pair alone,
# forced with a PYTHONPATH stub so the branch runs on a machine that has Pillow),
# the --storage-state checks (a missing, malformed or empty file, one inside a repo
# that git does not ignore, a TRACKED one → exit 1; an ignored one reaches the browser
# layer → exit 2 at a dead URL), a review run from a SUBDIRECTORY landing in the root's
# .design-kit/ with a git-ref base read from the toplevel, and — only when a
# Chromium-family browser is installed — one real shoot of two routes at two device
# sizes off a throwaway python3 -m http.server, plus a cookie-guarded route shot
# through a state file, where the SERVER logs the cookie and a localStorage beacon,
# and an expired session that must shoot with a WARN naming the login URL.
#
# WHAT THIS DOES NOT PROVE. That a shot LOOKS right: nothing here opens a browser
# at a pixel and judges it, which is the agent-graded half snapshot.sh's header
# claims. The fixture PNGs are flat 4x4 colour fields, so the percentage they
# produce is 0 or 100 and never exercises a partial-page change. That a state file
# SAVED by Playwright replays here — the fixture is hand-written in its shape; the
# save was run by hand once (CHANGELOG 0.5.1). With no browser installed both shoots
# are skipped and this file says so on stdout.
set -euo pipefail
unset CLAUDE_PROJECT_DIR DESIGN_KIT_DIR   # a live session exports the first
here="$(cd "$(dirname "$0")/.." && pwd)"
snap="$here/snapshot.sh"
tmp="$(mktemp -d)"
stop_all() {
  bash "$here/preview.sh" --docroot "$tmp/proj/.design-kit" --stop >/dev/null 2>&1 || true
  bash "$here/preview.sh" --docroot "$tmp/repo/.design-kit" --stop >/dev/null 2>&1 || true
}
trap 'stop_all; rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*"; exit 1; }
free_port() { python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()'; }

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
repo="$tmp/repo"; mkdir -p "$repo/app/Models" "$repo/.design-kit/auth"; git -C "$repo" init -q
printf '.design-kit/\n' > "$repo/.gitignore"
printf '%s' "$state_ok" > "$repo/auth.json"; printf '%s' "$state_ok" > "$repo/.design-kit/auth/walk.json"
rc_of bash -c "cd '$repo' && bash '$snap' snapshot --storage-state auth.json --base-url http://127.0.0.1:$port_dead"
[ "$rc" = 1 ] && grep -q 'REFUSED' <<<"$out" && grep -q 'session token' <<<"$out" \
  || fail "an un-ignored state file inside a repo must be REFUSED with the reason, got $rc: $out"
# ignored: it passes every check and reaches the browser layer — exit 2 at the dead URL (or
# at the missing browser), never the 1 a refusal is
rc_of bash -c "cd '$repo/app/Models' && bash '$snap' snapshot --storage-state ../../.design-kit/auth/walk.json --base-url http://127.0.0.1:$port_dead"
[ "$rc" = 2 ] || fail "an ignored state file should pass the checks and stop at the browser layer (2), got $rc: $out"
git -C "$repo" add -f .design-kit/auth/walk.json
rc_of bash -c "cd '$repo' && bash '$snap' snapshot --storage-state .design-kit/auth/walk.json --base-url http://127.0.0.1:$port_dead"
[ "$rc" = 1 ] && grep -q 'REFUSED' <<<"$out" || fail "a TRACKED state file must be refused even when a pattern ignores it, got $rc: $out"
git -C "$repo" rm -q --cached .design-kit/auth/walk.json

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

# --- SUBDIRECTORY cwd: the review lands in the ROOT's .design-kit/ (finding 2 of the
# marketplace's rationale/2026-09-25-session-plugin-usage-review.md), and a git-ref base is
# read from the toplevel — `git archive` refuses a pathspec outside the cwd, so from a
# subdirectory the committed shots were never found.
rsets="$repo/.design-kit/shots"
mkfix "$rsets/aaa111" "255,255,255" desktop:index
mkfix "$rsets/bbb222" "255,0,0" desktop:index; touch "$rsets/bbb222"
export DESIGN_KIT_PORT="$(free_port)"
rc_of bash -c "cd '$repo/app/Models' && bash '$snap' review --base '$rsets/aaa111'"
[ "$rc" = 0 ] || fail "review from a subdirectory should exit 0, got $rc: $out"
rpage="$(sed -n 's/^review=//p' <<<"$out")"
case "$rpage" in "../../.design-kit/reviews/"*) ;; *) fail "the review page is not under the root's .design-kit/: $rpage" ;; esac
[ -f "$repo/app/Models/$rpage" ] && [ ! -e "$repo/app/Models/.design-kit" ] || fail "a .design-kit/ appeared under the subdirectory: $out"
git -C "$repo" add -f .design-kit/shots/aaa111 && git -C "$repo" -c user.name=t -c user.email=t@t commit -q -m shots
rc_of bash -c "cd '$repo/app/Models' && bash '$snap' review --base HEAD --current '$rsets/bbb222'"
[ "$rc" = 0 ] && grep -q '| index | desktop | .* | changed |' <<<"$out" \
  || fail "a git-ref base read from a subdirectory should pair the committed shots, got $rc: $out"
bash "$here/preview.sh" --docroot "$repo/.design-kit" --stop >/dev/null 2>&1 || true; unset DESIGN_KIT_PORT

# --- the real surface: a throwaway server, a real browser, two devices ----------
if [ "$have_browser" = 0 ]; then
  echo "snapshot.test.sh: no Chromium-family browser on this machine — the SHOOT path and the signed-in shoot were NOT exercised (arguments, the state-file checks, exit 2 and pairing were)"
else
  site="$tmp/site"; mkdir -p "$site"
  printf '<!doctype html><title>a</title><body style="background:#123456">A</body>\n' > "$site/index.html"
  printf '<!doctype html><title>b</title><body style="background:#abcdef">B</body>\n' > "$site/b.html"
  sport="$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')"
  ( cd "$site" && exec python3 -m http.server "$sport" --bind 127.0.0.1 >/dev/null 2>&1 ) &
  site_pid=$!; disown "$site_pid" 2>/dev/null || true
  guard_pid=""
  trap 'kill "$site_pid" $guard_pid 2>/dev/null || true; stop_all; rm -rf "$tmp"' EXIT
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
  gport="$(free_port)"
  ( exec python3 "$tmp/guard.py" "$gport" "$tmp/guard.log" >/dev/null 2>&1 ) &
  guard_pid=$!; disown "$guard_pid" 2>/dev/null || true
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    python3 -c 'import sys,urllib.request;urllib.request.urlopen(sys.argv[1],timeout=1)' "http://127.0.0.1:$gport/" 2>/dev/null && break
    python3 -c 'import time;time.sleep(0.3)'
  done
  printf '{"cookies":[{"name":"dk_session","value":"ok123","domain":"127.0.0.1","path":"/","expires":-1,"httpOnly":true,"secure":false,"sameSite":"Lax"}],"origins":[{"origin":"http://127.0.0.1:%s","localStorage":[{"name":"tok","value":"ls-ok"}]}]}' \
    "$gport" > "$repo/.design-kit/auth/walk.json"
  rc_of bash -c "cd '$repo/app/Models' && bash '$snap' snapshot --routes /secret --device both --base-url http://127.0.0.1:$gport --storage-state ../../.design-kit/auth/walk.json --out '$tmp/authshot'"
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
  sed 's/ok123/expired/' "$repo/.design-kit/auth/walk.json" > "$repo/.design-kit/auth/stale.json"
  rc_of bash -c "cd '$repo' && bash '$snap' snapshot --routes /secret --base-url http://127.0.0.1:$gport --storage-state .design-kit/auth/stale.json --out '$tmp/staleshot'"
  [ "$rc" = 0 ] && grep -q "WARN /secret (desktop) ended on http://127.0.0.1:$gport/login" <<<"$out" \
    || fail "a stale session should shoot with a WARN naming the login URL, got $rc: $out"
  echo "snapshot.test.sh: shot a cookie-guarded route through --storage-state — the server saw the cookie and the seeded localStorage"
fi

echo "PASS snapshot.test.sh"
