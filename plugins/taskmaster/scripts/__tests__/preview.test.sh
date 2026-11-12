#!/usr/bin/env bash
# Drives scripts/preview.sh: start serves the docroot and records pid/URL, a second start reuses it, --lan over a loopback server is refused, --stop ends only a pid that is serve.py on this docroot, a busy port fails cleanly.
# Misses: exit 3 (python3 absent) is not exercised; the LAN half needs a non-loopback address and skips without one.
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
extra=""
cleanup() {
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
case "$(cat "$D/.preview.url")" in *"?key=$key") ok ;; *) bad "--lan .preview.url" "$(cat "$D/.preview.url")" ;; esac
[ "$(mode "$D/.preview.url")" = 0o600 ] && ok || bad "--lan .preview.url mode" "$(mode "$D/.preview.url")"
lanpid="$(cat "$D/.preview.pid")"
out="$(bash "$P" --docroot "$D" --port "$port")"
case "$out" in *"already running"*"?key=$key"*"LAN mode is still on"*) ok ;; *) bad "plain start over LAN" "$out" ;; esac
for _ in $(seq 1 80); do kill -0 "$lanpid" 2>/dev/null || break; sleep 0.1; done
kill -0 "$lanpid" 2>/dev/null && bad "LAN limit" "the LAN server outlived PREVIEW_LAN_MINUTES=0.05" || ok
out="$(bash "$P" --docroot "$D" --port "$port")"
case "$out" in *"preview: http://127.0.0.1:$port/"*) ok ;; *) bad "start after LAN expiry" "$out" ;; esac
bash "$P" --docroot "$D" --stop >/dev/null

# ---- bad arguments -------------------------------------------------------------
bash "$P" --port abc >/dev/null 2>&1; rc=$?
[ "$rc" = 2 ] && ok || bad "bad --port" "want 2, got $rc"
bash "$P" --bogus >/dev/null 2>&1; rc=$?
[ "$rc" = 2 ] && ok || bad "unknown argument" "want 2, got $rc"

echo "preview.sh tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
