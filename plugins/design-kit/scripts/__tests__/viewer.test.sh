#!/usr/bin/env bash
# Drives the viewer in headless Chrome on a served temp docroot: every kind of page framed with frame.js first and a null origin, the files an own-folder, a review and a deck page load, framed and raw, the bar, its frame's focus, query, hash and Back, reload (at a save of its own page, its last messages in first), the messages it acts on, copy, download and print in a frame, what a page stores, where it stays and who sees it, a full browser, a frame that left or stopped answering, the deleted and server-lost strips, a restart, also with a draft, the gallery, a worker an older server left, and, with the peer's address faked and its Sec-Fetch headers dropped as plain HTTP drops them, the LAN viewer and the bounce of a top-level framed page; browser_lib.py's exit 4 where no browser starts.
# Misses: a hostile page (attack.test.sh), a real second device, what a screen reader says, a page behind an open alert() or print dialog, a page that never stops computing, browsers outside Chromium.
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
page("artifacts/bridge.html", head="<script>window.printed = 0; addEventListener('beforeprint', () => printed++)</script>", body="<iframe srcdoc=\"<script>onmessage = (e) => parent.parent.postMessage(e.data, '*')</script>\"></iframe>")
page("artifacts/copies.html", body="""<button id="clip" onclick="navigator.clipboard.writeText('by clipboard').then(() => { window.said = 'copied'; }, (e) => { window.said = e.name; })">clip</button>
<button id="exec" onclick="const t = document.createElement('textarea'); t.value = 'by execCommand'; document.body.append(t); t.select(); window.said = document.execCommand('copy'); t.remove()">exec</button>
<a id="data" download="data.txt" href="data:text/plain,x">data</a> <a id="blob" download="blob.txt">blob</a><script>document.querySelector('#blob').href = URL.createObjectURL(new Blob(['y']))</script>""")

def built(script, name, spec):
    """A page one of the kit's builders makes."""
    src = os.path.join(os.path.dirname(ROOT), os.path.basename(name) + ".spec." + ("json" if spec[0] == "{" else "md"))
    with open(src, "w") as fh:
        fh.write(spec)
    subprocess.run([sys.executable, os.path.join(here, script), src, "--out", os.path.join(ROOT, name)], cwd=os.path.dirname(ROOT), check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

DECK, PICKS = "decks/slides.html", "boards/my, picks.html"
built("deck-build.py", DECK, "# Review\n\n## One\n\n- a\n\n## Two\n\n- b\n\n## Three\n\n- c\n")
built("board-build.py", PICKS, json.dumps({"title": "Checkout", "brief": "errors", "device": "phone", "boards": [{"title": t, "tradeoff": "wide", "body": "<h1>%s</h1>" % t} for t in ("One", "Two")]}))

SERVE = "import importlib.util, sys; s = importlib.util.spec_from_file_location('dkserve', sys.argv[1]); m = importlib.util.module_from_spec(s); s.loader.exec_module(m); m.SERVER_VERSION += int(sys.argv[2]); sys.exit(m.main(sys.argv[3:]))"

def free_port():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]

