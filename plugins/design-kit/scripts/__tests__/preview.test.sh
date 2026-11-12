#!/usr/bin/env bash
# Drives preview.sh and serve.py's lifecycle: idempotent start, --stop, --lan restarting a loopback server,
# the LAN and idle limits (DESIGN_KIT_LAN_MINUTES, DESIGN_KIT_IDLE_MINUTES in both modes, 0 = off).
# Misses: whether a browser tab's stream really holds the server open; the LAN half skips with no network address.
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

# Idle shutdown, every mode: no completed request and no open /_events stream for
# DESIGN_KIT_IDLE_MINUTES ends the server. Two servers that get no request run alongside.
mkdir -p "$tmp/i1" "$tmp/i2" "$tmp/i3"; for d in i1 i2 i3; do echo '<h1>idle</h1>' > "$tmp/$d/index.html"; done
p1=$(( 20000 + RANDOM % 10000 )); p2=$(( p1 + 1 )); p3=$(( p1 + 2 )); p4=$(( p1 + 3 ))
DESIGN_KIT_IDLE_MINUTES=0.05 bash "$here/preview.sh" --docroot "$tmp/i2" --port "$p2" >/dev/null
DESIGN_KIT_IDLE_MINUTES=0.05 DESIGN_KIT_LAN_MINUTES=0 python3 "$here/serve.py" --docroot "$tmp/i3" --port "$p3" --lan >/dev/null 2>&1 & lanpid=$!
DESIGN_KIT_IDLE_MINUTES=0 python3 "$here/serve.py" --docroot "$tmp/i3" --port "$p4" >/dev/null 2>"$tmp/off.err" & offpid=$!
DESIGN_KIT_IDLE_MINUTES=0.05 python3 "$here/serve.py" --docroot "$tmp/i1" --port "$p1" >/dev/null 2>"$tmp/idle.err" & ipid=$!
trap 'kill $ipid $lanpid $offpid 2>/dev/null || true; bash "$here/preview.sh" --docroot "$tmp/i2" --stop >/dev/null 2>&1 || true; bash "$here/preview.sh" --docroot "$tmp" --stop >/dev/null 2>&1 || true; rm -rf "$tmp"' EXIT
sleep 0.5
grep -q "idle shutdown after 0.05 min" "$tmp/idle.err" || { echo "FAIL: no idle-shutdown notice on stderr at start: $(cat "$tmp/idle.err")"; exit 1; }
grep -q "idle shutdown off" "$tmp/off.err" || { echo "FAIL: DESIGN_KIT_IDLE_MINUTES=0 does not say idle shutdown is off: $(cat "$tmp/off.err")"; exit 1; }
for _ in 1 2 3 4 5; do curl -s "http://127.0.0.1:$p1/index.html" >/dev/null; sleep 1; done
kill -0 "$ipid" 2>/dev/null || { echo "FAIL: idle shutdown fired while requests kept arriving"; exit 1; }
curl -s -N --max-time 5 "http://127.0.0.1:$p1/_events" >/dev/null 2>&1 || true
kill -0 "$ipid" 2>/dev/null || { echo "FAIL: idle shutdown fired while an event stream was open"; exit 1; }
for _ in $(seq 60); do kill -0 "$ipid" 2>/dev/null || break; sleep 0.1; done
curl -s --max-time 1 "http://127.0.0.1:$p1/" >/dev/null 2>&1 && { echo "FAIL: server outlived DESIGN_KIT_IDLE_MINUTES"; exit 1; }
curl -s --max-time 1 "http://127.0.0.1:$p3/" >/dev/null 2>&1 && { echo "FAIL: a LAN server outlived DESIGN_KIT_IDLE_MINUTES"; exit 1; }
curl -s --max-time 1 "http://127.0.0.1:$p2/" >/dev/null 2>&1 && { echo "FAIL: a preview.sh server outlived DESIGN_KIT_IDLE_MINUTES"; exit 1; }
curl -s --max-time 1 "http://127.0.0.1:$p4/" >/dev/null 2>&1 || { echo "FAIL: DESIGN_KIT_IDLE_MINUTES=0 still shut the server down"; exit 1; }
kill "$offpid"
# like a LAN expiry: the pid and url files stay; the launcher reads the pid as dead
gone="$(bash "$here/preview.sh" --docroot "$tmp/i2" --stop)"
case "$gone" in *"nothing running"*) ;; *) echo "FAIL: --stop after an idle exit: $gone"; exit 1 ;; esac
[ -f "$tmp/i2/.preview.url" ] && { echo "FAIL: .preview.url left after --stop following an idle exit"; exit 1; }
echo "PASS preview.test.sh"
