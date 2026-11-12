#!/usr/bin/env bash
# Drives preview.sh and serve.py's lifecycle: idempotent start, --stop, --lan restarting a loopback server, a recorded pid
# that is not serve.py or cannot be named (exit 6), state files gone after a self-exit, dk status on a dead server,
# the LAN and idle limits (DESIGN_KIT_LAN_MINUTES, DESIGN_KIT_IDLE_MINUTES in both modes, 0 = off; 403s do not count).
# Misses: whether a browser tab's stream really holds the server open; the LAN half skips with no network address.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; extra=""; trap 'kill $extra 2>/dev/null || true; bash "$here/preview.sh" --docroot "$tmp" --stop >/dev/null 2>&1 || true; rm -rf "$tmp"' EXIT
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
# a recorded pid that is not this server is never signalled: not by --stop, a plain start or a --lan restart
sleep 30 & decoy=$!; extra="$extra $decoy"
decoy_state() { echo "$decoy" > "$tmp/.preview.pid"; echo 127.0.0.1 > "$tmp/.preview.bind"; echo "http://127.0.0.1:1/" > "$tmp/.preview.url"; }
decoy_state; out="$(bash "$here/preview.sh" --docroot "$tmp" --stop)"
kill -0 "$decoy" 2>/dev/null || { echo "FAIL: --stop killed a recorded pid that is not serve.py"; exit 1; }
case "$out" in *"not serve.py"*) ;; *) echo "FAIL: --stop over a foreign pid did not say so: $out"; exit 1 ;; esac
decoy_state; out="$(bash "$here/preview.sh" --docroot "$tmp" --port "$port")"
case "$out" in *"already running"*|*"127.0.0.1:1/"*) echo "FAIL: a start over a foreign pid reused it: $out"; exit 1 ;; *"http://127.0.0.1:$port/"*) ;; *) echo "FAIL: start over a foreign pid: $out"; exit 1 ;; esac
bash "$here/preview.sh" --docroot "$tmp" --stop >/dev/null
decoy_state; bash "$here/preview.sh" --docroot "$tmp" --port "$port" --lan >/dev/null
kill -0 "$decoy" 2>/dev/null || { echo "FAIL: --lan killed a recorded pid that is not serve.py"; exit 1; }
bash "$here/preview.sh" --docroot "$tmp" --stop >/dev/null
# no usable ps: /proc names the server; a live pid nothing can name (a zombie) is exit 6 and its pid file stays
mkdir -p "$tmp/bin"; printf '#!/bin/sh\nexit 1\n' > "$tmp/bin/ps"; chmod +x "$tmp/bin/ps"
if [ -r /proc/self/cmdline ]; then
  bash "$here/preview.sh" --docroot "$tmp" --port "$port" >/dev/null
  out="$(PATH="$tmp/bin:$PATH" bash "$here/preview.sh" --docroot "$tmp" --port "$port" 2>&1)" || true
  case "$out" in *"already running"*) ;; *) echo "FAIL: with no usable ps a live server was not recognised: $out"; exit 1 ;; esac
  bash "$here/preview.sh" --docroot "$tmp" --stop >/dev/null
else echo "SKIP: no /proc — the ps-less identification is not exercised"; fi
python3 -c 'import os,time
pid=os.fork()
if pid==0: os._exit(0)
print(pid,flush=True); time.sleep(30)' > "$tmp/zpid" & extra="$extra $!"
for _ in $(seq 30); do [ -s "$tmp/zpid" ] && break; sleep 0.1; done
zpid="$(cat "$tmp/zpid")"
for args in "--stop" "--port $port"; do
  echo "$zpid" > "$tmp/.preview.pid"
  rc=0; PATH="$tmp/bin:$PATH" bash "$here/preview.sh" --docroot "$tmp" $args >/dev/null 2>&1 || rc=$?
  [ "$rc" = 6 ] && [ "$(cat "$tmp/.preview.pid" 2>/dev/null)" = "$zpid" ] || { echo "FAIL: preview.sh $args over a live pid it cannot identify: exit $rc, pid file $(cat "$tmp/.preview.pid" 2>/dev/null)"; exit 1; }
