#!/usr/bin/env bash
# preview.sh [--lan|--stop] [--port N] [--docroot DIR] — starts serve.py on DIR (default ./.cc-artifacts/design-kit) once, prints its URL and writes DIR/.preview.{pid,url,bind,port,ver}; a second start reuses it, or restarts an older version on its own port and bind. Port: --port or DESIGN_KIT_PORT, or exit 4; else DIR's last, 8124, then 8125 to 8139 (DESIGN_KIT_PORT_LAST), the first free, or exit 4. --stop ends it, only when the recorded pid is serve.py on DIR, and deletes those files but .port, and the LAN key.
# --lan binds 0.0.0.0 and prints the URL with the ?key= another device needs; serve.py ends itself (DESIGN_KIT_LAN_MINUTES 60, DESIGN_KIT_IDLE_MINUTES 240, 0 = off). Exit 6: the recorded pid is alive and neither ps nor /proc names it; nothing signalled or removed.
# Misses: serve.py's errors are discarded, so any start that ends before its bind reads as a busy port, and one that takes over 10 s is ended, exit 4; the LAN host is a guess; a server this one could bind beside (macOS, BSD) is seen only where it answers on 127.0.0.1 within 1 s, and by a bash with /dev/tcp; two starts, or a start and a --stop, are not locked: one that meets a start's record waits 15 s at most for that server, then a start ends with exit 4 and a --stop goes on; one that comes before that record starts a server of its own, or stops none. Harness: scripts/__tests__/preview.test.sh.
# Why, limits, history: rationale/derivations/plugin-design-kit.md § plugins/design-kit/scripts/preview.sh
set -euo pipefail

docroot=".cc-artifacts/design-kit"; port="${DESIGN_KIT_PORT:-}"; exact="${port:+1}"; bind="127.0.0.1"; stop=0
while [ $# -gt 0 ]; do
  case "$1" in
    --stop) stop=1 ;;
    --lan) bind="0.0.0.0" ;;
    --port) port="$2"; exact=1; shift ;;
    --docroot) docroot="$2"; shift ;;
    -h|--help) sed -n '2,4p' "$0"; exit 0 ;;
    *) echo "preview.sh: unknown argument $1" >&2; exit 2 ;;
  esac
  shift
done

