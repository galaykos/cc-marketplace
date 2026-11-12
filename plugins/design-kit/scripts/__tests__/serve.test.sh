#!/usr/bin/env bash
# Drives serve.py through preview.sh: gallery, the reload client (injected, reconnect bar, size, headless and ?static=1 opt-outs), /_index.json, SSE, never-served paths, /_decision, token badges, stop.
# LAN key: lan_gate and without_key as a unit, then end to end from this machine's own network address (a non-loopback peer); that half skips without one.
# Misses: the reconnect bar and the cookie page in a browser, and a real second device (both run once by hand in Chrome, 2026-11-12).
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
# the injected client reconnects: a role=status bar while the stream is down, a retry timer, no external asset, kept small
snip="$(printf '%s' "$page" | python3 -c 'import re,sys;m=re.search(r"<script data-design-kit-reload>.*?</script>",sys.stdin.read(),re.S);print(m.group(0) if m else "")')"
for want in '"role","status"' setTimeout location.reload; do
  case "$snip" in *"$want"*) ;; *) echo "FAIL: the injected client lacks $want (reconnect bar, retry, reload): $snip"; exit 1 ;; esac
done
case "$snip" in *"src="*|*"href="*|*"http"*) echo "FAIL: the reload client loads an external asset: $snip"; exit 1 ;; esac
[ "$(printf '%s' "$snip" | wc -c)" -le 800 ] || { echo "FAIL: the reload client grew past 800 bytes ($(printf '%s' "$snip" | wc -c)); it is injected into every page"; exit 1; }
case "$gal" in *"data-design-kit-reload"*) ;; *) echo "FAIL: the gallery lost its reload client"; exit 1 ;; esac
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
# never served: hidden files, auth/, state files, version ledgers, directory listings
mkdir -p "$tmp/auth" "$tmp/artifacts/.versions/a" "$tmp/shots"
echo '{"cookies":[{"value":"SECRET"}]}' > "$tmp/auth/walk.json"
echo '{"s":"SECRET"}' > "$tmp/workshop.json"; echo '{"s":"SECRET"}' > "$tmp/usage.jsonl"
echo '<p>SECRET</p>' > "$tmp/artifacts/.versions/a/v1.html"; echo '{"s":"SECRET"}' > "$tmp/artifacts/a.versions.json"
printf 'PNG' > "$tmp/shots/one.png"
for probe in /auth/walk.json /auth/ /AUTH/walk.json /workshop.json /usage.jsonl /.preview.pid /.preview.url /artifacts/.versions/a/v1.html /artifacts/a.versions.json /shots/ /decks/; do
  c="$(curl -s -o "$tmp/.resp" -w '%{http_code}' "http://127.0.0.1:$port$probe")"
  [ "$c" = 404 ] || { echo "FAIL: $probe should be 404, got $c"; exit 1; }
  grep -q "SECRET\|one.png" "$tmp/.resp" && { echo "FAIL: $probe leaked its content"; exit 1; }
done
[ "$(curl -s "http://127.0.0.1:$port/shots/one.png")" = PNG ] || { echo "FAIL: an ordinary asset is no longer served"; exit 1; }
# gallery thumbnails must not each hold an SSE connection (six fill a browser's per-host pool)
case "$gal" in *'src="/decks/a.html?static=1"'*) ;; *) echo "FAIL: gallery iframe lacks ?static=1"; exit 1 ;; esac
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
ok_body='{"board":"a.html","picked":2,"prompt":"planted"}'
c="$(post -H 'X-Design-Kit-Decision: 1' -H 'Host: attacker.example' --data "$ok_body")"; [ "$c" = 403 ] || { echo "FAIL: a foreign Host should be 403, got $c"; exit 1; }
c="$(post -H 'X-Design-Kit-Decision: 1' -H 'Origin: http://attacker.example' --data "$ok_body")"; [ "$c" = 403 ] || { echo "FAIL: a foreign Origin should be 403, got $c"; exit 1; }
c="$(post -H 'X-Design-Kit-Decision: 1' -H "Origin: http://127.0.0.1:$port" --data '{"board":"a.html","picked":3}')"; [ "$c" = 200 ] || { echo "FAIL: the page's own Origin should be 200, got $c"; exit 1; }
c="$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'X-Design-Kit-Decision: 1' --data '{"board":"a.html","picked":4}' "http://localhost:$port/_decision")"; [ "$c" = 200 ] || { echo "FAIL: localhost should be 200, got $c"; exit 1; }
[ "$(wc -l < "$tmp/decisions.jsonl" | tr -d ' ')" = 3 ] || { echo "FAIL: rejected posts must not append"; exit 1; }

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

