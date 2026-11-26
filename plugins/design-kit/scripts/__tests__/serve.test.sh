#!/usr/bin/env bash
# Drives serve.py through preview.sh: the viewer's document and headers at every page URL, its two files as the server started with them, the raw page's 303 (query, Sec-Fetch-Site, headless, ?static=1), the gallery (its address, reconnect client, sandboxed inert thumbnails, markup in what it lists, policy), /_index.json, SSE (the gallery's, a page's own), never-served paths (GET and HEAD, origin- and absolute-form), the Host rule, symlinks leaving the docroot or to a never-served file, the headers of every answer, SVG/XHTML/XML policy, /_decision (stored through picks.py with the server's own prompt), /_note (clamps, text required), both: body limits, lone surrogates, a cid, one row per cid under the file's lock, the 2 MiB cap, no symlink, a failed write; /_page, /_c/ (what a segment opens, the injected client, the policy on every file, links, 303, static), /_allow, the Origin of every POST; /_notes, token badges, stop.
# LAN key: lan_gate and without_key as a unit, a symlinked key file, then end to end from this machine's own network address (a non-loopback peer), /_page, /_c/ and /_allow included; that half skips without one.
# Misses: what a browser does with a /_c/ answer (viewer.test.sh, attack.test.sh); the reconnect bar, the cookie page, and Tab past the thumbnails in a browser (each run by hand in Chrome: 2026-11-12, the last 2026-11-25); a real second device, never run.
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
# the gallery's client reconnects: a role=status bar while the stream is down, a retry timer, no external asset; none for a headless browser or ?static=1
snip="$(printf '%s' "$gal" | python3 -c 'import re,sys;m=re.search(r"<script data-design-kit-reload>.*?</script>",sys.stdin.read(),re.S);print(m.group(0) if m else "")')"
for want in '"role","status"' setTimeout location.reload; do
  case "$snip" in *"$want"*) ;; *) echo "FAIL: the gallery's client lacks $want (reconnect bar, retry, reload): $snip"; exit 1 ;; esac
done
case "$snip" in *"src="*|*"href="*|*"http"*|*"//"*) echo "FAIL: the gallery's client loads an external asset: $snip"; exit 1 ;; esac
case "$(curl -s -A "Mozilla/5.0 HeadlessChrome/130" "http://127.0.0.1:$port/")$(curl -s "http://127.0.0.1:$port/_gallery?static=1")" in *"<script"*) echo "FAIL: the gallery carries its reload client for a headless UA or ?static=1"; exit 1 ;; *"Deck A"*"Deck A"*) ;; *) echo "FAIL: no gallery for a headless UA or ?static=1"; exit 1 ;; esac
# a page URL answers the viewer, or sends a capture of this machine to the static segment; the gallery has an address of its own and runs nothing of a page's
mkdir -p "$tmp/motion/y" "$tmp/motion/z"
printf '<!doctype html><html><head><title>&lt;b&gt; &amp; "two"</title></head><body><h1>own</h1></body></html>' | tee "$tmp/motion/y/index.html" "$tmp/motion/z/index.htm" > "$tmp/decks/q\"<b>.html"
python3 - "$here" "$tmp" "$port" <<'PY' || exit 1
import base64, hashlib, html.parser, http.client, importlib.util, json, os, re, sys
from urllib.parse import quote
here, root, port = sys.argv[1], sys.argv[2], int(sys.argv[3])
spec = importlib.util.spec_from_file_location("dkserve", here + "/serve.py"); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
host, failed = "127.0.0.1:%d" % port, []
def eq(claim, got, want):
    if got != want: failed.append("FAIL: %s: got %.500r, want %.500r" % (claim, got, want))
def ask(path, method="GET", **headers):
    con = http.client.HTTPConnection("127.0.0.1", port, timeout=5)
    con.request(method, path, headers={k.replace("_", "-"): v for k, v in headers.items()})
    r = con.getresponse()
    return r.status, r.headers, r.read()
def parsed(body):
    tags, texts = [], {}
    class P(html.parser.HTMLParser):
        def handle_starttag(self, tag, attrs): tags.append((tag, dict(attrs)))
        def handle_data(self, data): texts.setdefault(tags[-1][0] if tags else "", data)
    P().feed(body.decode())
    return tags, texts
def document(page, *notes):
    return [("html", {"lang": "en"}), ("head", {}), ("meta", {"charset": "utf-8"}), ("meta", {"name": "viewport", "content": "width=device-width,initial-scale=1"}), ("title", {}), ("link", {"rel": "stylesheet", "href": "/_viewer.css"}),
            ("body", {"data-page": page, "data-version": str(m.SERVER_VERSION), "data-rules": m.RULES}), ("header", {"id": "bar"}), ("a", {"href": "/_gallery"}), ("h1", {"id": "title"}), ("span", {"id": "chip"}),
            ("button", {"type": "button", "id": "network", "hidden": None}), ("button", dict({"type": "button", "id": "notes"}, **{n: None for n in notes})),
            ("div", {"id": "strips", "aria-live": "polite"}), ("div", {"id": "drawer", "hidden": None}), ("main", {"id": "frame"}), ("script", {"src": "/_viewer.js"})]
def viewed(path, **headers):
    """The page a viewer answer names, or the answer's status."""
    status, _, body = ask(path, **headers)
    found = re.search(rb'<body data-page="([^"]*)"', body)
    return found.group(1).decode() if status == 200 and found else status

page = "decks/a.html"
status, headers, body = ask("/" + page)
tags, texts = parsed(body)
eq("a page URL answers the viewer's document", (status, tags), (200, document(page)))
eq("with the page's title and the bar's words, and nothing of the page", (texts, b"<h1>a</h1>" in body), ({"title": "Deck A", "a": "Gallery", "h1": "Deck A", "button": "Network"}, False))
eq("the viewer is handed the rules a pick, a frame and a drawn character go by", json.loads(dict(tags)["body"].get("data-rules", "null")), {
    "knobs": {"space": [0, 64, "spacing base {}px"], "radius": [0, 64, "corner radius {}px"], "hue": [0, 360, "accent hue {}°"], "type": [0.5, 3, "type scale ×{}"], "density": [0.5, 3, "density ×{}"], "scheme": ["light", "dark", "{} scheme"]},
    "decimals": 2, "picked": [1, 99], "scope": "[1-9][0-9]?", "path": "[a-z0-9:/-]{1,200}", "edits": 100, "chars": 500,
    "hidden": r"\p{C}\p{Zl}\p{Zp}\u{115F}-\u{1160}\u{180B}-\u{180F}\u{2800}-\u{2800}\u{3164}-\u{3164}\u{FE00}-\u{FE0F}\u{FFA0}-\u{FFA0}\u{E0100}-\u{E01EF}",
    "sandbox": "allow-scripts allow-forms allow-modals allow-downloads", "gallery": "/_gallery"})
eq("the viewer's headers", [headers.get_all(h) for h in ("Content-Type", "Content-Security-Policy", "Cross-Origin-Opener-Policy", "Cache-Control")], [["text/html; charset=utf-8"], [m.isolate.viewer_policy(host)], ["same-origin"], ["no-store"]])
again = ask("/" + page, "HEAD")
eq("HEAD of a page URL answers the viewer's headers", (again[0], again[1]["Content-Length"], again[1]["Content-Security-Policy"], again[2]), (200, str(len(body)), m.isolate.viewer_policy(host), b""))
status, headers, body = ask("/" + page, Host="192.0.2.7:%d" % port)
eq("at an address no write route takes the viewer hides Notes", (status, parsed(body)[0], headers["Content-Security-Policy"]), (200, document(page, "hidden"), m.isolate.viewer_policy("192.0.2.7:%d" % port)))
odd = 'decks/q"<b>.html'
tags, texts = parsed(ask("/" + quote(odd))[2])
eq("a page name and a title holding markup are text in the viewer", (tags, texts.get("title"), texts.get("h1")), (document(odd), '<b> & "two"', '<b> & "two"'))
eq("a missing page is 404", [ask("/decks/none.html", method)[0] for method in ("GET", "HEAD")], [404, 404])
for path, want in (("/motion/y/", "motion/y/index.html"), ("/motion/y%2f", "motion/y/index.html"), ("/motion/y%2F", "motion/y/index.html"), ("/motion/y/index.html", "motion/y/index.html"), ("/motion/z/", "motion/z/index.htm"), ("/decks%2fa.html", page), ("/decks/../decks//a.html", page)):
    eq("a page is named by its file path: %s" % path, viewed(path), want)
