#!/usr/bin/env bash
# Drives preview.sh and serve.py's lifecycle: idempotent start, the port choice (8124 busy, the recorded port, an explicit port, a full range, a port that answers though a server starts on it, one that takes no more connects, the moved-port line), a python3 that is late (its port another project's, a second launch meanwhile, one that waits too long, a launcher killed, a bind that never comes), the version record (an older server replaced on its port and bind, a newer one kept), --stop, --lan restarting a loopback server, a recorded pid that is not serve.py or cannot be named (exit 6),
# state files gone after a self-exit, kept when they name another server, dk status on a dead server, the LAN and idle limits (DESIGN_KIT_LAN_MINUTES, DESIGN_KIT_IDLE_MINUTES in both modes, 0 = off; 403s do not count, an open stream of the gallery or of a page does).
# Misses: whether a browser tab's stream really holds the server open; the LAN half skips with no network address; two launches that both find nothing recorded.
set -euo pipefail
unset DESIGN_KIT_PORT DESIGN_KIT_PORT_LAST
here="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; extra=""; trap 'kill $extra 2>/dev/null || true; bash "$here/preview.sh" --docroot "$tmp" --stop >/dev/null 2>&1 || true; rm -rf "$tmp"' EXIT
port=$(( 20000 + RANDOM % 10000 ))
echo '<h1>ok</h1>' > "$tmp/index.html"
out="$(bash "$here/preview.sh" --docroot "$tmp" --port "$port")"
case "$out" in *"http://127.0.0.1:$port/"*) ;; *) echo "FAIL: start output: $out"; exit 1 ;; esac
body="$(curl -s "http://127.0.0.1:$port/index.html")"
case "$body" in *'<body data-page="index.html"'*) ;; *) echo "FAIL: served body is not the viewer: $body"; exit 1 ;; esac
raw="$(curl -sL "http://127.0.0.1:$port/index.html?static=1")"
case "$raw" in "<script data-design-kit-frame>"*"</script><h1>ok</h1>") ;; *) echo "FAIL: ?static=1 does not lead to the raw body: $raw"; exit 1 ;; esac
[ "$(cat "$tmp/.preview.url")" = "http://127.0.0.1:$port/" ] || { echo "FAIL: .preview.url: $(cat "$tmp/.preview.url" 2>&1)"; exit 1; }
version="$(python3 -c 'import importlib.util, sys
spec = importlib.util.spec_from_file_location("dkserve", sys.argv[1]); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
print(getattr(m, "SERVER_VERSION", "no SERVER_VERSION"))' "$here/serve.py")"
[ "$(cat "$tmp/.preview.ver" 2>&1)" = "$(cat "$tmp/.preview.pid") $version" ] || { echo "FAIL: .preview.ver after a start: $(cat "$tmp/.preview.ver" 2>&1); wanted the pid and $version"; exit 1; }
out2="$(bash "$here/preview.sh" --docroot "$tmp" --port "$port")"
case "$out2" in *"not used"*) echo "FAIL: a second start on the running port says the port was not used: $out2"; exit 1 ;; *"already running"*) ;; *) echo "FAIL: second start not idempotent: $out2"; exit 1 ;; esac
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
mkdir -p "$tmp/i1" "$tmp/i2" "$tmp/i3" "$tmp/i5"; for d in i1 i2 i3 i5; do echo '<h1>idle</h1>' > "$tmp/$d/index.html"; done
p1=$(( 20000 + RANDOM % 10000 )); p2=$(( p1 + 1 )); p3=$(( p1 + 2 )); p4=$(( p1 + 3 )); pages=$(( p1 + 6 ))
DESIGN_KIT_IDLE_MINUTES=0.05 bash "$here/preview.sh" --docroot "$tmp/i2" --port "$p2" >/dev/null
DESIGN_KIT_IDLE_MINUTES=0.05 DESIGN_KIT_LAN_MINUTES=0 python3 "$here/serve.py" --docroot "$tmp/i3" --port "$p3" --lan >/dev/null 2>&1 & lanpid=$!
DESIGN_KIT_IDLE_MINUTES=0 python3 "$here/serve.py" --docroot "$tmp/i3" --port "$p4" >/dev/null 2>"$tmp/off.err" & offpid=$!
DESIGN_KIT_IDLE_MINUTES=0.05 python3 "$here/serve.py" --docroot "$tmp/i1" --port "$p1" >/dev/null 2>"$tmp/idle.err" & ipid=$!
DESIGN_KIT_IDLE_MINUTES=0.05 python3 "$here/serve.py" --docroot "$tmp/i5" --port "$pages" >/dev/null 2>&1 & viewed=$!; extra="$extra $viewed"
# the LAN server of i3, which ends itself below, is not the one its state files name
i3_state() { (cd "$tmp/i3" && grep -H . .preview.pid .preview.url .preview.bind .preview.ver 2>/dev/null) || true; }
echo "$offpid" > "$tmp/i3/.preview.pid"; for f in url bind ver; do echo "of $offpid" > "$tmp/i3/.preview.$f"; done; named="$(i3_state)"
trap 'kill $ipid $lanpid $offpid $extra 2>/dev/null || true; bash "$here/preview.sh" --docroot "$tmp/i2" --stop >/dev/null 2>&1 || true; bash "$here/preview.sh" --docroot "$tmp" --stop >/dev/null 2>&1 || true; rm -rf "$tmp"' EXIT
sleep 0.5
grep -q "idle shutdown after 0.05 min" "$tmp/idle.err" || { echo "FAIL: no idle-shutdown notice on stderr at start: $(cat "$tmp/idle.err")"; exit 1; }
grep -q "idle shutdown off" "$tmp/off.err" || { echo "FAIL: DESIGN_KIT_IDLE_MINUTES=0 does not say idle shutdown is off: $(cat "$tmp/off.err")"; exit 1; }
curl -s -N --max-time 7 "http://127.0.0.1:$pages/_events?page=index.html" >/dev/null 2>&1 & extra="$extra $!"
for _ in 1 2 3 4 5; do curl -s "http://127.0.0.1:$p1/index.html" >/dev/null; sleep 1; done
kill -0 "$ipid" 2>/dev/null || { echo "FAIL: idle shutdown fired while requests kept arriving"; exit 1; }
kill -0 "$viewed" 2>/dev/null || { echo "FAIL: idle shutdown fired while a page's own event stream was open"; exit 1; }
curl -s -N --max-time 5 "http://127.0.0.1:$p1/_events" >/dev/null 2>&1 || true
kill -0 "$ipid" 2>/dev/null || { echo "FAIL: idle shutdown fired while an event stream was open"; exit 1; }
for _ in $(seq 60); do kill -0 "$ipid" 2>/dev/null || break; sleep 0.1; done
curl -s --max-time 1 "http://127.0.0.1:$p1/" >/dev/null 2>&1 && { echo "FAIL: server outlived DESIGN_KIT_IDLE_MINUTES"; exit 1; }
curl -s --max-time 1 "http://127.0.0.1:$p3/" >/dev/null 2>&1 && { echo "FAIL: a LAN server outlived DESIGN_KIT_IDLE_MINUTES"; exit 1; }
[ "$(i3_state)" = "$named" ] || { echo "FAIL: a server that ended itself changed the state of the server recorded beside it: $(i3_state), was $named"; exit 1; }
curl -s --max-time 1 "http://127.0.0.1:$p2/" >/dev/null 2>&1 && { echo "FAIL: a preview.sh server outlived DESIGN_KIT_IDLE_MINUTES"; exit 1; }
curl -s --max-time 1 "http://127.0.0.1:$p4/" >/dev/null 2>&1 || { echo "FAIL: DESIGN_KIT_IDLE_MINUTES=0 still shut the server down"; exit 1; }
kill "$offpid"
# a self-exit removes the pid, url, bind and ver files that still name it; dk status then prints no URL
[ -f "$tmp/i2/.preview.pid" ] || [ -f "$tmp/i2/.preview.url" ] || [ -f "$tmp/i2/.preview.ver" ] && { echo "FAIL: serve.py left its pid, url or ver file after an idle exit"; exit 1; }
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
free_port() { python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1])'; }
p7="$(free_port)"
( cd "$tmp/up" && DESIGN_KIT_IDLE_MINUTES=0 exec python3 "$here/serve.py" --docroot .design-kit --port "$p7" >/dev/null 2>&1 ) & upid=$!; extra="$extra $upid"
for _ in $(seq 50); do curl -s -o /dev/null --max-time 1 "http://127.0.0.1:$p7/" && break; sleep 0.1; done
printf '%s\n' "$upid" > "$tmp/up/.design-kit/.preview.pid"; printf 'http://127.0.0.1:%s/\n' "$p7" > "$tmp/up/.design-kit/.preview.url"
rc=0; out="$(bash "$here/preview.sh" --docroot "$tmp/up/.design-kit" --stop 2>&1)" || rc=$?
for _ in $(seq 30); do kill -0 "$upid" 2>/dev/null || break; sleep 0.1; done
kill -0 "$upid" 2>/dev/null && { echo "FAIL: --stop left a server started with a relative --docroot running (rc=$rc: $out)"; exit 1; }
[ ! -e "$tmp/up/.design-kit/.preview.pid" ] || { echo "FAIL: --stop left the pid file of the relative-docroot server"; exit 1; }
# Port choice. The cases take the ports they need themselves, so a server already on 8124 only stands in for the other docroot.
trap 'kill $extra 2>/dev/null || true; for d in "$tmp" "$tmp"/p?; do bash "$here/preview.sh" --docroot "$d" --stop >/dev/null 2>&1 || true; done; rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*"; exit 1; }
cat > "$tmp/ports.py" <<'PY'
import socket, sys, time
def take(port):
    s = socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try: s.bind(("127.0.0.1", port)); s.listen()
    except OSError: return None
    return s
