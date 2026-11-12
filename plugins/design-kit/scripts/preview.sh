#!/usr/bin/env bash
# preview.sh [--lan|--stop] [--port N] [--docroot DIR] — starts serve.py on DIR (default ./.design-kit) at 127.0.0.1:N (default 8124; 8123 is taskmaster's) once, writing DIR/.preview.{pid,url,bind}; a second start reuses it; --stop ends it and deletes those files and DIR/.preview.key.
# --lan binds 0.0.0.0 (restarting a loopback server) and prints the URL with the ?key= another device needs; a plain start over a LAN server says LAN mode is still on. serve.py ends itself (DESIGN_KIT_LAN_MINUTES, DESIGN_KIT_IDLE_MINUTES) and leaves the files for the next start to replace.
# Misses: serve.py's own output is discarded; the LAN host is a guess (en0, else hostname -I's first); a recycled pid in a stale file reads as running. Harness: scripts/__tests__/preview.test.sh.
# Why, limits, history: rationale/derivations/plugin-design-kit.md § plugins/design-kit/scripts/preview.sh
set -euo pipefail

docroot=".design-kit"; port="${DESIGN_KIT_PORT:-8124}"; bind="127.0.0.1"; stop=0
while [ $# -gt 0 ]; do
  case "$1" in
    --stop) stop=1 ;;
    --lan) bind="0.0.0.0" ;;
    --port) port="$2"; shift ;;
    --docroot) docroot="$2"; shift ;;
    -h|--help) sed -n '2,4p' "$0"; exit 0 ;;
    *) echo "preview.sh: unknown argument $1" >&2; exit 2 ;;
  esac
  shift
done

pidfile="$docroot/.preview.pid"; urlfile="$docroot/.preview.url"; bindfile="$docroot/.preview.bind"; keyfile="$docroot/.preview.key"
if [ "$stop" = 1 ]; then
  if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
    kill "$(cat "$pidfile")" && rm -f "$pidfile" "$urlfile" "$bindfile" "$keyfile" && echo "preview: stopped"
  else
    rm -f "$pidfile" "$urlfile" "$bindfile" "$keyfile"; echo "preview: nothing running"
  fi
  exit 0
fi
keyq() { if [ -s "$keyfile" ]; then printf '?key=%s' "$(cat "$keyfile")"; fi; }

command -v python3 >/dev/null || { echo "preview.sh: python3 3.8+ is required (or open the .html files directly)" >&2; exit 3; }
mkdir -p "$docroot"
if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
  running="$(cat "$bindfile" 2>/dev/null || echo 127.0.0.1)"
  if [ "$bind" = "0.0.0.0" ] && [ "$running" != "0.0.0.0" ]; then
    kill "$(cat "$pidfile")" 2>/dev/null || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 "$(cat "$pidfile")" 2>/dev/null || break; sleep 0.1; done
    rm -f "$pidfile" "$urlfile" "$bindfile"
  else
    q=""; [ "$running" = "0.0.0.0" ] && q="$(keyq)"
    echo "preview: already running — $(cat "$urlfile" 2>/dev/null || echo "http://127.0.0.1:$port/")$q"
    if [ "$running" = "0.0.0.0" ] && [ "$bind" != "0.0.0.0" ]; then echo "preview: LAN mode is still on — any device on this network with the keyed URL can open it; end it with --stop"; fi
    exit 0
  fi
fi
here="$(cd "$(dirname "$0")" && pwd)"
lan_flag=""; [ "$bind" = "0.0.0.0" ] && lan_flag="--lan"
( exec python3 "$here/serve.py" --docroot "$docroot" --port "$port" $lan_flag >/dev/null 2>&1 ) &
echo $! > "$pidfile"
sleep 0.3
kill -0 "$(cat "$pidfile")" 2>/dev/null || { rm -f "$pidfile"; echo "preview.sh: server did not start (port $port busy?)" >&2; exit 4; }
host="127.0.0.1"; [ "$bind" = "0.0.0.0" ] && host="$(ipconfig getifaddr en0 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}' || echo 127.0.0.1)"
q=""
if [ "$bind" = "0.0.0.0" ]; then
  for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$keyfile" ] && break; sleep 0.1; done
  q="$(keyq)"; [ -n "$q" ] || echo "preview.sh: the LAN server wrote no $keyfile; other devices will get 403" >&2
fi
echo "http://$host:$port/" > "$urlfile"; echo "$bind" > "$bindfile"
echo "preview: http://$host:$port/$q"
[ "$bind" = "0.0.0.0" ] && echo "preview: LAN mode — any device on this network with this keyed URL can open it while the server runs; a pick made from another device is not recorded (loopback only)"
exit 0
