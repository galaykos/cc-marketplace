#!/usr/bin/env bash
# Drives skills/visual-decisions/assets/serve.py over real HTTP on free ports with temp docroots: static files, /events, /_versions.json, /_restore and its rejects, the Host/Origin guard, the stream cap.
# Misses: anything only a browser does (the shell's reload client never runs here); IPv6 peers.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
SERVE="$here/../../skills/visual-decisions/assets/serve.py"
pass=0; fail=0
ok() { pass=$((pass+1)); }
bad() { echo "FAIL $1: $2"; fail=$((fail+1)); }

if ! command -v python3 >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
  echo "SKIP: python3 or curl not found"
  echo "serve.py tests: 0 passed, 0 failed"
  exit 0
fi

T="$(mktemp -d)"
pids=""
cleanup() {
  for p in $pids; do kill "$p" 2>/dev/null; done
  for p in $pids; do wait "$p" 2>/dev/null; done
  rm -rf "$T"
}
trap cleanup EXIT

free_port() { python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()'; }

# start <docroot> <port> [serve.py args...]: sets $srv; ready once serve.py prints its Serving line.
start() {
  local root=$1 port=$2; shift 2
  python3 "$SERVE" --docroot "$root" --port "$port" "$@" >"$T/log.$port" 2>&1 &
  srv=$!; pids="$pids $srv"
  for _ in $(seq 1 50); do
    grep -q '^Serving ' "$T/log.$port" 2>/dev/null && return 0
    kill -0 "$srv" 2>/dev/null || return 1
    sleep 0.1
  done
  return 1
}

# wait_for <pattern> <file> [tenths]: poll a file for a fixed string.
wait_for() {
  for _ in $(seq 1 "${3:-40}"); do grep -qF -- "$1" "$2" 2>/dev/null && return 0; sleep 0.1; done
  return 1
}

# code <curl args...>: prints the HTTP status; the body lands in $T/resp.
code() { curl -s -o "$T/resp" -w '%{http_code}' --max-time 5 "$@"; }

# expect <name> <want> <curl args...>
expect() {
  local name=$1 want=$2 got; shift 2
  got="$(code "$@")"
  if [ "$got" = "$want" ]; then ok; else bad "$name" "want $want, got $got"; fi
}

# sse <url> <outfile> [seconds]: a background event-stream reader.
sse() { curl -s -N --max-time "${3:-8}" "$1" > "$2" 2>/dev/null & sse_pid=$!; pids="$pids $sse_pid"; }

# ---- fixture docroot --------------------------------------------------------
D="$T/root"
mkdir -p "$D/gallery" "$D/sub"
printf '<!doctype html><title>live</title><p>LIVE</p>\n' > "$D/current.html"
printf '<!doctype html><p>PASS-A</p>\n' > "$D/2026-01-01-a.html"
printf '<!doctype html><p>theme</p>\n' > "$D/theme.html"
printf '<!doctype html><p>GALLERY-ONE</p>\n' > "$D/gallery/2026-01-01-one.html"
printf 'hello asset\n' > "$D/sub/asset.txt"
mkdir -p "$D/.hidden" "$D/withindex"
for f in .env .preview.pid .preview.url .preview.key .preview.log sub/.secret.txt .hidden/page.html; do printf 'SECRET\n' > "$D/$f"; done
printf '<!doctype html><p>SECRET</p>\n' > "$D/.private.html"
printf '<!doctype html><p>DIR-INDEX</p>\n' > "$D/withindex/index.html"

port="$(free_port)"; base="http://127.0.0.1:$port"
if ! start "$D" "$port"; then
  echo "FAIL start: serve.py did not come up"; cat "$T/log.$port"
  echo "serve.py tests: $pass passed, 1 failed"; exit 1
fi

# ---- static, landing, gallery --------------------------------------------------
expect "static page" 200 "$base/current.html"
grep -q LIVE "$T/resp" && ok || bad "static body" "current.html body not served"
expect "static asset in a subfolder" 200 "$base/sub/asset.txt"
grep -q "hello asset" "$T/resp" && ok || bad "asset body" "sub/asset.txt body not served"
expect "synthesized landing" 200 "$base/"
grep -q "Mockup session" "$T/resp" && grep -q "current.html" "$T/resp" && ok || bad "landing body" "no session map"
grep -q "private.html" "$T/resp" && bad "landing lists a dot file" ".private.html on the session map" || ok
expect "synthesized gallery" 200 "$base/gallery/"
grep -q "2026-01-01-one.html" "$T/resp" && ok || bad "gallery body" "gallery page not listed"

# ---- private paths: dot names at any depth, state files, directory listings ----
for probe in /.env /%2Eenv //.env /.preview.pid /.preview.url /.preview.key /.preview.log /sub/.secret.txt /.hidden/page.html /.hidden/ /.private.html /sub/ /gallery/../sub/; do
  expect "private $probe" 404 --path-as-is "$base$probe"
  grep -q "SECRET\|asset.txt" "$T/resp" && bad "private $probe body" "leaked its content or a listing"
done
got="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 -I "$base/.env")"
[ "$got" = 404 ] && ok || bad "HEAD /.env" "want 404, got $got"
expect "folder with its own index.html" 200 "$base/withindex/"
grep -q DIR-INDEX "$T/resp" && ok || bad "folder index body" "withindex/index.html not served"

# ---- /_versions.json -----------------------------------------------------------
expect "versions route" 200 "$base/_versions.json"
python3 -c '
import json,sys
d=json.load(open(sys.argv[1]))
names=[v["name"] for v in d["versions"]]
assert d["current"]=="current.html", d
assert names==["2026-01-01-a.html"], names' "$T/resp" 2>/dev/null \
  && ok || bad "versions body" "want only the ledger pass, got $(cat "$T/resp")"

# ---- /events: a change event arrives after a write ----------------------------
sse "$base/events" "$T/sse1"
if wait_for ": connected" "$T/sse1"; then
  ok
  printf 'SECRET-2\n' > "$D/.preview.log"
  printf '<!doctype html><p>LIVE-2</p>\n' > "$D/current.html"
  wait_for "data: current.html" "$T/sse1" 40 && ok || bad "sse change" "no change event for current.html: $(cat "$T/sse1")"
  grep -q "preview.log" "$T/sse1" && bad "sse dot name" "a dot file's name went down the stream" || ok
else
  bad "sse connect" "no ': connected' preamble"
fi
kill "$sse_pid" 2>/dev/null

# ---- /_restore -----------------------------------------------------------------
restore() { code -X POST -H 'Content-Type: application/json' -H 'Expect:' "$@" "$base/_restore"; }
printf 'LIVE\n' > "$D/current.html"
got="$(restore -H 'X-Preview-Restore: 1' --data '{"name":"2026-01-01-a.html"}')"
[ "$got" = 200 ] && ok || bad "restore accept" "want 200, got $got: $(cat "$T/resp")"
grep -q PASS-A "$D/current.html" && ok || bad "restore copy" "current.html was not overwritten by the ledger pass"
printf 'LIVE\n' > "$D/current.html"
got="$(restore --data '{"name":"2026-01-01-a.html"}')"
[ "$got" = 403 ] && ok || bad "restore without header" "want 403, got $got"
big="$(python3 -c 'print("{\"name\":\"" + "x"*5000 + ".html\"}")')"
got="$(restore -H 'X-Preview-Restore: 1' --data "$big")"
[ "$got" = 413 ] && ok || bad "restore over the size cap" "want 413, got $got"
for name in theme.html current.html ../2026-01-01-a.html missing.html sub/asset.txt .private.html; do
  got="$(restore -H 'X-Preview-Restore: 1' --data "{\"name\":\"$name\"}")"
  [ "$got" = 400 ] && ok || bad "restore non-ledger $name" "want 400, got $got"
done
got="$(restore -H 'X-Preview-Restore: 1' -H 'Origin: http://attacker.example' --data '{"name":"2026-01-01-a.html"}')"
[ "$got" = 403 ] && ok || bad "restore foreign Origin" "want 403, got $got"
got="$(restore -H 'X-Preview-Restore: 1' -H 'Host: attacker.example' --data '{"name":"2026-01-01-a.html"}')"
[ "$got" = 403 ] && ok || bad "restore foreign Host" "want 403, got $got"
grep -q LIVE "$D/current.html" && ok || bad "rejected restores" "a rejected restore still wrote current.html"

# ---- Host/Origin guard on the guarded routes ----------------------------------
for route in /events /_versions.json / /gallery/; do
  expect "foreign Host on $route" 403 -H 'Host: attacker.example' "$base$route"
  expect "foreign Origin on $route" 403 -H 'Origin: http://attacker.example' "$base$route"
done
expect "own Origin on /_versions.json" 200 -H "Origin: http://localhost:$port" "$base/_versions.json"

# ---- the ninth stream is refused (own server: dead streams hold a slot until the next keep-alive) ----
port2="$(free_port)"; base2="http://127.0.0.1:$port2"
if start "$D" "$port2"; then
  cap_pids=""
  for i in 1 2 3 4 5 6 7 8; do sse "$base2/events" "$T/cap$i" 6; cap_pids="$cap_pids $sse_pid"; done
  all=1; for i in 1 2 3 4 5 6 7 8; do wait_for ": connected" "$T/cap$i" || all=0; done
  if [ "$all" = 1 ]; then
    ok
    expect "ninth stream" 503 "$base2/events"
  else
    bad "eight streams" "not all eight streams connected"
  fi
  for p in $cap_pids; do kill "$p" 2>/dev/null; done
  kill "$srv" 2>/dev/null
else
  bad "second server" "did not start"
fi

# ---- idle shutdown and the LAN time limit, with tiny limits -------------------
gone_within() { for _ in $(seq 1 "$2"); do kill -0 "$1" 2>/dev/null || return 0; sleep 0.1; done; return 1; }
D3="$T/limits"; mkdir -p "$D3"; printf 'x\n' > "$D3/current.html"

export PREVIEW_IDLE_MINUTES=0.02
p="$(free_port)"
if start "$D3" "$p"; then
  grep -q "PREVIEW_IDLE_MINUTES" "$T/log.$p" && ok || bad "idle notice" "start-up stderr does not name PREVIEW_IDLE_MINUTES: $(cat "$T/log.$p")"
  gone_within "$srv" 60 && ok || bad "idle shutdown" "still running 6 s after a 1.2 s idle limit"
  grep -qi "idle" "$T/log.$p" && ok || bad "idle reason" "no stop reason on stderr"
else bad "idle server" "did not start"; fi

p="$(free_port)"
if start "$D3" "$p"; then
  sse "http://127.0.0.1:$p/events" "$T/idle-sse" 6
  wait_for ": connected" "$T/idle-sse" && sleep 3
  kill -0 "$srv" 2>/dev/null && ok || bad "open stream" "an open event stream did not hold off the idle limit"
  kill "$sse_pid" 2>/dev/null; kill "$srv" 2>/dev/null
else bad "idle stream server" "did not start"; fi

export PREVIEW_IDLE_MINUTES=0.03
p="$(free_port)"
if start "$D3" "$p"; then
  for _ in 1 2 3 4 5 6 7 8; do curl -s -o /dev/null --max-time 1 "http://127.0.0.1:$p/current.html"; sleep 0.4; done
  kill -0 "$srv" 2>/dev/null && ok || bad "requests" "completed requests did not reset the idle clock"
  gone_within "$srv" 60 && ok || bad "idle after requests" "still running 6 s after the last request"
else bad "idle request server" "did not start"; fi

export PREVIEW_IDLE_MINUTES=0
p="$(free_port)"
if start "$D3" "$p"; then
  sleep 1.5
  kill -0 "$srv" 2>/dev/null && ok || bad "idle off" "PREVIEW_IDLE_MINUTES=0 still stopped the server"
  kill "$srv" 2>/dev/null
else bad "idle-off server" "did not start"; fi
unset PREVIEW_IDLE_MINUTES

export PREVIEW_LAN_MINUTES=0.03
p="$(free_port)"
if start "$D3" "$p" --lan; then
  grep -q "PREVIEW_LAN_MINUTES" "$T/log.$p" && ok || bad "LAN notice" "start-up stderr does not name PREVIEW_LAN_MINUTES: $(cat "$T/log.$p")"
  for _ in $(seq 1 60); do
    curl -s -o /dev/null --max-time 1 "http://127.0.0.1:$p/current.html"
    kill -0 "$srv" 2>/dev/null || break
    sleep 0.1
  done
  kill -0 "$srv" 2>/dev/null && bad "LAN limit" "a busy LAN server outlived a 1.8 s limit" || ok
else bad "LAN limit server" "did not start"; fi
unset PREVIEW_LAN_MINUTES

p="$(free_port)"
if start "$D3" "$p" --lan; then
  grep -q "60 minutes" "$T/log.$p" && ok || bad "LAN default" "start-up stderr does not state the 60-minute default: $(cat "$T/log.$p")"
  kill "$srv" 2>/dev/null
else bad "LAN default server" "did not start"; fi

# ---- LAN key: the peer rule as a unit (a harness cannot fake a remote peer) ----
unit="$(python3 - "$(dirname "$SERVE")" <<'EOF' 2>&1
import sys
sys.path.insert(0, sys.argv[1])
import serve
fails = []
def want(label, got, expected):
    if got != expected:
        fails.append("%s: got %r, want %r" % (label, got, expected))
for peer, expected in [("127.0.0.1", True), ("127.8.9.1", True), ("::1", True), ("::ffff:127.0.0.1", True),
                       ("192.168.1.5", False), ("10.0.0.9", False), ("::ffff:192.168.1.5", False), ("", False), ("not-an-ip", False)]:
    want("peer_is_loopback(%r)" % peer, serve.peer_is_loopback(peer), expected)
K = "k" * 32
for args, expected in [
    ((False, "192.168.1.5", None, None, K), "open"),
    ((True, "127.0.0.1", None, None, K), "open"),
    ((True, "192.168.1.5", None, None, K), "deny"),
    ((True, "192.168.1.5", K, None, K), "grant"),
    ((True, "192.168.1.5", "wrong", None, K), "deny"),
    ((True, "192.168.1.5", None, K, K), "open"),
    ((True, "192.168.1.5", None, "wrong", K), "deny"),
    ((True, "192.168.1.5", "", "", ""), "deny"),
    ((True, "192.168.1.5", "é", None, K), "deny"),
]:
    want("lan_access%r" % (args,), serve.lan_access(*args), expected)
want("clean_location key only", serve.clean_location("/current.html?key=abc"), "/current.html")
want("clean_location keeps the rest", serve.clean_location("/a.html?x=1&key=abc&y=2"), "/a.html?x=1&y=2")
want("clean_location protocol-relative", serve.clean_location("//evil.example/?key=abc"), "/evil.example/")
want("clean_location backslash", serve.clean_location("/\\evil.example/?key=abc"), "/evil.example/")
print("\n".join(fails) if fails else "UNIT-OK")
EOF
)"
[ "$unit" = UNIT-OK ] && ok || bad "LAN key unit" "$unit"