def silent(port):  # bound, answers no connect
    s = socket.socket(); s.bind(("127.0.0.1", port))
    return s
def full(port):  # listens, takes no more connects
    s = take(port); s.listen(0); waiting = [socket.socket() for _ in range(4)]
    for c in waiting: c.setblocking(False); c.connect_ex(("127.0.0.1", port))
    return s, waiting
if sys.argv[1] == "first":
    print(next(p for p in range(int(sys.argv[2]), 8200) if take(p)))
else:
    held = [{"": take, "silent": silent, "full": full}[kind](int(p)) for kind, _, p in (a.rpartition(":") for a in sys.argv[2:])]
    open(sys.argv[1], "w").close(); time.sleep(60)
PY
first_free() { python3 "$tmp/ports.py" first "$1"; }
hold() { rm -f "$tmp/held"; python3 "$tmp/ports.py" "$tmp/held" "$@" & holder=$!; extra="$extra $holder"
  for _ in $(seq 50); do [ -f "$tmp/held" ] && return; sleep 0.1; done; fail "the port holder did not start"; }
release() { { kill "$holder"; wait "$holder"; } 2>/dev/null || true; }
# launch <docroot> [args]: sets rc and out, the output of both streams; url_of and port_of read what it recorded
launch() { local d="$1"; shift; rc=0; out="$(bash "$here/preview.sh" --docroot "$d" "$@" 2>&1)" || rc=$?; }
url_of() { cat "$1/.preview.url" 2>/dev/null || true; }
port_of() { cat "$1/.preview.port" 2>/dev/null || true; }
moved() { printf '%s\n' "$out" | grep -cxF "preview: moved from port $1; saved knobs and page data stay on the old address" || true; }
mkdir -p "$tmp/p1" "$tmp/p2" "$tmp/p3" "$tmp/p4"; echo '<h1>p2</h1>' > "$tmp/p2/index.html"
export DESIGN_KIT_PORT_LAST=8199

