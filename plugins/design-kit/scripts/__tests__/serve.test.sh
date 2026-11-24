#!/usr/bin/env bash
# Drives serve.py through preview.sh: gallery, the reload client (injected, reconnect bar, size, note hook, headless and ?static=1 opt-outs), /_index.json, SSE, never-served paths (GET and HEAD, origin- and absolute-form), the Host rule, symlinks leaving the docroot, the headers of every answer, SVG/XHTML/XML policy, /_decision (stored through picks.py with the server's own prompt), /_note (clamps, text required), both: body limits, lone surrogates, one row per cid under the file's lock, the 2 MiB cap, no symlink, a failed write; /_notes, /_note.js, ?_outline= and its origin import, token badges, stop.
# LAN key: lan_gate and without_key as a unit, a symlinked key file, then end to end from this machine's own network address (a non-loopback peer); that half skips without one.
# Misses: the reconnect bar, the cookie page and the note widget in a browser, and a real second device (each run by hand in Chrome: 2026-11-12, the widget 2026-11-13).
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'bash "$here/preview.sh" --docroot "$tmp" --stop >/dev/null 2>&1 || true; rm -rf "$tmp" "$tmp.out"' EXIT
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
# /_decision: loopback + header + size + JSON, append-only; a row holds what picks.py keeps (its bounds: picks.test.sh) and the server's own prompt
post() { curl -s -o "$tmp/.resp" -w '%{http_code}' -X POST "$@" "http://127.0.0.1:$port/_decision"; }
c="$(post -H 'X-Design-Kit-Decision: 1' -H 'Content-Type: application/json' --data '{"board":"a.html","picked":1,"knobs":{"all":{"hue":400,"evil":"x"}},"text":{"1":{"h1":{"was":"Old","now":"New","evil":"x"}}},"prompt":"POSTED","evil":"x","v":9,"ts":"x","consumed":true}')"
[ "$c" = 200 ] || { echo "FAIL: decision accept http $c: $(cat "$tmp/.resp")"; exit 1; }
python3 - "$tmp/decisions.jsonl" <<'PY' || { echo "FAIL: posted prompt never stored, every other field as picks.py keeps it: $(cat "$tmp/decisions.jsonl" 2>/dev/null)"; exit 1; }
import json, re, sys
row = json.loads(open(sys.argv[1], encoding="utf-8").read())
assert re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ", row.pop("ts")), row
assert row == {"v": 2, "cid": None, "board": "a.html", "picked": 1, "knobs": {"all": {"hue": 360}}, "text": {"1": {"h1": {"was": "Old", "now": "New"}}},
               "prompt": "From the design board a.html, implement artboard 1. Update design-kit in this session to read adjustments and text edits.", "consumed": False}, row
PY
c="$(post -H 'Content-Type: application/json' --data '{"board":"a.html"}')"; [ "$c" = 403 ] || { echo "FAIL: missing header should be 403, got $c"; exit 1; }
big="$(python3 -c 'print("{\"board\":\"a.html\",\"prompt\":\"" + "x"*70000 + "\"}")')"
c="$(post -H 'X-Design-Kit-Decision: 1' --data "$big")"; [ "$c" = 413 ] || { echo "FAIL: a 70 KiB pick should be 413, got $c"; exit 1; }
c="$(post -H 'X-Design-Kit-Decision: 1' --data 'not json')"; [ "$c" = 400 ] || { echo "FAIL: bad json should be 400, got $c"; exit 1; }
c="$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'X-Design-Kit-Decision: 1' --data '{}' "http://127.0.0.1:$port/decks/a.html")"; [ "$c" = 501 ] || { echo "FAIL: POST elsewhere should be 501, got $c"; exit 1; }
ok_body='{"board":"a.html","picked":2,"prompt":"planted"}'
c="$(post -H 'X-Design-Kit-Decision: 1' -H 'Host: attacker.example' --data "$ok_body")"; [ "$c" = 403 ] || { echo "FAIL: a foreign Host should be 403, got $c"; exit 1; }
c="$(post -H 'X-Design-Kit-Decision: 1' -H 'Origin: http://attacker.example' --data "$ok_body")"; [ "$c" = 403 ] || { echo "FAIL: a foreign Origin should be 403, got $c"; exit 1; }
c="$(post -H 'X-Design-Kit-Decision: 1' -H "Origin: http://127.0.0.1:$port" --data '{"board":"a.html","picked":3}')"; [ "$c" = 200 ] || { echo "FAIL: the page's own Origin should be 200, got $c"; exit 1; }
c="$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'X-Design-Kit-Decision: 1' --data '{"board":"a.html","picked":4}' "http://localhost:$port/_decision")"; [ "$c" = 200 ] || { echo "FAIL: localhost should be 200, got $c"; exit 1; }
c="$(post -H 'X-Design-Kit-Decision: 1' --data '{"board":"a\ud83d.html","picked":5}')"
[ "$c" = 400 ] && python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["recorded"] is False and d["error"].startswith("board must be"), d' "$tmp/.resp" \
  || { echo "FAIL: a board picks.py refuses should be 400 with its reason, got $c: $(head -c 200 "$tmp/.resp")"; exit 1; }