# LAN key, as a unit: the peer/key decision and the redirect target are pure functions
python3 - "$here/serve.py" <<'PY' || { echo "FAIL: lan_gate / without_key unit cases"; exit 1; }
import importlib.util, sys
spec = importlib.util.spec_from_file_location("dkserve", sys.argv[1]); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
k, far = "Zx9_-Zx9_-Zx9_-Zx9_-ab", "192.168.1.9"
cases = [((None, far, "", ""), "pass"), ((k, "127.0.0.1", "", ""), "pass"), ((k, "::1", "", ""), "pass"),
         ((k, "::ffff:127.0.0.1", "", ""), "pass"), ((k, far, "", ""), "deny"), ((k, far, "key=" + k, ""), "set"),
         ((k, far, "static=1&key=" + k, ""), "set"), ((k, far, "key=" + k[:-1], ""), "deny"), ((k, far, "key=" + k + "x", ""), "deny"),
         ((k, far, "key=", ""), "deny"), ((k, far, "key=%C3%A9%00", ""), "deny"), ((k, far, "", "design_kit_key=" + k), "pass"),
         ((k, far, "", "a=1; design_kit_key=" + k), "pass"), ((k, far, "", "design_kit_key=nope"), "deny"),
         ((k, far, "", "key=" + k), "deny"), ((k, far, "", 'design_kit_key="; ;=='), "deny"), ((k, far, "key=nope", "design_kit_key=" + k), "pass")]
bad = [(a, want, m.lan_gate(*a)) for a, want in cases if m.lan_gate(*a) != want]
for path, q, want in [("/decks/a.html", "key=K", "/decks/a.html"), ("/decks/a.html", "static=1&key=K", "/decks/a.html?static=1"),
                      ("//evil.example/x", "key=K", "/evil.example/x"), ("/", "key=K&b=2", "/?b=2")]:
    if m.without_key(path, q) != want:
        bad.append(((path, q), want, m.without_key(path, q)))
for b in bad:
    print("  case, wanted, got:", b)
sys.exit(1 if bad else 0)
PY
# serve.py --lan prints its keyed URL, keeps the key in a 0600 dot-file, and a restart reuses it
mkdir -p "$tmp/k"; pk=$(( 20000 + RANDOM % 10000 ))
lan_once() { DESIGN_KIT_IDLE_MINUTES=0 DESIGN_KIT_LAN_MINUTES=0 python3 "$here/serve.py" --docroot "$tmp/k" --port "$pk" --lan > "$tmp/k.out" 2>/dev/null & local p=$!; sleep 0.5; kill "$p" 2>/dev/null || true; wait "$p" 2>/dev/null || true; }
lan_once; k1="$(cat "$tmp/k/.preview.key" 2>/dev/null || true)"
[ -n "$k1" ] && grep -q "?key=$k1" "$tmp/k.out" || { echo "FAIL: serve.py --lan printed no keyed URL: $(cat "$tmp/k.out")"; exit 1; }
[ "$(python3 -c 'import os,sys;print(oct(os.stat(sys.argv[1]).st_mode & 0o777))' "$tmp/k/.preview.key")" = 0o600 ] || { echo "FAIL: .preview.key is not mode 0600"; exit 1; }
lan_once; [ "$(cat "$tmp/k/.preview.key")" = "$k1" ] && grep -q "?key=$k1" "$tmp/k.out" || { echo "FAIL: a restart changed the LAN key"; exit 1; }