class Server:
    """serve.py on ROOT, in a process of its own: what it signed dies with it."""

    def __init__(self, port):
        self.port, self.url, self.proc = port, "http://127.0.0.1:%d" % port, None

    def start(self, newer=0, root=ROOT):
        self.proc = subprocess.Popen([sys.executable, "-c", SERVE, os.path.join(here, "serve.py"), str(newer), "--docroot", root, "--port", str(self.port)],
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

# before the viewer's own listener, and a window's run in the order they came; deaf: the viewer hears no answer
HEARD = "window.heard = []; addEventListener('message', (e) => { const { t, n } = e.data, forged = n === 1 || n === 1e9; heard.push(e.source && (forged ? 'forged' : t)); if (window.mute || window.deaf && t === 'pong' && !forged) e.stopImmediatePropagation(); });"
QUICK = "{ const real = setTimeout; window.setTimeout = (fn, ms) => real(fn, { 2000: 200, 8000: 1000 }[ms] || ms); }"

def quick(b, tab):
    """The viewer in tab loaded again, with its pings 10 and its patience 8 times as short."""
    again(b, tab, HEARD + QUICK)
    tab.wait("heard.includes('ready')", 10)
    return tab

def again(b, tab, source=""):
    """The tab, loaded again, and from now on source before any script of its document."""
    b.chrome.call("Page.addScriptToEvaluateOnNewDocument", {"source": source}, tab.sid)
    tab.evaluate("window.was = 1")
    b.chrome.call("Page.reload", {}, tab.sid)
    tab.wait("!window.was && !!document.querySelector('iframe')", 10)
    return tab

MARK = "window.mark = document.querySelector('iframe'); 1"
NEW = "document.querySelector('iframe') !== window.mark"

def reframed(tab, do):
    """The frame the viewer builds anew once do() happened."""
    tab.evaluate(MARK)
    do()
    if not tab.wait(NEW, 12):
        raise TimeoutError("the frame was not replaced")
    return tab.frame()

def reload(b):
    tab = visit(b, server.url + "/decks/fixture.html")
    tab.frame()
    eq("the frame takes focus on load", lambda: tab.wait(FOCUS + " === 'iframe'") and tab.evaluate(FOCUS), "iframe")
    tab.evaluate(MARK)
    before = tab.evaluate("history.length")
    page("decks/other.html")
    put("shots/two.png", png())
    eq("saving another page, or a file that is not the page's own, reloads nothing", lambda: (time.sleep(2.4), tab.evaluate(NEW))[1], False)
    page("decks/fixture.html", title="saved")
    eq("a save reloads the frame alone, as a new frame, with no new history entry, and renames the bar", lambda: (tab.wait("document.querySelector('iframe') !== window.mark", 8), tab.wait(FOCUS + " === 'iframe'"), tab.frame().evaluate(H1), tab.evaluate("[!!window.mark, history.length - %d, document.title, document.querySelector('#bar h1').textContent]" % before))[1:],
       (True, "saved", [True, 0, "saved", "saved"]))
    tab.evaluate("document.querySelector('#notes').focus(); 1")
    on_bar = (reframed(tab, lambda: page("decks/fixture.html", title="again")), time.sleep(0.2), tab.evaluate(FOCUS))[2]
    name = "decks/hung.html"
    page(name, title="first")
    tab = quick(b, visit(b, server.url + "/" + name))
    tab.evaluate("window.said = 0; new MutationObserver((all) => { for (const one of all) window.said += one.addedNodes.length; }).observe(document.querySelector('#strips'), { childList: true }); 1")
    eq("a frame that answers shows no strip", lambda: (time.sleep(1.4), tab.evaluate("window.said"))[1], 0)
    tab.evaluate("window.deaf = true")
    tab.wait(STRIPS + ".length", 3)
    tab.evaluate("document.querySelector('#strips button')?.focus(); window.was = document.querySelector('#strips').firstChild; 1")
    said = "[document.activeElement.textContent, window.was?.isConnected]"
    eq("reload keeps focus on a viewer control", lambda: [on_bar, reframed(tab, lambda: page(name, title="second")).evaluate(H1), (time.sleep(0.3), tab.evaluate(said))[1]], ["notes", "second", ["Reload page", True]])
    eq("Reload page frames the page again and keeps the focus until it answers", lambda: [reframed(tab, lambda: tab.key("Enter")).evaluate(H1), (time.sleep(0.3), tab.evaluate(said))[1]], ["second", ["Reload page", True]])
    tab.evaluate("window.deaf = false")
    eq("an answer takes the strip away and gives the page its focus", lambda: (tab.wait("!%s.length" % STRIPS, 3), tab.evaluate(FOCUS)), (True, "iframe"))
    tab.evaluate("heard.length = 0")
    eq("one ping every 2 s, 10 times as fast here, however often the frame was replaced", lambda: (time.sleep(1), 3 <= tab.evaluate("heard.filter((t) => t === 'pong').length") <= 6)[1], True)
    tab.evaluate("window.deaf = true; Object.defineProperty(document, 'hidden', { configurable: true, value: true }); document.dispatchEvent(new Event('visibilitychange')); 1")
    reframed(tab, lambda: page(name, title="third"))
    tab.evaluate("heard.length = 0")
    eq("a hidden viewer pings nothing and shows no strip", lambda: (time.sleep(1.4), tab.evaluate("[heard.filter((t) => t === 'pong').length < 2, %s]" % STRIPS))[1], [True, []])
    tab.evaluate("delete document.hidden; document.dispatchEvent(new Event('visibilitychange')); 1")
    eq("and pings again once it is visible", lambda: (tab.wait(STRIPS + ".length", 3), tab.evaluate("heard.includes('pong')")), (1, True))
    tab.frame().evaluate("location.href = 'https://out.example/'; 1")
    eq("a frame that left is not one that does not answer", lambda: (tab.wait("!document.querySelector('iframe')"), time.sleep(1.4), tab.evaluate(STRIPS))[2], [])
    again(b, tab, "window.mute = true")
    eq("a frame that never starts is", lambda: tab.wait(STRIPS + ".length", 3), 1)

def entries(tab, part=""):
    return {k: v for k, v in tab.evaluate("Object.entries(localStorage)") if k.startswith("dk-store:") and part in k}

WHOLE = "JSON.stringify([location.href, document.title, document.body.innerHTML, Object.entries(localStorage).sort(), %s])" % FOCUS
POST = "postMessage(%s, '*'); "
KINDLY = ("{ dk: 1, t: 'ready', hash: '#' }", "{ dk: 1, t: 'hash', hash: '#/9' }", "{ dk: 1, t: 'store', items: [['forged', '1']] }", "{ dk: 1, t: 'key', name: 'print' }")
WRONG = (
    "null", "'ready'", "{ dk: 2, t: 'ready', hash: '#' }", "{ dk: 1, t: ['ready'], hash: '#' }", "{ dk: 1, t: 'toString', hash: '#' }", "{ dk: 1, t: 'open', hash: '#' }",
    "{ dk: 1, t: 'ready' }", "{ dk: 1, t: 'ready', hash: 7 }", "{ dk: 1, t: 'ready', hash: '#<' }",
    "{ dk: 1, t: 'hash' }", "{ dk: 1, t: 'hash', hash: '#<' }", "{ dk: 1, t: 'hash', hash: '/decks/old.htm' }", "{ dk: 1, t: 'hash', hash: '#' + 'x'.repeat(129) }", "{ dk: 1, t: 'hash', hash: ['#/9'] }",
    "{ dk: 1, t: 'store' }", "{ dk: 1, t: 'store', items: 'k' }", "{ dk: 1, t: 'store', items: [['k', 1]] }", "{ dk: 1, t: 'store', items: [['k']] }", "{ dk: 1, t: 'store', items: [['k', '1', '2']] }", "{ dk: 1, t: 'store', items: [['j', '1'], [1, '1']] }",
    "{ dk: 1, t: 'store', items: [['k'.repeat(257), '1']] }", "{ dk: 1, t: 'store', items: [['k', '1'], , ['j', '1']] }", "{ dk: 1, t: 'store', items: new Array(2 ** 32 - 1) }", "{ dk: 1, t: 'store', items: { 0: ['k', '1'], length: 1 } }", "{ dk: 1, t: 'store', clear: 1 }", "{ dk: 1, t: 'store', clear: true, items: [['k', '1']] }",
    "{ dk: 1, t: 'key' }", "{ dk: 1, t: 'key', name: 'Print' }", "{ dk: 1, t: 'key', name: ['print'] }", "{ dk: 1, t: 'key', name: 'constructor' }",
    "{ dk: 1, t: 'pong', n: 0 }", "{ dk: 1, t: 'pong', n: 1e9 }", "{ dk: 1, t: 'pong', n: '1' }",
    "{ dk: 1, t: 'anchor', anchor: { selector: 'h1', tag: 'h1', text: 'x', rect: { x: 0, y: 0, w: 1, h: 1 } }, context: { viewport: { w: 1, h: 1 }, theme: '', console: [] } }", "{ dk: 1, t: 'context', context: { viewport: { w: 1, h: 1 }, theme: '', console: [] } }",
)

def bridge(b):
    tab = visit(b, server.url + "/artifacts/bridge.html")
    f = tab.frame()
    tab.wait(FOCUS + " === 'iframe'")
    f.evaluate("parent." + POST % "{ dk: 1, t: 'store', items: [['mine', '1']] }" + "1")
    tab.wait("Object.keys(localStorage).some((k) => k.endsWith(':mine'))", 2)
    tab.evaluate("document.activeElement.blur(); 1")
    before = tab.evaluate(WHOLE)
    tab.evaluate("".join(POST % one for one in KINDLY + ("{ dk: 1, t: 'store', clear: true }",)) + "1")
    eq("a message from another window changes nothing", lambda: (time.sleep(0.2), tab.evaluate(WHOLE), f.evaluate("printed"))[1:], (before, 0))
    f.evaluate("".join("document.querySelector('iframe').contentWindow." + POST % one for one in KINDLY + ("{ dk: 1, t: 'store', clear: true }",)) + "1")
    eq("a message from a frame inside the page changes nothing", lambda: (time.sleep(0.2), tab.evaluate(WHOLE), f.evaluate("printed"))[1:], (before, 0))
    f.evaluate("".join("parent." + POST % one for one in WRONG) + "1")
    eq("a wrong shape, an unknown type and an anchor with notes off change nothing", lambda: (time.sleep(0.2), tab.evaluate(WHOLE), f.evaluate("printed"))[1:], (before, 0))
    f.evaluate("".join("parent." + POST % one for one in KINDLY) + "1")
    eq("the page's own of the same four types are acted on", lambda: (f.wait("printed"), tab.wait(FOCUS + " === 'iframe'"), tab.evaluate("location.hash"), sorted(k.split(":")[-1] for k in entries(tab, "bridge.html")))[1:], (True, "#/9", ["forged", "mine"]))
    tab.evaluate("window.moves = []; history.replaceState = function (...args) { moves.push(performance.now()); History.prototype.replaceState.apply(this, args); }; 1")
    f.evaluate("let n = 0; const flood = setInterval(() => { for (let i = 0; i < 10; i++, n++) { parent." + POST % "{ dk: 1, t: 'hash', hash: '#/' + n }" + "if (n % 100 === 0) parent." + POST % "{ dk: 1, t: 'store', items: [['n' + n, 'x']] }" + "} if (n === 500) clearInterval(flood); }, 12); 1")
    tab.wait("Object.keys(localStorage).some((k) => k.endsWith(':n400'))", 5)
    time.sleep(0.3)
    eq("of 500 hash messages in a second at most 50 are acted on, while store messages still land", lambda: tab.evaluate("[Math.max(...moves.map((t) => moves.filter((u) => u >= t && u < t + 990).length)) <= 50, moves.length >= 40, Object.keys(localStorage).filter((k) => /:n\\d+$/.test(k)).length]"), [True, True, 5])

def place(b):
    deck = "/" + DECK
    with open(os.path.join(ROOT, DECK), encoding="utf-8") as fh:
        slides = fh.read()
    isolated = "[location.hash, [...document.querySelectorAll('.dk-board')].findIndex((one) => one.classList.contains('isolated')) + 1]"
    slide = "[location.hash, [...document.querySelectorAll('.slide')].findIndex((one) => one.classList.contains('current')) + 1]"
    eq("a board opens at #board=2", lambda: visit(b, server.url + "/" + quote(PICKS) + "#board=2").frame().evaluate(isolated), ["#board=2", 2])
    for what, happen in (("moving slides", None), ("a save", lambda: put(DECK, slides)), ("a server restart", lambda: (server.stop(), server.start()))):
        tab = visit(b, server.url + "/artifacts/fixture.html")
        tab.frame()
        b.chrome.call("Page.navigate", {"url": server.url + deck + "#/2"}, tab.sid)
        tab.wait("location.hash")
        f = tab.frame()
        eq("a deck opens at #/2", lambda: f.evaluate(slide), ["#/2", 2])
        tab.wait(FOCUS + " === 'iframe'")
        tab.key("ArrowRight")
        eq("an arrow key right after load moves the deck, and the address with it", lambda: (tab.wait("location.hash === '#/3'"), f.evaluate(slide), tab.evaluate("location.pathname + location.hash"))[1:], (["#/3", 3], deck + "#/3"))
        if happen:
            eq("after %s at #/3 the frame stays at #/3" % what, lambda: (reframed(tab, happen).evaluate(slide), tab.evaluate("[location.pathname + location.hash, !!window.mark]")), (["#/3", 3], [deck + "#/3", True]))
        tab.evaluate("history.back(); 1")
        eq("Back after %s goes to the page before" % what, lambda: (tab.wait("location.pathname !== '%s'" % deck), tab.evaluate("location.pathname + location.hash"), tab.frame().evaluate(H1))[1:], ("/artifacts/fixture.html", "fixture"))
    tab = visit(b, server.url + "/_gallery")
    asked_for = "?still=1&static=1&key=k&capture=a%20b&st%61tic=1&x"
    tab.evaluate("location.href = '/decks/fixture.html%s#/2'; 1" % asked_for)  # from the gallery, as ?static=1 typed opens the raw page
    tab.wait("document.body.dataset.page")
    f = tab.frame()
    eq("?still=1 reaches the frame and static does not", lambda: f.evaluate("location.search + location.hash"), "?still=1&capture=a%20b&x#/2")
    f.evaluate("location.hash = '#/4'; 1")
    eq("the address keeps its own query as the frame moves", lambda: (tab.wait("location.hash === '#/4'"), tab.evaluate("location.search + location.hash"))[1], asked_for + "#/4")
    f.evaluate("document.body.append(Object.assign(document.createElement('a'), { href: '#/5', id: 'inside', textContent: 'inside' })); 1")
    tab.evaluate(MARK)
    tab.click(*f.at("#inside"))
    tab.wait("location.hash === '#/5'")
    tab.evaluate("history.back(); 1")
    eq("Back after a link inside the page steps back in it", lambda: (tab.wait("location.hash === '#/4'"), time.sleep(0.5), f.evaluate("location.hash"), tab.evaluate(NEW)), (True, None, "#/4", False))
    eq("a hash typed into the address moves the frame", lambda: reframed(tab, lambda: tab.evaluate("location.hash = '#/1'; 1")).evaluate("location.hash"), "#/1")

def copies(b):
    tab = visit(b, server.url + "/artifacts/copies.html")
    f = tab.frame()
    del b.chrome.downloads[:]
    tab.evaluate("document.body.append(document.createElement('textarea')); document.querySelector('textarea').style.cssText = 'position: fixed; right: 0; bottom: 0'; 1")
    def copied(how):
        f.evaluate("window.said = null")
        tab.click(*f.at(how))
        said = f.wait("window.said")
        tab.evaluate("document.querySelector('textarea').value = ''; document.querySelector('textarea').focus(); 1")
        b.chrome.call("Input.dispatchKeyEvent", {"type": "rawKeyDown", "commands": ["paste"]}, tab.sid)
        tab.wait("document.querySelector('textarea').value", 2)
        return [said, tab.evaluate("document.querySelector('textarea').value")]
    eq("copy by clipboard works in the frame", lambda: copied("#clip"), ["copied", "by clipboard"])
    eq("copy by execCommand works in the frame", lambda: copied("#exec"), [True, "by execCommand"])
    for one in ("#data", "#blob"):
        tab.click(*f.at(one))
    eq("a download link works in the frame", lambda: (tab.evaluate("new Promise((r) => setTimeout(r, 300))"), sorted(b.chrome.downloads))[1], ["blob.txt", "data.txt"])

def prints(b):
    said = []
    for at, key in (("iframe", "p"), ("iframe", "Control+p"), ("#notes", "Control+p"), ("#notes", "Meta+p"), ("#notes", "p"), ("#notes", "Control+b"), ("#notes", "Control+Shift+p")):  # headless Chrome prints once a document
        tab = visit(b, server.url + "/" + DECK)
        f = tab.frame()
        f.evaluate("window.printed = 0; addEventListener('beforeprint', () => printed++); 1")
        tab.wait(FOCUS + " === 'iframe'")
        tab.evaluate("document.querySelector('%s').focus(); 1" % at)
        tab.key(key)
        time.sleep(0.3)
        said.append(f.evaluate("printed"))
    eq("P and Ctrl+P fire beforeprint in the frame, Ctrl+P and Cmd+P on a viewer control too, no other key there does", said, [1, 1, 1, 1, 0, 0, 0])

STOPPED = [["p", "Page stopped: it tried to open another site."], ["button", "Reload page"], ["a", "Back to gallery"]]
AREA = "[...document.querySelectorAll('#frame *')].filter((e) => !e.children.length).map((e) => [e.localName, e.textContent])"
BAR = "[...document.querySelectorAll('#bar *')].filter((e) => !e.children.length && e.checkVisibility()).map((e) => e.textContent)"

def stops(b):
    tab = visit(b, server.url + "/artifacts/fixture.html")
    tab.wait("document.querySelector('#chip').textContent")
    bar = tab.evaluate(BAR)
    for how in ("location.href = 'https://out.example/'", "location.replace('/_gallery')"):
        tab.wait(FOCUS + " === 'iframe'")
        tab.frame().evaluate(how + "; 1")
        eq("a frame that navigates away shows the stopped area", lambda: (tab.wait("!document.querySelector('iframe')"), tab.evaluate("[%s, %s, %s]" % (AREA, STRIPS, BAR)))[1], [STOPPED, [], bar])
        eq("the stopped area is read out where the page had the focus", lambda: tab.evaluate("document.activeElement.textContent"), STOPPED[0][1])
        eq("Reload page in the stopped area brings the page back", lambda: (tab.click(*tab.at("#frame button")), tab.frame().evaluate(H1), tab.wait(FOCUS + " === 'iframe'"))[1:], ("fixture", True))
    tab.evaluate("document.querySelector('#notes').focus(); 1")
    tab.frame().evaluate("location.href = 'https://out.example/'; 1")
    tab.wait("!document.querySelector('iframe')")
    eq("a viewer control keeps the focus: the area is announced, and nothing there happens by itself", lambda: (time.sleep(2.2), tab.evaluate("[%s, %s, %s, document.querySelector('#frame [role=alert]').textContent]" % (AREA, STRIPS, FOCUS)))[1], [STOPPED, [], "notes", "".join(text for _, text in STOPPED)])
    eq("and the viewer threw nothing", lambda: [e["params"] for e in b.chrome.events if e.get("sessionId") == tab.sid and e["method"] == "Runtime.exceptionThrown"], [])
    eq("Back to gallery opens the gallery", lambda: (tab.click(*tab.at("#frame a")), tab.wait("location.pathname === '/_gallery'"), tab.evaluate("document.title"))[2], "design-kit gallery")

def hangs(b):
    page("artifacts/busy.html", title="busy", body="<script>const from = Date.now(); while (Date.now() - from < 9000);</script>")
    tab = visit(b, server.url + "/artifacts/fixture.html")
    b.chrome.call("Page.navigate", {"url": server.url + "/artifacts/busy.html"}, tab.sid)
    tab.wait("document.body.dataset.page === 'artifacts/busy.html' && !!document.querySelector('iframe')")
    tab.evaluate(MARK)
    eq("a frame blocked 9 s shows the not-answering strip", lambda: (tab.wait(STRIPS + ".length", 10), tab.evaluate("[[...document.querySelectorAll('#strips > * > *')].map((e) => [e.localName, e.textContent]), %s]" % FOCUS))[1], [[["p", "This page is not answering"], ["button", "Reload page"]], "iframe"])
    eq("its answer clears the strip, and nothing was reloaded", lambda: (tab.wait("!%s.length" % STRIPS, 5), tab.evaluate(NEW), tab.frame().evaluate(H1)), (True, False, "busy"))
    os.unlink(os.path.join(ROOT, "artifacts/busy.html"))  # before the gallery frames it

TRY = "const t = (f) => { try { f(); return 'ok'; } catch (e) { return e.name; } };"
WRITES = "localStorage.clear(); new Promise((done) => { let n = 0; const tick = () => { localStorage.setItem('count', String(++n)); if (n < 120) setTimeout(tick, 8); else { %s; done(1); } }; tick(); })"

def keeps(b):
    name, other = "boards/keeps.html", "boards/keeps.html:k.html"
    for one in (name, other, "boards/going.html", "boards/kept.shtml"):
        page(one)
    page("design-system/kit.html")
    at = lambda one: server.url + "/" + quote(one)
    mine = "[localStorage.k, localStorage.getItem('at:' + location.pathname), localStorage.getItem('__proto__'), localStorage.length]"
    tab = visit(b, at(name))
    f = tab.frame()
    f.evaluate("localStorage.setItem('k', 'one'); localStorage.setItem('at:' + location.pathname, 'two'); localStorage.setItem('gone', '1'); 1")
    tab.wait("Object.keys(localStorage).some((k) => k.endsWith(':gone'))")
    f.evaluate("localStorage.removeItem('gone'); localStorage.setItem('__proto__', 'three'); 1")
    tab.wait("!Object.keys(localStorage).some((k) => k.endsWith(':gone'))")
    want = ["one", "two", "three", 3]
    eq("storage survives a frame reload, a key holding the content path included", lambda: reframed(tab, lambda: page(name, title="saved")).evaluate(mine), want)
    eq("storage survives a server restart", lambda: reframed(tab, lambda: (server.stop(), server.start())).evaluate(mine), want)
    tab = visit(b, at(other))
    f = tab.frame()
    eq("another page sees nothing", lambda: f.evaluate("Object.keys(localStorage)"), [])
    f.evaluate("localStorage.setItem('k', 'of the other'); localStorage.clear(); localStorage.setItem('j', 'of the other'); 1")
    tab.wait("Object.keys(localStorage).some((k) => k.endsWith(':j'))")
    eq("nor does what it writes, or its clear(), reach this one", lambda: visit(b, at(name)).frame().evaluate(mine), want)
    second = os.path.join(os.path.dirname(ROOT), "second")
    os.makedirs(os.path.join(second, "boards"))
    theirs = "boards/going.html"
    for one in (name, theirs):
        with open(os.path.join(second, one), "w") as fh:
            fh.write("<!doctype html><title>second</title><h1>second</h1>")
    server.stop()
    server.start(root=second)
    try:
        for one in (name, theirs):
            tab = visit(b, at(one))
            f = tab.frame()
            eq("another docroot on the same port sees nothing", lambda: f.evaluate("[document.title, Object.keys(localStorage)]"), ["second", []])
            f.evaluate("localStorage.setItem('k', 'of the second'); 1")
            tab.wait("Object.entries(localStorage).filter(([k, v]) => v === 'of the second').length === %d" % (1 + (one == theirs)))
        time.sleep(0.5)
    finally:
        server.stop()
        server.start()
    tab = visit(b, at(name))
    f = tab.frame()
    eq("and its own writes, and its list of pages, leave this one's", lambda: f.evaluate(mine), want)
    eq("a write past the cap throws QuotaExceededError and the page goes on", lambda: f.evaluate(TRY + "[t(() => localStorage.setItem('big', 'x'.repeat(256 * 1024))), t(() => localStorage.setItem('after', '1'))]"), ["QuotaExceededError", "ok"])
    eq("and keeps what it writes after that", lambda: (tab.wait("Object.keys(localStorage).some((k) => k.endsWith(':after'))"), tab.evaluate(STRIPS))[1], [])
    def big(f, *keys):
        """What the viewer keeps once the page, going round its client, posted each of these keys with 100 KB, or removed it: -2."""
        f.evaluate("for (const i of %s) parent." % json.dumps(keys) + POST % "{ dk: 1, t: 'store', items: [['big' + Math.abs(i), i < 0 ? null : 'x'.repeat(100 * 1024)]] }" + "1")
        time.sleep(0.3)
        return [sorted(k.split(":")[-1] for k in entries(tab, "big")), tab.evaluate(STRIPS + ".length")]
    eq("nor does the viewer keep more than 256 KB for a page that goes round its client, a key counted once however often written", lambda: big(f, 1, 1, 1, 2, 3), [["big1", "big2"], 1])
    f = reframed(tab, lambda: page(name, title="big"))
    eq("a reload takes the strip away and counts what is there", lambda: [tab.evaluate(STRIPS), big(f, 4), big(f, -1, -2, 4), big(f, 1, 2)], [[], [["big1", "big2"], 1], [["big4"], 0], [["big1", "big4"], 1]])
    f.evaluate("parent." + POST % "{ dk: 1, t: 'store', clear: true }" + "1")
    eq("and so does a clear()", lambda: big(f), [[], 0])

    f.evaluate(WRITES % "location.reload()")
    eq("120 writes a second to one key, then the page's own reload, keep the last value", lambda: (tab.wait("Object.entries(localStorage).some(([k, v]) => k.endsWith(':count') && v === '120')"), tab.frame().wait("localStorage.count === '120'"))[1], True)
    tab.frame().evaluate(WRITES % "1")
    eq("and then the viewer's", lambda: again(b, tab).frame().evaluate("localStorage.count"), "120")

    for one in ("boards/going.html", "boards/kept.shtml", "design-system/kit.html"):
        tab = visit(b, at(one))
        tab.frame().evaluate("localStorage.setItem('k', 'here'); 1")
        tab.wait("Object.keys(localStorage).some((k) => k.includes(':%s:'))" % one)
    os.unlink(os.path.join(ROOT, "boards/going.html"))
    before = entries(tab)
    tab = visit(b, at(BOARD))
    tab.wait("!Object.entries(localStorage).some(([k, v]) => k.includes(':boards/going.html:') && v === 'here')", 5)
    time.sleep(0.3)
    eq("entries of a deleted page are gone on the next load, those of a page no list names and of another docroot are not", lambda: [sorted(k.split(":", 2)[2] for k in set(before) - set(entries(tab))), len([k for k in entries(tab) if "kept.shtml" in k or "kit.html" in k]), list(entries(tab).values()).count("of the second")], [["boards/going.html:k"], 2, 2])

    state, newer = ({"knobs": {"all": {"space": n}}, "text": {}, "picked": None} for n in (12, 14))
    old = "localStorage.%s('design-kit:' + new URL('/" + PICKS + "', location).pathname%s); 1"
    board = "window.designKit.state()"
    tab.evaluate(old % ("setItem", ", " + json.dumps(json.dumps(state))))
    tab = visit(b, at(PICKS))
    eq("a board's state left by 0.19.3 is read", lambda: tab.frame().evaluate(board), state)
    tab.evaluate(old % ("setItem", ", " + json.dumps(json.dumps(newer))))
    tab = visit(b, at(PICKS))
    eq("not where the board has one of its own", lambda: tab.frame().evaluate(board), state)
    tab.evaluate(old % ("removeItem", ""))
    tab.frame().evaluate("localStorage.clear(); 1")
    tab.wait("!Object.keys(localStorage).some((k) => k.includes(':%s:'))" % PICKS)
    eq("and once", lambda: visit(b, at(PICKS)).frame().evaluate(board + ".knobs"), {})

def full(b):
    tab = visit(b, server.url + "/" + BOARD)
    f = tab.frame()
    tab.evaluate("for (const size of [1 << 20, 1 << 10]) { try { for (let i = 0; ; i++) localStorage.setItem('fill' + size + i, 'x'.repeat(size)); } catch (e) { /* full */ } } 1")
    f.evaluate("localStorage.setItem('late', 'y'.repeat(4096)); 1")
    eq("storage-full strip shown", lambda: (tab.wait(STRIPS + ".length"), tab.evaluate("[%s, %s]" % (STRIPS, FOCUS)))[1], [["Storage is full; changes to this page are not saved"], "iframe"])
    f.evaluate("localStorage.setItem('small', 'z'); 1")
    eq("it stays while a change is not saved", lambda: (time.sleep(0.4), tab.evaluate(STRIPS))[1], ["Storage is full; changes to this page are not saved"])
    tab.evaluate("for (const k of Object.keys(localStorage)) if (k.startsWith('fill')) localStorage.removeItem(k); 1")
    f.evaluate("localStorage.setItem('next', 'z'); 1")
    eq("it goes, and the refused write is saved, with the next write there is room for", lambda: (tab.wait("!%s.length" % STRIPS), sorted((k.split(":")[-1], len(v)) for k, v in entries(tab, BOARD).items())), (True, [("late", 4096), ("next", 1), ("small", 1)]))
    f = again(b, tab, "Object.defineProperty(window, 'localStorage', { get() { throw new DOMException('refused', 'SecurityError'); } })").frame()
    f.evaluate("localStorage.setItem('late', 'y'); 1")
    eq("a browser that keeps no site data shows the page, and says its changes are not saved", lambda: (tab.wait(STRIPS + ".length"), tab.evaluate(STRIPS), f.evaluate(H1 + " + localStorage.late"))[1:], (["Storage is full; changes to this page are not saved"], "fixturey"))

def drops(b):
    name = "decks/writes.html"
    writes = "<script>let n = 0; setInterval(() => localStorage.setItem('n', ++n), 10); let k = 0; setInterval(() => parent.postMessage({ dk: 1, t: 'pong', n: k++ % 2 ? 1 : 1e9 }, '*'), 40)</script>"
    page(name, head=writes)
    tab = visit(b, server.url + "/" + name)
    again(b, tab, HEARD)
    tab.wait("heard.includes('ready')", 10)
    tab.evaluate("new MutationObserver(() => heard.push('replaced')).observe(document.querySelector('#frame'), { childList: true }); 1")
    reframed(tab, lambda: page(name, title="saved", head=writes))
    eq("a frame is replaced once its last write is in", lambda: tab.evaluate("heard.filter((t) => t !== 'forged').join().split(',replaced')[0].replace(/(,pong)+$/, ',pong').split(',').slice(-2)"), ["store", "pong"])
    tab.evaluate("window.deaf = true")
    eq("a frame that does not answer is replaced all the same", lambda: reframed(tab, lambda: page(name, title="unanswered")).evaluate(H1), "unanswered")
    eq("and no sooner for a pong that answers no ping, or an earlier one", lambda: tab.evaluate("heard.join().split(',replaced')[1].split(',pong').pop().split('forged').length > 3"), True)

def gone(b):
    page("decks/going.html", title="going")
    tab = visit(b, server.url + "/decks/going.html")
    tab.frame()
    os.unlink(os.path.join(ROOT, "decks/going.html"))
    eq("a page deleted while open says so, its frame answering or not", lambda: (tab.wait(STRIPS + ".length", 8), time.sleep(2.2), tab.evaluate(STRIPS))[2], ["This page was deleted"])
    server.stop()
    eq("then a lost server too", lambda: (tab.wait(STRIPS + ".length > 1", 8), tab.evaluate(STRIPS))[1], ["This page was deleted", "Preview server stopped; retrying"])
    server.start()
    eq("and once it is back, the deleted page alone", lambda: (tab.wait(STRIPS + ".length === 1", 8), tab.evaluate(STRIPS))[1], ["This page was deleted"])
    page("decks/going.html", title="back")
    eq("the page shows again when it returns", lambda: (tab.wait("!%s.length" % STRIPS, 12), tab.wait("document.title === 'back'"), tab.frame().evaluate(H1))[1:], (True, "back"))

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
    tab.evaluate("document.querySelector('#drawer').append(Object.assign(document.createElement('textarea'), { value: 'half a note' })); 1")
    def newer():
        server.stop()
        server.start(newer=1)
    eq("a viewer older than the server that came back keeps a draft: the frame alone is new", lambda: (reframed(tab, newer).evaluate(H1), tab.evaluate("[!!window.was, document.querySelector('textarea').value]")), ("fixture", [True, "half a note"]))
    tab.evaluate("document.querySelector('textarea').remove(); 1")
    newer()
    eq("a viewer older than the server that came back reloads itself", lambda: (tab.wait("!window.was && document.body.dataset.version === '%d'" % (m.SERVER_VERSION + 1), 12), tab.frame().evaluate(H1))[1], "fixture")
    server.stop()
    server.start()

def gallery(b):
    for at in ("/_gallery", "/", "/index.html"):
        tab = visit(b, server.url + at)
        eq("the gallery answers at %s, its pages sandboxed" % at, lambda: tab.evaluate("[document.title, [...document.querySelectorAll('iframe')].every((f) => f.getAttribute('sandbox') === 'allow-scripts' && f.getAttribute('src').startsWith('/_c/')), document.querySelectorAll('iframe').length > 5]"), ["design-kit gallery", True, True])
    eq("a thumbnail is a page in its null origin", lambda: browser_lib.Frame(tab, b.chrome.children[tab.sid][0]).evaluate("self.origin"), "null")  # the first: Chrome paints no thumbnail below the window
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
    with browser_lib.browser(420) as b:
        for part in (kinds, files, bar, reload, bridge, place, copies, prints, stops, hangs, keeps, full, drops, gone, lost, gallery, worker, far):
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
