#!/usr/bin/env bash
# preview.sh [--docroot DIR] [--port N] [--lan] | --stop [--docroot DIR] — starts visual-decisions' serve.py in the background unless this docroot's recorded server is alive (then prints the same URL and starts nothing); state in DIR/.preview.pid, .preview.url, .preview.log, private under serve.py's dot rule. --stop kills the recorded pid only when it is serve.py on DIR. One start or stop per DIR at a time (DIR/.preview.lock). With --lan it also relays serve.py's loopback URL, the one Restore accepts.
# Exit: 0 started, already running, stopped or nothing to stop; 2 bad argument; 3 python3 or serve.py missing; 4 serve.py did not start (port busy?) or the lock stayed held 15 s; 5 --lan asked while a loopback-only server runs for DIR (--stop first); 6 the recorded pid is alive and neither ps nor /proc names it (nothing signalled, no state removed).
# Misses: a server started without this launcher holds the port and gets exit 4, not reuse; two starts that find a stale lock (owner killed -9) at the same moment can both take it; nothing proves a browser rendered a page.
# Why, limits, history: rationale/derivations/plugin-taskmaster.md § plugins/taskmaster/scripts/preview.sh
set -u

docroot="taskmaster-docs/mockups"; port="${PREVIEW_PORT:-8123}"; lan=0; stop=0
while [ $# -gt 0 ]; do
  case "$1" in
    --docroot) [ $# -ge 2 ] || { echo "preview.sh: --docroot needs a directory" >&2; exit 2; }; docroot=$2; shift ;;
    --port) case "${2:-}" in '' | *[!0-9]*) echo "preview.sh: --port needs a number" >&2; exit 2 ;; esac; port=$2; shift ;;
    --lan) lan=1 ;;
    --stop) stop=1 ;;
    -h | --help) sed -n '2,4p' "$0"; exit 0 ;;
    *) echo "preview.sh: unknown argument $1" >&2; exit 2 ;;
  esac
  shift
done

serve="$(cd "$(dirname "$0")/.." && pwd)/skills/visual-decisions/assets/serve.py"
pidfile="$docroot/.preview.pid"; urlfile="$docroot/.preview.url"; logfile="$docroot/.preview.log"

# ours <pid>: 0 = serve.py on this docroot (sets $running_args), 1 = dead or another process, 6 = alive and unnamed.
ours() {
  case "$1" in '' | *[!0-9]*) return 1 ;; esac
  kill -0 "$1" 2>/dev/null || return 1
  running_args="$(ps -ww -p "$1" -o args= 2>/dev/null)" || running_args=""
  [ -n "$running_args" ] || running_args="$(tr '\0' ' ' < "/proc/$1/cmdline" 2>/dev/null)" || running_args=""
  [ -n "$running_args" ] || { kill -0 "$1" 2>/dev/null && return 6; return 1; }
  case "$running_args" in *serve.py" --docroot $abs --port "*) return 0 ;; esac
  return 1
}
unnamed() { echo "preview.sh: pid $1 in $pidfile is alive and neither ps nor /proc says what it is; signalled nothing, kept the state files — check it, then delete $pidfile" >&2; exit 6; }

# take_lock: one check-and-start (or stop) per docroot at a time. A lock whose owner is dead, or that names no owner for 2 s, is stale.
take_lock() {
  lockdir="$docroot/.preview.lock"; local unowned=0 owner
  for _ in $(seq 1 150); do
    if mkdir "$lockdir" 2>/dev/null; then
      echo $$ > "$lockdir/owner"; trap 'rm -rf "$lockdir"' EXIT; trap 'exit 130' INT TERM HUP; return 0
    fi
    owner="$(cat "$lockdir/owner" 2>/dev/null)"
    if [ -z "$owner" ]; then unowned=$((unowned + 1)); else unowned=0; fi
    if { [ -n "$owner" ] && ! kill -0 "$owner" 2>/dev/null; } || [ "$unowned" -ge 20 ]; then rm -rf "$lockdir"; continue; fi
    sleep 0.1
  done
  echo "preview.sh: another start for $docroot has held $lockdir for 15 s; delete it if no preview.sh is running" >&2
  exit 4
}

if [ "$stop" = 1 ]; then
  if [ ! -d "$docroot" ]; then echo "preview: nothing running"; exit 0; fi
  abs="$(cd "$docroot" && pwd -P)"
  take_lock
  pid="$(cat "$pidfile" 2>/dev/null)"
  rc=0; ours "$pid" || rc=$?
  [ "$rc" = 6 ] && unnamed "$pid"
  if [ "$rc" = 0 ]; then
    kill "$pid" 2>/dev/null
    for _ in $(seq 1 30); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
    rm -f "$pidfile" "$urlfile"
    echo "preview: stopped"
  else
    [ -n "$pid" ] && echo "preview: pid $pid is not serve.py on $abs; left it running, removed the stale state"
    rm -f "$pidfile" "$urlfile"
    echo "preview: nothing running"
  fi
  exit 0
fi

command -v python3 >/dev/null 2>&1 || { echo "preview.sh: python3 not found; use the fallback rungs" >&2; exit 3; }
[ -f "$serve" ] || { echo "preview.sh: serve.py not found at $serve" >&2; exit 3; }
mkdir -p "$docroot" || exit 4
abs="$(cd "$docroot" && pwd -P)"
umask 077
take_lock

pid="$(cat "$pidfile" 2>/dev/null)"
rc=0; ours "$pid" || rc=$?
[ "$rc" = 6 ] && unnamed "$pid"
if [ "$rc" = 0 ]; then
  url="$(cat "$urlfile" 2>/dev/null)"
  case "$running_args" in *" --lan"*) running_lan=1 ;; *) running_lan=0 ;; esac
  if [ "$lan" = 1 ] && [ "$running_lan" = 0 ]; then
    echo "preview.sh: a loopback-only server already runs for $abs at $url; run preview.sh --stop, then --lan" >&2
    exit 5
  fi
  echo "preview: already running — $url"
  if [ "$running_lan" = 1 ]; then
    grep '^On this machine: ' "$logfile" 2>/dev/null | head -n 1 | sed 's/^/preview: /'
    echo "preview: LAN mode is still on — any device on this network with the key can open it until the time limit or --stop"
  fi
  exit 0
fi
rm -f "$pidfile" "$urlfile"

lan_flag=""; [ "$lan" = 1 ] && lan_flag="--lan"
# Truncate here: the redirect below runs in the child, after the readiness loop may already read a previous run's line.
: > "$logfile"
nohup python3 "$serve" --docroot "$abs" --port "$port" $lan_flag >"$logfile" 2>&1 </dev/null &
pid=$!
echo "$pid" > "$pidfile"
url=""
for _ in $(seq 1 50); do
  url="$(sed -n 's/^Serving .* at \(http[^ ]*\).*/\1/p' "$logfile" | head -n 1)"
  [ -n "$url" ] && break
  kill -0 "$pid" 2>/dev/null || break
  sleep 0.1
done
if [ -z "$url" ] || ! kill -0 "$pid" 2>/dev/null; then
  kill "$pid" 2>/dev/null
  [ "$(cat "$pidfile" 2>/dev/null)" = "$pid" ] && rm -f "$pidfile"
  echo "preview.sh: serve.py did not start on port $port:" >&2
  tail -n 3 "$logfile" >&2
  exit 4
fi
printf '%s\n' "$url" > "$urlfile"
echo "preview: $url"
grep -E '^(On this machine:|LAN|Idle) ' "$logfile" | sed 's/^/preview: /'
exit 0