c="8124 held by another docroot starts on the next port, reused next time"
launch "$tmp/p1" --port 8124
[ "$rc" = 0 ] || { [ "$rc" = 4 ] && echo "NOTE: 8124 is held by a process this harness did not start; it stands in for the other docroot"; } || fail "$c: --port 8124 exit $rc: $out"
want="$(first_free 8125)"; launch "$tmp/p2"
[ "$rc" = 0 ] && [ "$(url_of "$tmp/p2")" = "http://127.0.0.1:$want/" ] && [ "$(port_of "$tmp/p2")" = "$want" ] || fail "$c: wanted port $want, got exit $rc, url $(url_of "$tmp/p2"), recorded $(port_of "$tmp/p2"): $out"
case "$out" in *moved*) fail "$c: a first start prints a moved-port line: $out" ;; esac
case "$(curl -sL "http://127.0.0.1:$want/index.html?static=1")" in *"</script><h1>p2</h1>") ;; *) fail "$c: port $want does not serve this docroot" ;; esac
code="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$want/.preview.port")"; [ "$code" = 404 ] || fail ".preview.port is served: $code"
launch "$tmp/p2" --stop; [ "$(port_of "$tmp/p2")" = "$want" ] || fail "$c: --stop did not keep .preview.port: $(port_of "$tmp/p2")"
[ ! -e "$tmp/p2/.preview.pid" ] && [ ! -e "$tmp/p2/.preview.url" ] && [ ! -e "$tmp/p2/.preview.bind" ] && [ ! -e "$tmp/p2/.preview.ver" ] || fail "--stop left a pid, url, bind or ver file"
launch "$tmp/p1" --stop; launch "$tmp/p2"
[ "$(url_of "$tmp/p2")" = "http://127.0.0.1:$want/" ] || fail "$c: the second start went to $(url_of "$tmp/p2"), wanted $want: $out"
[ "$(moved "$want")" = 0 ] || fail "$c: a start on the recorded port prints the moved-port line: $out"

c="moved-port line printed once"; high="$(free_port)"
launch "$tmp/p2" --stop; launch "$tmp/p2" --port "$high"
[ "$rc" = 0 ] && [ "$(moved "$want")" = 1 ] && [ "$(port_of "$tmp/p2")" = "$high" ] || fail "$c: --port $high after $want, exit $rc, recorded $(port_of "$tmp/p2"): $out"
launch "$tmp/p2" --stop; DESIGN_KIT_PORT="" launch "$tmp/p2"
[ "$(url_of "$tmp/p2")" = "http://127.0.0.1:$high/" ] && [ "$(moved "$high")" = 0 ] || fail "the recorded port $high is not tried first with an empty DESIGN_KIT_PORT: exit $rc, $(url_of "$tmp/p2"): $out"
launch "$tmp/p2" --stop; hold "$high"; want="$(first_free 8124)"; launch "$tmp/p2"; release
[ "$(url_of "$tmp/p2")" = "http://127.0.0.1:$want/" ] && [ "$(moved "$high")" = 1 ] || fail "$c: recorded port $high busy, wanted $want and the line once: exit $rc, $(url_of "$tmp/p2"): $out"
launch "$tmp/p2" --stop; launch "$tmp/p2"; case "$rc $out" in "0 "*moved*) fail "$c: printed again on the next start: $out" ;; "0 "*) ;; *) fail "$c: $out" ;; esac
launch "$tmp/p2" --lan
case "$(url_of "$tmp/p2")" in *":$want/") ;; *) fail "a --lan restart left port $want: $(url_of "$tmp/p2"): $out" ;; esac

