#!/usr/bin/env bash
# Drives scripts/preview.sh: start serves the docroot and records pid/URL, a second start reuses it, --lan over a loopback server is refused, --stop ends only a pid that is serve.py on this docroot, a busy port fails cleanly, two starts at once leave one server, a live pid nothing can name is exit 6, --lan relays the loopback URL, a running server reporting a lower version, none, or nothing is replaced on its own port with its own --lan (exit 4, state kept, when it will not exit), the same version is reused, a newer one is left running with a warning.
# Misses: exit 3 (python3 absent) is not exercised; the LAN half needs a non-loopback address and skips without one; the other-version servers are this serve.py with one line changed by sed, not a released older copy; a restart whose new server fails to start is not exercised.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
P="$here/../preview.sh"
pass=0; fail=0
ok() { pass=$((pass+1)); }
bad() { echo "FAIL $1: $2"; fail=$((fail+1)); }

if ! command -v python3 >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
  echo "SKIP: python3 or curl not found"
  echo "preview.sh tests: 0 passed, 0 failed"
  exit 0
fi

T="$(mktemp -d)"
D="$T/mockups"
extra=""; frozen=""
cleanup() {
  [ -n "$frozen" ] && kill -CONT "$frozen" 2>/dev/null
  bash "$P" --docroot "$D" --stop >/dev/null 2>&1
  for p in $extra; do kill "$p" 2>/dev/null; done
  for p in $extra; do wait "$p" 2>/dev/null; done
  rm -rf "$T"
}
trap cleanup EXIT

free_port() { python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()'; }
up() { curl -s -o /dev/null --max-time 2 "http://127.0.0.1:$1/" ; }
mode() { python3 -c 'import os,sys;print(oct(os.stat(sys.argv[1]).st_mode & 0o777))' "$1"; }

port="$(free_port)"
mkdir -p "$D"; printf '<!doctype html><p>PAGE-OK</p>\n' > "$D/current.html"

# ---- start ------------------------------------------------------------------
out="$(bash "$P" --docroot "$D" --port "$port")"; rc=$?
[ "$rc" = 0 ] && ok || bad "start exit" "want 0, got $rc: $out"
case "$out" in *"preview: http://127.0.0.1:$port/"*) ok ;; *) bad "start output" "$out" ;; esac
case "$out" in *"preview: Idle shutdown: after 240 minutes"*) ok ;; *) bad "idle notice relayed" "$out" ;; esac
body="$(curl -s --max-time 3 "http://127.0.0.1:$port/current.html")"
case "$body" in *PAGE-OK*) ok ;; *) bad "served body" "$body" ;; esac
[ "$(cat "$D/.preview.url" 2>/dev/null)" = "http://127.0.0.1:$port/" ] && ok || bad ".preview.url" "$(cat "$D/.preview.url" 2>&1)"
pid1="$(cat "$D/.preview.pid" 2>/dev/null)"
[ -n "$pid1" ] && kill -0 "$pid1" 2>/dev/null && ok || bad ".preview.pid" "no live pid recorded"
for f in .preview.pid .preview.url .preview.log; do
  c="$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "http://127.0.0.1:$port/$f")"
  [ "$c" = 404 ] && ok || bad "state file $f over HTTP" "want 404, got $c"
  [ "$(mode "$D/$f")" = 0o600 ] && ok || bad "state file $f mode" "want 0o600, got $(mode "$D/$f")"
done

# ---- idempotent second start -------------------------------------------------
out="$(bash "$P" --docroot "$D" --port "$port")"; rc=$?
[ "$rc" = 0 ] && ok || bad "second start exit" "want 0, got $rc"
case "$out" in *"already running — http://127.0.0.1:$port/"*) ok ;; *) bad "second start output" "$out" ;; esac
[ "$(cat "$D/.preview.pid")" = "$pid1" ] && ok || bad "second start pid" "pid file changed"
n="$(pgrep -f "serve.py --docroot $(cd "$D" && pwd -P) --port" | wc -l | tr -d ' ')"
[ "$n" = 1 ] && ok || bad "second start process count" "want 1 serve.py on this docroot, got $n"