done
rm -f "$tmp/.preview.pid"
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
trap 'kill $ipid $lanpid $offpid $extra 2>/dev/null || true; bash "$here/preview.sh" --docroot "$tmp/i2" --stop >/dev/null 2>&1 || true; bash "$here/preview.sh" --docroot "$tmp" --stop >/dev/null 2>&1 || true; rm -rf "$tmp"' EXIT
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
# a self-exit removes the pid, url and bind files that still name it; dk status then prints no URL
[ -f "$tmp/i2/.preview.pid" ] || [ -f "$tmp/i2/.preview.url" ] && { echo "FAIL: serve.py left its pid or url file after an idle exit"; exit 1; }
dk_status() { (cd "$tmp" && DESIGN_KIT_IGNORE=off DESIGN_KIT_DIR="$1" bash "$here/dk.sh" status); }
st="$(dk_status "$tmp/i2")"; case "$st" in *"server: not running"*) ;; *) echo "FAIL: dk status after an idle exit: $st"; exit 1 ;; esac
gone="$(bash "$here/preview.sh" --docroot "$tmp/i2" --stop)"
case "$gone" in *"nothing running"*) ;; *) echo "FAIL: --stop after an idle exit: $gone"; exit 1 ;; esac
[ -f "$tmp/i2/.preview.url" ] && { echo "FAIL: .preview.url left after --stop following an idle exit"; exit 1; }
# a server killed outright leaves its files; dk status still reads it as not running
mkdir -p "$tmp/i4"; p5=$(( p1 + 4 ))
bash "$here/preview.sh" --docroot "$tmp/i4" --port "$p5" >/dev/null; kpid="$(cat "$tmp/i4/.preview.pid")"
kill -9 "$kpid"; for _ in $(seq 30); do kill -0 "$kpid" 2>/dev/null || break; sleep 0.1; done
st="$(dk_status "$tmp/i4")"; case "$st" in *"server: not running"*) ;; *) echo "FAIL: dk status printed a URL for a killed server: $st"; exit 1 ;; esac
# the idle clock counts only requests that pass the key gate: 403s from a LAN peer without the key do not hold the server up
lanip="$(python3 -c 'import socket
s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM)
try: s.connect(("192.0.2.1",9)); a=s.getsockname()[0]; print("" if a.startswith("127.") else a)
except OSError: print("")')"
if [ -z "$lanip" ]; then echo "SKIP: no non-loopback address — 403s and the idle clock are not exercised"
else
  p6=$(( p1 + 5 ))
  DESIGN_KIT_IDLE_MINUTES=0.05 DESIGN_KIT_LAN_MINUTES=0 python3 "$here/serve.py" --docroot "$tmp/i3" --port "$p6" --lan >/dev/null 2>&1 & gpid=$!; extra="$extra $gpid"
  sleep 0.5
  for _ in $(seq 80); do kill -0 "$gpid" 2>/dev/null || break; curl -s -o /dev/null --max-time 1 "http://$lanip:$p6/index.html" || true; sleep 0.1; done
  kill -0 "$gpid" 2>/dev/null && { echo "FAIL: 403s from a LAN peer without the key kept the server from its idle exit"; exit 1; }
fi
# A server an older launcher started with a RELATIVE --docroot is still this docroot's server: --stop must stop it, not orphan it.
mkdir -p "$tmp/up/.design-kit"; printf '<p>u</p>' > "$tmp/up/.design-kit/index.html"
p7="$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1])')"
( cd "$tmp/up" && DESIGN_KIT_IDLE_MINUTES=0 exec python3 "$here/serve.py" --docroot .design-kit --port "$p7" >/dev/null 2>&1 ) & upid=$!; extra="$extra $upid"
for _ in $(seq 50); do curl -s -o /dev/null --max-time 1 "http://127.0.0.1:$p7/" && break; sleep 0.1; done
printf '%s\n' "$upid" > "$tmp/up/.design-kit/.preview.pid"; printf 'http://127.0.0.1:%s/\n' "$p7" > "$tmp/up/.design-kit/.preview.url"
rc=0; out="$(bash "$here/preview.sh" --docroot "$tmp/up/.design-kit" --stop 2>&1)" || rc=$?
for _ in $(seq 30); do kill -0 "$upid" 2>/dev/null || break; sleep 0.1; done
kill -0 "$upid" 2>/dev/null && { echo "FAIL: --stop left a server started with a relative --docroot running (rc=$rc: $out)"; exit 1; }
[ ! -e "$tmp/up/.design-kit/.preview.pid" ] || { echo "FAIL: --stop left the pid file of the relative-docroot server"; exit 1; }
echo "PASS preview.test.sh"