eq("a folder asked without its slash is sent to it", (ask("/motion/y")[0], ask("/motion/y")[1]["Location"]), (301, "/motion/y/"))

HEADLESS = "Mozilla/5.0 (X11) HeadlessChrome/130"
static = re.compile(r"/_c/([\w-]{22}\.[\w-]+\.s)/decks/a\.html")
for site, want in ((None, "static"), ("none", "static"), ("cross-site", page), ("same-site", page), ("same-origin", page), ("", page)):
    sent = {} if site is None else {"Sec_Fetch_Site": site}
    for claim, path, more in (("?static=1", "/%s?static=1" % page, {}), ("a headless browser", "/" + page, {"User_Agent": HEADLESS})):
        for method in ("GET", "HEAD"):
            status, headers, _ = ask(path, method, **dict(more, **sent))
            got = "static" if status == 303 and static.fullmatch(headers["Location"] or "") else viewed(path, **dict(more, **sent)) if status == 200 else status
            eq("%s with Sec-Fetch-Site %s gets the %s: %s" % (claim, site, "static segment" if want == "static" else "viewer", method), got, want)
status, headers, _ = ask("/decks/a.html?capture&static=1&key=K&a=%20b+c&st%61tic=1&static=0")
at, _, query = (headers["Location"] or "").partition("?")
eq("the 303 keeps the query as it was typed, static and key left out", (status, bool(static.fullmatch(at)), query), (303, True, "capture&a=%20b+c"))
eq("only static=1 asks for the raw page", [viewed("/decks/a.html?" + q) for q in ("static=10", "xstatic=1", "static=0", "static")], [page] * 4)
eq("a folder's index is raw too", [re.sub(r"/_c/[^/]+", "", ask(p, User_Agent=HEADLESS)[1]["Location"] or "") for p in ("/motion/y/", "/motion/y%2f")], ["/motion/y/index.html"] * 2)
status, headers, body = ask(at or "/")
with open(os.path.join(root, page), "rb") as fh: raw = fh.read()
eq("that static segment is the page under its static policy, with the in-frame client and no other script of the plugin's", (status, headers["Content-Security-Policy"], body.replace(m.FRAME_TAG, b"")), (200, m.isolate.page_policy("s", page, (at.split("/") + ["", ""])[2], [], host), raw))
status, headers, _ = ask("/decks/a.html?_outline=h1", User_Agent=HEADLESS)
eq("?_outline= is a query field like any other, and /_note.js is gone", (status, b"data-design-kit-outline" in ask(headers["Location"] or "/")[2], ask("/_note.js")[0]), (303, False, 404))
for path, name, ctype in (("/_viewer.js", "viewer.js", "text/javascript; charset=utf-8"), ("/_viewer.css", "viewer.css", "text/css; charset=utf-8")):
    with open(os.path.join(here, name), "rb") as fh: want = fh.read()
    status, headers, body = ask(path)
    eq("%s is the plugin's file" % path, (status, headers["Content-Type"], body), (200, ctype, want))

def gallery(path):
    status, headers, body = ask(path)
    tags, _ = parsed(body)
    scripts = re.findall(r"<script[^>]*>(.*?)</script>", body.decode(), re.S)
    sha = base64.b64encode(hashlib.sha256(scripts[0].encode()).digest()).decode() if scripts else ""
    frames = [a for t, a in tags if t == "iframe"]
    eq("the gallery is at %s" % path, (status, b"<title>design-kit gallery</title>" in body, len(frames) >= 4, headers["Cross-Origin-Opener-Policy"]), (200, True, True, "same-origin"))
    eq("%s: every thumbnail carries sandbox and a framed /_c/ src" % path, [a for a in frames if a.get("sandbox") != "allow-scripts" or not re.match(r"/_c/[\w-]{22}\.[\w-]+/", a.get("src", ""))], [])
    eq("%s: no thumbnail takes Tab" % path, [a for a in frames if "inert" not in a or a.get("tabindex") != "-1"], [])
    eq("%s: a thumbnail's src is its page" % path, {ask(a["src"], Sec_Fetch_Dest="iframe")[0] for a in frames}, {200})
    eq("%s: the policy allows its one inline script by its SHA-256" % path, (len(scripts), headers["Content-Security-Policy"]), (1, m.isolate.gallery_policy(host, sha)))
    eq("%s: no unsafe-inline in its script-src" % path, re.findall(r"script-src ([^;]*)", headers["Content-Security-Policy"] or ""), ["'sha256-%s'" % sha])
    eq("%s: a card's link opens a page of any name" % path, [viewed(a["href"]) for t, a in tags if t == "a" and a.get("class") == "card" and "q%22" in a["href"]], [odd.replace('"', "&quot;").replace("<", "&lt;").replace(">", "&gt;")])
for path in ("/", "/index.html", "/_gallery"):
    gallery(path)
os.makedirs(os.path.join(root, "<u>dir"))
with open(os.path.join(root, "<u>dir", "<u>file.html"), "w") as fh: fh.write("<title>&lt;u&gt;title</title>")
with open(os.path.join(root, "workshop.json"), "w") as fh: json.dump({"scratch": {"slug": "<u>slug", "kept": True}}, fh)
body = ask("/_gallery")[2].decode()
eq("a folder, a file, a title and a flow step holding markup are text in the gallery", ("<u>" in body, [html.escape(w) in body for w in ("<u>dir", "<u>dir/<u>file.html", "<u>title", "<u>slug")]), (False, [True] * 4))
for name in ("<u>dir/<u>file.html", "workshop.json"): os.unlink(os.path.join(root, name))
os.rmdir(os.path.join(root, "<u>dir"))
eq("HEAD of the gallery answers its headers", [(ask(p, "HEAD")[0], ask(p, "HEAD")[1]["Content-Length"]) for p in ("/", "/_gallery")], [(200, str(len(ask("/")[2])))] * 2)
with open(os.path.join(root, "index.html"), "w") as fh: fh.write("<h1>mine</h1>")
eq("with an index.html in the docroot / is that page", [viewed(p) for p in ("/", "/index.html")], ["index.html"] * 2)
gallery("/_gallery")
os.unlink(os.path.join(root, "index.html"))
print("\n".join(failed), end="\n" if failed else "")
sys.exit(1 if failed else 0)
PY
rm -rf "$tmp/motion" "$tmp/decks/q\"<b>.html"
idx="$(curl -s "http://127.0.0.1:$port/_index.json")"
case "$idx" in *'"path": "decks/a.html"'*) ;; *) echo "FAIL: _index.json: $idx"; exit 1 ;; esac
# /_events says reload at any change; with ?page= at a change of that page or of a file in its own folder alone, and gone when its file is deleted
python3 - "$here" "$tmp" "$port" <<'PY' || exit 1
import http.client, importlib.util, os, sys, threading, time
from urllib.parse import quote
here, root, port = sys.argv[1], sys.argv[2], int(sys.argv[3])
spec = importlib.util.spec_from_file_location("dkserve", here + "/serve.py"); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
said, failed = {}, []
def eq(claim, got, want):
    if got != want:
        failed.append(claim)
        print("FAIL: %s: got %.500r, want %.500r" % (claim, got, want), flush=True)
def put(name, body, like=None):
    """Saves a file in one step; like: keeps that mtime, in ns."""
    path = os.path.join(root, name)
    tmp = os.path.join(os.path.dirname(path), ".put")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(tmp, "w") as fh: fh.write(body)
    if like: os.utime(tmp, ns=(like, like))
    os.replace(tmp, path)
def answer(query=""):
    con = http.client.HTTPConnection("127.0.0.1", port, timeout=5)
    con.request("GET", "/_events" + query)
    return con.getresponse()
def listen(page=None):
    r, said[page] = answer("" if page is None else "?page=" + quote(page, safe="")), []
    eq("%s has a stream" % page, (r.status, r.headers["Content-Type"]), (200, "text/event-stream"))
    def read():
        for line in r:
            if line.startswith(b"data: "): said[page].append(line[6:].decode().strip())
    threading.Thread(target=read, daemon=True).start()
def heard(*first, more=0.0):
    """What each stream that said anything said, the gallery's last word alone, more seconds after each of first did."""
    until = time.monotonic() + 6
    while time.monotonic() < until and not all(said[p] for p in first): time.sleep(0.05)
    time.sleep(more)
    got = {p: said[p][:] if p else said[p][-1:] for p in said if said[p]}
    for p in said: del said[p][:]
    return got
TWO_POLLS = 1.6