c="a running server on another port than an explicit one is reused"
launch "$tmp/p2" --stop; launch "$tmp/p2"; pid="$(cat "$tmp/p2/.preview.pid")"
launch "$tmp/p2" --port "$high"; flag="$out"; DESIGN_KIT_PORT="$high" launch "$tmp/p2"
for o in "$flag" "$out"; do
  case "$o" in *"already running — http://127.0.0.1:$want/"*) ;; *) fail "$c: $o" ;; esac
  printf '%s\n' "$o" | grep -qxF "preview: already running on port $want; --port $high not used" || fail "$c: the port is not named: $o"
done
[ "$(cat "$tmp/p2/.preview.pid")" = "$pid" ] && kill -0 "$pid" && [ "$(port_of "$tmp/p2")" = "$want" ] || fail "$c: the server or its recorded port changed"
rm "$tmp/p2/.preview.url"; launch "$tmp/p2"; [ "$out" = "preview: already running — http://127.0.0.1:$want/" ] || fail "$c: with no url file and no port: $out"
launch "$tmp/p2" --stop

c="explicit port busy exits 4"; hold "$high"
DESIGN_KIT_PORT="$high" launch "$tmp/p2"; flag="$rc $out"; launch "$tmp/p2" --port "$high"; release
for o in "$flag" "$rc $out"; do [ "$o" = "4 preview.sh: server did not start (port $high busy?)" ] || fail "$c: $o"; done
[ ! -e "$tmp/p2/.preview.pid" ] && [ "$(port_of "$tmp/p2")" = "$want" ] || fail "$c: pid file left or the recorded port changed to $(port_of "$tmp/p2")"

c="range full exits 4"; hold 8124 8125; DESIGN_KIT_PORT_LAST=8125 launch "$tmp/p3"; release
[ "$rc $out" = "4 preview.sh: no free port from 8124 to 8125" ] || fail "$c: exit $rc: $out"
[ ! -e "$tmp/p3/.preview.pid" ] && [ ! -e "$tmp/p3/.preview.port" ] || fail "$c: a failed start left a pid or port file"

# The version record. older <docroot> <port> [--lan]: a server started as the 0.19.3 launcher starts one, leaving .preview.ver and .preview.port as they are
older() { local b=127.0.0.1; [ "${3:-}" = --lan ] && b=0.0.0.0
  python3 "$here/serve.py" --docroot "$(cd "$1" && pwd -P)" --port "$2" ${3:-} >/dev/null 2>&1 & oldpid=$!; extra="$extra $oldpid"
  echo "$oldpid" > "$1/.preview.pid"; echo "http://127.0.0.1:$2/" > "$1/.preview.url"; echo "$b" > "$1/.preview.bind"
  for _ in $(seq 50); do curl -s -o /dev/null --max-time 1 "http://127.0.0.1:$2/" && return; sleep 0.1; done; fail "the older server did not start on port $2"; }
pid_of() { cat "$1/.preview.pid" 2>/dev/null || true; }
ver_of() { cat "$1/.preview.ver" 2>/dev/null || true; }
line() { printf '%s\n' "$out" | grep -qxF "$1" || fail "$c: no line \"$1\": $out"; }
# replaced <docroot> <port> <bind>: after a launch, oldpid is gone and a server with its own record answers on that port and bind
replaced() { local new; new="$(pid_of "$1")"
  [ "$rc" = 0 ] || fail "$c: exit $rc: $out"
  if kill -0 "$oldpid" 2>/dev/null; then fail "$c: the older server still runs: $out"; fi
  [ "$new" != "$oldpid" ] && kill -0 "$new" 2>/dev/null && [ "$(ver_of "$1")" = "$new $version" ] || fail "$c: pid file $new, record $(ver_of "$1"): $out"
  case "$(url_of "$1")" in *":$2/") ;; *) fail "$c: moved to $(url_of "$1"), was on $2: $out" ;; esac
  case "$(curl -sL --max-time 1 --retry 3 --retry-connrefused "http://127.0.0.1:$2/index.html?static=1")" in *"</script><h1>p5</h1>") ;; *) fail "$c: nothing serves this docroot on port $2" ;; esac
  [ "$(cat "$1/.preview.bind")" = "$3" ] && [ "$(port_of "$1")" = "$2" ] || fail "$c: bind $(cat "$1/.preview.bind"), recorded port $(port_of "$1"); wanted $3 and $2"
  local net=0; bound "$2" || net=$?
  case "$3 $net" in "127.0.0.1 0" | "0.0.0.0 1") fail "$c: the network address answers $net (0 = yes, 1 = no) on a $3 server" ;; esac; }
