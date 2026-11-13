#!/usr/bin/env bash
# Drives serve.py through preview.sh: gallery, the reload client (injected, reconnect bar, size, note hook, headless and ?static=1 opt-outs), /_index.json, SSE, never-served paths (GET and HEAD, origin- and absolute-form), /_decision, /_note (clamps, text required, lone surrogates, the 2 MiB cap, no symlink, a failed write), /_notes, /_note.js, ?_outline= and its origin import, token badges, stop.
# LAN key: lan_gate and without_key as a unit, a symlinked key file, then end to end from this machine's own network address (a non-loopback peer); that half skips without one.
# Misses: the reconnect bar, the cookie page and the note widget in a browser, and a real second device (each run by hand in Chrome: 2026-11-12, the widget 2026-11-13).
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
case "$snip" in *"src="*|*"href="*|*"http"*|*"//"*) echo "FAIL: the reload client loads an external asset: $snip"; exit 1 ;; esac
# the note widget's one hook: the client imports /_note.js from its own origin, nothing else
case "$snip" in *'location.origin+"/_note.js"'*) ;; *) echo "FAIL: the reload client does not load the note widget from its own origin: $snip"; exit 1 ;; esac
[ "$(printf '%s' "$snip" | wc -c)" -le 800 ] || { echo "FAIL: the reload client grew past 800 bytes ($(printf '%s' "$snip" | wc -c)); it is injected into every page"; exit 1; }
case "$gal" in *"data-design-kit-reload"*) ;; *) echo "FAIL: the gallery lost its reload client"; exit 1 ;; esac
case "$gal" in *"_note.js"*) echo "FAIL: the gallery loads the note widget; it is not a page"; exit 1 ;; esac
c="$(curl -s -o "$tmp/.resp" -w '%{http_code} %{content_type}' "http://127.0.0.1:$port/_note.js")"
case "$c" in "200 text/javascript"*) ;; *) echo "FAIL: /_note.js should be 200 JavaScript, got $c"; exit 1 ;; esac
grep -qE "[\"']/_note[\"']" "$tmp/.resp" && grep -q 'X-Design-Kit-Note' "$tmp/.resp" || { echo "FAIL: /_note.js does not post to /_note"; exit 1; }
# ?_outline= from loopback: the outline helper alone, for a headless shot; no reload client
page_o="$(curl -s -A "Mozilla/5.0 HeadlessChrome/130" "http://127.0.0.1:$port/decks/a.html?_outline=h1")"
case "$page_o" in *"data-design-kit-outline"*) ;; *) echo "FAIL: ?_outline= did not inject the outline helper"; exit 1 ;; esac
case "$page_o" in *"data-design-kit-reload"*) echo "FAIL: ?_outline= injected the reload client into a headless page"; exit 1 ;; esac
# the outline tag imports from the page's own origin too: a bare src="/_note.js" follows a page's <base href> to another host
case "$page_o" in *'src="/_note.js"'*|*'src=\"/_note.js'*) echo "FAIL: the outline tag loads /_note.js by bare path"; exit 1 ;; esac
case "$page_o" in *'location.origin+"/_note.js"'*) ;; *) echo "FAIL: the outline tag does not import /_note.js from location.origin"; exit 1 ;; esac
gal_h="$(curl -s -A "Mozilla/5.0 HeadlessChrome/130" "http://127.0.0.1:$port/")"
case "$gal_h" in *"data-design-kit-reload"*) echo "FAIL: gallery carries the reload snippet for a headless UA"; exit 1 ;; esac
page_h="$(curl -s -A "Mozilla/5.0 HeadlessChrome/130" "http://127.0.0.1:$port/decks/a.html")"
case "$page_h" in *"data-design-kit-reload"*) echo "FAIL: reload snippet injected for a headless UA"; exit 1 ;; esac
page_s="$(curl -s "http://127.0.0.1:$port/decks/a.html?static=1")"
case "$page_s" in *"data-design-kit-reload"*) echo "FAIL: reload snippet injected despite static=1"; exit 1 ;; esac
case "$page_h" in *"_note.js"*) echo "FAIL: a headless page loads the note script"; exit 1 ;; esac
case "$page_s" in *"_note.js"*) echo "FAIL: a ?static=1 page loads the note script"; exit 1 ;; esac
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
printf 'PNG' > "$tmp/shots/one.png"; echo 'SECRET' > "$tmp/.preview.key"
# never_served <path> <leak>: 404 with no body for GET and HEAD, origin-form and absolute-form (http://x//auth/... was 200 once)
never_served() {
  local t c
  for t in "$1" "http://x$1" "http://x/$1"; do
    c="$(curl -s -o "$tmp/.resp" -w '%{http_code}' --request-target "$t" "http://127.0.0.1:$port/")"
    [ "$c" = 404 ] || { echo "FAIL: GET $t should be 404, got $c"; exit 1; }
    grep -q "$2" "$tmp/.resp" && { echo "FAIL: GET $t leaked its content"; exit 1; }
  done
  for t in "$1" "http://x$1" "http://x/$1"; do
    c="$(curl -s -I -o /dev/null -w '%{http_code}' --request-target "$t" "http://127.0.0.1:$port/")"
    [ "$c" = 404 ] || { echo "FAIL: HEAD $t should be 404, got $c"; exit 1; }
  done
}
for probe in /auth/walk.json /auth/ /AUTH/walk.json /workshop.json /usage.jsonl /.preview.pid /.preview.url /.preview.key /artifacts/.versions/a/v1.html /artifacts/a.versions.json /shots/ /decks/; do
  never_served "$probe" "SECRET\|one.png"
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
never_served /decisions.jsonl '"picked"'

