#!/usr/bin/env bash
# preview.sh [--lan|--stop] [--port N] [--docroot DIR] — starts serve.py on DIR (default ./.design-kit) at 127.0.0.1:N (default 8124; 8123 is taskmaster's) once, writing DIR/.preview.{pid,url,bind}; a second start reuses it; --stop ends it, only when the recorded pid is serve.py on DIR, and deletes those files and DIR/.preview.key.
# --lan binds 0.0.0.0 (restarting a loopback server) and prints the URL with the ?key= another device needs; a plain start over a LAN server says LAN mode is still on. serve.py ends itself (DESIGN_KIT_LAN_MINUTES, DESIGN_KIT_IDLE_MINUTES) and removes the pid, url and bind files that still name it. Exit 6: the recorded pid is alive and neither ps nor /proc names it; nothing signalled or removed.
# Misses: serve.py's own output is discarded; the LAN host is a guess (en0, else hostname -I's first); two starts at once are not locked (taskmaster's launcher is), so both may launch and one fail on the port. Harness: scripts/__tests__/preview.test.sh.
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
# ours <pid>: 0 = serve.py on this docroot (sets running_args), 1 = dead or another process, 6 = alive and unnamed.
ours() {
  case "$1" in '' | *[!0-9]*) return 1 ;; esac
  kill -0 "$1" 2>/dev/null || return 1
  running_args="$(ps -ww -p "$1" -o args= 2>/dev/null)" || running_args=""
  [ -n "$running_args" ] || running_args="$(tr '\0' ' ' < "/proc/$1/cmdline" 2>/dev/null)" || running_args=""
  [ -n "$running_args" ] || { kill -0 "$1" 2>/dev/null && return 6; return 1; }
  case "$running_args" in *serve.py" --docroot $abs --port "* | *serve.py" --docroot $docroot --port "*) return 0 ;; esac
  # A launcher before 0.14.0 passed the docroot as typed: resolve a relative one against that process's own directory.
  case "$running_args" in *serve.py" --docroot "*)
    local other="${running_args#*serve.py --docroot }" cwd; other="${other% --port *}"
    case "$other" in /*) return 1 ;; esac
    cwd="$(readlink "/proc/$1/cwd" 2>/dev/null)" || cwd=""
    [ -n "$cwd" ] || return 6
    [ "$(cd "$cwd" 2>/dev/null && cd "$other" 2>/dev/null && pwd -P)" = "$abs" ] && return 0 ;;
  esac
  return 1
}
unnamed() { echo "preview.sh: pid $1 in $pidfile is alive and neither ps nor /proc says what it is; signalled nothing, kept the state files — check it, then delete $pidfile" >&2; exit 6; }
if [ "$stop" = 1 ]; then
  [ -d "$docroot" ] || { echo "preview: nothing running"; exit 0; }
  abs="$(cd "$docroot" && pwd -P)"; pid="$(cat "$pidfile" 2>/dev/null || true)"
  rc=0; ours "$pid" || rc=$?
  [ "$rc" = 6 ] && unnamed "$pid"
  if [ "$rc" = 0 ]; then
    kill "$pid" 2>/dev/null || true
    for _ in $(seq 30); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
    rm -f "$pidfile" "$urlfile" "$bindfile" "$keyfile"; echo "preview: stopped"
  else
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then echo "preview: pid $pid is not serve.py on $abs; left it running, removed the stale state"; fi
    rm -f "$pidfile" "$urlfile" "$bindfile" "$keyfile"; echo "preview: nothing running"
  fi
  exit 0
fi
keyq() { if [ -s "$keyfile" ]; then printf '?key=%s' "$(cat "$keyfile")"; fi; }

command -v python3 >/dev/null || { echo "preview.sh: python3 3.8+ is required (or open the .html files directly)" >&2; exit 3; }
mkdir -p "$docroot"
abs="$(cd "$docroot" && pwd -P)"; pid="$(cat "$pidfile" 2>/dev/null || true)"
rc=0; ours "$pid" || rc=$?
[ "$rc" = 6 ] && unnamed "$pid"
if [ "$rc" = 0 ]; then
  running="$(cat "$bindfile" 2>/dev/null || echo 127.0.0.1)"
  if [ "$bind" = "0.0.0.0" ] && [ "$running" != "0.0.0.0" ]; then
    kill "$pid" 2>/dev/null || true
    for _ in $(seq 30); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
    rm -f "$pidfile" "$urlfile" "$bindfile"
  else
    q=""; [ "$running" = "0.0.0.0" ] && q="$(keyq)"
    echo "preview: already running — $(cat "$urlfile" 2>/dev/null || echo "http://127.0.0.1:$port/")$q"
    if [ "$running" = "0.0.0.0" ] && [ "$bind" != "0.0.0.0" ]; then echo "preview: LAN mode is still on — any device on this network with the keyed URL can open it; end it with --stop"; fi
    exit 0
  fi
else
  rm -f "$pidfile" "$urlfile" "$bindfile"
fi
here="$(cd "$(dirname "$0")" && pwd)"
lan_flag=""; [ "$bind" = "0.0.0.0" ] && lan_flag="--lan"
( exec python3 "$here/serve.py" --docroot "$abs" --port "$port" $lan_flag >/dev/null 2>&1 ) &
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
