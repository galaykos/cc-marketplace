#!/usr/bin/env bash
# Drives the viewer in headless Chrome on a served temp docroot: every kind of page framed with frame.js first and a null origin, the files an own-folder, a review and a deck page load, framed and raw, the bar, its frame's reload and focus, the deleted and server-lost strips, a restart, the gallery, a worker an older server left, and, with the peer's address faked and its Sec-Fetch headers dropped as plain HTTP drops them, the LAN viewer and the bounce of a top-level framed page; browser_lib.py's exit 4 where no browser starts.
# Misses: a hostile page (attack.test.sh), a real second device, what a screen reader says, browsers outside Chromium.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export TMPDIR="$tmp" PYTHONDONTWRITEBYTECODE=1
unset DESIGN_KIT_PORT

rc=0
python3 - "$here" "$tmp/dk" <<'PY' || rc=$?
import base64, http.server, io, json, os, re, socket, struct, subprocess, sys, threading, time, wave, zlib
from urllib.parse import quote, unquote

here, ROOT = sys.argv[1:3]
sys.path.insert(0, os.path.join(here, "__tests__"))
import browser_lib

m = browser_lib.check.m  # serve.py
bad = []

def eq(name, fn, want):
    try:
        got = fn() if callable(fn) else fn
    except Exception as exc:
        got = repr(exc)
    print("ok: " + name if got == want else "FAIL: %s: got %.600s, want %.400s" % (name, json.dumps(got), json.dumps(want)))
    if got != want:
        bad.append(name)

def put(name, body):
    path = os.path.join(ROOT, name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as fh:
        fh.write(body if isinstance(body, bytes) else body.encode())

EARLY = "<script>window.early = window.__designKitFrame</script>"
def page(name, title="fixture", head=EARLY, body=""):
    put(name, "<!doctype html><html lang=\"en\"><head><title>%s</title>%s</head><body><h1>%s</h1>%s</body></html>" % (title, head, title, body))

def png():
    chunk = lambda kind, data: struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 0, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(b"\0\0")) + chunk(b"IEND", b"")

def wav():
    out = io.BytesIO()
    with wave.open(out, "wb") as w:
        w.setnchannels(1); w.setsampwidth(1); w.setframerate(8000); w.writeframes(b"\x80" * 800)
    return out.getvalue()

# a TrueType font of one glyph
FONT = zlib.decompress(base64.b64decode("eNqNj71KA0EUhc/MbDTKYiSg9RYphYBFsLBwEYNYJKBoJegQY1LsmqArxM5HsPAJUltaWARJaeFDWKawjK3rmZk1ERXxLnvnfvdvzkAAmMc1FIL6Xnn14GV/iZk7/seNWHfhIwGET15pRVen6jF3T14jl9pNfaJnN/vkQ3KlzURuWZTJt7YeJz01YgTxQJePOg1t8uQhTz/WvS48fhDP5OBMx025XSyQX8k73c5FQl00ae4LoMRY3CCH/5j4CrV6bQsbCBGqIOUuFeDps0eM5cBud1PKZn2qMhmjznCYps6nw2zzdJYKBc0Q8O5bvYNJT6bjqLD+xntHv0p1CvKQ091Op9lovfg2Ik3FVSdWsl0yewF+zMC+p2Lq3hyrkuxiiQU3x9hjtJjFM4yLqGIXTbRwiQga5+SqnfzTPgDQQD77"))
OWN, BOARD, KIT_TEXT = "motion/a;b, c ü/", "boards/fixture.html", "data-design-kit-frame"
KINDS = (
    ("boards", BOARD, None), ("decks", "decks/fixture.html", None), ("artifacts", "artifacts/fixture.html", None), ("previews", "previews/fixture.html", None),
    ("motion", "motion/one/index.html", None), (".htm", "decks/old.htm", None), ("a folder's index", "motion/one/index.html", "/motion/one/"), ("a folder's index asked with %2f", "motion/one/index.html", "/motion/one%2f"),
    ("a folder's index.htm", "motion/two/index.htm", "/motion/two/"), ("a page with no head", "artifacts/nohead.html", None),
    ("a head inside a script and a textarea", "artifacts/nested.html", None), ("a page holding the text " + KIT_TEXT, "artifacts/saved.html", None),
)
for name in (BOARD, "decks/fixture.html", "artifacts/fixture.html", "previews/fixture.html", "motion/one/index.html", "decks/old.htm", "motion/two/index.htm"):
    page(name)