pidfile="$docroot/.preview.pid"; urlfile="$docroot/.preview.url"; bindfile="$docroot/.preview.bind"; keyfile="$docroot/.preview.key"; portfile="$docroot/.preview.port"; verfile="$docroot/.preview.ver"
state=("$pidfile" "$urlfile" "$bindfile" "$verfile")
# ours <pid>: 0 = serve.py on this docroot (sets running_args), 1 = dead or another process, 6 = alive and unnamed.
ours() {
  case "$1" in '' | *[!0-9]*) return 1 ;; esac
  kill -0 "$1" 2>/dev/null || return 1
  running_args="$(ps -ww -p "$1" -o args= 2>/dev/null)" || running_args=""
  [ -n "$running_args" ] || running_args="$(tr '\0' ' ' < "/proc/$1/cmdline" 2>/dev/null)" || running_args=""
  [ -n "$running_args" ] || { kill -0 "$1" 2>/dev/null && return 6; return 1; }
  # as typed only when absolute: another project's server can show the same relative docroot
  local typed="$abs"; case "$docroot" in /*) typed="$docroot" ;; esac
  case "$running_args" in *serve.py" --docroot $abs --port "* | *serve.py" --docroot $typed --port "*) return 0 ;; esac
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
# "<pid> <version> starting <launcher's pid>" until the server is bound: no version record yet. settled: 0 once no such launcher runs, 1 when one still does after 15 s.
settled() {
  local i word
  for ((i = 0; i < 150; i++)); do
    word=""; { read -r _ _ word launcher < "$verfile"; } 2>/dev/null || true
    [ "$word" = starting ] && kill -0 "$launcher" 2>/dev/null || return 0
    sleep 0.1
  done
  return 1
}
if [ "$stop" = 1 ]; then
  [ -d "$docroot" ] || { echo "preview: nothing running"; exit 0; }
  settled || true
  abs="$(cd "$docroot" && pwd -P)"; pid="$(cat "$pidfile" 2>/dev/null || true)"
  rc=0; ours "$pid" || rc=$?
  [ "$rc" = 6 ] && unnamed "$pid"
  if [ "$rc" = 0 ]; then
    kill "$pid" 2>/dev/null || true
    for _ in $(seq 30); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
    rm -f "${state[@]}" "$keyfile"; echo "preview: stopped"
  else
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then echo "preview: pid $pid is not serve.py on $abs; left it running, removed the stale state"; fi
    rm -f "${state[@]}" "$keyfile"; echo "preview: nothing running"
  fi
  exit 0
fi
keyq() { if [ -s "$keyfile" ]; then printf '?key=%s' "$(python3 -I "$here/picks.py" key "$(cat "$keyfile")")"; fi; }

command -v python3 >/dev/null || { echo "preview.sh: python3 3.8+ is required (or open the .html files directly)" >&2; exit 3; }
mkdir -p "$docroot"
settled || { echo "preview.sh: waited 15 s for another launch (pid $launcher) that is still starting the server; stopped nothing. Try again; if no such launch runs, --stop clears its record" >&2; exit 4; }
abs="$(cd "$docroot" && pwd -P)"; pid="$(cat "$pidfile" 2>/dev/null || true)"
here="$(cd "$(dirname "$0")" && pwd)"; version="$(sed -n 's/^SERVER_VERSION = \([0-9][0-9]*\).*/\1/p' "$here/serve.py")"; unused=""
rc=0; ours "$pid" || rc=$?
[ "$rc" = 6 ] && unnamed "$pid"
if [ "$rc" = 0 ]; then
  running="$(cat "$bindfile" 2>/dev/null || echo 127.0.0.1)"; restart=""
  at="${running_args##* --port }"; at="${at%% *}"
  not_used() { if [ -n "$exact" ] && [ "$port" != "$at" ]; then echo "preview: already running on port $at; --port $port not used"; fi; }
  # nine digits: `[` fails on a number past the shell's integers, which would read as not lower
  recorded="$(sed -n "1s/^$pid \([0-9]\{1,9\}\)\$/\1/p" "$verfile" 2>/dev/null || true)"; recorded="${recorded:-0}"
  if [ "$recorded" -lt "$version" ]; then
    restart=1; unused="$(not_used)"; port="$at"; exact=1
    [ "$running" != "0.0.0.0" ] || bind="0.0.0.0"
  elif [ "$recorded" -eq "$version" ] && [ "$bind" = "0.0.0.0" ] && [ "$running" != "0.0.0.0" ]; then restart=1; fi
  if [ -n "$restart" ]; then
    kill "$pid" 2>/dev/null || true
    for _ in $(seq 30); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
    if ours "$pid"; then echo "preview.sh: pid $pid on port $at did not stop; kept the state files" >&2; exit 4; fi
    rm -f "${state[@]}"
  else
    q=""; [ "$running" = "0.0.0.0" ] && q="$(keyq)"
    echo "preview: already running — $(python3 -I "$here/picks.py" url "$(cat "$urlfile" 2>/dev/null || echo "http://127.0.0.1:$at/")")$q"
    if [ "$recorded" -gt "$version" ]; then echo "preview: a newer server is running; left as it is."; fi
    if [ "$bind" = "0.0.0.0" ] && [ "$running" != "0.0.0.0" ]; then echo "preview: --lan not used"; fi
    not_used
    if [ "$running" = "0.0.0.0" ] && [ "$bind" != "0.0.0.0" ]; then echo "preview: LAN mode is still on — any device on this network with the keyed URL can open it; end it with --stop"; fi
    exit 0
  fi
else
  rm -f "${state[@]}"