[ "$(wc -l < "$tmp/decisions.jsonl" | tr -d ' ')" = 3 ] || { echo "FAIL: rejected posts must not append"; exit 1; }
fits="$(python3 -c 'import json; print(json.dumps({"board": "a.html", "picked": 2, "text": {"1": {"h1:%d" % i: {"was": "w" * 295, "now": "n" * 295} for i in range(100)}}}))')"
[ "${#fits}" -ge 61440 ] || { echo "FAIL: the big pick is under 60 KiB: ${#fits}"; exit 1; }
c="$(post -H 'X-Design-Kit-Decision: 1' --data "$fits")"
[ "$c" = 200 ] && tail -n 1 "$tmp/decisions.jsonl" | python3 -c 'import json,sys; t=json.load(sys.stdin)["text"]["1"]; assert len(t) == 100 and all(e == {"was": "w" * 295, "now": "n" * 295} for e in t.values())' \
  || { echo "FAIL: a 60 KiB pick should be recorded whole, got $c: $(head -c 200 "$tmp/.resp")"; exit 1; }
never_served /decisions.jsonl '"picked"'

# /_note: /_decision's guards with its own header; every field clamped, unknown keys dropped; notes.jsonl never served
npost() { curl -s -o "$tmp/.resp" -w '%{http_code}' -X POST "$@" "http://127.0.0.1:$port/_note"; }
nbody="$(python3 -c '
import json
b = {"page": "/decks/a.html?x=1", "text": "y" * 2500, "evil": "dropped", "status": "addressed", "cid": "0123456789abcdef",
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
assert set(a) == set(b) == {"id", "ts", "cid", "page", "kind", "anchor", "text", "context", "status", "reply"}, (sorted(a), sorted(b))
assert (a["cid"], b["cid"]) == ("0123456789abcdef", None), (a["cid"], b["cid"])
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
big="$(python3 -c 'print("{\"text\":\"" + "x"*9216 + "\"}")')"
c="$(npost -H 'X-Design-Kit-Note: 1' --data "$big")"; [ "$c" = 413 ] || { echo "FAIL: a 9 KiB note should be 413, got $c"; exit 1; }
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
c="$(post -H 'X-Design-Kit-Decision: 1' --data '{"board":"a.html","picked":1,"text":{"1":{"h1":{"was":"w\ud83d","now":"\udc00"}}}}')"
[ "$c" = 200 ] && tail -n 1 "$tmp/decisions.jsonl" | python3 -c '
import json,sys
r=json.loads(sys.stdin.buffer.read().decode("utf-8"))
assert r["text"] == {"1": {"h1": {"was": "w?", "now": "?"}}}, r' \
  || { echo "FAIL: a text edit with a lone surrogate should be 200 and stored with ? ($c): $(tail -n 1 "$tmp/decisions.jsonl" | cut -c1-200)"; exit 1; }
deep="$(python3 -c 'print("[" * 8000)')"
c="$(npost -H 'X-Design-Kit-Note: 1' --data "$deep")"; [ "$c" = 400 ] || { echo "FAIL: 8 KiB of nesting to /_note should be 400, got $c"; exit 1; }
deep="$(python3 -c 'print("[" * 65000)')"
c="$(post -H 'X-Design-Kit-Decision: 1' --data "$deep")"; [ "$c" = 400 ] || { echo "FAIL: 64 KiB of nesting to /_decision should be 400, got $c"; exit 1; }
# one row per cid, both routes: the same send answers the row on disk and writes nothing, only the last 50 rows count, the file's lock covers the search and the write
python3 - "$here/serve.py" "$tmp" "$port" <<'PY' || { echo "FAIL: one row per cid"; exit 1; }
import http.client, importlib.util, json, os, sys, threading, time
spec = importlib.util.spec_from_file_location("dkserve", sys.argv[1]); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
root, port = sys.argv[2], int(sys.argv[3])
A, B, C = "00000000000000aa", "00000000000000bb", "00000000000000cc"
bad = []
for route, header, name, lock, body, keys in (
        ("/_decision", "X-Design-Kit-Decision", "decisions.jsonl", ".decisions.lock", {"board": "a.html", "picked": 1}, {"recorded", "cid", "ts"}),
        ("/_note", "X-Design-Kit-Note", "notes.jsonl", ".notes.lock", {"page": "/decks/a.html", "text": "t"}, {"recorded", "id", "cid", "ts"})):
    path = os.path.join(root, name)
    def check(case, got, want):
        if got != want: bad.append("  %s %s: got %r, want %r" % (route, case, got, want))
    def send(cid):
        con = http.client.HTTPConnection("127.0.0.1", port, timeout=10)
        con.request("POST", route, json.dumps(dict(body, cid=cid)), {header: "1"})
        r = con.getresponse()
        return r.status, json.loads(r.read())
    def rows():
        with open(path, encoding="utf-8") as fh: return [json.loads(line) for line in fh]
    with open(path, "rb") as fh: kept = fh.read()
    n = len(rows())
    first = send(A); row = rows()[-1]
    check("a new cid is recorded", first, (200, {k: True if k == "recorded" else row.get(k) for k in keys}))
    check("the cid is stored", (row.get("cid"), len(rows())), (A, n + 1))
    check("one row per cid", (send(A), len(rows())), (first, n + 1))
    check("a new cid writes a second row", (send(B)[0], len(rows())), (200, n + 2))
    for cid in ("a" * 15, "a" * 17, "A" * 16, "g" * 16, "a" * 16 + "\n", "", 1234567890123456, False, [A]):
        check("cid %r is refused" % (cid,), (send(cid)[0], len(rows())), (400, n + 2))
    old = {"cid": C, "ts": "2001-01-01T00:00:00Z", "id": "0badc0de"}
    with open(path, "w", encoding="utf-8") as fh:
        for r in [old] + [{"cid": None}] * 49: fh.write(json.dumps(r) + "\n")
    check("the 50th row from the end answers its own ts", (send(C), len(rows())), ((200, {k: True if k == "recorded" else old[k] for k in keys}), 50))
    with open(path, "a", encoding="utf-8") as fh: fh.write('{"cid": null}\n')
    check("the 51st is not searched", (send(C)[0], len(rows())), (200, 52))
    got = []
    threads = [threading.Thread(target=lambda: got.append(send(A))) for _ in range(4)]
    with m.locked(os.path.join(root, lock)):
        for t in threads: t.start()
        time.sleep(0.5)
        check("nothing is written while %s is held" % lock, (got, len(rows())), ([], 52))
    for t in threads: t.join()
    check("four sends that waited make one row", ([g == got[0] for g in got], got[0][0], len(rows())), ([True] * 4, 200, 53))
    with open(path, "wb") as fh: fh.write(kept)
for b in bad: print(b)
sys.exit(1 if bad else 0)
PY
# appends stop at 2 MiB: 507 with a JSON reason, the file untouched
for f in notes.jsonl decisions.jsonl; do
  cp "$tmp/$f" "$tmp/.keep"
  python3 -c '
import json,sys
with open(sys.argv[1],"a") as h:
    while h.tell() < 2*1024*1024: h.write(json.dumps({"id":"pad","cid":"00000000000000dd","page":"old.html","text":"p"*500,"status":"dismissed","consumed":True})+"\n")' "$tmp/$f"
  size="$(wc -c < "$tmp/$f" | tr -d ' ')"
  send() { if [ "$f" = notes.jsonl ]; then npost -H 'X-Design-Kit-Note: 1' --data "{\"text\":\"one more\",\"cid\":\"$1\"}"; else post -H 'X-Design-Kit-Decision: 1' --data "{\"board\":\"a.html\",\"picked\":1,\"cid\":\"$1\"}"; fi; }
  c="$(send 00000000000000dd)"; [ "$c" = 200 ] || { echo "FAIL: a send a full $f already holds should be answered, got $c"; exit 1; }
  c="$(send 00000000000000ee)"
  [ "$c" = 507 ] && python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["recorded"] is False and "MiB" in d["error"], d' "$tmp/.resp" \
    || { echo "FAIL: a post to a full $f should be 507 with a JSON reason, got $c: $(head -c 200 "$tmp/.resp")"; exit 1; }
  [ "$(wc -c < "$tmp/$f" | tr -d ' ')" = "$size" ] || { echo "FAIL: $f grew past the cap"; exit 1; }
  mv "$tmp/.keep" "$tmp/$f"
done
# a pick that cannot be written answers 500 and leaves nothing behind
mv "$tmp/decisions.jsonl" "$tmp/.keep"; mkdir "$tmp/decisions.jsonl"
for b in '{"board":"a.html","picked":1}' '{"board":"a.html","picked":1,"cid":"00000000000000aa"}'; do
  c="$(post -H 'X-Design-Kit-Decision: 1' --data "$b" || true)"
  [ "$c" = 500 ] && [ -z "$(ls -A "$tmp/decisions.jsonl")" ] && python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["recorded"] is False and d["error"], d' "$tmp/.resp" \
    || { echo "FAIL: a pick while decisions.jsonl is a folder should be a JSON 500 ($b), got $c: $(head -c 200 "$tmp/.resp")"; exit 1; }
done
rmdir "$tmp/decisions.jsonl"; mv "$tmp/.keep" "$tmp/decisions.jsonl"
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

# what the control origin refuses, on every method and route: a Host that is not localhost or an IP literal (a rebound DNS name), a service worker's script
base="http://127.0.0.1:$port"
code() { curl -s -o "$tmp/.resp" -w '%{http_code}' --max-time 2 "$@" || true; }
for n in evil.example localhost.evil "evil.example:$port" empty missing; do
  case "$n" in empty) h='Host;' ;; missing) h='Host:' ;; *) h="Host: $n" ;; esac
  for p in / /decks/a.html /_index.json /_events /_note.js; do
    c="$(code -H "$h" "$base$p")"; [ "$c" = 403 ] || { echo "FAIL: GET with Host $n is 403: $p got $c"; exit 1; }
    c="$(code -I -H "$h" "$base$p")"; [ "$c" = 403 ] || { echo "FAIL: HEAD with Host $n is 403: $p got $c"; exit 1; }
  done
  c="$(code -X POST -H "$h" --data '{}' "$base/decks/a.html")"; [ "$c" = 403 ] || { echo "FAIL: POST with Host $n is 403: got $c"; exit 1; }
