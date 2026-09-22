#!/usr/bin/env bash
# preview.sh — launcher for serve.py, design-kit's own preview server.
#
# WHAT IT DOES. Starts serve.py (gallery at /, SSE live reload at /_events,
# /_index.json listing) on <docroot> (default ./.design-kit) at 127.0.0.1:<port>
# (default 8124 — 8123 is the taskmaster/ui-ux mockup server, reserved), records
# the PID in <docroot>/.preview.pid and the URL in <docroot>/.preview.url (dk.sh
# reads it — no script assembles a URL from a literal port), prints the URL.
# `--stop` kills that PID. `--lan` binds 0.0.0.0 so a phone on the same network can
# open it — that is the only path here that lets a page leave the machine, and the
# command using it says so first; a pick made on that phone is not recorded (the
# decision route is loopback-only). Standing: scripts/__tests__/preview.test.sh
# drives start, idempotent restart, a served body, the URL file, and stop; nothing
# proves a browser rendered.
set -euo pipefail

docroot=".design-kit"; port="${DESIGN_KIT_PORT:-8124}"; bind="127.0.0.1"; stop=0
while [ $# -gt 0 ]; do
  case "$1" in
    --stop) stop=1 ;;
    --lan) bind="0.0.0.0" ;;
    --port) port="$2"; shift ;;
    --docroot) docroot="$2"; shift ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "preview.sh: unknown argument $1" >&2; exit 2 ;;
  esac
  shift
done

pidfile="$docroot/.preview.pid"; urlfile="$docroot/.preview.url"
if [ "$stop" = 1 ]; then
  if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
    kill "$(cat "$pidfile")" && rm -f "$pidfile" "$urlfile" && echo "preview: stopped"
  else
    rm -f "$pidfile" "$urlfile"; echo "preview: nothing running"
  fi
  exit 0
fi

command -v python3 >/dev/null || { echo "preview.sh: python3 3.8+ is required (or open the .html files directly)" >&2; exit 3; }
mkdir -p "$docroot"
if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
  echo "preview: already running — $(cat "$urlfile" 2>/dev/null || echo "http://127.0.0.1:$port/")"; exit 0
fi
here="$(cd "$(dirname "$0")" && pwd)"
lan_flag=""; [ "$bind" = "0.0.0.0" ] && lan_flag="--lan"
( exec python3 "$here/serve.py" --docroot "$docroot" --port "$port" $lan_flag >/dev/null 2>&1 ) &
echo $! > "$pidfile"
sleep 0.3
kill -0 "$(cat "$pidfile")" 2>/dev/null || { rm -f "$pidfile"; echo "preview.sh: server did not start (port $port busy?)" >&2; exit 4; }
host="127.0.0.1"; [ "$bind" = "0.0.0.0" ] && host="$(ipconfig getifaddr en0 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}' || echo 127.0.0.1)"
echo "http://$host:$port/" > "$urlfile"
echo "preview: http://$host:$port/"
[ "$bind" = "0.0.0.0" ] && echo "preview: LAN mode — any device on this network can open it while the server runs; a pick made from another device is not recorded (loopback only)"
exit 0