for name in ("decks/b.html", "motion/x/index.html", "motion/x/other.html", "motion/x/style.css", "motion/x/sub/n.js", "motion/y/index.html", "decks/ino.html", "decks/size.html", "decks/time.html"):
    put(name, "<html><body>saved</body></html>")
for page in (None, "decks/a.html", "decks/b.html", "motion/x/index.html", "motion/y/index.html", "decks/ino.html", "decks/size.html", "decks/time.html"):
    listen(page)
heard(more=TWO_POLLS)
for name in ("decks/b.html", "motion/x/.put.css", "motion/x/.d/n.js", "motion/x/other.html"):
    put(name, "<html><body>changed</body></html>")
got = heard(None, "decks/b.html", more=TWO_POLLS)
eq("a save reaches the page's own stream, once, and the gallery's", (got.pop("decks/b.html", None), got.pop(None, None)), (["reload"], ["reload"]))
eq("saving another page sends nothing on this page's stream, in its own folder too, nor does a dot file there", got, {})
put("motion/x/style.css", "i {}")
eq("saving motion/x/style.css reloads motion/x/index.html only", heard(None, "motion/x/index.html", more=TWO_POLLS), {None: ["reload"], "motion/x/index.html": ["reload"]})
stat_of = lambda name: os.stat(os.path.join(root, "decks", name + ".html"))
was = {name: stat_of(name) for name in ("ino", "size", "time")}
put("decks/ino.html", "<html><body>again</body></html>", like=was["ino"].st_mtime_ns)
eq("the inode alone moved", [getattr(stat_of("ino"), k) == getattr(was["ino"], k) for k in ("st_ino", "st_size", "st_mtime_ns")], [False, True, True])
with open(os.path.join(root, "decks/size.html"), "a") as fh: fh.write(" ")
os.utime(fh.name, ns=(was["size"].st_mtime_ns,) * 2)
os.utime(os.path.join(root, "decks/time.html"), ns=(was["time"].st_mtime_ns + 1000,) * 2)
put("motion/x/sub/n.js", "1")
os.unlink(os.path.join(root, "decks/b.html"))
got = heard("decks/ino.html", "decks/size.html", "decks/time.html", "motion/x/index.html", "decks/b.html")
got.pop(None, None)
eq("an inode, a size or an mtime alone, and a file below the page's own folder, is a change; a deleted file is gone", {page: lines[-1] for page, lines in got.items()},
   {"decks/ino.html": "reload", "decks/size.html": "reload", "decks/time.html": "reload", "motion/x/index.html": "reload", "decks/b.html": "gone"})
put("decks/b.html", "<html><body>back</body></html>")
eq("a page that returns reloads, after one gone", heard("decks/b.html").get("decks/b.html"), ["reload"])
eq("no stream for what is not a page", {q: answer(q).status for q in ("?page=decks/none.html", "?page=", "?page=motion/x", "?page=motion/x/style.css", "?page=../serve.py", "?page=/decks/a.html")}, dict.fromkeys(("?page=decks/none.html", "?page=", "?page=motion/x", "?page=motion/x/style.css", "?page=../serve.py", "?page=/decks/a.html"), 404))
walked, walk = [], os.walk
m.os.walk = lambda top, **more: (walked.append(os.path.relpath(top, root)), walk(top, **more))[1]
m.page_state(root, "decks/a.html"); m.page_state(root, "reviews/r.html")
eq("a page with no folder of its own walks nothing", walked, [])
m.page_state(root, "motion/x/index.html")
eq("a page with one walks that folder alone", walked, ["motion/x"])
sys.exit(1 if failed else 0)
PY
rm -rf "$tmp/motion" "$tmp/decks/ino.html" "$tmp/decks/size.html" "$tmp/decks/time.html"
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
# /_decision: loopback + header + size + JSON, append-only; a row holds what picks.py keeps (its bounds: picks.test.sh) and the server's own prompt
post() { curl -s -o "$tmp/.resp" -w '%{http_code}' -X POST "$@" "http://127.0.0.1:$port/_decision"; }
# with_cid <object>: it with a cid no other send holds
with_cid() { printf '{"cid":"%04x%04x%04x%04x",%s' $RANDOM $RANDOM $RANDOM $RANDOM "${1#\{}"; }
c="$(post -H 'X-Design-Kit-Decision: 1' -H 'Content-Type: application/json' --data '{"cid":"00000000000000f1","board":"a.html","picked":1,"knobs":{"all":{"hue":400,"evil":"x"}},"text":{"1":{"h1":{"was":"Old","now":"New","evil":"x"}}},"prompt":"POSTED","evil":"x","v":9,"ts":"x","consumed":true}')"
[ "$c" = 200 ] || { echo "FAIL: decision accept http $c: $(cat "$tmp/.resp")"; exit 1; }
python3 - "$tmp/decisions.jsonl" <<'PY' || { echo "FAIL: posted prompt never stored, every other field as picks.py keeps it: $(cat "$tmp/decisions.jsonl" 2>/dev/null)"; exit 1; }
import json, re, sys
row = json.loads(open(sys.argv[1], encoding="utf-8").read())
assert re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ", row.pop("ts")), row
assert row == {"v": 2, "cid": "00000000000000f1", "board": "a.html", "picked": 1, "knobs": {"all": {"hue": 360}}, "text": {"1": {"h1": {"was": "Old", "now": "New"}}},
               "prompt": "From the design board \"a.html\", implement artboard 1. Update design-kit in this session to read adjustments and text edits.", "consumed": False}, row
PY
c="$(post -H 'Content-Type: application/json' --data '{"board":"a.html"}')"; [ "$c" = 403 ] || { echo "FAIL: missing header should be 403, got $c"; exit 1; }
big="$(python3 -c 'print("{\"board\":\"a.html\",\"prompt\":\"" + "x"*70000 + "\"}")')"
c="$(post -H 'X-Design-Kit-Decision: 1' --data "$big")"; [ "$c" = 413 ] || { echo "FAIL: a 70 KiB pick should be 413, got $c"; exit 1; }
c="$(post -H 'X-Design-Kit-Decision: 1' --data 'not json')"; [ "$c" = 400 ] || { echo "FAIL: bad json should be 400, got $c"; exit 1; }
c="$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'X-Design-Kit-Decision: 1' --data '{}' "http://127.0.0.1:$port/decks/a.html")"; [ "$c" = 501 ] || { echo "FAIL: POST elsewhere should be 501, got $c"; exit 1; }
ok_body='{"board":"a.html","picked":2,"prompt":"planted"}'
c="$(post -H 'X-Design-Kit-Decision: 1' -H 'Host: attacker.example' --data "$ok_body")"; [ "$c" = 403 ] || { echo "FAIL: a foreign Host should be 403, got $c"; exit 1; }
c="$(post -H 'X-Design-Kit-Decision: 1' -H 'Origin: http://attacker.example' --data "$ok_body")"; [ "$c" = 403 ] || { echo "FAIL: a foreign Origin should be 403, got $c"; exit 1; }
c="$(post -H 'X-Design-Kit-Decision: 1' -H "Origin: http://127.0.0.1:$port" --data "$(with_cid '{"board":"a.html","picked":3}')")"; [ "$c" = 200 ] || { echo "FAIL: the page's own Origin should be 200, got $c"; exit 1; }
c="$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'X-Design-Kit-Decision: 1' --data "$(with_cid '{"board":"a.html","picked":4}')" "http://localhost:$port/_decision")"; [ "$c" = 200 ] || { echo "FAIL: localhost should be 200, got $c"; exit 1; }
c="$(post -H 'X-Design-Kit-Decision: 1' --data "$(with_cid '{"board":"a\ud83d.html","picked":5}')")"
[ "$c" = 400 ] && python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["recorded"] is False and d["error"].startswith("board must be"), d' "$tmp/.resp" \
  || { echo "FAIL: a board picks.py refuses should be 400 with its reason, got $c: $(head -c 200 "$tmp/.resp")"; exit 1; }