# ---- LAN key end to end ---------------------------------------------------------
D4="$T/lan"; mkdir -p "$D4"
printf 'LIVE\n' > "$D4/current.html"; printf '<!doctype html><p>PASS-L</p>\n' > "$D4/2026-01-02-l.html"
p="$(free_port)"
if start "$D4" "$p" --lan; then
  key="$(cat "$D4/.preview.key" 2>/dev/null | tr -d '\n')"
  [ "${#key}" -ge 16 ] && ok || bad "key file" "no key of 16+ characters in .preview.key"
  m="$(python3 -c 'import os,sys;print(oct(os.stat(sys.argv[1]).st_mode & 0o777))' "$D4/.preview.key" 2>/dev/null)"
  [ "$m" = 0o600 ] && ok || bad "key file mode" "want 0o600, got $m"
  grep -q "^Serving .*/?key=$key " "$T/log.$p" && ok || bad "key in the printed URL" "$(head -n 1 "$T/log.$p")"
  kill "$srv" 2>/dev/null; wait "$srv" 2>/dev/null
  if start "$D4" "$p" --lan; then
    [ "$(cat "$D4/.preview.key" | tr -d '\n')" = "$key" ] && grep -q "?key=$key " "$T/log.$p" && ok \
      || bad "restart" "a restart changed the key or the URL"
  else bad "LAN restart" "did not start"; fi
  lbase="http://127.0.0.1:$p"
  expect "LAN: loopback needs no key" 200 "$lbase/current.html"
  expect "LAN: loopback /events needs no key" 200 --max-time 1 "$lbase/events"
  got="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 -X POST -H 'X-Preview-Restore: 1' -H 'Expect:' --data '{"name":"2026-01-02-l.html"}' "$lbase/_restore")"
  [ "$got" = 200 ] && grep -q PASS-L "$D4/current.html" && ok || bad "LAN: loopback restore" "want 200 and a copy, got $got"
  printf 'LIVE\n' > "$D4/current.html"
  got="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 -X POST -H 'X-Preview-Restore: 1' -H 'Host: attacker.example' -H 'Expect:' --data '{"name":"2026-01-02-l.html"}' "$lbase/_restore")"
  [ "$got" = 403 ] && ok || bad "LAN: restore with a foreign Host" "want 403, got $got"

  ip="$(python3 -c 'import socket