put("artifacts/nohead.html", "<h1>fixture</h1>" + EARLY)
put("artifacts/nested.html", "<!doctype html><html><script>const s = '<head>';</script>" + EARLY + "<textarea><head></textarea><h1>fixture</h1>")
page("artifacts/saved.html", head="<!-- %s --><script %s>window.saved = 1</script>%s" % (KIT_TEXT, KIT_TEXT, EARLY))
put("artifacts/markup.html", "<title>&lt;img src=x onerror=alert(1)&gt; &amp; &quot;two&quot;</title><h1>markup</h1>")
page("artifacts/long.html", title="A quarterly review of every office and its revenue, with the notes of the third quarter and what comes next")
page(OWN + "index.html", head='<style>@font-face { font-family: F; src: url(f.ttf) }</style><script src="s.js"></script><script type="module" src="sub/m.js"></script>', body='<img src="i.png"><audio src="a.wav" preload="auto"></audio>')
for name, body in (("s.js", "window.script = 1"), ("sub/m.js", "import { two } from './n.js'; window.module = two"), ("sub/n.js", "export const two = 2"), ("f.ttf", FONT), ("i.png", png()), ("a.wav", wav()), ("d.json", '{"three": 3}')):
    put(OWN + name, body)
put("shots/one.png", png())
page("reviews/r.html", body='<img src="../shots/one.png">')
page("decks/loads.html", head='<script src="s.js"></script>', body='<img src="../shots/one.png">')
put("decks/s.js", "window.script = 1")
page("decks/sized.html", head="<script>window.sized = [innerWidth, innerHeight]</script>")
page("motion/top/index.html", head="<script>if (parent === window) new Image().src = 'ran.png'</script>")
page("artifacts/nest.html", body="<iframe srcdoc=\"<script>onmessage = () => parent.parent.postMessage({ dk: 1, t: 'ready', hash: '#' }, '*')</script>\"></iframe>")

SERVE = "import importlib.util, sys; s = importlib.util.spec_from_file_location('dkserve', sys.argv[1]); m = importlib.util.module_from_spec(s); s.loader.exec_module(m); m.SERVER_VERSION += int(sys.argv[2]); sys.exit(m.main(sys.argv[3:]))"

def free_port():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]

class Server:
    """serve.py on ROOT, in a process of its own: what it signed dies with it."""

    def __init__(self, port):
        self.port, self.url, self.proc = port, "http://127.0.0.1:%d" % port, None

    def start(self, newer=0):
        self.proc = subprocess.Popen([sys.executable, "-c", SERVE, os.path.join(here, "serve.py"), str(newer), "--docroot", ROOT, "--port", str(self.port)],
                                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=dict(os.environ, DESIGN_KIT_IDLE_MINUTES="0"))
        for _ in range(100):
            try:
                return socket.create_connection(("127.0.0.1", self.port), 1).close()
            except OSError:
                time.sleep(0.05)
        raise OSError("serve.py did not start on port %d" % self.port)

    def stop(self):
        if self.proc:
            self.proc.kill()
            self.proc.wait()

asked = []

class Far(m.Handler):
    """serve.py as a LAN peer meets it: not this machine's address, and no Sec-Fetch header, which a browser sends to a trustworthy address only."""
    root, state = ROOT, {"version": 0, "last": time.monotonic(), "streams": 0}

    def setup(self):
        super().setup()
        self.client_address = ("192.0.2.7", 50000)

    def parse_request(self):
        parsed = super().parse_request()
        if parsed:
            asked.append(unquote(self.path))
            for name in [n for n in self.headers if n.lower().startswith("sec-fetch-")]:
                del self.headers[name]
        return parsed

UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36"

visited = []

def visit(b, url, w=1280, h=800):
    """The one open tab, at url, with a person's user agent: a headless one is sent to the raw page, and each viewer left open keeps one of the six connections Chrome gives a host."""
    while visited:
        b.chrome.call("Page.close", {}, visited.pop().sid)
    tab = b.page("about:blank", w, h)
    visited.append(tab)
    b.chrome.call("Emulation.setUserAgentOverride", {"userAgent": UA}, tab.sid)
    b.chrome.call("Page.navigate", {"url": url}, tab.sid)
    tab.wait("location.href !== 'about:blank' && document.readyState === 'complete'", 10)
    return tab