[ "$(wc -l < "$tmp/decisions.jsonl" | tr -d ' ')" = 3 ] || { echo "FAIL: rejected posts must not append"; exit 1; }
fits="$(python3 -c 'import json; print(json.dumps({"cid": "00000000000000f2", "board": "a.html", "picked": 2, "text": {"1": {"h1:%d" % i: {"was": "w" * 295, "now": "n" * 295} for i in range(100)}}}))')"
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
c="$(npost -H 'X-Design-Kit-Note: 1' -H "Origin: http://127.0.0.1:$port" --data '{"cid":"00000000000000f3","page":"/decks/a.html","text":"page note","anchor":"no"}')"
[ "$c" = 200 ] || { echo "FAIL: a page note from the page's own Origin should be 200, got $c"; exit 1; }
python3 - "$tmp/notes.jsonl" <<'PY' || { echo "FAIL: notes.jsonl rows: $(cat "$tmp/notes.jsonl" 2>/dev/null)"; exit 1; }
import json, re, sys
a, b = [json.loads(l) for l in open(sys.argv[1], encoding="utf-8")]
assert set(a) == set(b) == {"id", "ts", "cid", "page", "kind", "anchor", "text", "context", "status", "reply"}, (sorted(a), sorted(b))
assert (a["cid"], b["cid"]) == ("0123456789abcdef", "00000000000000f3"), (a["cid"], b["cid"])
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
for b in '{"context":{}}' '{"text":"   "}' '{"page":"/decks/a.html","anchor":{"selector":"h1"}}'; do
  c="$(npost -H 'X-Design-Kit-Note: 1' --data "$(with_cid "$b")")"; [ "$c" = 400 ] && grep -q 'a note needs text' "$tmp/.resp" || { echo "FAIL: a note without text ($b) should be 400, got $c: $(cat "$tmp/.resp")"; exit 1; }
done
[ "$(wc -l < "$tmp/notes.jsonl" | tr -d ' ')" = 2 ] || { echo "FAIL: a note without text was recorded"; exit 1; }
# numbers clamp to +-1e7; NaN and Infinity read as 0
c="$(npost -H 'X-Design-Kit-Note: 1' --data "$(with_cid '{"page":"/decks/n.html","text":"big","anchor":{"selector":"p","rect":{"x":1e308,"y":-1e308,"w":3,"h":1e999}},"context":{"viewport":{"w":3e9,"h":NaN}}}')")"
[ "$c" = 200 ] && tail -n 1 "$tmp/notes.jsonl" | python3 -c 'import json,sys; r=json.load(sys.stdin); assert r["anchor"]["rect"]=={"x":10000000,"y":-10000000,"w":3,"h":0} and r["context"]["viewport"]=={"w":10000000,"h":0}, (r["anchor"]["rect"], r["context"]["viewport"])' \
  || { echo "FAIL: note numbers are not clamped to +-1e7 ($c): $(tail -n 1 "$tmp/notes.jsonl" | cut -c1-300)"; exit 1; }
# a folder's index page lists what was filed under the folder's own name too, and nothing else does
for p in motion/w motion/w/index.html motion/w/other.html motion/ww; do
  c="$(npost -H 'X-Design-Kit-Note: 1' --data "$(with_cid '{"page":"/'"$p"'","text":"at '"$p"'"}')")"; [ "$c" = 200 ] || { echo "FAIL: a note on $p should be 200, got $c"; exit 1; }
done
for q in "motion/w/index.html=at motion/w,at motion/w/index.html" "motion/w/index.htm=at motion/w" "motion/w=at motion/w" "motion/w/other.html=at motion/w/other.html"; do
  got="$(curl -s "http://127.0.0.1:$port/_notes?page=/${q%%=*}" | python3 -c 'import json,sys; print(",".join(r["text"] for r in json.load(sys.stdin)))')"
  [ "$got" = "${q#*=}" ] || { echo "FAIL: /_notes for ${q%%=*}: got $got, want ${q#*=}"; exit 1; }
done
# a lone surrogate (a page slicing through an emoji) is stored as ?, and the post gets its answer
c="$(npost -H 'X-Design-Kit-Note: 1' --data "$(with_cid '{"page":"/decks/s\ud83d.html","text":"cut \ud83d","anchor":{"selector":"p\udc00","tag":"p\ud83d","text":"\ud83d","rect":{}},"context":{"theme":"\ud83d","console":["e\ud83d"]}}')")"
[ "$c" = 200 ] && tail -n 1 "$tmp/notes.jsonl" | python3 -c '
import json,sys
r=json.loads(sys.stdin.buffer.read().decode("utf-8")); a=r["anchor"]
assert (r["page"], r["text"], a["selector"], a["tag"], a["text"], r["context"]["theme"], r["context"]["console"]) == ("decks/s?.html", "cut ?", "p?", "p?", "?", "?", ["e?"]), r' \
  || { echo "FAIL: a note with a lone surrogate should be 200 and stored with ? ($c): $(tail -n 1 "$tmp/notes.jsonl" | cut -c1-200)"; exit 1; }
c="$(post -H 'X-Design-Kit-Decision: 1' --data "$(with_cid '{"board":"a.html","picked":1,"text":{"1":{"h1":{"was":"w\ud83d","now":"\udc00"}}}}')")"
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
A, B, C, NONE = "00000000000000aa", "00000000000000bb", "00000000000000cc", object()
bad = []
for route, header, name, lock, body, keys in (
        ("/_decision", "X-Design-Kit-Decision", "decisions.jsonl", ".decisions.lock", {"board": "a.html", "picked": 1}, {"recorded", "cid", "ts"}),
        ("/_note", "X-Design-Kit-Note", "notes.jsonl", ".notes.lock", {"page": "/decks/a.html", "text": "t"}, {"recorded", "id", "cid", "ts"})):
    path = os.path.join(root, name)
    def check(case, got, want):
        if got != want: bad.append("  %s %s: got %r, want %r" % (route, case, got, want))
    def send(cid):
        con = http.client.HTTPConnection("127.0.0.1", port, timeout=10)
        con.request("POST", route, json.dumps(body if cid is NONE else dict(body, cid=cid)), {header: "1"})
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
    for cid in ("a" * 15, "a" * 17, "A" * 16, "g" * 16, "a" * 16 + "\n", "", 1234567890123456, False, [A], None, NONE):
        got = send(cid)
        check("cid %s is refused" % ("left out" if cid is NONE else repr(cid)), (got[0], got[1].get("error"), len(rows())), (400, "cid must be 16 of 0-9 a-f", n + 2))
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
c="$(post -H 'X-Design-Kit-Decision: 1' --data '{"board":"a.html","picked":1,"cid":"00000000000000aa"}' || true)"
[ "$c" = 500 ] && [ -z "$(ls -A "$tmp/decisions.jsonl")" ] && python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["recorded"] is False and d["error"], d' "$tmp/.resp" \
  || { echo "FAIL: a pick while decisions.jsonl is a folder should be a JSON 500, got $c: $(head -c 200 "$tmp/.resp")"; exit 1; }
rmdir "$tmp/decisions.jsonl"; mv "$tmp/.keep" "$tmp/decisions.jsonl"
# notes.jsonl is never followed through a symlink (a tracked one would let a post append to its target), and a failed append answers 500
mv "$tmp/notes.jsonl" "$tmp/.keep"
printf '{"id":"out1","page":"decks/a.html","kind":"note","text":"FROM-OUTSIDE","status":"open"}\n' > "$tmp.target.jsonl"
ln -s "$tmp.target.jsonl" "$tmp/notes.jsonl"
c="$(npost -H 'X-Design-Kit-Note: 1' --data "$(with_cid '{"page":"/decks/a.html","text":"through the link"}')")"
[ "$c" = 500 ] && python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["recorded"] is False, d' "$tmp/.resp" \
  || { echo "FAIL: a note to a symlinked notes.jsonl should be a JSON 500, got $c: $(head -c 200 "$tmp/.resp")"; exit 1; }
[ "$(wc -l < "$tmp.target.jsonl" | tr -d ' ')" = 1 ] || { echo "FAIL: a note was appended through the notes.jsonl symlink"; exit 1; }
case "$(curl -s "http://127.0.0.1:$port/_notes?page=decks/a.html")" in *FROM-OUTSIDE*) echo "FAIL: /_notes read through the notes.jsonl symlink"; exit 1 ;; esac
rm -f "$tmp/notes.jsonl" "$tmp.target.jsonl"; mkdir "$tmp/notes.jsonl"
c="$(npost -H 'X-Design-Kit-Note: 1' --data "$(with_cid '{"page":"/decks/a.html","text":"into a folder"}')")"
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
  for p in / /_gallery /decks/a.html /_index.json /_events /_viewer.js; do
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
for p in / /decks/a.html /_viewer.js; do
  c="$(code -H 'Service-Worker: script' "$base$p")"; [ "$c" = 404 ] || { echo "FAIL: Service-Worker: script is 404: GET $p got $c"; exit 1; }
  c="$(code -I -H 'Service-Worker: script' "$base$p")"; [ "$c" = 404 ] || { echo "FAIL: Service-Worker: script is 404: HEAD $p got $c"; exit 1; }