# a fresh older server on $own, and no recorded port to lead the launcher back to it
outdate() { launch "$tmp/p5" --stop; rm -f "$tmp/p5/.preview.port"; older "$tmp/p5" "$own" "$@"; }
# stale <what> <record>: PID in the record is the running server's
stale() { c="$1 is replaced on its port"; outdate; [ -z "$2" ] || printf '%s\n' "${2//PID/$oldpid}" > "$tmp/p5/.preview.ver"
  launch "$tmp/p5"; replaced "$tmp/p5" "$own" 127.0.0.1; case "$out" in *"not used"*) fail "$c: no port was asked for: $out" ;; esac; }
mkdir -p "$tmp/p5"; echo '<h1>p5</h1>' > "$tmp/p5/index.html"; own="$(free_port)"; other="$(free_port)"
stale "a server with no version record" ""
stale "a server of a lower version" "PID $(( version - 1 ))"
stale "version record for another pid is ignored and the server" "1PID $version"
stale "a server whose version record is no number" "PID ${version}x"
stale "a server whose version record is past any integer" "PID 99999999999999999999"

c="an older server asked for on another port is replaced on its own"
outdate; launch "$tmp/p5" --port "$other"; replaced "$tmp/p5" "$own" 127.0.0.1; line "preview: already running on port $own; --port $other not used"
outdate; DESIGN_KIT_PORT="$other" launch "$tmp/p5"; replaced "$tmp/p5" "$own" 127.0.0.1; line "preview: already running on port $own; --port $other not used"

c="an older LAN server is replaced as a LAN server"
outdate --lan; key="$(cat "$tmp/p5/.preview.key")"; launch "$tmp/p5"; replaced "$tmp/p5" "$own" 0.0.0.0
case "$out" in *"LAN mode"*) ;; *) fail "$c: the output does not say LAN mode is on: $out" ;; esac
[ "$(cat "$tmp/p5/.preview.key")" = "$key" ] || fail "$c: its key changed"
c="--lan over an older loopback server keeps its port"; outdate; launch "$tmp/p5" --lan; replaced "$tmp/p5" "$own" 0.0.0.0

c="after a kill -9, a 0.19.3 start beside a stale version record is replaced"
launch "$tmp/p5" --stop; launch "$tmp/p5" --port "$own"; pid="$(pid_of "$tmp/p5")"
kill -9 "$pid"; for _ in $(seq 30); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
older "$tmp/p5" "$own"; [ "$(ver_of "$tmp/p5")" = "$pid $version" ] || fail "$c: the record the killed server left is not there: $(ver_of "$tmp/p5")"
launch "$tmp/p5"; replaced "$tmp/p5" "$own" 127.0.0.1

c="a newer server is kept"
outdate; echo "$oldpid $(( version + 1 ))" > "$tmp/p5/.preview.ver"; newer="$(ver_of "$tmp/p5")"
for args in "" "--lan" "--port $other"; do
  launch "$tmp/p5" $args; line "preview: already running — http://127.0.0.1:$own/"; line "preview: a newer server is running; left as it is."
  [ "$rc $(pid_of "$tmp/p5") $(ver_of "$tmp/p5")" = "0 $oldpid $newer" ] && kill -0 "$oldpid" || fail "$c: $args exit $rc, pid file $(pid_of "$tmp/p5"), record $(ver_of "$tmp/p5"): $out"
  case "$args" in --lan) line "preview: --lan not used" ;; --port*) line "preview: already running on port $own; --port $other not used" ;; esac
done

c="an older server that takes a second to stop is waited for"
outdate; kill -STOP "$oldpid"; { sleep 1; kill -CONT "$oldpid"; } & launch "$tmp/p5"; replaced "$tmp/p5" "$own" 127.0.0.1

c="an older server that does not stop is kept recorded"
outdate; kill -STOP "$oldpid"; launch "$tmp/p5"; kill -CONT "$oldpid"
[ "$rc $out" = "4 preview.sh: pid $oldpid on port $own did not stop; kept the state files" ] && [ "$(pid_of "$tmp/p5")" = "$oldpid" ] || fail "$c: exit $rc, pid file $(pid_of "$tmp/p5"): $out"
for _ in $(seq 30); do kill -0 "$oldpid" 2>/dev/null || break; sleep 0.1; done

c="a server of another docroot with the same relative name is left running"; mkdir -p "$tmp/p6/.dk" "$tmp/p7/.dk"
( cd "$tmp/p6" && exec python3 "$here/serve.py" --docroot .dk --port "$own" >/dev/null 2>&1 ) & theirs=$!; extra="$extra $theirs"
for _ in $(seq 50); do curl -s -o /dev/null --max-time 1 "http://127.0.0.1:$own/" && break; sleep 0.1; done
echo "$theirs" > "$tmp/p7/.dk/.preview.pid"; cd "$tmp/p7"; launch .dk --port "$other"; cd "$OLDPWD"
started="$out"; launch "$tmp/p7/.dk" --stop; kill -0 "$theirs" 2>/dev/null || fail "$c: $started"