# /_note: /_decision's guards with its own header; every field clamped, unknown keys dropped; notes.jsonl never served
npost() { curl -s -o "$tmp/.resp" -w '%{http_code}' -X POST "$@" "http://127.0.0.1:$port/_note"; }
nbody="$(python3 -c '
import json
b = {"page": "/decks/a.html?x=1", "text": "y" * 2500, "evil": "dropped", "status": "addressed",
     "anchor": {"selector": "s" * 600, "tag": "t" * 40, "text": "z" * 300, "rect": {"x": 1.4, "y": "2", "w": 3, "h": 7}, "more": 1},
     "context": {"viewport": {"w": 800, "h": 600}, "theme": "d" * 30, "console": ["e%d" % i + "c" * 400 for i in range(7)] + [5], "x": 1}}
print(json.dumps(b).replace("\"h\": 7", "\"h\": Infinity"))')"
c="$(npost -H 'X-Design-Kit-Note: 1' -H 'Content-Type: application/json' --data "$nbody")"
[ "$c" = 200 ] || { echo "FAIL: note accept http $c: $(cat "$tmp/.resp")"; exit 1; }
c="$(npost -H 'X-Design-Kit-Note: 1' -H "Origin: http://localhost:$port" --data '{"page":"/decks/a.html","text":"page note","anchor":"no"}')"
[ "$c" = 200 ] || { echo "FAIL: a page note from the page's own Origin should be 200, got $c"; exit 1; }
python3 - "$tmp/notes.jsonl" <<'PY' || { echo "FAIL: notes.jsonl rows: $(cat "$tmp/notes.jsonl" 2>/dev/null)"; exit 1; }
import json, re, sys
a, b = [json.loads(l) for l in open(sys.argv[1], encoding="utf-8")]
assert set(a) == {"id", "ts", "page", "kind", "anchor", "text", "context", "status", "reply"}, sorted(a)
assert re.fullmatch(r"[0-9a-f]{8}", a["id"]) and a["id"] != b["id"], (a["id"], b["id"])
assert re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ", a["ts"]), a["ts"]
assert (a["page"], a["kind"], a["status"], a["reply"]) == ("decks/a.html", "note", "open", ""), a
assert len(a["text"]) == 2000
an = a["anchor"]
assert set(an) == {"selector", "tag", "text", "rect"} and (len(an["selector"]), len(an["tag"]), len(an["text"])) == (512, 32, 200), an
assert an["rect"] == {"x": 1, "y": 0, "w": 3, "h": 0}, an["rect"]
cx = a["context"]
assert set(cx) == {"viewport", "theme", "console"} and cx["viewport"] == {"w": 800, "h": 600} and len(cx["theme"]) == 16, cx
assert len(cx["console"]) == 5 and all(len(s) == 300 for s in cx["console"]) and cx["console"][0].startswith("e2"), cx["console"]
assert b["anchor"] is None and b["text"] == "page note", b
PY
c="$(npost -H 'Content-Type: application/json' --data '{"text":"x"}')"; [ "$c" = 403 ] || { echo "FAIL: a note without X-Design-Kit-Note should be 403, got $c"; exit 1; }
c="$(npost -H 'X-Design-Kit-Decision: 1' --data '{"text":"x"}')"; [ "$c" = 403 ] || { echo "FAIL: the decision header must not open /_note, got $c"; exit 1; }
c="$(npost -H 'X-Design-Kit-Note: 1' -H 'Host: attacker.example' --data '{"text":"x"}')"; [ "$c" = 403 ] || { echo "FAIL: a note with a foreign Host should be 403, got $c"; exit 1; }
c="$(npost -H 'X-Design-Kit-Note: 1' -H 'Origin: http://attacker.example' --data '{"text":"x"}')"; [ "$c" = 403 ] || { echo "FAIL: a note with a foreign Origin should be 403, got $c"; exit 1; }
big="$(python3 -c 'print("{\"text\":\"" + "x"*9000 + "\"}")')"
c="$(npost -H 'X-Design-Kit-Note: 1' --data "$big")"; [ "$c" = 413 ] || { echo "FAIL: an oversize note should be 413, got $c"; exit 1; }
c="$(npost -H 'X-Design-Kit-Note: 1' --data 'not json')"; [ "$c" = 400 ] || { echo "FAIL: a non-JSON note should be 400, got $c"; exit 1; }
c="$(npost -H 'X-Design-Kit-Note: 1' --data '["a list"]')"; [ "$c" = 400 ] || { echo "FAIL: a note that is not a JSON object should be 400, got $c"; exit 1; }
[ "$(wc -l < "$tmp/notes.jsonl" | tr -d ' ')" = 2 ] || { echo "FAIL: rejected notes must not append"; exit 1; }
never_served /notes.jsonl '"kind"'
# GET /_notes?page=: that page's rows, from this machine's own address only
c="$(curl -s -o "$tmp/.resp" -w '%{http_code}' "http://127.0.0.1:$port/_notes?page=%2Fdecks%2Fa.html")"
[ "$c" = 200 ] && python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); assert [x["text"][:4] for x in r] == ["yyyy", "page"], r' "$tmp/.resp" \
  || { echo "FAIL: /_notes for decks/a.html: $c $(head -c 300 "$tmp/.resp")"; exit 1; }