done
# a file or folder that resolves outside the docroot, or to a file that is never served, is 404 and unlisted; %2f is a trailing slash to http.server, which would open the index itself
mkdir -p "$tmp.out" "$tmp/decks/sub"
printf '<!doctype html><title>OUTSIDE</title><body>OUTSIDE</body>' | tee "$tmp.out/index.html" > "$tmp.out/p.html"; printf 'OUTSIDE' > "$tmp.out/p.png"
ln -s "$tmp.out/p.html" "$tmp/decks/out.html"; ln -s "$tmp.out/p.png" "$tmp/shots/out.png"; ln -s "$tmp.out" "$tmp/decks/outdir"
ln -s "$tmp.out/index.html" "$tmp/decks/sub/index.html"; ln -s a.html "$tmp/decks/in.html"
for p in /decks/out.html /shots/out.png /decks/outdir /decks/outdir/ /decks/outdir%2f /decks/outdir/p.html /decks/outdir/p.png /decks/sub/ /decks/sub%2f /decks/sub%2F /decks/%00; do
  c="$(code "$base$p")"; [ "$c" = 404 ] && ! grep -q OUTSIDE "$tmp/.resp" || { echo "FAIL: symlink leaving the docroot is 404: GET $p got $c"; exit 1; }
  c="$(code -I "$base$p")"; [ "$c" = 404 ] || { echo "FAIL: symlink leaving the docroot is 404: HEAD $p got $c"; exit 1; }
done
case "$(curl -s "$base/_index.json")" in *OUTSIDE*) echo "FAIL: /_index.json gives the title of a page outside the docroot"; exit 1 ;; *'"path": "decks/in.html"'*) ;; *) echo "FAIL: /_index.json lost a link that stays inside the docroot"; exit 1 ;; esac
c="$(code -L "$base/decks/in.html?static=1")"; [ "$c" = 200 ] && grep -q '<h1>a</h1>' "$tmp/.resp" || { echo "FAIL: a symlink that stays inside the docroot is still served: got $c"; exit 1; }
ln -s ../auth/walk.json "$tmp/decks/in.json"; ln -s ../auth "$tmp/decks/indir"; ln -s ../artifacts/.versions/a/v1.html "$tmp/decks/inver.html"; ln -s ../artifacts/a.versions.json "$tmp/decks/inled.json"; ln -s ../workshop.json "$tmp/shots/in.png"
for p in /decks/in.json /decks/indir /decks/indir/ /decks/indir/walk.json /decks/inver.html /decks/inled.json /shots/in.png; do
  c="$(code "$base$p")"; [ "$c" = 404 ] && ! grep -q SECRET "$tmp/.resp" || { echo "FAIL: a link to a never-served file is 404: GET $p got $c"; exit 1; }
  c="$(code -I "$base$p")"; [ "$c" = 404 ] || { echo "FAIL: a link to a never-served file is 404: HEAD $p got $c"; exit 1; }
done
case "$(curl -s "$base/_index.json")" in *inver.html*) echo "FAIL: /_index.json lists a link to a never-served page"; exit 1 ;; esac
rm -rf "$tmp.out" "$tmp/decks/out.html" "$tmp/decks/outdir" "$tmp/decks/in.html" "$tmp/decks/sub" "$tmp/shots/out.png" "$tmp/decks/in.json" "$tmp/decks/indir" "$tmp/decks/inver.html" "$tmp/decks/inled.json" "$tmp/shots/in.png"
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
for p in / /_gallery /decks/a.html "/decks/a.html?static=1" /_index.json /_notes /_checks /_events /_viewer.js /_viewer.css /shots/one.png /decks /auth/walk.json /nope; do has_common "GET $p" "$(heads "$base$p")"; done
has_common "HEAD a page" "$(heads -I "$base/decks/a.html")"
has_common "a 304" "$(heads -H 'If-Modified-Since: Fri, 01 Jan 2100 00:00:00 GMT' "$base/shots/one.png")"
has_common "a 403 on Host" "$(heads -H 'Host: evil.example' "$base/")"
has_common "a refused POST" "$(heads -X POST --data '{}' "$base/_note")"
has_common "a recorded POST" "$(heads -X POST -H 'X-Design-Kit-Decision: 1' --data "$(with_cid '{"board":"a.html","picked":1}')" "$base/_decision")"
has_common "an unknown method" "$(heads -X PUT "$base/")"
rm -f "$tmp/decks/x.svg" "$tmp/decks/X.SVG" "$tmp/decks/x.xhtml" "$tmp/decks/x.xml" "$tmp/decks/x.pdf"

# a page in its own origin: /_page names its signed URL, /_c/ answers that page and the files it may load under the page's policy, /_allow lists the hosts it may load from
bad=""; say() { echo "FAIL: $1"; bad=1; }
answer() { head -c 200 "$tmp/.resp" | tr -d ' \n'; }
same() { [ "$2" = "$3" ] || say "$1: got $2, want $3"; }
own='motion/a;b, c ü'; mkdir -p "$tmp/$own/sub" "$tmp/$own/.d" "$tmp/motion/y" "$tmp/decks/folder.html" "$tmp.out"
printf '<!doctype html><html><head><title>Own &amp; only</title></head><body><h1>own</h1></body></html>' | tee "$tmp/$own/two.html" "$tmp/motion/y/index.html" > "$tmp/$own/index.html"
printf '<svg xmlns="http://www.w3.org/2000/svg"><script>1</script></svg>' > "$tmp/$own/x.svg"
printf 'export default 1' | tee "$tmp/$own/.m.js" "$tmp/$own/.d/m.js" "$tmp.out/m.js" > "$tmp/$own/sub/m.js"
ln -s "$tmp.out/m.js" "$tmp/$own/out.js"; ln -s "$tmp.out" "$tmp/$own/outdir"; ln -s ../../workshop.json "$tmp/$own/state.json"; ln -s ../../auth "$tmp/$own/in"
ln -s ../../decks/a.html "$tmp/$own/a.txt"; ln -s ../../shots/one.png "$tmp/$own/one.png"; ln -s sub/m.js "$tmp/$own/near.js"; ln -s sub/m.js "$tmp/$own/usage.jsonl"; ln -s "../$own/sub/m.js" "$tmp/shots/m.js"; mkfifo "$tmp/$own/pipe"
printf '<h1>OUTSIDE</h1>' > "$tmp.out/p.html"; ln -s "$tmp.out/p.html" "$tmp/decks/out.html"; ln -s ../artifacts/.versions/a/v1.html "$tmp/decks/linked.html"
page_of() { curl -s -G --data-urlencode "page=$1" "$base/_page"; }
field() { python3 -c 'import json,sys; print(json.load(sys.stdin)[sys.argv[1]])' "$1" 2>/dev/null || true; }
src="$(page_of "$own/index.html" | field src)"; at="${src%/index.html}"; rest="${src#/_c/*/}"; seg="${src#/_c/}"; seg="${seg%%/*}"
live="$(code "$base${src:-/_c/}")"; same "a page is served at the URL /_page gives it" "$live $(grep -c '<h1>own</h1>' "$tmp/.resp")" "200 1"
# gone <claim> <path>: 404 to GET and HEAD, while the segment's own page answers (a server without the route fails too). One line it can print: HEAD of a symlinked folder under /_c/ is 404
gone() {
  local c; [ "$live" = 200 ] || { say "$1: its own page got $live"; return; }
  c="$(code --path-as-is "$base$2")"; [ "$c" = 404 ] && ! grep -q 'SECRET\|export\|PNG\|<h1>\|<svg' "$tmp/.resp" || say "$1: GET $2 got $c"
  c="$(code --path-as-is -I "$base$2")"; [ "$c" = 404 ] || say "HEAD of $1: $2 got $c"
}
gone "a wrong token is 404" "/_c/AAAAAAAAAAAAAAAAAAAAAA${seg:22}/$rest"
for s in x "${seg%%.*}" "$seg.s.s" "${seg%%.*}%2e${seg#*.}" %2e%2e; do gone "a malformed segment is 404" "/_c/$s/$rest"; done
for p in "/_c/$seg" "/_c/$seg/"; do gone "a segment with no path is 404" "$p"; done
for p in "/_c/$seg/decks/a.html" "/_c/$seg/motion/y/index.html" "$at/two.html" "$at/sub/../../../decks/a.html" "/_c/$seg/motion/%2e%2e/decks%2Fa.html"; do gone "another page's path under a valid token is 404" "$p"; done
gone "a framed token used as static is 404" "/_c/$seg.s/$rest"
gone "a symlinked file under /_c/ is 404" "$at/out.js"
gone "a symlinked folder under /_c/ is 404" "$at/outdir/m.js"
for p in "$at/.m.js" "$at/.d/m.js" "/_c/$seg/.preview.key"; do gone "a dot path under /_c/ is 404" "$p"; done
for p in "$at/state.json" "$at/usage.jsonl" "$at/in/walk.json" "/_c/$seg/auth/walk.json" "/_c/$seg/workshop.json"; do gone "a never-served file under /_c/ is 404" "$p"; done
for p in "$at/a.txt" "$at/one.png" "/_c/$seg/shots/one.png" "/_c/$seg/shots/m.js"; do gone "a file the page may not load, by its path or through a link, is 404" "$p"; done
for p in "$at/" "$at/sub" "$at/sub/" "$at/sub%2f" "$at/pipe" "$at/gone.js" "$at/%00"; do gone "what is no file under /_c/ is 404" "$p"; done
printf '<h1>t</h1>' > "$tmp/decks/turn.html"; turn="$(page_of decks/turn.html | field src)"; same "a page is served until it becomes a link out" "$(code "$base${turn:-/_c/}")" 200
for p in "$tmp.out/p.html" ../artifacts/.versions/a/v1.html; do ln -sf "$p" "$tmp/decks/turn.html"; gone "a page that became a link out of the docroot or to a never-served file is 404" "$turn"; done
for p in sub/m.js near.js; do same "a file in the page's own folder is served: $p" "$(code "$base$at/$p") $(answer)" "200 exportdefault1"; done
for p in "$src" "$at/x.svg" "$at/gone.js"; do
  hd="$(heads -H 'Sec-Fetch-Dest: document' "$base$p" | sed -n '1s/^[^ ]* \([0-9]*\).*/\1/p;s/^Location: //p' | tr '\n' ' ')"; same "a framed segment opened as a document is 303 to the page URL: GET $p" "$hd" "303 /motion/a%3Bb%2C%20c%20%C3%BC/index.html "
  c="$(code -I -H 'Sec-Fetch-Dest: document' "$base$p")"; same "a framed segment opened as a document is 303 to the page URL: HEAD $p" "$c" 303
  for d in "-H Sec-Fetch-Dest:document" -I ""; do hd="$(heads $d "$base$p")"; same "every answer under /_c/ is no-store: ${d:-GET} $p" "$(printf '%s\n' "$hd" | grep -cxF 'Cache-Control: no-store')" 1; done