# ---- --lan over a loopback server is refused, server untouched ---------------
out="$(bash "$P" --docroot "$D" --port "$port" --lan 2>&1)"; rc=$?
[ "$rc" = 5 ] && ok || bad "--lan over loopback exit" "want 5, got $rc: $out"
kill -0 "$pid1" 2>/dev/null && ok || bad "--lan over loopback" "the running server was killed"

# ---- stop ------------------------------------------------------------------
out="$(bash "$P" --docroot "$D" --stop)"; rc=$?
[ "$rc" = 0 ] && ok || bad "stop exit" "want 0, got $rc"
case "$out" in *"preview: stopped"*) ok ;; *) bad "stop output" "$out" ;; esac
kill -0 "$pid1" 2>/dev/null && bad "stop" "pid $pid1 still alive" || ok
up "$port" && bad "stop" "port $port still answers" || ok
[ -e "$D/.preview.pid" ] || [ -e "$D/.preview.url" ] && bad "stop state" "pid or url file left behind" || ok
out="$(bash "$P" --docroot "$D" --stop)"; rc=$?
[ "$rc" = 0 ] && case "$out" in *"nothing running"*) true ;; *) false ;; esac && ok || bad "second stop" "rc=$rc: $out"

# ---- a recorded pid that is not this server is never killed ----------------
sleep 30 & decoy=$!; extra="$extra $decoy"
echo "$decoy" > "$D/.preview.pid"
out="$(bash "$P" --docroot "$D" --stop)"
kill -0 "$decoy" 2>/dev/null && ok || bad "foreign pid" "--stop killed a process that is not serve.py"
case "$out" in *"not serve.py"*) ok ;; *) bad "foreign pid output" "$out" ;; esac
echo "$decoy" > "$D/.preview.pid"
out="$(bash "$P" --docroot "$D" --port "$port")"
case "$out" in *"preview: http://127.0.0.1:$port/"*) ok ;; *) bad "start over a foreign pid" "$out" ;; esac
kill -0 "$decoy" 2>/dev/null && ok || bad "start over a foreign pid" "the decoy was killed"
bash "$P" --docroot "$D" --stop >/dev/null

# ---- a busy port fails cleanly, and a previous run's log line is never taken for readiness ----
printf 'Serving %s at http://127.0.0.1:1/  (SSE: GET /events)\n' "$D" > "$D/.preview.log"
busy="$(free_port)"
python3 -c 'import socket,sys,time
s=socket.socket(); s.bind(("127.0.0.1",int(sys.argv[1]))); s.listen(1); print("up",flush=True); time.sleep(30)' "$busy" > "$T/busy" 2>/dev/null &
extra="$extra $!"
for _ in $(seq 1 30); do grep -q up "$T/busy" && break; sleep 0.1; done
out="$(bash "$P" --docroot "$D" --port "$busy" 2>&1)"; rc=$?
[ "$rc" = 4 ] && ok || bad "busy port exit" "want 4, got $rc: $out"
[ -e "$D/.preview.pid" ] && bad "busy port state" "pid file left behind" || ok

# ---- LAN: keyed URL, reuse says LAN is on, the time limit ends it -------------
out="$(PREVIEW_LAN_MINUTES=0.05 bash "$P" --docroot "$D" --port "$port" --lan)"; rc=$?
key="$(tr -d '\n' < "$D/.preview.key" 2>/dev/null)"
[ "$rc" = 0 ] && [ -n "$key" ] && ok || bad "--lan start" "rc=$rc, key file empty or missing: $out"
case "$out" in *"preview: http://"*":$port/?key=$key"*) ok ;; *) bad "--lan URL" "$out" ;; esac
case "$out" in *"preview: LAN mode:"*"0.05 minutes"*) ok ;; *) bad "--lan notice" "$out" ;; esac
case "$out" in *"preview: On this machine: http://127.0.0.1:$port/ "*) ok ;; *) bad "--lan loopback URL" "$out" ;; esac
case "$(cat "$D/.preview.url")" in *"?key=$key") ok ;; *) bad "--lan .preview.url" "$(cat "$D/.preview.url")" ;; esac
[ "$(mode "$D/.preview.url")" = 0o600 ] && ok || bad "--lan .preview.url mode" "$(mode "$D/.preview.url")"
lanpid="$(cat "$D/.preview.pid")"
out="$(bash "$P" --docroot "$D" --port "$port")"
case "$out" in *"already running"*"?key=$key"*"LAN mode is still on"*) ok ;; *) bad "plain start over LAN" "$out" ;; esac
case "$out" in *"preview: On this machine: http://127.0.0.1:$port/ "*) ok ;; *) bad "plain start over LAN: loopback URL" "$out" ;; esac
for _ in $(seq 1 80); do kill -0 "$lanpid" 2>/dev/null || break; sleep 0.1; done
kill -0 "$lanpid" 2>/dev/null && bad "LAN limit" "the LAN server outlived PREVIEW_LAN_MINUTES=0.05" || ok
out="$(bash "$P" --docroot "$D" --port "$port")"
case "$out" in *"preview: http://127.0.0.1:$port/"*) ok ;; *) bad "start after LAN expiry" "$out" ;; esac
bash "$P" --docroot "$D" --stop >/dev/null