# A start counts once its own server has said it is bound. late <seconds> <docroot> [args]: a launch whose python3 begins that much later; during: one left running, its pid file written
mkdir -p "$tmp/late" "$tmp/p8" "$tmp/p9" "$tmp/pa"; echo '<h1>p8</h1>' | tee "$tmp/p9/index.html" "$tmp/pa/index.html" > "$tmp/p8/index.html"
printf '#!/bin/sh\n"%s" "$LATE"\nexec "%s" "$@"\n' "$(command -v sleep)" "$(command -v python3)" > "$tmp/late/python3"; chmod +x "$tmp/late/python3"
late() { local s="$1"; shift; LATE="$s" PATH="$tmp/late:$PATH" launch "$@"; }
during() { local d="$1"; shift; LATE=0.8 PATH="${with:-$tmp/late}:$PATH" bash "$here/preview.sh" --docroot "$d" "$@" > "$tmp/first" 2>&1 & first=$!
  for _ in $(seq 100); do [ -s "$d/.preview.pid" ] && { extra="$extra $(cat "$d/.preview.pid")"; return; }; sleep 0.02; done; fail "$c: no pid file: $(cat "$tmp/first")"; }
servers() { ps -ww -eo args= > "$tmp/ps"; grep -cF "serve.py --docroot $(cd "$1" && pwd -P) --port " "$tmp/ps" || true; }
none() { [ ! -e "$1/.preview.pid" ] && [ ! -e "$1/.preview.ver" ] && [ ! -e "$1/.preview.url" ]; }

c="a late server on a port another project answers is not this docroot's"
late 0.6 "$tmp/p8" --port "$own"
[ "$rc $out" = "4 preview.sh: server did not start (port $own busy?)" ] && none "$tmp/p8" || fail "$c: exit $rc, url $(url_of "$tmp/p8"): $out"
echo "$own" > "$tmp/p8/.preview.port"; want="$(first_free 8124)"; late 0.6 "$tmp/p8"
[ "$rc" = 0 ] && [ "$(url_of "$tmp/p8")" = "http://127.0.0.1:$want/" ] && kill -0 "$(pid_of "$tmp/p8")" || fail "$c: wanted the next free port $want, got exit $rc, url $(url_of "$tmp/p8"): $out"
case "$(curl -sL "http://127.0.0.1:$want/index.html?static=1")" in *"</script><h1>p8</h1>") ;; *) fail "$c: port $want does not serve this docroot" ;; esac
launch "$tmp/p8" --stop
c="a late server on a port that is taken and answers nothing is not this docroot's either"; quiet="$(free_port)"; hold "silent:$quiet"; late 0.6 "$tmp/p8" --port "$quiet"; release
[ "$rc $out" = "4 preview.sh: server did not start (port $quiet busy?)" ] && none "$tmp/p8" || fail "$c: exit $rc, url $(url_of "$tmp/p8"): $out"

c="a port that answers is skipped, though a server would start beside the one there"; mkdir -p "$tmp/beside" "$tmp/pb"; busy="$(free_port)"; hold "$busy"
# a python3 that says it serves and binds nothing stands for the bind that macOS and BSD allow there
printf '#!/bin/sh\necho "design-kit: serving $3 on http://127.0.0.1:$5/"\nexec "%s" 30\n' "$(command -v sleep)" > "$tmp/beside/python3"; chmod +x "$tmp/beside/python3"
beside() { PATH="$tmp/beside:$PATH" launch "$tmp/pb" "$@"; extra="$extra $(pid_of "$tmp/pb")"; }
beside --port "$busy"; [ "$rc $out" = "4 preview.sh: server did not start (port $busy busy?)" ] && none "$tmp/pb" || fail "$c: exit $rc, url $(url_of "$tmp/pb"): $out"
echo "$busy" > "$tmp/pb/.preview.port"; want="$(first_free 8124)"; beside
[ "$rc" = 0 ] && [ "$(url_of "$tmp/pb")" = "http://127.0.0.1:$want/" ] || fail "$c: recorded, wanted the next free port $want, got exit $rc, url $(url_of "$tmp/pb"): $out"
release; echo "$busy" > "$tmp/pb/.preview.port"; beside
[ "$rc" = 0 ] && [ "$(url_of "$tmp/pb")" = "http://127.0.0.1:$busy/" ] || fail "the recorded port is not tried first once nothing answers on it: exit $rc, url $(url_of "$tmp/pb"): $out"

c="a port whose server takes no more connects does not hold a launch"; hung="$(free_port)"; hold "full:$hung"
echo "$hung" > "$tmp/p8/.preview.port"; want="$(first_free 8124)"; s=$SECONDS; launch "$tmp/p8"; s=$(( SECONDS - s )); release
[ "$rc" = 0 ] && [ "$s" -le 20 ] && [ "$out" = "$(printf 'preview: http://127.0.0.1:%s/\npreview: moved from port %s; saved knobs and page data stay on the old address' "$want" "$hung")" ] || fail "$c: after $s s exit $rc: $out"
launch "$tmp/p8" --stop