def logged(b, tab):
    return [str((e["params"].get("entry") or {}).get("text") or e["params"])[:200] for e in b.chrome.events if e.get("sessionId") == tab.sid and e["method"] in ("Log.entryAdded", "Runtime.exceptionThrown", "Runtime.consoleAPICalled")]

SHOWN = "(() => { const e = document.querySelector('%s'); return !!e && e.checkVisibility(); })()"
STRIPS = "[...document.querySelectorAll('#strips > *')].map((s) => s.textContent)"
FOCUS = "(document.activeElement || document.body).id || document.activeElement.localName"
H1 = "(document.querySelector('h1') || {}).textContent"

def kinds(b):
    origins = {}
    for label, name, at in KINDS:
        tab = visit(b, server.url + (at or "/" + quote(name)))
        def shown():
            origins[label] = None
            frame = tab.frame()
            origins[label] = frame.evaluate("self.origin")
            return [tab.evaluate("[document.body.dataset.page, document.querySelectorAll('#bar, #strips, #drawer, main#frame > iframe').length]"), frame.evaluate("[window.early, %s]" % H1)]
        eq("%s shows the viewer, with the client before the page's first script" % label, shown, [[name, 4], [True, "fixture"]])
    eq("frame origin is null for boards, motion, .htm and a page with no head", origins, {label: "null" for label, _, _ in KINDS})
    sizes = []
    for _ in range(8):
        sizes.append(visit(b, server.url + "/decks/sized.html").frame().evaluate("window.sized"))
    eq("a page's first script sees its frame's size, every time of 8", sizes, [[1280, 757]] * 8)

LOADED = """(async () => {
  const audio = document.querySelector('audio');
  if (!audio.readyState) await new Promise((r) => { audio.onloadedmetadata = audio.onerror = r; });
  return { script: window.script, module: window.module, font: (await document.fonts.load('12px F').catch(() => [])).map((f) => f.status), image: document.querySelector('img').naturalWidth,
    audio: audio.duration > 0, json: await fetch('d.json').then((r) => r.json()).catch((e) => e.name), gone: await fetch('gone.json').then((r) => r.status).catch((e) => e.name) };
})()"""

def files(b):
    want = {"script": 1, "module": 2, "font": ["loaded"], "image": 1, "audio": True, "json": {"three": 3}, "gone": 404}
    image = "[document.querySelector('img').complete, document.querySelector('img').naturalWidth]"
    def framed(name):
        return visit(b, server.url + "/" + quote(name)).frame()
    def raw(name):
        tab = visit(b, server.url + "/" + quote(name) + "?static=1")
        eq("?static=1 opens %s raw, at its own address" % name, lambda: tab.evaluate("[self.origin, location.pathname.startsWith('/_c/'), location.search, document.querySelectorAll('#bar').length]"), ["null", True, "", 0])
        return tab
    for how, at in (("framed", framed), ("raw", raw)):
        eq("a page in a folder named 'a;b, c ü' loads its script, module, font, image, audio and JSON, %s, and reads a 404 for a file that is not there" % how, lambda: at(OWN + "index.html").evaluate(LOADED), want)
        eq("a review page shows its shots/ image, %s" % how, lambda: at("reviews/r.html").wait(image), [True, 1])
        eq("a deck loads no server file, %s" % how, lambda: at("decks/loads.html").evaluate("(async () => [window.script || 0, document.querySelector('img').naturalWidth, await fetch('../shots/one.png').then((r) => r.status, (e) => e.name)])()"), [0, 0, "TypeError"])