done
hd="$(heads -H 'Sec-Fetch-Dest: document' "$base$src?still=1&key=x" | sed -n 's/^Location: //p')"; same "that 303 keeps the query, the key left out" "$hd" "/motion/a%3Bb%2C%20c%20%C3%BC/index.html?still=1"
same "a framed segment in a frame is the page" "$(code -H 'Sec-Fetch-Dest: iframe' "$base$src")" 200
same "a valid segment passes neither the Host check nor the service worker check" "$(code -H 'Host: evil.example' "$base$src") $(code -I -H 'Service-Worker: script' "$base$src")" "403 404"
same "a POST under /_c/ is no route" "$(code -X POST --data '{}' "$base$src")" 501
python3 - "$here" "$tmp" "$port" "$own/index.html" "$src" <<'PY' || bad=1
import hashlib, http.client, importlib.util, json, mimetypes, os, sys
from urllib.parse import quote
here, root, port, page, src = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4], sys.argv[5]
spec = importlib.util.spec_from_file_location("dkserve", here + "/serve.py"); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
failed = []
def eq(claim, got, want):
    if got != want: failed.append("FAIL: %s: got %.400r, want %.400r" % (claim, got, want))
def ask(path, method="GET", **headers):
    con = http.client.HTTPConnection("127.0.0.1", port, timeout=5)
    con.request(method, path, headers={k.replace("_", "-"): v for k, v in headers.items()})
    r = con.getresponse()
    return r.status, r.headers, r.read()
def about(page, **headers):
    status, _, body = ask("/_page?page=" + quote(page), **headers)
    try: return status, json.loads(body)
    except ValueError: return status, None

host, seg, encoded = "127.0.0.1:%d" % port, (src.split("/") + ["", "", ""])[2], "/motion/a%3Bb%2C%20c%20%C3%BC/index.html"
eq("/_page answers the fields of decision 21 on loopback", about(page), (200, {
    "page": page, "title": "Own & only", "src": "/_c/" + seg + encoded, "project": hashlib.sha256(os.path.realpath(root).encode()).hexdigest()[:12], "hosts": [], "hosts_error": None,
    "writable": True, "version": m.SERVER_VERSION, "local": "http://" + host + encoded}))
eq("/_page says not writable at an address no write route takes", (about(page, Host="192.0.2.7:%d" % port)[1] or {}).get("writable"), False)
eq("a page with no title is named by its file", (about("decks/b.html")[1] or {}).get("title"), "b.html")
eq("/_page is for a same-origin fetch", [about(page, Sec_Fetch_Site=s)[0] for s in ("same-origin", "cross-site", "same-site", "none", "")], [200, 403, 403, 403, 403])
for name in ("decks/gone.html", "decks", "motion", page.rsplit("/", 1)[0], "shots/one.png", "", "/", "/decks/a.html", "decks//a.html", "decks/./a.html", "decks/../decks/a.html", "../" + os.path.basename(root) + "/decks/a.html",
             "artifacts/.versions/a/v1.html", "auth/x.html", "decks/a.html\0", "decks/folder.html", "decks/linked.html", "decks/out.html"):
    eq("no such page is 404: %r" % name, about(name)[0], 404)

with open(os.path.join(root, page), "rb") as fh: raw = fh.read()
with open(here + "/frame.js", "rb") as fh: client = b"<script data-design-kit-frame>" + fh.read() + b"</script>"
policy = m.isolate.page_policy("f", page, seg, [], host)
status, headers, body = ask(src)
eq("a framed page is its file with the client right after <head>, and nothing else", (status, body), (200, raw.replace(b"<head>", b"<head>" + client)))
eq("HEAD of a framed page gives its injected length", (ask(src, "HEAD")[1]["Content-Length"], ask(src, "HEAD")[2]), (str(len(body)), b""))
at = src.rsplit("/", 1)[0]
for claim, path, ctype in (("a framed page carries its policy", src, "text/html; charset=utf-8"), ("own-folder SVG carries sandbox", at + "/x.svg", "image/svg+xml"), ("a module carries the page's policy", at + "/sub/m.js", mimetypes.guess_type("m.js")[0])):
    for method in ("GET", "HEAD"):
        status, headers, _ = ask(path, method, If_Modified_Since="Fri, 01 Jan 2100 00:00:00 GMT")
        eq("%s: %s" % (claim, method), [status] + [headers.get_all(h) for h in ("Content-Type", "Content-Security-Policy", "Access-Control-Allow-Origin", "Cross-Origin-Resource-Policy", "X-Content-Type-Options", "Referrer-Policy", "X-DNS-Prefetch-Control")],
           [200, [ctype], [policy], ["*"], ["cross-origin"], ["nosniff"], ["no-referrer"], ["off"]])
eq("a page reads the 404 of a file it may load, never of another path", [ask(p)[1]["Access-Control-Allow-Origin"] for p in (at + "/gone.js", "/_c/" + seg + "/decks/a.html")], ["*", None])
eq("that policy is the page's: sandboxed, framed here alone", (policy.startswith("sandbox allow-scripts "), policy.endswith("; frame-ancestors http://" + host)), (True, True))
print("\n".join(failed), end="\n" if failed else "")
sys.exit(1 if failed else 0)
PY
has_common "/_page" "$(heads "$base/_page?page=decks/a.html")"
has_common "a 404 under /_c/" "$(heads "$base/_c/x/decks/a.html")"
# a static segment opens top-level; on one connection the next answer is the control origin's again; a page is what ends in .htm or goes out as text/html; a docroot reached by a link is its real path
python3 - "$here/serve.py" "$tmp" <<'PY' || say "a static segment, the answer after it, a page by its type, a linked docroot"
import hashlib, http.client, importlib.util, json, mimetypes, os, sys, threading, time
mimetypes.add_type("text/html", ".dkpage"); mimetypes.add_type("text/plain", ".htm")
spec = importlib.util.spec_from_file_location("dkserve", sys.argv[1]); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
class H(m.Handler):
    root, state, protocol_version = sys.argv[2] + "/.lnk", {"version": 0, "last": time.monotonic(), "streams": 0}, "HTTP/1.1"