fi
lan_flag=""; [ "$bind" = "0.0.0.0" ] && lan_flag="--lan"
old="$(cat "$portfile" 2>/dev/null || true)"; case "$old" in 0* | *[!0-9]* | ??????*) old="" ;; esac
last="${DESIGN_KIT_PORT_LAST:-8139}"; case "$last" in 0* | *[!0-9]* | ??????*) last=8139 ;; esac
if [ -n "$exact" ]; then candidates=("$port"); else
  candidates=()
  if [ -n "$old" ] && [ "$old" -ge 1024 ] && [ "$old" -le 65535 ] && [ "$old" != 8123 ]; then candidates=("$old"); fi
  for ((p = 8124; p == 8124 || p <= last; p++)); do [ "$p" = "$old" ] || candidates+=("$p"); done
fi
# answers <port>: 0 when a connect to 127.0.0.1 succeeds within 1 s; macOS and BSD let a bind succeed beside that server
answers() {
  local probe i
  (: <> "/dev/tcp/127.0.0.1/$1") 2>/dev/null & probe=$!
  for ((i = 0; i < 100; i++)); do kill -0 "$probe" 2>/dev/null || break; sleep 0.01; done
  { kill "$probe"; wait "$probe"; } 2>/dev/null
}
# moved into place: a reader never meets an empty record
record() { echo "$*" > "$verfile.$$"; mv -f "$verfile.$$" "$verfile"; }
record "- $version starting $$" # no server yet; the look at each port may take 1 s
# serve.py's line, which holds the LAN key, is read from a file with no name
said="$(mktemp)"; exec 3> "$said" 4< "$said"; rm -f "$said"
started=""; slow=""; heard=""
for port in "${candidates[@]}"; do
  answers "$port" && continue
  # serve.py turns DESIGN_KIT_PORT into a number even when --port is given, and dies on an empty one
  ( unset DESIGN_KIT_PORT; exec python3 "$here/serve.py" --docroot "$abs" --port "$port" $lan_flag >&3 2>/dev/null 3>&- 4<&- ) &
  pid=$!; record "$pid $version starting $$"; echo "$pid" > "$pidfile"
  for ((i = 0; i < 200; i++)); do
    IFS= read -r line <&4 || true; heard="$heard$line"
    case "$heard" in *" on http://$bind:$port/"*) started=1; break 2 ;; esac
    kill -0 "$pid" 2>/dev/null || continue 2
    sleep 0.05
  done
  kill "$pid" 2>/dev/null || true; slow=1; break
done
if [ -z "$started" ]; then
  rm -f "$pidfile" "$verfile"
  if [ -n "$slow" ]; then echo "preview.sh: the server did not bind port $port in 10 s; ended it" >&2
  elif [ -n "$exact" ]; then echo "preview.sh: server did not start (port $port busy?)" >&2; else echo "preview.sh: no free port from 8124 to $last" >&2; fi
  exit 4
fi
host="127.0.0.1"; [ "$bind" = "0.0.0.0" ] && host="$(ipconfig getifaddr en0 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}' || echo 127.0.0.1)"
q=""
if [ "$bind" = "0.0.0.0" ]; then
  for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$keyfile" ] && break; sleep 0.1; done
  q="$(keyq)"; [ -n "$q" ] || echo "preview.sh: the LAN server wrote no $keyfile; other devices will get 403" >&2
fi
echo "http://$host:$port/" > "$urlfile"; echo "$bind" > "$bindfile"; echo "$port" > "$portfile"; record "$pid $version"
echo "preview: http://$host:$port/$q"
[ -z "$old" ] || [ "$old" = "$port" ] || echo "preview: moved from port $old; saved knobs and page data stay on the old address"
[ -z "$unused" ] || echo "$unused"
[ "$bind" = "0.0.0.0" ] && echo "preview: LAN mode — any device on this network with this keyed URL can open it while the server runs; a pick made from another device is not recorded (loopback only)"
exit 0
