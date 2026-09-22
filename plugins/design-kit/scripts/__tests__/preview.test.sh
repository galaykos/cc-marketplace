#!/usr/bin/env bash
# Drives preview.sh: start serves a file, second start is idempotent, --stop kills it.
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
echo "PASS preview.test.sh"