def bar(b):
    tab = visit(b, server.url + "/" + BOARD)
    tab.frame()
    eq("the bar holds Gallery, the title, the check result and Notes, in that order", lambda: (tab.wait("document.querySelector('#chip').textContent"), tab.evaluate("[...document.querySelectorAll('#bar a, #bar h1, #bar #chip, #bar button')].filter((e) => e.checkVisibility()).map((e) => [e.localName, e.textContent])"))[1],
       [["a", "Gallery"], ["h1", "fixture"], ["span", "Not checked"], ["button", "Notes"]])
    eq("the Gallery link opens the gallery's own address", lambda: tab.evaluate("document.querySelector('#bar a').getAttribute('href')"), "/_gallery")
    eq("Network hidden while nothing was blocked or allowed", lambda: tab.evaluate("[%s, %s]" % (SHOWN % "#network", SHOWN % "#notes")), [False, True])
    tab.click(*tab.at("#notes"))
    eq("Notes shows no panel", lambda: tab.evaluate(SHOWN % "#drawer"), False)
    eq("the frame is sandboxed as its policy says, seeded by name, and named for a screen reader", lambda: tab.evaluate("(() => { const f = document.querySelector('iframe'); return [f.getAttribute('sandbox'), f.getAttribute('allow'), f.name, f.title, f.allowFullscreen, /^\\/_c\\/[\\w-]{22}\\.[\\w-]+\\/boards\\/fixture\\.html$/.test(f.getAttribute('src'))]; })()"),
       ["allow-scripts allow-forms allow-modals allow-downloads", "clipboard-write", '{"dk":1,"store":{}}', "fixture", False, True])
    eq("the viewer logs no error and no refused load", lambda: logged(b, tab), [])
    for findings, changed, want in ((0, 0, "Checked, 0 problems"), (1, 0, "Checked, 1 problem"), (2, 1, "Checked, 2 problems; page changed since")):
        put(".checks/results.json", json.dumps({BOARD: {"ts": "2026-11-24T10:00:00Z", "findings": findings, "widths": [375], "mtime_ns": os.stat(os.path.join(ROOT, BOARD)).st_mtime_ns - changed}}))
        tab = visit(b, server.url + "/" + BOARD)
        eq("the chip says what the last check found: " + want, lambda: (tab.wait("document.querySelector('#chip').textContent"), tab.evaluate("document.querySelector('#chip').textContent"))[1], want)
    title = '<img src=x onerror=alert(1)> & "two"'
    tab = visit(b, server.url + "/artifacts/markup.html")
    eq("a page title holding markup shows as text in the bar", lambda: (tab.frame(), tab.evaluate("[document.title, document.querySelector('#bar h1').textContent, document.querySelector('#bar').querySelectorAll('img').length, document.querySelector('iframe').title]"))[1], [title, title, 0, title])
    with open(os.path.join(here, "viewer.js"), encoding="utf-8") as fh:
        eq("viewer.js builds no markup from text", re.findall(r"innerHTML|outerHTML|insertAdjacentHTML|document\.write|createContextualFragment|DOMParser", fh.read()), [])
    for w in (1280, 375):
        tab = visit(b, server.url + "/artifacts/long.html", w)
        tab.frame()
        eq("at %d px the frame fills the window under the bar, the title is cut and nothing scrolls sideways" % w, lambda: tab.evaluate("(() => { const bar = document.querySelector('#bar').getBoundingClientRect(), f = document.querySelector('iframe').getBoundingClientRect(), t = document.querySelector('#bar h1'), n = document.querySelector('#notes').getBoundingClientRect(); return [bar.top, f.top === bar.bottom, f.bottom, f.left, f.width, document.documentElement.scrollWidth, getComputedStyle(t).textOverflow, t.scrollWidth > t.clientWidth || innerWidth > 1000, n.right <= innerWidth, %s]; })()" % (SHOWN % "#chip")),
           [0, True, 800, 0, w, w, "ellipsis", True, True, w == 1280])