[ "$(curl -s "http://127.0.0.1:$port/_notes?page=decks/b.html" | tr -d ' \n')" = "[]" ] || { echo "FAIL: /_notes leaked another page's rows"; exit 1; }
c="$(curl -s -o /dev/null -w '%{http_code}' -H 'Host: attacker.example' "http://127.0.0.1:$port/_notes?page=decks/a.html")"; [ "$c" = 403 ] || { echo "FAIL: /_notes with a foreign Host should be 403, got $c"; exit 1; }
# a note needs text, as taskmaster's /_feedback does
for b in '{}' '{"text":"   "}' '{"page":"/decks/a.html","anchor":{"selector":"h1"}}'; do
  c="$(npost -H 'X-Design-Kit-Note: 1' --data "$b")"; [ "$c" = 400 ] || { echo "FAIL: a note without text ($b) should be 400, got $c"; exit 1; }
done
[ "$(wc -l < "$tmp/notes.jsonl" | tr -d ' ')" = 2 ] || { echo "FAIL: a note without text was recorded"; exit 1; }
# numbers clamp to +-1e7; NaN and Infinity read as 0
c="$(npost -H 'X-Design-Kit-Note: 1' --data '{"page":"/decks/n.html","text":"big","anchor":{"selector":"p","rect":{"x":1e308,"y":-1e308,"w":3,"h":1e999}},"context":{"viewport":{"w":3e9,"h":NaN}}}')"
[ "$c" = 200 ] && tail -n 1 "$tmp/notes.jsonl" | python3 -c 'import json,sys; r=json.load(sys.stdin); assert r["anchor"]["rect"]=={"x":10000000,"y":-10000000,"w":3,"h":0} and r["context"]["viewport"]=={"w":10000000,"h":0}, (r["anchor"]["rect"], r["context"]["viewport"])' \
  || { echo "FAIL: note numbers are not clamped to +-1e7 ($c): $(tail -n 1 "$tmp/notes.jsonl" | cut -c1-300)"; exit 1; }
# a lone surrogate (a page slicing through an emoji) is stored as ?, and the post gets its answer
c="$(npost -H 'X-Design-Kit-Note: 1' --data '{"page":"/decks/s\ud83d.html","text":"cut \ud83d","anchor":{"selector":"p\udc00","tag":"p\ud83d","text":"\ud83d","rect":{}},"context":{"theme":"\ud83d","console":["e\ud83d"]}}')"
[ "$c" = 200 ] && tail -n 1 "$tmp/notes.jsonl" | python3 -c '
import json,sys
r=json.loads(sys.stdin.buffer.read().decode("utf-8")); a=r["anchor"]
assert (r["page"], r["text"], a["selector"], a["tag"], a["text"], r["context"]["theme"], r["context"]["console"]) == ("decks/s?.html", "cut ?", "p?", "p?", "?", "?", ["e?"]), r' \
  || { echo "FAIL: a note with a lone surrogate should be 200 and stored with ? ($c): $(tail -n 1 "$tmp/notes.jsonl" | cut -c1-200)"; exit 1; }
c="$(post -H 'X-Design-Kit-Decision: 1' --data '{"board":"a\ud83d.html","picked":1,"knobs":{"k\ud83d":{"v":"\udc00"}},"text":{"t":"\ud83d"},"prompt":"p\ud83d"}')"
[ "$c" = 200 ] && tail -n 1 "$tmp/decisions.jsonl" | python3 -c '
import json,sys
r=json.loads(sys.stdin.buffer.read().decode("utf-8"))
assert (r["board"], r["knobs"], r["text"], r["prompt"]) == ("a?.html", {"k?": {"v": "?"}}, {"t": "?"}, "p?"), r' \
  || { echo "FAIL: a decision with a lone surrogate should be 200 and stored with ? ($c): $(tail -n 1 "$tmp/decisions.jsonl" | cut -c1-200)"; exit 1; }
deep="$(python3 -c 'print("[" * 8000)')"
c="$(npost -H 'X-Design-Kit-Note: 1' --data "$deep")"; [ "$c" = 400 ] || { echo "FAIL: 8 KiB of nesting to /_note should be 400, got $c"; exit 1; }
c="$(post -H 'X-Design-Kit-Decision: 1' --data "$deep")"; [ "$c" = 400 ] || { echo "FAIL: 8 KiB of nesting to /_decision should be 400, got $c"; exit 1; }
# appends stop at 2 MiB: 507 with a JSON reason, the file untouched
for f in notes.jsonl decisions.jsonl; do
  cp "$tmp/$f" "$tmp/.keep"
  python3 -c '
import json,sys
with open(sys.argv[1],"a") as h:
    while h.tell() < 2*1024*1024: h.write(json.dumps({"id":"pad","page":"old.html","text":"p"*500,"status":"dismissed","consumed":True})+"\n")' "$tmp/$f"
  size="$(wc -c < "$tmp/$f" | tr -d ' ')"
  if [ "$f" = notes.jsonl ]; then c="$(npost -H 'X-Design-Kit-Note: 1' --data '{"text":"one more"}')"; else c="$(post -H 'X-Design-Kit-Decision: 1' --data '{"board":"a.html","picked":1}')"; fi
  [ "$c" = 507 ] && python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["recorded"] is False and "MiB" in d["error"], d' "$tmp/.resp" \
    || { echo "FAIL: a post to a full $f should be 507 with a JSON reason, got $c: $(head -c 200 "$tmp/.resp")"; exit 1; }
  [ "$(wc -c < "$tmp/$f" | tr -d ' ')" = "$size" ] || { echo "FAIL: $f grew past the cap"; exit 1; }
  mv "$tmp/.keep" "$tmp/$f"
done
# notes.jsonl is never followed through a symlink (a tracked one would let a post append to its target), and a failed append answers 500
mv "$tmp/notes.jsonl" "$tmp/.keep"
printf '{"id":"out1","page":"decks/a.html","kind":"note","text":"FROM-OUTSIDE","status":"open"}\n' > "$tmp.target.jsonl"
ln -s "$tmp.target.jsonl" "$tmp/notes.jsonl"
c="$(npost -H 'X-Design-Kit-Note: 1' --data '{"page":"/decks/a.html","text":"through the link"}')"
[ "$c" = 500 ] && python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["recorded"] is False, d' "$tmp/.resp" \
  || { echo "FAIL: a note to a symlinked notes.jsonl should be a JSON 500, got $c: $(head -c 200 "$tmp/.resp")"; exit 1; }
[ "$(wc -l < "$tmp.target.jsonl" | tr -d ' ')" = 1 ] || { echo "FAIL: a note was appended through the notes.jsonl symlink"; exit 1; }
case "$(curl -s "http://127.0.0.1:$port/_notes?page=decks/a.html")" in *FROM-OUTSIDE*) echo "FAIL: /_notes read through the notes.jsonl symlink"; exit 1 ;; esac
rm -f "$tmp/notes.jsonl" "$tmp.target.jsonl"; mkdir "$tmp/notes.jsonl"
c="$(npost -H 'X-Design-Kit-Note: 1' --data '{"page":"/decks/a.html","text":"into a folder"}')"
[ "$c" = 500 ] || { echo "FAIL: an append that fails (notes.jsonl is a folder) should answer 500, got $c"; exit 1; }
rmdir "$tmp/notes.jsonl"; mv "$tmp/.keep" "$tmp/notes.jsonl"
# a note or its lock must not reload every open page (a half-typed note on another tab would be lost)
python3 - "$here/serve.py" "$tmp" <<'PY' || { echo "FAIL: writing notes.jsonl or .notes.lock moves the reload clock"; exit 1; }
import importlib.util, os, sys, time
spec = importlib.util.spec_from_file_location("dkserve", sys.argv[1]); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
before = m._newest_mtime(sys.argv[2]); later = time.time() + 60
for name in ("notes.jsonl", ".notes.lock", ".notes.jsonl.tmp"):
    p = os.path.join(sys.argv[2], name); open(p, "a").close(); os.utime(p, (later, later))
assert m._newest_mtime(sys.argv[2]) == before
os.unlink(os.path.join(sys.argv[2], ".notes.jsonl.tmp"))
PY

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
         ((k, far, "", "key=" + k), "deny"), ((k, far, "", 'design_kit_key="; ;=='), "deny"), ((k, far, "key=nope", "design_kit_key=" + k), "pass"),
         ((k, far, "", "design_kit_key=" + k + "; theme=dark mode"), "pass"), ((k, far, "", "theme=dark mode; design_kit_key=" + k), "pass"),
         ((k, far, "", "flag; design_kit_key=" + k), "pass"), ((k, far, "", 'x=a"b; design_kit_key=' + k), "pass"),
         ((k, far, "", "xdesign_kit_key=" + k), "deny"), ((k, far, "", "design_kit_key=" + k + "x"), "deny")]
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
# a symlinked key file is replaced, never read, chmod-ed or written through
printf 'Outside_key_0123456789abc\n' > "$tmp/k.target"; chmod 644 "$tmp/k.target"
rm -f "$tmp/k/.preview.key"; ln -s "$tmp/k.target" "$tmp/k/.preview.key"; lan_once
[ -L "$tmp/k/.preview.key" ] && { echo "FAIL: .preview.key is still a symlink after a --lan start"; exit 1; }
grep -q "?key=Outside_key" "$tmp/k.out" && { echo "FAIL: serve.py took its key through a symlink"; exit 1; }
[ "$(cat "$tmp/k.target")" = Outside_key_0123456789abc ] && [ "$(python3 -c 'import os,sys;print(oct(os.stat(sys.argv[1]).st_mode & 0o777))' "$tmp/k.target")" = 0o644 ] || { echo "FAIL: the symlink's target was changed"; exit 1; }
[ "$(python3 -c 'import os,sys;print(oct(os.lstat(sys.argv[1]).st_mode & 0o777))' "$tmp/k/.preview.key")" = 0o600 ] || { echo "FAIL: the replaced .preview.key is not mode 0600"; exit 1; }
rm -f "$tmp/k/.preview.key"; ln -s "$tmp/k.planted" "$tmp/k/.preview.key"; lan_once
[ -e "$tmp/k.planted" ] && { echo "FAIL: a dangling .preview.key symlink created its target"; exit 1; }

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
  c="$(hc -X POST --data '{}' "$L/decks/a.html")"; [ "$c" = 403 ] || { echo "FAIL: a POST from a LAN peer without the key should meet the key gate (403), got $c"; exit 1; }
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
  n="$(wc -l < "$tmp/notes.jsonl")"
  c="$(hc -b "design_kit_key=$key" -X POST -H 'X-Design-Kit-Note: 1' --data '{"text":"from a phone"}' "$L/_note?key=$key")"
  [ "$c" = 403 ] && [ "$(wc -l < "$tmp/notes.jsonl")" = "$n" ] || { echo "FAIL: /_note from a LAN peer with the key should be 403 and not append, got $c"; exit 1; }
  c="$(hc -b "design_kit_key=$key" "$L/_notes?page=decks/a.html")"; [ "$c" = 403 ] || { echo "FAIL: /_notes from a LAN peer with the key should be 403, got $c"; exit 1; }
  c="$(hc -b "design_kit_key=$key" -A "Mozilla/5.0 HeadlessChrome/130" "$L/decks/a.html?_outline=h1")"
  [ "$c" = 200 ] && ! grep -q 'data-design-kit-outline' "$tmp/.resp" || { echo "FAIL: ?_outline= from a LAN peer injected the outline helper ($c)"; exit 1; }
  c="$(hc "$L/_note.js")"; [ "$c" = 403 ] || { echo "FAIL: /_note.js from a LAN peer without the key should be 403, got $c"; exit 1; }
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