# ---- two starts at once: one server, one URL, and --stop still ends it ----------
D2="$T/race"; mkdir -p "$D2"; printf '<!doctype html><p>RACE</p>\n' > "$D2/current.html"
abs2="$(cd "$D2" && pwd -P)"
# race <port>: two starts at once on one port; sets c1 and c2.
race() {
  bash "$P" --docroot "$D2" --port "$1" > "$T/race1" 2>&1 & r1=$!
  bash "$P" --docroot "$D2" --port "$1" > "$T/race2" 2>&1 & r2=$!
  wait "$r1"; c1=$?; wait "$r2"; c2=$?
}
race_diag() { printf 'starter 1: %s | starter 2: %s | .preview.log: %s' "$(cat "$T/race1")" "$(cat "$T/race2")" "$(cat "$D2/.preview.log" 2>/dev/null)"; }
for round in 1 2 3; do
  rport="$(free_port)"; race "$rport"
  # free_port closes its probe before serve.py binds, so another process can take the port in between; both
  # starters then fail on it. That is the harness's port, not the launcher: redo the round once on a new port.
  if [ "$c1" != 0 ] && [ "$c2" != 0 ] && grep -q unavailable "$T/race1" && grep -q unavailable "$T/race2"; then
    echo "NOTE race $round: port $rport was taken before serve.py bound it; redoing the round on a new port"
    rport="$(free_port)"; race "$rport"
  fi
  [ "$c1" = 0 ] && [ "$c2" = 0 ] && ok || bad "race $round exit" "want 0 and 0, got $c1 and $c2: $(race_diag)"
  u1="$(grep -o "http://127.0.0.1:$rport/" "$T/race1" | head -n 1)"; u2="$(grep -o "http://127.0.0.1:$rport/" "$T/race2" | head -n 1)"
  [ -n "$u1" ] && [ "$u1" = "$u2" ] && ok || bad "race $round URL" "both starts must print the URL: $(cat "$T/race1") | $(cat "$T/race2")"
  n="$(pgrep -f "serve.py --docroot $abs2 --port" | wc -l | tr -d ' ')"
  [ "$n" = 1 ] && ok || bad "race $round servers" "want 1 serve.py on the docroot, got $n: $(race_diag)"
  out="$(bash "$P" --docroot "$D2" --stop)"
  case "$out" in *"preview: stopped"*) ok ;; *) bad "race $round stop" "$out" ;; esac
  n="$(pgrep -f "serve.py --docroot $abs2 --port" | wc -l | tr -d ' ')"
  [ "$n" = 0 ] && ok || { bad "race $round stop" "$n serve.py left on the docroot"; pkill -f "serve.py --docroot $abs2 --port"; }
  [ -e "$D2/.preview.lock" ] && bad "race $round lock" ".preview.lock left behind" || ok
done