def reload(b):
    tab = visit(b, server.url + "/decks/fixture.html")
    tab.frame()
    eq("the frame takes focus on load", lambda: tab.wait(FOCUS + " === 'iframe'") and tab.evaluate(FOCUS), "iframe")
    tab.evaluate("window.mark = document.querySelector('iframe'); 1")
    before = tab.evaluate("history.length")
    page("decks/fixture.html", title="saved")
    eq("a save reloads the frame alone, as a new frame, with no new history entry, and renames the bar", lambda: (tab.wait("document.querySelector('iframe') !== window.mark", 8), tab.wait(FOCUS + " === 'iframe'"), tab.frame().evaluate(H1), tab.evaluate("[!!window.mark, history.length - %d, document.title, document.querySelector('#bar h1').textContent]" % before))[1:],
       (True, "saved", [True, 0, "saved", "saved"]))
    tab.evaluate("window.mark = document.querySelector('iframe'); document.querySelector('#notes').focus(); 1")
    page("decks/fixture.html", title="again")
    eq("a reload leaves the focus on a viewer control", lambda: (tab.wait("document.querySelector('iframe') !== window.mark", 8), tab.frame().evaluate(H1), time.sleep(0.2), tab.evaluate(FOCUS))[1:], ("again", None, "notes"))
    say = "postMessage(%s, '*'); 1"
    ready = "{ dk: 1, t: 'ready', hash: '#' }"
    tab.evaluate("document.activeElement.blur(); 1")
    tab.evaluate(say % ready)
    for shape in ("{ dk: 2, t: 'ready', hash: '#' }", "{ dk: 1, t: 'ready' }", "{ dk: 1, t: 'ready', hash: 7 }", "{ dk: 1, t: 'ready', hash: '#<' }", "{ dk: 1, t: ['ready'], hash: '#' }", "{ dk: 1, t: 'toString', hash: '#' }", "{ dk: 1, t: 'open', hash: '#' }", "null", "'ready'"):
        tab.frame().evaluate("parent." + say % shape)
    eq("a message from another window, of another shape or an unknown type changes nothing", lambda: (time.sleep(0.2), tab.evaluate(FOCUS))[1], "body")
    tab.frame().evaluate("parent." + say % ready)
    eq("the frame's own ready message focuses it", lambda: tab.wait(FOCUS + " === 'iframe'"), True)
    tab = visit(b, server.url + "/artifacts/nest.html")
    f = tab.frame()
    tab.wait(FOCUS + " === 'iframe'")
    tab.evaluate("document.activeElement.blur(); 1")
    f.evaluate("document.querySelector('iframe').contentWindow.postMessage(1, '*'); 1")
    eq("a message from a frame inside the page changes nothing", lambda: (time.sleep(0.2), tab.evaluate(FOCUS))[1], "body")

def gone(b):
    page("decks/going.html", title="going")
    tab = visit(b, server.url + "/decks/going.html")
    tab.frame()
    time.sleep(1.6)
    os.unlink(os.path.join(ROOT, "decks/going.html"))
    eq("a page deleted while open says so", lambda: (tab.wait(STRIPS + ".length", 8), tab.evaluate(STRIPS))[1], ["This page was deleted"])
    page("decks/going.html", title="back")
    eq("and shows again when it returns", lambda: (tab.wait("!%s.length" % STRIPS, 8), tab.wait("document.title === 'back'"), tab.frame().evaluate(H1))[1:], (True, "back"))

def lost(b):
    tab = visit(b, server.url + "/" + BOARD)
    tab.frame()
    tab.evaluate("window.mark = document.querySelector('iframe'); window.was = window.mark.src; window.said = 0; new MutationObserver((all) => { for (const one of all) window.said += one.addedNodes.length; }).observe(document.querySelector('#strips'), { childList: true, subtree: true }); document.querySelector('#notes').focus(); 1")
    server.stop()
    eq("server lost strip", lambda: (tab.wait(STRIPS + ".length", 8), tab.evaluate("[%s, document.querySelector('#strips').getAttribute('aria-live'), %s]" % (STRIPS, FOCUS)))[1], [["Preview server stopped; retrying"], "polite", "notes"])
    time.sleep(3.5)
    eq("the strip is said once, however often the viewer retries", lambda: tab.evaluate("[window.said, %s.length]" % STRIPS), [1, 1])
    server.start()
    eq("the strip goes when the server answers again", lambda: tab.wait("!%s.length" % STRIPS, 12), True)
    eq("the frame is then a new one, at the new server's address for the page; the bar stayed", lambda: (tab.wait("document.querySelector('iframe') !== window.mark"), tab.frame().evaluate(H1), tab.evaluate("[document.querySelector('iframe').src !== window.was, %s]" % FOCUS))[1:], ("fixture", [True, "notes"]))
    server.stop()
    server.start(newer=1)
    eq("a viewer older than the server that came back reloads itself", lambda: (tab.wait("!window.was && document.body.dataset.version === '%d'" % (m.SERVER_VERSION + 1), 12), tab.frame().evaluate(H1))[1], "fixture")
    server.stop()
    server.start()

