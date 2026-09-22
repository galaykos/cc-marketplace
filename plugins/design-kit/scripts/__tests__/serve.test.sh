#!/usr/bin/env bash
# Drives serve.py through preview.sh: gallery at /, reload snippet injected into a
# page, /_index.json lists it, SSE emits reload after a write, the /_decision route
# accepts loopback+header+JSON and rejects the rest, token badges, --stop ends it.
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
gal_h="$(curl -s -A "Mozilla/5.0 HeadlessChrome/130" "http://127.0.0.1:$port/")"
case "$gal_h" in *"data-design-kit-reload"*) echo "FAIL: gallery carries the reload snippet for a headless UA"; exit 1 ;; esac
page_h="$(curl -s -A "Mozilla/5.0 HeadlessChrome/130" "http://127.0.0.1:$port/decks/a.html")"
case "$page_h" in *"data-design-kit-reload"*) echo "FAIL: reload snippet injected for a headless UA"; exit 1 ;; esac
page_s="$(curl -s "http://127.0.0.1:$port/decks/a.html?static=1")"
case "$page_s" in *"data-design-kit-reload"*) echo "FAIL: reload snippet injected despite static=1"; exit 1 ;; esac
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
# /_decision: the one write route — loopback + header + size + JSON, append-only
post() { curl -s -o "$tmp/.resp" -w '%{http_code}' -X POST "$@" "http://127.0.0.1:$port/_decision"; }
c="$(post -H 'X-Design-Kit-Decision: 1' -H 'Content-Type: application/json' --data '{"board":"a.html","picked":1,"knobs":{},"text":{},"prompt":"pick 1"}')"
[ "$c" = 200 ] || { echo "FAIL: decision accept http $c: $(cat "$tmp/.resp")"; exit 1; }
grep -q '"picked": 1' "$tmp/decisions.jsonl" 2>/dev/null || grep -q '"picked":1' "$tmp/decisions.jsonl" || { echo "FAIL: decisions.jsonl not appended"; cat "$tmp/decisions.jsonl" 2>/dev/null; exit 1; }
grep -q '"consumed": false' "$tmp/decisions.jsonl" || { echo "FAIL: consumed flag missing"; exit 1; }
c="$(post -H 'Content-Type: application/json' --data '{"board":"a.html"}')"; [ "$c" = 403 ] || { echo "FAIL: missing header should be 403, got $c"; exit 1; }
big="$(python3 -c 'print("{\"prompt\":\"" + "x"*9000 + "\"}")')"
c="$(post -H 'X-Design-Kit-Decision: 1' --data "$big")"; [ "$c" = 413 ] || { echo "FAIL: oversize should be 413, got $c"; exit 1; }
c="$(post -H 'X-Design-Kit-Decision: 1' --data 'not json')"; [ "$c" = 400 ] || { echo "FAIL: bad json should be 400, got $c"; exit 1; }
c="$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'X-Design-Kit-Decision: 1' --data '{}' "http://127.0.0.1:$port/decks/a.html")"; [ "$c" = 501 ] || { echo "FAIL: POST elsewhere should be 501, got $c"; exit 1; }
[ "$(wc -l < "$tmp/decisions.jsonl" | tr -d ' ')" = 1 ] || { echo "FAIL: rejected posts must not append"; exit 1; }

# token badge: a stamped page vs ../design-system/tokens.json
mkdir -p "$tmp.ds/design-system"; printf '{"color":{"a":{"$value":"#000"}}}' > "$tmp.ds/design-system/tokens.json"
sha="$(python3 -c 'import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest()[:12])' "$tmp.ds/design-system/tokens.json")"
mkdir -p "$tmp.ds/.design-kit/decks"
printf '<!doctype html><html><head><title>Cur</title><meta name="design-kit-tokens" content="%s none"></head><body>x</body></html>' "$sha" > "$tmp.ds/.design-kit/decks/cur.html"
printf '<!doctype html><html><head><title>Old</title><meta name="design-kit-tokens" content="000000000000 none"></head><body>x</body></html>' > "$tmp.ds/.design-kit/decks/old.html"
port2=$(( 20000 + RANDOM % 10000 ))
bash "$here/preview.sh" --docroot "$tmp.ds/.design-kit" --port "$port2" >/dev/null; sleep 0.4
idx="$(curl -s "http://127.0.0.1:$port2/_index.json")"
python3 -c '
import json,sys; d={p["path"]:p["tokens"] for p in json.loads(sys.argv[1])}
assert d["decks/cur.html"]["current"] is True, d
assert d["decks/old.html"]["current"] is False, d' "$idx" || { echo "FAIL: _index.json tokens: $idx"; exit 1; }
gal2="$(curl -s "http://127.0.0.1:$port2/")"
case "$gal2" in *"tokens current"*"tokens moved since build"*|*"tokens moved since build"*"tokens current"*) ;; *) echo "FAIL: badges missing in gallery"; exit 1 ;; esac
bash "$here/preview.sh" --docroot "$tmp.ds/.design-kit" --stop >/dev/null; rm -rf "$tmp.ds"

out="$(bash "$here/preview.sh" --docroot "$tmp" --stop)"
case "$out" in *stopped*) ;; *) echo "FAIL: stop: $out"; exit 1 ;; esac
echo "PASS serve.test.sh"