os.symlink(sys.argv[2], H.root)
srv = m.ThreadingHTTPServer(("127.0.0.1", 0), H); srv.daemon_threads = True
threading.Thread(target=srv.serve_forever, daemon=True).start()
con = http.client.HTTPConnection("127.0.0.1", srv.server_port, timeout=5)
def ask(method, path, **headers):
    con.request(method, path, headers=headers); r = con.getresponse(); body = r.read()
    return r, body
src, got = m.isolate.content_url("decks/a.html", "s"), []
for method, path, headers in (("GET", src, {"Sec-Fetch-Dest": "document"}), ("HEAD", "/shots/one.png", {})):
    r, _ = ask(method, path, **headers)
    got.append((r.status, r.getheader("Cross-Origin-Resource-Policy"), r.getheader("Access-Control-Allow-Origin"), r.getheader("Content-Security-Policy")))
for name in ("decks/x.dkpage", "decks/x.htm"):
    with open(os.path.join(H.root, name), "w") as fh: fh.write("<h1>x</h1>")
    found, body = ask("GET", "/_page?page=" + name)
    page = json.loads(body) if found.status == 200 else {}
    framed, _ = ask("GET", page.get("src", "/_c/"))
    _, viewer = ask("GET", "/" + name)
    got.append((found.status, page.get("project"), framed.status, framed.getheader("Content-Type"), ('data-page="%s"' % name).encode() in viewer))
apart, beside = {}, m.isolate.content_url("motion/y/index.html", "f").rsplit("/", 1)[0]
for name in ("report.html.gz", "x.dkpage", "x.htm", "x.txt"):
    with open(os.path.join(H.root, "motion/y", name), "w") as fh: fh.write("x")
    apart[name] = [ask("GET", at + name)[0].status for at in ("/_page?page=motion/y/", beside + "/")]
srv.shutdown()
policy = m.isolate.page_policy("s", "decks/a.html", src.split("/")[2], [], "127.0.0.1:%d" % srv.server_port)
page = (200, hashlib.sha256(os.path.realpath(sys.argv[2]).encode()).hexdigest()[:12], 200, "text/html; charset=utf-8", True)
assert got == [(200, "cross-origin", "*", policy), (200, "same-origin", None, None), page, page], got
assert apart == {"report.html.gz": [404, 200], "x.dkpage": [200, 404], "x.htm": [200, 404], "x.txt": [404, 200]}, ("a file is a page or a file its folder's pages may load, never neither", apart)
PY
rm -f "$tmp/decks/x.dkpage" "$tmp/decks/x.htm" "$tmp/.lnk"
# an update on disk under a running server: the viewer's files stay those it started with, like the client and the rules it sends
mkdir "$tmp/.kit"; cp "$here/serve.py" "$here/isolate.py" "$here/picks.py" "$here/frame.js" "$here/viewer.js" "$here/viewer.css" "$tmp/.kit"
python3 - "$tmp/.kit" <<'PY' || say "an update on disk changes the viewer's files of a running server"
import http.client, importlib.util, os, sys, threading, time
spec = importlib.util.spec_from_file_location("dkserve", sys.argv[1] + "/serve.py"); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
class H(m.Handler):
    root, state = sys.argv[1], {"version": 0, "last": time.monotonic(), "streams": 0}
srv = m.ThreadingHTTPServer(("127.0.0.1", 0), H); srv.daemon_threads = True
threading.Thread(target=srv.serve_forever, daemon=True).start()
def ask(path):
    con = http.client.HTTPConnection("127.0.0.1", srv.server_port, timeout=5)
    con.request("GET", path); r = con.getresponse()
    return r.status, r.read()
got = {}
for name in ("viewer.js", "viewer.css"):
    path = os.path.join(sys.argv[1], name)
    with open(path, "rb") as fh: started = (200, fh.read())
    with open(path, "ab") as fh: fh.write(b"\n/* updated */")
    got[name] = [ask("/_" + name) == started]
    os.unlink(path)
    got[name].append(ask("/_" + name) == started)
srv.shutdown()
assert got == {"viewer.js": [True, True], "viewer.css": [True, True]}, ("as it started, once changed and once deleted", got)
PY
rm -rf "$tmp/.kit"
# /_allow: the host in, on that page alone; what is refused writes nothing
allow() { code -X POST -H 'Content-Type: application/json' "$@" "$base/_allow"; }
csp() { heads "$base$(page_of "$1" | field src)" | sed -n 's/^Content-Security-Policy: //p'; }
A='X-Design-Kit-Allow: 1'; yes='{"page":"decks/a.html","host":"CDN.example.org","allow":true}'
same "/_allow without its header is 403" "$(allow -H 'X-Design-Kit-Note: 1' --data "$yes")" 403
same "/_allow with a foreign Origin is 403" "$(allow -H "$A" -H 'Origin: http://attacker.example' --data "$yes")" 403
same "/_allow with a foreign Host is 403" "$(allow -H "$A" -H 'Host: attacker.example' --data "$yes")" 403
for h in '"127.0.0.1"' '"localhost"' '"https://cdn.example.org"' '"cdn.example.org:443"' 7 null; do
  same "/_allow with a bad host is 400: $h" "$(allow -H "$A" --data '{"page":"decks/a.html","host":'"$h"',"allow":true}') $(field error < "$tmp/.resp" | cut -c1-12)" "400 host must be"
done
same "/_allow for no such page is 400" "$(allow -H "$A" --data '{"page":"shots/one.png","host":"cdn.example.org","allow":true}') $(field error < "$tmp/.resp")" "400 no such page"
same "/_allow takes allow as true or false" "$(allow -H "$A" --data '{"page":"decks/a.html","host":"cdn.example.org","allow":"no"}') $(field error < "$tmp/.resp")" "400 allow must be true or false"
same "/_allow past 8 KiB is 413" "$(allow -H "$A" --data "$(python3 -c 'print("{\"page\":\"" + "x" * 9000 + "\"}")')")" 413
[ ! -e "$tmp/.allow.json" ] || say "a refused /_allow writes nothing: $(cat "$tmp/.allow.json")"
same "/_allow lists the host" "$(allow -H "$A" -H "Origin: $base" --data "$yes") $(answer)" '200 {"hosts":["cdn.example.org"]}'
same "/_page lists the page's hosts" "$(page_of decks/a.html | field hosts) $(page_of "$own/index.html" | field hosts)" "['cdn.example.org'] []"
case "$(csp decks/a.html)" in *"; img-src data: blob: https://cdn.example.org; "*"; connect-src data: blob:; "*) ;; *) say "an allowed host is in its page's policy: $(csp decks/a.html)" ;; esac
case "$(csp "$own/index.html")" in *cdn.example.org*|"") say "an allowed host is in no other page's policy: $(csp "$own/index.html")" ;; esac
never_served /.allow.json cdn.example.org
same "/_allow removes the host" "$(allow -H "$A" --data '{"page":"decks/a.html","host":"cdn.example.org","allow":false}') $(answer)" '200 {"hosts":[]}'
printf '{"decks/a.html":["127.0.0.1","evil.local","cdn.example.org"]}' > "$tmp/.allow.json"
case "$(csp decks/a.html)" in *"; img-src data: blob: https://cdn.example.org; "*) ;; *) say "a host written in by hand is checked at read: $(csp decks/a.html)" ;; esac
printf '{"decks/a.html":' > "$tmp/.allow.json"
same "an unreadable approvals file allows nothing and says so" "$(page_of decks/a.html | field hosts) $(page_of decks/a.html | field hosts_error) $(csp decks/a.html | grep -c https:)" "[] approvals file unreadable; all hosts blocked 0"
same "Remove on an unreadable approvals file is a 400 with its reason, the file as it was" "$(allow -H "$A" --data '{"page":"decks/a.html","host":"cdn.example.org","allow":false}') $(field error < "$tmp/.resp") $(cat "$tmp/.allow.json")" \
  '400 approvals file unreadable; all hosts blocked; nothing removed until .allow.json is repaired or deleted {"decks/a.html":'
mkdir "$tmp/.allow.json.bad"
same "an approval that cannot be written is a JSON 500, the file as it was and nothing left beside it" "$(allow -H "$A" --data "$yes") $(field error < "$tmp/.resp" | cut -c1-28) $(cat "$tmp/.allow.json") $(cd "$tmp" && echo .allow*)" \
  '500 could not write .allow.json: {"decks/a.html": .allow.json .allow.json.bad .allow.lock'