def gallery(b):
    for at in ("/_gallery", "/", "/index.html"):
        tab = visit(b, server.url + at)
        eq("the gallery answers at %s, its pages sandboxed" % at, lambda: tab.evaluate("[document.title, [...document.querySelectorAll('iframe')].every((f) => f.getAttribute('sandbox') === 'allow-scripts' && f.getAttribute('src').startsWith('/_c/')), document.querySelectorAll('iframe').length > 5]"), ["design-kit gallery", True, True])
    eq("a thumbnail is a page in its null origin", lambda: tab.frame().evaluate("self.origin"), "null")
    tab.evaluate("window.mark = 1")
    page("decks/new.html", title="a new deck")
    eq("the gallery reloads on a save, under its own policy", lambda: (tab.wait("!window.mark && document.body.textContent.includes('a new deck')", 8), logged(b, tab))[1], [])
    tab.evaluate("document.querySelector('a.card[href^=\"/motion/a\"]').click(); 1")
    eq("a card opens its page in the viewer", lambda: (tab.wait("document.body.dataset.page", 8), tab.frame().evaluate(H1))[0], OWN + "index.html")

class Older(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_GET(self):
        body = b"" if self.path == "/sw.js" else b"<!doctype html><title>older</title>"
        self.send_response(200)
        for name, value in (("Content-Type", "text/javascript" if self.path == "/sw.js" else "text/html"), ("Content-Length", str(len(body)))):
            self.send_header(name, value)
        self.end_headers()
        self.wfile.write(body)

def threaded(handler, port=0):
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", port), handler)
    srv.daemon_threads = True
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return srv

def worker(b):
    older = threaded(Older)
    count = "navigator.serviceWorker.getRegistrations().then((all) => all.length)"
    tab = b.page("http://127.0.0.1:%d/old.html" % older.server_port)
    was = tab.evaluate("navigator.serviceWorker.register('/sw.js').then(() => navigator.serviceWorker.ready).then(() => %s)" % count)
    older.shutdown(); older.server_close()
    again = Server(older.server_port)
    again.start()
    try:
        tab = visit(b, again.url + "/" + BOARD)
        eq("the viewer unregisters a worker an older server left on its address", lambda: (was, tab.wait(count + ".then((n) => n === 0)", 8)), (1, True))
    finally:
        again.stop()

def far(b):
    srv = threaded(Far)
    url = "http://127.0.0.1:%d" % srv.server_port
    content = lambda name, mode: url + m.isolate.content_url(name, mode)
    top = "motion/top/index.html"
    tab = visit(b, content(top, "s"))
    eq("a static segment opens top-level and its own script runs", lambda: (tab.wait("document.readyState === 'complete'"), time.sleep(0.2), [p for p in asked if p.endswith("ran.png")] != [])[2], True)
    del asked[:]
    tab = visit(b, content(top, "f") + "?still=1#/2")
    eq("without Sec-Fetch headers a top-level framed page leaves for its page URL, query and hash kept, before its own script runs", lambda: (tab.wait("document.body.dataset.page", 3), tab.evaluate("[document.body.dataset.page || null, location.href]"), time.sleep(0.2), [p for p in asked if p.endswith("ran.png")])[1::2],
       ([top, url + "/" + top + "?still=1#/2"], []))
    tab = visit(b, url + "/" + quote(OWN + "index.html") + "?static=1")
    eq("another device gets the viewer, whatever it asks, with Gallery and the title alone; the page loads its own files", lambda: (tab.frame().evaluate("document.querySelector('img').naturalWidth"), tab.evaluate("[...document.querySelectorAll('#bar *')].filter((e) => !e.children.length && e.checkVisibility()).map((e) => e.textContent)")), (1, ["Gallery", "fixture"]))
    eq("and logs no refused request", lambda: logged(b, tab), [])
    srv.shutdown()

server = Server(free_port())
server.start()
try:
    with browser_lib.browser(240) as b:
        for part in (kinds, files, bar, reload, gone, lost, gallery, worker, far):
            try:
                part(b)
            except Exception as exc:
                print("FAIL: %s stopped: %r" % (part.__name__, exc))
                bad.append(part.__name__)
finally:
    server.stop()
sys.exit(1 if bad else 0)
PY
[ "$rc" != 4 ] || [ "${DESIGN_KIT_REQUIRE_BROWSER:-}" = 1 ] || { echo "PASS viewer.test.sh (no browser: nothing ran)"; exit 0; }
[ "$rc" = 0 ] || { echo "FAIL: viewer.test.sh (exit $rc)"; exit 1; }
echo "PASS viewer.test.sh"