done
for n in "127.0.0.1:$port" localhost "LOCALHOST:$port" "[::1]:$port" "192.0.2.7:$port"; do
  c="$(code -H "Host: $n" "$base/decks/a.html")"; [ "$c" = 200 ] || { echo "FAIL: GET with Host $n is 200: got $c"; exit 1; }
  c="$(code -I -H "Host: $n" "$base/decks/a.html")"; [ "$c" = 200 ] || { echo "FAIL: HEAD with Host $n is 200: got $c"; exit 1; }
  c="$(code -X POST -H "Host: $n" --data '{}' "$base/decks/a.html")"; [ "$c" = 501 ] || { echo "FAIL: POST with Host $n passes the Host check (501, no such route): got $c"; exit 1; }
done
for p in / /decks/a.html /_note.js; do
  c="$(code -H 'Service-Worker: script' "$base$p")"; [ "$c" = 404 ] || { echo "FAIL: Service-Worker: script is 404: GET $p got $c"; exit 1; }
  c="$(code -I -H 'Service-Worker: script' "$base$p")"; [ "$c" = 404 ] || { echo "FAIL: Service-Worker: script is 404: HEAD $p got $c"; exit 1; }
done
# a file or folder that resolves outside the docroot is 404 and unlisted; %2f is a trailing slash to http.server, which would open the index itself
mkdir -p "$tmp.out" "$tmp/decks/sub"
printf '<!doctype html><title>OUTSIDE</title><body>OUTSIDE</body>' | tee "$tmp.out/index.html" > "$tmp.out/p.html"; printf 'OUTSIDE' > "$tmp.out/p.png"
ln -s "$tmp.out/p.html" "$tmp/decks/out.html"; ln -s "$tmp.out/p.png" "$tmp/shots/out.png"; ln -s "$tmp.out" "$tmp/decks/outdir"
ln -s "$tmp.out/index.html" "$tmp/decks/sub/index.html"; ln -s a.html "$tmp/decks/in.html"
for p in /decks/out.html /shots/out.png /decks/outdir /decks/outdir/ /decks/outdir%2f /decks/outdir/p.html /decks/outdir/p.png /decks/sub/ /decks/sub%2f /decks/sub%2F /decks/%00; do
  c="$(code "$base$p")"; [ "$c" = 404 ] && ! grep -q OUTSIDE "$tmp/.resp" || { echo "FAIL: symlink leaving the docroot is 404: GET $p got $c"; exit 1; }
  c="$(code -I "$base$p")"; [ "$c" = 404 ] || { echo "FAIL: symlink leaving the docroot is 404: HEAD $p got $c"; exit 1; }