# ---- no usable ps: /proc names the server; a live pid nothing can name is exit 6, its pid file kept ----
mkdir -p "$T/bin"; printf '#!/bin/sh\nexit 1\n' > "$T/bin/ps"; chmod +x "$T/bin/ps"
if [ -r /proc/self/cmdline ]; then
  bash "$P" --docroot "$D" --port "$port" >/dev/null
  pidp="$(cat "$D/.preview.pid")"
  out="$(PATH="$T/bin:$PATH" bash "$P" --docroot "$D" --port "$port" 2>&1)"; rc=$?
  [ "$rc" = 0 ] && case "$out" in *"already running"*) true ;; *) false ;; esac && ok || bad "no ps: live server" "rc=$rc: $out"
  [ "$(cat "$D/.preview.pid" 2>/dev/null)" = "$pidp" ] && ok || bad "no ps: pid file" "the live server's pid file was removed or replaced"
  bash "$P" --docroot "$D" --stop >/dev/null
else echo "SKIP: no /proc — the ps-less identification is not exercised"; fi
python3 -c 'import os,time
pid=os.fork()
if pid==0: os._exit(0)
print(pid,flush=True); time.sleep(30)' > "$T/zpid" & extra="$extra $!"
for _ in $(seq 1 30); do [ -s "$T/zpid" ] && break; sleep 0.1; done
zpid="$(cat "$T/zpid")"
for args in "--stop" "--port $port"; do
  echo "$zpid" > "$D/.preview.pid"
  PATH="$T/bin:$PATH" bash "$P" --docroot "$D" $args >/dev/null 2>&1; rc=$?
  [ "$rc" = 6 ] && [ "$(cat "$D/.preview.pid" 2>/dev/null)" = "$zpid" ] && ok || bad "unnamed live pid ($args)" "want exit 6 and the pid file kept, got $rc and $(cat "$D/.preview.pid" 2>/dev/null)"
done
rm -f "$D/.preview.pid"

# ---- a server of another version: older, numberless or silent is replaced on its port with its options, same is reused, newer is left ----
# plugin_copy <name> <sed script>: this launcher beside a serve.py changed by the sed script, laid out as preview.sh expects.
plugin_copy() {
  mkdir -p "$T/$1/scripts" "$T/$1/skills/visual-decisions/assets"
  cp "$P" "$T/$1/scripts/preview.sh"
  sed "$2" "$here/../../skills/visual-decisions/assets/serve.py" > "$T/$1/skills/visual-decisions/assets/serve.py"
}
# number <port>: the "server" value that port's feedback list route answers with; None when it gives none.
number() { curl -s --max-time 3 "http://127.0.0.1:$1/_feedback?page=" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("server"))' 2>/dev/null; }
args_of() { ps -ww -p "$1" -o args= 2>/dev/null; }
recorded() { cat "$D/.preview.pid" 2>/dev/null; }
absd="$(cd "$D" && pwd -P)"
servers() { pgrep -f "serve.py --docroot $absd --port" | wc -l | tr -d ' '; }
other="$(free_port)"

plugin_copy numberless 's/, "server": SERVER_VERSION//'
PREVIEW_LAN_MINUTES=2 bash "$T/numberless/scripts/preview.sh" --docroot "$D" --port "$port" --lan >/dev/null
oldpid="$(recorded)"; key="$(tr -d '\n' < "$D/.preview.key" 2>/dev/null)"
[ "$(number "$port")" = None ] && ok || bad "fixture: a server from before the number" "want no server field from port $port, got $(number "$port")"
out="$(PREVIEW_LAN_MINUTES=2 bash "$P" --docroot "$D" --port "$other" 2>&1)"; rc=$?
newpid="$(recorded)"
[ "$rc" = 0 ] && [ -n "$newpid" ] && [ "$newpid" != "$oldpid" ] && ! kill -0 "$oldpid" 2>/dev/null && ok \
  || bad "older server restarted on the same port" "want exit 0 and a new server in place of pid $oldpid, got $rc and pid $newpid: $out"