c="a second launch waits while the first still looks at a port that hangs"; hung="$(free_port)"; hold "full:$hung"; echo "$hung" > "$tmp/p9/.preview.port"
bash "$here/preview.sh" --docroot "$tmp/p9" > "$tmp/first" 2>&1 & first=$!
for _ in $(seq 200); do [ -s "$tmp/p9/.preview.ver" ] && break; sleep 0.02; done; early="$(ver_of "$tmp/p9")"; launch "$tmp/p9"; second="$rc $out"; rc=0; wait "$first" || rc=$?; release
[ "$early" = "- $version starting $first" ] && [ "$rc" = 0 ] && [ "$second" = "0 preview: already running — $(url_of "$tmp/p9")" ] && [ "$(servers "$tmp/p9")" = 1 ] || fail "$c: record $early, $(servers "$tmp/p9") servers; the first: exit $rc, $(cat "$tmp/first"); the second: exit $second"
launch "$tmp/p9" --stop; rm -f "$tmp/p9/.preview.port"

c="--stop waits for a launch that still looks at a port that hangs, then stops its server"; hung="$(free_port)"; hold "full:$hung"; echo "$hung" > "$tmp/p9/.preview.port"; want="$(first_free 8124)"
bash "$here/preview.sh" --docroot "$tmp/p9" > "$tmp/first" 2>&1 & first=$!
for _ in $(seq 200); do [ -s "$tmp/p9/.preview.ver" ] && break; sleep 0.02; done; early="$(ver_of "$tmp/p9")"; launch "$tmp/p9" --stop; second="$rc $out"; rc=0; wait "$first" || rc=$?; release
[ "$early" = "- $version starting $first" ] && [ "$rc $(cat "$tmp/first")" = "$(printf '0 preview: http://127.0.0.1:%s/\npreview: moved from port %s; saved knobs and page data stay on the old address' "$want" "$hung")" ] && [ "$second" = "0 preview: stopped" ] \
  && none "$tmp/p9" && [ "$(servers "$tmp/p9")" = 0 ] || fail "$c: record $early, then $(servers "$tmp/p9") servers, pid file $(pid_of "$tmp/p9"), record $(ver_of "$tmp/p9"); the launch: exit $rc, $(cat "$tmp/first"); --stop: exit $second"
rm -f "$tmp/p9/.preview.port"

for args in "--port $other" ""; do
  c="a second launch takes the server the first one waits for (${args:-its recorded port busy})"
  [ -n "$args" ] || echo "$own" > "$tmp/p9/.preview.port"
  during "$tmp/p9" $args; launch "$tmp/p9"; second="$rc $out"; rc=0; wait "$first" || rc=$?; pid="$(pid_of "$tmp/p9")"
  [ "$rc" = 0 ] && [ "$second" = "0 preview: already running — $(url_of "$tmp/p9")" ] && kill -0 "$pid" && [ "$(ver_of "$tmp/p9")" = "$pid $version" ] && [ "$(servers "$tmp/p9")" = 1 ] \
    || fail "$c: $(servers "$tmp/p9") servers, pid file $pid, record $(ver_of "$tmp/p9"); the first: exit $rc, $(cat "$tmp/first"); the second: exit $second"
  case "$(curl -sL "$(url_of "$tmp/p9")index.html?static=1")" in *"</script><h1>p8</h1>") ;; *) fail "$c: $(url_of "$tmp/p9") does not serve this docroot" ;; esac
  launch "$tmp/p9" --stop; rm -f "$tmp/p9/.preview.port"
done

c="a start whose launcher was killed is replaced, at once"; during "$tmp/pa" --port "$other"
kill -9 "$first"; wait "$first" 2>/dev/null || true; pid="$(pid_of "$tmp/pa")"; s=$SECONDS; launch "$tmp/pa"; s=$(( SECONDS - s ))
[ "$rc" = 0 ] && ! kill -0 "$pid" 2>/dev/null && [ "$(url_of "$tmp/pa")" = "http://127.0.0.1:$other/" ] && [ "$(ver_of "$tmp/pa")" = "$(pid_of "$tmp/pa") $version" ] && [ "$(servers "$tmp/pa")" = 1 ] && [ "$s" -le 4 ] \
  || fail "$c: after $s s exit $rc, $(servers "$tmp/pa") servers, pid file $(pid_of "$tmp/pa") (was $pid), record $(ver_of "$tmp/pa"): $out"
launch "$tmp/pa" --stop

