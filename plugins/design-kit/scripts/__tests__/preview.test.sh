#!/usr/bin/env bash
# Drives preview.sh: start serves a file, second start is idempotent, --stop kills it;
# --lan restarts a loopback server, a later plain start says LAN is still on, and a LAN
# server ends itself after DESIGN_KIT_LAN_MINUTES.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'bash "$here/preview.sh" --docroot "$tmp" --stop >/dev/null 2>&1 || true; rm -rf "$tmp"' EXIT
port=$(( 20000 + RANDOM % 10000 ))
echo '<h1>ok</h1>' > "$tmp/index.html"
out="$(bash "$here/preview.sh" --docroot "$tmp" --port "$port")"
case "$out" in *"http://127.0.0.1:$port/"*) ;; *) echo "FAIL: start output: $out"; exit 1 ;; esac
body="$(curl -s "http://127.0.0.1:$port/index.html")"
case "$body" in "<h1>ok</h1>"*) ;; *) echo "FAIL: served body: $body"; exit 1 ;; esac
[ "$(cat "$tmp/.preview.url")" = "http://127.0.0.1:$port/" ] || { echo "FAIL: .preview.url: $(cat "$tmp/.preview.url" 2>&1)"; exit 1; }
out2="$(bash "$here/preview.sh" --docroot "$tmp" --port "$port")"
case "$out2" in *"already running"*) ;; *) echo "FAIL: second start not idempotent: $out2"; exit 1 ;; esac
out3="$(bash "$here/preview.sh" --docroot "$tmp" --stop)"
case "$out3" in *stopped*) ;; *) echo "FAIL: stop output: $out3"; exit 1 ;; esac
curl -s "http://127.0.0.1:$port/index.html" >/dev/null 2>&1 && { echo "FAIL: still serving after --stop"; exit 1; }
[ -f "$tmp/.preview.url" ] && { echo "FAIL: .preview.url left after --stop"; exit 1; }
bound() { python3 -c 'import socket,sys
s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM)
try: s.connect(("192.0.2.1",9)); ip=s.getsockname()[0]
except OSError: sys.exit(2)
c=socket.socket(); c.settimeout(1)
sys.exit(0 if c.connect_ex((ip,int(sys.argv[1])))==0 else 1)' "$1"; }
bash "$here/preview.sh" --docroot "$tmp" --port "$port" >/dev/null
[ "$(cat "$tmp/.preview.bind")" = 127.0.0.1 ] || { echo "FAIL: .preview.bind after a plain start: $(cat "$tmp/.preview.bind" 2>&1)"; exit 1; }
rc=0; bound "$port" || rc=$?
if [ "$rc" = 2 ]; then echo "SKIP: no non-loopback address on this machine — the LAN half is not exercised"
else
  [ "$rc" = 1 ] || { echo "FAIL: a loopback server answered on the network address"; exit 1; }
  lan="$(DESIGN_KIT_LAN_MINUTES=0.05 bash "$here/preview.sh" --docroot "$tmp" --port "$port" --lan)"
  case "$lan" in *"already running"*) echo "FAIL: --lan reused the loopback server: $lan"; exit 1 ;; esac
  case "$lan" in *"LAN mode"*) ;; *) echo "FAIL: --lan start output: $lan"; exit 1 ;; esac
  [ "$(cat "$tmp/.preview.bind")" = 0.0.0.0 ] || { echo "FAIL: .preview.bind after --lan"; exit 1; }
  bound "$port" || { echo "FAIL: --lan server is not reachable on the network address"; exit 1; }
  again="$(bash "$here/preview.sh" --docroot "$tmp" --port "$port")"
  case "$again" in *"LAN mode is still on"*) ;; *) echo "FAIL: a plain start over a LAN server did not say so: $again"; exit 1 ;; esac
  sleep 4
  curl -s "http://127.0.0.1:$port/index.html" >/dev/null 2>&1 && { echo "FAIL: LAN server outlived DESIGN_KIT_LAN_MINUTES"; exit 1; }
  back="$(bash "$here/preview.sh" --docroot "$tmp" --port "$port")"
  case "$back" in *"http://127.0.0.1:$port/"*) ;; *) echo "FAIL: start after LAN expiry: $back"; exit 1 ;; esac
  rc=0; bound "$port" || rc=$?; [ "$rc" = 1 ] || { echo "FAIL: the server after LAN expiry is not loopback-only"; exit 1; }
  bash "$here/preview.sh" --docroot "$tmp" --stop >/dev/null
fi
[ -f "$tmp/.preview.bind" ] && { echo "FAIL: .preview.bind left after --stop"; exit 1; }
echo "PASS preview.test.sh"