s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM)
try:
    s.connect(("203.0.113.1",9)); a=s.getsockname()[0]
    print("" if a.startswith("127.") else a)
except OSError:
    print("")')"
  if [ -z "$ip" ]; then
    echo "SKIP: no non-loopback IPv4 address — the remote-peer half of the LAN key is unit-tested only"
  else
    rbase="http://$ip:$p"
    for route in /current.html /events /_versions.json / /gallery/; do
      expect "LAN: no key from $ip on $route" 403 "$rbase$route"
    done
    expect "LAN: wrong key" 403 "$rbase/current.html?key=wrong"
    hdr="$(curl -s -D - -o "$T/grant" --max-time 5 "$rbase/current.html?x=1&key=$key")"
    case "$hdr" in *" 200 "*) ok ;; *) bad "LAN: key grant status (a 303 loses the Strict cookie on a link followed from another site)" "$(printf '%s' "$hdr" | head -n 1)" ;; esac
    grep -qF 'http-equiv="refresh" content="0;url=/current.html?x=1"' "$T/grant" && ok || bad "LAN: grant page refreshes to the URL without the key" "$(head -c 300 "$T/grant")"
    grep -qF "$key" "$T/grant" && bad "LAN: grant page body repeats the key" "$(head -c 300 "$T/grant")" || ok
    cookie="$(printf '%s' "$hdr" | grep -i '^set-cookie:' | tr -d '\r')"
    case "$cookie" in *"=$key;"*HttpOnly*SameSite=Strict*) ok ;; *) bad "LAN: cookie flags" "$cookie" ;; esac
    cname="$(printf '%s' "$cookie" | sed -n 's/^[Ss]et-[Cc]ookie: *\([^=]*\)=.*/\1/p')"
    expect "LAN: cookie admits" 200 -H "Cookie: $cname=$key" "$rbase/current.html"
    grep -q LIVE "$T/resp" && ok || bad "LAN: cookie body" "page not served with the cookie"
    expect "LAN: wrong cookie" 403 -H "Cookie: $cname=wrong" "$rbase/current.html"
    got="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 -X POST -H "Cookie: $cname=$key" -H 'X-Preview-Restore: 1' -H 'Expect:' --data '{"name":"2026-01-02-l.html"}' "$rbase/_restore")"
    [ "$got" = 403 ] && ok || bad "LAN: remote restore with a valid key" "want 403, got $got"
    grep -q LIVE "$D4/current.html" && ok || bad "LAN: remote restore" "current.html was overwritten from a remote peer"
    curl -s -o "$T/grant2" --max-time 5 --path-as-is "$rbase//evil.example/?key=$key"
    grep -qF 'content="0;url=/evil.example/"' "$T/grant2" && ok || bad "LAN: no protocol-relative refresh target" "$(head -c 300 "$T/grant2")"
  fi
  kill "$srv" 2>/dev/null
else bad "LAN key server" "did not start"; fi

echo "serve.py tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