done
case "$(curl -s "$base/_index.json")" in *OUTSIDE*) echo "FAIL: /_index.json gives the title of a page outside the docroot"; exit 1 ;; *'"path": "decks/in.html"'*) ;; *) echo "FAIL: /_index.json lost a link that stays inside the docroot"; exit 1 ;; esac
c="$(code "$base/decks/in.html")"; [ "$c" = 200 ] && grep -q '<h1>a</h1>' "$tmp/.resp" || { echo "FAIL: a symlink that stays inside the docroot is still served: got $c"; exit 1; }
rm -rf "$tmp.out" "$tmp/decks/out.html" "$tmp/decks/outdir" "$tmp/decks/in.html" "$tmp/decks/sub" "$tmp/shots/out.png"
# an XML type opened directly runs no script: the policy, GET and HEAD; other types carry none
heads() { curl -s -D - -o /dev/null --max-time 2 "$@" | tr -d '\r' || true; }
for f in x.svg X.SVG x.xhtml x.xml x.pdf; do printf '<svg xmlns="http://www.w3.org/2000/svg"><script>1</script></svg>' > "$tmp/decks/$f"; done
xml="Content-Security-Policy: default-src 'none'; style-src 'unsafe-inline'; img-src data:; sandbox"
for f in x.svg X.SVG x.xhtml x.xml; do
  for m in "" -I; do hd="$(heads $m "$base/decks/$f")"; [ "$(printf '%s\n' "$hd" | grep -cxF "$xml")" = 1 ] || { echo "FAIL: $f opened directly carries the sandbox policy ($m): $hd"; exit 1; }; done