rmdir "$tmp/.allow.json.bad"; rm -f "$tmp/.allow.json"
python3 - "$here/serve.py" "$tmp" "$port" <<'PY' || say "/_allow writes only with .allow.lock held"
import http.client, importlib.util, os, sys, threading, time
spec = importlib.util.spec_from_file_location("dkserve", sys.argv[1]); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
got = []
def send():
    con = http.client.HTTPConnection("127.0.0.1", int(sys.argv[3]), timeout=10)
    con.request("POST", "/_allow", '{"page":"decks/a.html","host":"a.io","allow":true}', {"X-Design-Kit-Allow": "1"})
    got.append(con.getresponse().status)
one = threading.Thread(target=send)
with m.locked(os.path.join(sys.argv[2], ".allow.lock")):
    one.start(); time.sleep(0.4)
    assert (got, os.path.exists(os.path.join(sys.argv[2], ".allow.json"))) == ([], False), got
one.join()
assert got == [200] and os.path.exists(os.path.join(sys.argv[2], ".allow.json")), got
PY
rm -f "$tmp/.allow.json"
# a sent Origin is http:// and the Host, letter for letter, on every write route: a page of another local port is another site
for r in decision note allow; do
  case "$r" in decision) h='X-Design-Kit-Decision: 1' b="$(with_cid '{"board":"a.html","picked":7}')" ;; note) h='X-Design-Kit-Note: 1' b="$(with_cid '{"page":"decks/a.html","text":"origin"}')" ;; allow) h="$A" b="$yes" ;; esac
  n="$(cat "$tmp/decisions.jsonl" "$tmp/notes.jsonl" | wc -l)"
  for o in "http://127.0.0.1:1" "http://localhost:$port" "https://127.0.0.1:$port" "$base/" "http://127.0.0.1" null; do
    same "a sent Origin must equal http:// and the Host: /_$r from $o" "$(code -X POST -H "$h" -H "Origin: $o" --data "$b" "$base/_$r")" 403
  done
  same "an empty Origin was sent: /_$r" "$(code -X POST -H "$h" -H 'Origin;' --data "$b" "$base/_$r")" 403
  [ "$(cat "$tmp/decisions.jsonl" "$tmp/notes.jsonl" | wc -l)" = "$n" ] && [ ! -e "$tmp/.allow.json" ] || say "a refused Origin writes nothing: /_$r"
  same "the server's own Origin passes: /_$r" "$(code -X POST -H "$h" -H "Origin: http://localhost:$port" --data "$b" "http://localhost:$port/_$r")" 200
done
[ -z "$bad" ] || exit 1
rm -rf "$tmp.out" "$tmp/motion" "$tmp/decks/folder.html" "$tmp/decks/out.html" "$tmp/decks/linked.html" "$tmp/decks/turn.html" "$tmp/shots/m.js"

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
  for probe in / /_gallery /decks/a.html /_index.json /_viewer.js "/decks/a.html?static=1" "/decks/a.html?key=wrong" "/decks/a.html?key="; do
    for o in "" -I; do c="$(hc $o "$L$probe")"; [ "$c" = 403 ] || { echo "FAIL: $probe from a LAN peer without the key should be 403 (${o:-GET}), got $c"; exit 1; }; done
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
  c="$(hc -b "design_kit_key=$key" "$L/decks/a.html")"; [ "$c" = 200 ] && grep -q 'data-page="decks/a.html"' "$tmp/.resp" && grep -q 'id="notes" hidden' "$tmp/.resp" || { echo "FAIL: the cookie should serve the viewer, with no Notes, got $c: $(head -c 400 "$tmp/.resp")"; exit 1; }
  c="$(hc -b "design_kit_key=$key" "$L/_index.json")"; [ "$c" = 200 ] || { echo "FAIL: the cookie should serve /_index.json, got $c"; exit 1; }
  c="$(hc -b "design_kit_key=$key" --max-time 2 "$L/_events")"; [ "$c" = 200 ] || { echo "FAIL: the cookie should open /_events, got $c"; exit 1; }
  n="$(wc -l < "$tmp/decisions.jsonl")"
  c="$(hc -b "design_kit_key=$key" -X POST -H 'X-Design-Kit-Decision: 1' --data '{"board":"a.html","picked":9}' "$L/_decision?key=$key")"
  [ "$c" = 403 ] && [ "$(wc -l < "$tmp/decisions.jsonl")" = "$n" ] || { echo "FAIL: /_decision from a LAN peer with the key should be 403 and not append, got $c"; exit 1; }
  n="$(wc -l < "$tmp/notes.jsonl")"
  c="$(hc -b "design_kit_key=$key" -X POST -H 'X-Design-Kit-Note: 1' --data '{"text":"from a phone"}' "$L/_note?key=$key")"
  [ "$c" = 403 ] && [ "$(wc -l < "$tmp/notes.jsonl")" = "$n" ] || { echo "FAIL: /_note from a LAN peer with the key should be 403 and not append, got $c"; exit 1; }
  c="$(hc -b "design_kit_key=$key" "$L/_notes?page=decks/a.html")"; [ "$c" = 403 ] || { echo "FAIL: /_notes from a LAN peer with the key should be 403, got $c"; exit 1; }
  c="$(hc -b "design_kit_key=$key" -A "Mozilla/5.0 HeadlessChrome/130" "$L/decks/a.html?static=1")"
  [ "$c" = 200 ] && grep -q 'data-page="decks/a.html"' "$tmp/.resp" || { echo "FAIL: a LAN peer asking for the raw page should get the viewer, got $c"; exit 1; }
  # a signed content URL needs no key; what names one and what allows a host do, and a LAN peer may change nothing
  c="$(hc "$L/_page?page=decks/a.html")"; [ "$c" = 403 ] || { echo "FAIL: /_page from a LAN peer without the key should be 403, got $c"; exit 1; }
  hc -b "design_kit_key=$key" "$L/_page?page=decks/a.html" > /dev/null
  python3 - "$tmp/.resp" "$port" <<'PY' || { echo "FAIL: /_page for a LAN peer is not writable and lists no hosts: $(head -c 400 "$tmp/.resp")"; exit 1; }
import json, sys
with open(sys.argv[1], encoding="utf-8") as fh: d = json.load(fh)
assert (d["page"], d["writable"], d["hosts"], d["hosts_error"], d["local"]) == ("decks/a.html", False, [], None, "http://127.0.0.1:%s/decks/a.html" % sys.argv[2]), d
PY
  [ "$(curl -s "http://127.0.0.1:$port/_page?page=decks/a.html" | field hosts)" = "['cdn.example.org']" ] || { echo "FAIL: /_page lost the host /_allow listed, so a LAN peer's empty list proves nothing"; exit 1; }
  lsrc="$(field src < "$tmp/.resp")"; lseg="${lsrc#/_c/}"; lseg="${lseg%%/*}"
  for o in "" -I; do c="$(hc $o "$L$lsrc")"; [ "$c" = 200 ] || { echo "FAIL: a valid segment is served to a LAN peer with no cookie (${o:-GET}): got $c"; exit 1; }; done
  hc "$L$lsrc" > /dev/null; grep -q '<h1>a</h1>' "$tmp/.resp" || { echo "FAIL: a valid segment gave a LAN peer something else: $(head -c 200 "$tmp/.resp")"; exit 1; }
  for p in "/_c/AAAAAAAAAAAAAAAAAAAAAA${lseg:22}/decks/a.html" "/_c/$lseg.s/decks/a.html" "/_c/" "/_c/../decks/a.html" "/x/../_c/$lseg/decks/a.html" "/$lseg/_c/decks/a.html"; do
    c="$(hc --path-as-is "$L$p")"; [ "$c" = 403 ] || { echo "FAIL: a segment that does not open should meet the key gate: $p got $c"; exit 1; }
  done
  c="$(hc -X POST --data '{}' "$L$lsrc")"; [ "$c" = 403 ] || { echo "FAIL: a POST under a valid segment should meet the key gate, got $c"; exit 1; }
  c="$(hc -b "design_kit_key=$key" "$L/_c/$lseg/decks/b.html")"; [ "$c" = 404 ] || { echo "FAIL: another page under a LAN peer's valid segment should be 404, got $c"; exit 1; }
  cp "$tmp/.allow.json" "$tmp/.keep"
  for o in "$L" "http://127.0.0.1:$port"; do
    c="$(hc -b "design_kit_key=$key" -X POST -H "$A" -H "Origin: $o" --data '{"page":"decks/a.html","host":"cdn.example.org","allow":false}' "$L/_allow?key=$key")"
    [ "$c" = 403 ] && cmp -s "$tmp/.allow.json" "$tmp/.keep" || { echo "FAIL: /_allow from the LAN is 403 and writes nothing, got $c"; exit 1; }
  done
  rm -f "$tmp/.keep"
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