# LAN key, end to end: this machine's own network address is a non-loopback peer
lanip="$(python3 -c 'import socket
s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM); s.connect(("192.0.2.1",9)); print(s.getsockname()[0])' 2>/dev/null || true)"
if [ -z "$lanip" ] || [ "${lanip#127.}" != "$lanip" ]; then echo "SKIP: no non-loopback address — the LAN key ran as a unit only"
else
  out="$(bash "$here/preview.sh" --docroot "$tmp" --port "$port" --lan)"
  key="$(cat "$tmp/.preview.key" 2>/dev/null || true)"
  [ -n "$key" ] || { echo "FAIL: --lan wrote no .preview.key"; exit 1; }
  case "$out" in *"/?key=$key"*) ;; *) echo "FAIL: preview.sh --lan URL lacks the key: $out"; exit 1 ;; esac
  L="http://$lanip:$port"
  hc() { curl -s -o "$tmp/.resp" -w '%{http_code}' "$@" || true; }
  for probe in / /decks/a.html /_index.json "/decks/a.html?key=wrong" "/decks/a.html?key="; do
    c="$(hc "$L$probe")"; [ "$c" = 403 ] || { echo "FAIL: $probe from a LAN peer without the key should be 403, got $c"; exit 1; }
  done
  c="$(hc --max-time 2 "$L/_events")"; [ "$c" = 403 ] || { echo "FAIL: /_events from a LAN peer without the key should be 403, got $c"; exit 1; }
  c="$(hc -b "design_kit_key=wrong" "$L/decks/a.html")"; [ "$c" = 403 ] || { echo "FAIL: a wrong cookie should be 403, got $c"; exit 1; }
  # first keyed visit: 200 + cookie + a meta refresh to the clean URL (a 303 measured 403 in Chrome for a link from another site)
  hdr="$(curl -s -D - -o "$tmp/.resp" "$L/decks/a.html?static=1&key=$key" | tr -d '\r')"
  case "$hdr" in "HTTP/1."?" 200"*) ;; *) echo "FAIL: first keyed visit should be 200: $hdr"; exit 1 ;; esac
  grep -qF 'http-equiv="refresh" content="0;url=/decks/a.html?static=1"' "$tmp/.resp" || { echo "FAIL: first keyed visit does not refresh to the clean URL: $(cat "$tmp/.resp")"; exit 1; }
  grep -qF "$key" "$tmp/.resp" && { echo "FAIL: the cookie page echoes the key"; exit 1; }
  ck="$(printf '%s\n' "$hdr" | grep -i '^set-cookie:' || true)"
  case "$ck" in *"design_kit_key=$key"*HttpOnly*SameSite=Strict*) ;; *) echo "FAIL: cookie lacks the key, HttpOnly or SameSite=Strict: $ck"; exit 1 ;; esac
  c="$(hc -b "design_kit_key=$key" "$L/decks/a.html")"; [ "$c" = 200 ] && grep -q '<h1>a</h1>' "$tmp/.resp" || { echo "FAIL: the cookie should serve the page, got $c"; exit 1; }
  c="$(hc -b "design_kit_key=$key" "$L/_index.json")"; [ "$c" = 200 ] || { echo "FAIL: the cookie should serve /_index.json, got $c"; exit 1; }
  c="$(hc -b "design_kit_key=$key" --max-time 2 "$L/_events")"; [ "$c" = 200 ] || { echo "FAIL: the cookie should open /_events, got $c"; exit 1; }
  n="$(wc -l < "$tmp/decisions.jsonl")"
  c="$(hc -b "design_kit_key=$key" -X POST -H 'X-Design-Kit-Decision: 1' --data '{"board":"a.html","picked":9}' "$L/_decision?key=$key")"
  [ "$c" = 403 ] && [ "$(wc -l < "$tmp/decisions.jsonl")" = "$n" ] || { echo "FAIL: /_decision from a LAN peer with the key should be 403 and not append, got $c"; exit 1; }
  c="$(hc "http://127.0.0.1:$port/decks/a.html")"; [ "$c" = 200 ] || { echo "FAIL: a loopback peer should need no key, got $c"; exit 1; }
  c="$(hc "http://127.0.0.1:$port/.preview.key")"; [ "$c" = 404 ] || { echo "FAIL: /.preview.key should be 404, got $c"; exit 1; }
  kill "$(cat "$tmp/.preview.pid")"; sleep 0.3
  again="$(bash "$here/preview.sh" --docroot "$tmp" --port "$port" --lan)"
  case "$again" in *"?key=$key"*) ;; *) echo "FAIL: a restart changed the LAN URL: $again"; exit 1 ;; esac
  share="$(cd "$tmp" && DESIGN_KIT_DIR="$tmp" DESIGN_KIT_PORT="$port" bash "$here/dk.sh" share "$tmp/decks/a.html" --lan 2>/dev/null)"
  case "$share" in *"url=http://"*"/decks/a.html?key=$key") ;; *) echo "FAIL: dk share --lan URL lacks the key: $share"; exit 1 ;; esac
fi

out="$(bash "$here/preview.sh" --docroot "$tmp" --stop)"
case "$out" in *stopped*) ;; *) echo "FAIL: stop: $out"; exit 1 ;; esac
[ -f "$tmp/.preview.key" ] && { echo "FAIL: --stop left .preview.key; the next LAN start should mint a new one"; exit 1; }
echo "PASS serve.test.sh"