done
for f in /decks/x.pdf /shots/one.png; do hd="$(heads "$base$f")"; case "$hd" in *" 200 "*) ;; *) echo "FAIL: $f is 200: $hd"; exit 1 ;; esac; case "$hd" in *Content-Security-Policy*) echo "FAIL: $f carries no sandbox policy: $hd"; exit 1 ;; esac; done
# every answer carries the common headers and CORP same-origin, once each
has_common() {
  local h
  for h in 'X-Content-Type-Options: nosniff' 'Referrer-Policy: no-referrer' 'X-DNS-Prefetch-Control: off' 'Cross-Origin-Resource-Policy: same-origin'; do
    [ "$(printf '%s\n' "$2" | grep -cxF "$h")" = 1 ] || { echo "FAIL: every answer carries one $h: $1: $2"; exit 1; }
  done
}
for p in / /decks/a.html /_index.json /_notes /_checks /_events /_note.js /shots/one.png /decks /auth/walk.json /nope; do has_common "GET $p" "$(heads "$base$p")"; done
has_common "HEAD a page" "$(heads -I "$base/decks/a.html")"
has_common "a 304" "$(heads -H 'If-Modified-Since: Fri, 01 Jan 2100 00:00:00 GMT' "$base/shots/one.png")"
has_common "a 403 on Host" "$(heads -H 'Host: evil.example' "$base/")"
has_common "a refused POST" "$(heads -X POST --data '{}' "$base/_note")"
has_common "a recorded POST" "$(heads -X POST -H 'X-Design-Kit-Decision: 1' --data '{"board":"a.html","picked":1}' "$base/_decision")"
has_common "an unknown method" "$(heads -X PUT "$base/")"
# _cors drops CORP same-origin from that answer alone, and nothing else
python3 - "$here/serve.py" "$tmp" <<'PY' || { echo "FAIL: Handler._cors drops Cross-Origin-Resource-Policy and keeps the common headers"; exit 1; }
import http.client, importlib.util, sys, threading, time
spec = importlib.util.spec_from_file_location("dkserve", sys.argv[1]); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
class H(m.Handler):
    root, state, protocol_version = sys.argv[2], {"version": 0, "last": time.monotonic(), "streams": 0}, "HTTP/1.1"
    def do_GET(self):
        self._cors = self.path == "/decks/x.svg"
        super().do_GET()