# quick: a sleep that takes no time, for a launch's own waits
c="a second launch that waited 15 s stops nothing"; mkdir -p "$tmp/quick" "$tmp/gate" "$tmp/pc"; printf '#!/bin/sh\n' > "$tmp/quick/sleep"
printf '#!/bin/sh\nwhile [ ! -e "%s" ]; do "%s" 0.05; done\nexec "%s" "$@"\n' "$tmp/go" "$(command -v sleep)" "$(command -v python3)" > "$tmp/gate/python3"; chmod +x "$tmp/quick/sleep" "$tmp/gate/python3"
waited="waited 15 s for another launch (pid PID) that is still starting the server; stopped nothing. Try again; if no such launch runs, --stop clears its record"
with="$tmp/gate" during "$tmp/pc" --port "$other"; PATH="$tmp/quick:$PATH" launch "$tmp/pc"; second="$rc $out"; : > "$tmp/go"; rc=0; wait "$first" || rc=$?; pid="$(pid_of "$tmp/pc")"
[ "$second" = "4 preview.sh: ${waited/PID/$first}" ] && [ "$rc" = 0 ] && kill -0 "$pid" && [ "$(url_of "$tmp/pc")" = "http://127.0.0.1:$other/" ] && [ "$(ver_of "$tmp/pc")" = "$pid $version" ] && [ "$(servers "$tmp/pc")" = 1 ] \
  || fail "$c: $(servers "$tmp/pc") servers, pid file $pid, record $(ver_of "$tmp/pc"); the first: exit $rc, $(cat "$tmp/first"); the second: exit $second"
launch "$tmp/pc" --stop
c="a record whose launcher's pid is another process by now is cleared by --stop"; sleep 30 & decoy=$!; extra="$extra $decoy"; echo "1 $version starting $decoy" > "$tmp/pc/.preview.ver"
PATH="$tmp/quick:$PATH" launch "$tmp/pc"; [ "$rc $out" = "4 preview.sh: ${waited/PID/$decoy}" ] || fail "$c: exit $rc: $out"
PATH="$tmp/quick:$PATH" launch "$tmp/pc" --stop; launch "$tmp/pc"; [ "$rc" = 0 ] && [ "$(ver_of "$tmp/pc")" = "$(pid_of "$tmp/pc") $version" ] || fail "$c: exit $rc, record $(ver_of "$tmp/pc"): $out"
launch "$tmp/pc" --stop

c="a server that does not bind in time is ended"; mkdir -p "$tmp/never"
printf '#!/bin/sh\necho $$ > "%s"\nexec "%s" 30\n' "$tmp/hung" "$(command -v sleep)" > "$tmp/never/python3"; chmod +x "$tmp/never/python3"
PATH="$tmp/quick:$tmp/never:$PATH" launch "$tmp/pa"; pid="$(cat "$tmp/hung")"; extra="$extra $pid"
[ "$rc $out" = "4 preview.sh: the server did not bind port $other in 10 s; ended it" ] && none "$tmp/pa" || fail "$c: exit $rc, pid file $(pid_of "$tmp/pa"): $out"
for _ in $(seq 30); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done; ! kill -0 "$pid" 2>/dev/null || fail "$c: it still runs"

# The order, with a python3 that only records the port it was given and dies: nothing is bound, 8123 and the whole default range included.
mkdir -p "$tmp/fake"; printf '#!/bin/sh\necho "$5" >> "%s"\nexit 1\n' "$tmp/tried" > "$tmp/fake/python3"
printf '#!/bin/sh\nwhile kill -0 "$(cat "%s" 2>/dev/null)" 2>/dev/null; do :; done\n' "$tmp/p4/.preview.pid" > "$tmp/fake/sleep"; chmod +x "$tmp/fake/python3" "$tmp/fake/sleep"
# order <recorded> <ports> <last>: what a start with no port tries, less the ports something on this machine answers on, and the message when all of it fails
taken=" $(python3 -c 'import socket, sys
for p in sys.argv[1:]:
    with socket.socket() as s:
        if s.connect_ex(("127.0.0.1", int(p))) == 0: print(p, end=" ")' 1024 9000 65535 $(seq 8124 8139))"
order() { local got want="" p; for p in $2; do case "$taken" in *" $p "*) ;; *) want="$want$p " ;; esac; done; : > "$tmp/tried"; printf '%s\n' "$1" > "$tmp/p4/.preview.port"; PATH="$tmp/fake:$PATH" launch "$tmp/p4"; got="$(tr '\n' ' ' < "$tmp/tried")"
  [ "$got$rc $out" = "${want}4 preview.sh: no free port from 8124 to $3" ] || fail "candidate ports with ${1:-nothing} recorded: tried $got, exit $rc: $out; wanted $want up to $3"; }
export DESIGN_KIT_PORT_LAST=8126
for r in "" abc 8124x 08126 8123 1023 65536 99999999999999999999; do order "$r" "8124 8125 8126" 8126; done
for r in 1024 9000 65535; do order "$r" "$r 8124 8125 8126" 8126; done
order 8125 "8125 8124 8126" 8126
DESIGN_KIT_PORT_LAST=8000 order "" 8124 8000
all="8124 8125 8126 8127 8128 8129 8130 8131 8132 8133 8134 8135 8136 8137 8138 8139"
DESIGN_KIT_PORT_LAST=abc order "" "$all" 8139; unset DESIGN_KIT_PORT_LAST; order "" "$all" 8139
echo "PASS preview.test.sh"
