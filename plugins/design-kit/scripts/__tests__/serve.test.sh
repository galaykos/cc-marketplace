#!/usr/bin/env bash
# Drives serve.py through preview.sh: gallery at /, reload snippet injected into a
# page, /_index.json lists it, SSE emits reload after a write, --stop ends it.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'bash "$here/preview.sh" --docroot "$tmp" --stop >/dev/null 2>&1 || true; rm -rf "$tmp"' EXIT
port=$(( 20000 + RANDOM % 10000 ))
mkdir -p "$tmp/decks"
printf '<!doctype html><html><head><title>Deck A</title></head><body><h1>a</h1></body></html>' > "$tmp/decks/a.html"
bash "$here/preview.sh" --docroot "$tmp" --port "$port" >/dev/null
sleep 0.4
gal="$(curl -s "http://127.0.0.1:$port/")"
case "$gal" in *"design-kit gallery"*"Deck A"*) ;; *) echo "FAIL: gallery missing page: ${gal:0:200}"; exit 1 ;; esac
page="$(curl -s "http://127.0.0.1:$port/decks/a.html")"
case "$page" in *"data-design-kit-reload"*"</body>"*) ;; *) echo "FAIL: reload snippet not injected"; exit 1 ;; esac
idx="$(curl -s "http://127.0.0.1:$port/_index.json")"
case "$idx" in *'"path": "decks/a.html"'*) ;; *) echo "FAIL: _index.json: $idx"; exit 1 ;; esac
( curl -s -N --max-time 3 "http://127.0.0.1:$port/_events" > "$tmp/.sse" 2>/dev/null || true ) &
sleep 1.0
printf '<html><body>changed</body></html>' > "$tmp/decks/b.html"
sleep 2.4
grep -q "data: reload" "$tmp/.sse" || { echo "FAIL: no reload event after a write"; cat "$tmp/.sse"; exit 1; }
echo "OUTSIDE" > "$tmp.outside.txt"
for probe in "/../$(basename "$tmp").outside.txt" "/%2e%2e/$(basename "$tmp").outside.txt" "/../../etc/passwd"; do
  curl -s --path-as-is "http://127.0.0.1:$port$probe" | grep -qE "OUTSIDE|root:" && { echo "FAIL: path traversal via $probe"; exit 1; }
done
rm -f "$tmp.outside.txt"
out="$(bash "$here/preview.sh" --docroot "$tmp" --stop)"
case "$out" in *stopped*) ;; *) echo "FAIL: stop: $out"; exit 1 ;; esac
echo "PASS serve.test.sh"