srv = m.ThreadingHTTPServer(("127.0.0.1", 0), H); srv.daemon_threads = True
threading.Thread(target=srv.serve_forever, daemon=True).start()
con = http.client.HTTPConnection("127.0.0.1", srv.server_port, timeout=5)
got = []
for method, path in (("GET", "/decks/x.svg"), ("HEAD", "/shots/one.png")):
    con.request(method, path); r = con.getresponse(); r.read()
    got.append((r.status, r.getheader("Cross-Origin-Resource-Policy"), r.getheader("X-Content-Type-Options"), r.getheader("Content-Security-Policy")))
srv.shutdown()
assert got == [(200, None, "nosniff", m.isolate.XML_POLICY), (200, "same-origin", "nosniff", None)], got
PY
rm -f "$tmp/decks/x.svg" "$tmp/decks/X.SVG" "$tmp/decks/x.xhtml" "$tmp/decks/x.xml" "$tmp/decks/x.pdf"

# token badge: a stamped page vs <docroot>/design-system/tokens.json; the design-system/ folder is not a gallery group
dr="$tmp.ds/.cc-artifacts/design-kit"
mkdir -p "$dr/design-system"; printf '{"color":{"a":{"$value":"#000"}}}' > "$dr/design-system/tokens.json"
printf '<!doctype html><html><head><title>Kit</title></head><body>k</body></html>' > "$dr/design-system/kit.html"
sha="$(python3 -c 'import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest()[:12])' "$dr/design-system/tokens.json")"
mkdir -p "$dr/decks"
printf '<!doctype html><html><head><title>Cur</title><meta name="design-kit-tokens" content="%s none"></head><body>x</body></html>' "$sha" > "$dr/decks/cur.html"
printf '<!doctype html><html><head><title>Old</title><meta name="design-kit-tokens" content="000000000000 none"></head><body>x</body></html>' > "$dr/decks/old.html"
port2=$(( 20000 + RANDOM % 10000 ))
bash "$here/preview.sh" --docroot "$dr" --port "$port2" >/dev/null; sleep 0.4
idx="$(curl -s "http://127.0.0.1:$port2/_index.json")"
python3 -c '
import json,sys; d={p["path"]:p["tokens"] for p in json.loads(sys.argv[1])}
assert d["decks/cur.html"]["current"] is True, d
assert d["decks/old.html"]["current"] is False, d
assert not [p for p in d if p.startswith("design-system/")], d' "$idx" || { echo "FAIL: _index.json tokens: $idx"; exit 1; }
gal2="$(curl -s "http://127.0.0.1:$port2/")"
case "$gal2" in *"tokens current"*"tokens moved since build"*|*"tokens moved since build"*"tokens current"*) ;; *) echo "FAIL: badges missing in gallery"; exit 1 ;; esac
bash "$here/preview.sh" --docroot "$dr" --stop >/dev/null
# plugins before 2026-11-14 kept design-system/ at the project root: read it while the docroot holds none
mkdir -p "$tmp.ds/design-system"; mv "$dr/design-system/tokens.json" "$tmp.ds/design-system/tokens.json"
python3 - "$here/serve.py" "$dr" "$sha" <<'PY' || { echo "FAIL: the badge did not fall back to <project>/design-system/tokens.json"; exit 1; }
import importlib.util, sys
spec = importlib.util.spec_from_file_location("dkserve", sys.argv[1]); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
assert m._tokens_sha(sys.argv[2]) == sys.argv[3], m._tokens_sha(sys.argv[2])
PY
rm -rf "$tmp.ds"

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
  has_common "the cookie page" "$hdr"
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