case "$out" in *"preview: http://"*":$port/?key=$key"*) ok ;; *) bad "older server restarted on the same port: URL" "want port $port and the key it had, got: $out" ;; esac
case "$(args_of "$newpid")" in *" --port $port --lan"*) ok ;; *) bad "older server restarted on the same port: options" "want --port $port --lan, got: $(args_of "$newpid")" ;; esac
mine="$(number "$port")"
case "$mine" in '' | *[!0-9]*) bad "older server restarted on the same port: version" "the server now on port $port reports $mine"; mine=1 ;; *) ok ;; esac
up "$other" && bad "older server restarted on the same port: caller's --port" "a server answers on port $other" || ok
[ "$(servers)" = 1 ] && ok || bad "older server restarted on the same port: servers" "want 1 serve.py on the docroot, got $(servers)"

out="$(bash "$P" --docroot "$D" --port "$other" 2>&1)"; rc=$?
[ "$rc" = 0 ] && [ "$(recorded)" = "$newpid" ] && kill -0 "$newpid" 2>/dev/null \
  && case "$out" in *"may be refused"*) false ;; *"already running — http://"*":$port/?key=$key"*) true ;; *) false ;; esac && ok \
  || bad "same version reused" "want exit 0, pid $newpid kept and only the already-running lines, got $rc and pid $(recorded): $out"
bash "$P" --docroot "$D" --stop >/dev/null

bash "$P" --docroot "$D" --port "$port" >/dev/null
lowpid="$(recorded)"
plugin_copy next "s/^SERVER_VERSION = .*/SERVER_VERSION = $((mine + 1))/"
out="$(bash "$T/next/scripts/preview.sh" --docroot "$D" --port "$other" --lan 2>&1)"; rc=$?
[ "$rc" = 5 ] && [ "$(recorded)" = "$lowpid" ] && kill -0 "$lowpid" 2>/dev/null && ok \
  || bad "--lan over an older loopback server" "want exit 5 and pid $lowpid left running, got $rc and pid $(recorded): $out"
out="$(bash "$T/next/scripts/preview.sh" --docroot "$D" --port "$other" 2>&1)"; rc=$?
nextpid="$(recorded)"
[ "$rc" = 0 ] && [ "$(number "$port")" = "$((mine + 1))" ] && ! kill -0 "$lowpid" 2>/dev/null && ok \
  || bad "lower number restarted" "want exit 0 and port $port answering as $((mine + 1)), got $rc and $(number "$port"): $out"
case "$(args_of "$nextpid")" in *" --lan"*) bad "loopback server restarted loopback-only" "got: $(args_of "$nextpid")" ;; *" --port $port"*) ok ;; *) bad "loopback server restarted loopback-only" "want --port $port, got: $(args_of "$nextpid")" ;; esac

out="$(bash "$P" --docroot "$D" --port "$other" 2>&1)"; rc=$?
[ "$rc" = 0 ] && [ "$(recorded)" = "$nextpid" ] && [ "$(number "$port")" = "$((mine + 1))" ] && [ "$(servers)" = 1 ] && ok \
  || bad "newer server left running" "want exit 0 and pid $nextpid still answering as $((mine + 1)), got $rc, pid $(recorded), $(number "$port"), $(servers) server(s): $out"
case "$out" in *"already running — http://127.0.0.1:$port/"*"may be refused"*) ok ;; *) bad "newer server left running: output" "want the URL and a line saying controls may be refused, got: $out" ;; esac

# a stopped process answers nothing and outlives the stop signal: it is treated as older, and its pid and URL files stay for the next call
frozen="$nextpid"; kill -STOP "$frozen" 2>/dev/null
out="$(bash "$P" --docroot "$D" --port "$other" 2>&1)"; rc=$?
[ "$rc" = 4 ] && [ "$(recorded)" = "$nextpid" ] && [ -s "$D/.preview.url" ] && ok \
  || bad "silent server that outlives its stop" "want exit 4 with the pid and URL files kept, got $rc and pid $(recorded): $out"
kill -CONT "$frozen" 2>/dev/null; frozen=""
bash "$P" --docroot "$D" --stop >/dev/null

# ---- bad arguments -------------------------------------------------------------
bash "$P" --port abc >/dev/null 2>&1; rc=$?
[ "$rc" = 2 ] && ok || bad "bad --port" "want 2, got $rc"
bash "$P" --bogus >/dev/null 2>&1; rc=$?
[ "$rc" = 2 ] && ok || bad "unknown argument" "want 2, got $rc"

echo "preview.sh tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
