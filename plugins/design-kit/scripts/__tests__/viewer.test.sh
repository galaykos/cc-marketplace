#!/usr/bin/env bash
# Drives the viewer in headless Chrome on a served temp docroot: every kind of page framed with frame.js first and a null origin, the files an own-folder, a review and a deck page load, framed and raw, the bar, its frame's focus, a page that takes it from the viewer (a pointer moved by the system's way, for DevTools' own says nothing of a frame it is over; how much of what is typed such a page got is printed as a NOTE), query, hash and Back, reload (at a save of its own page, its last messages in first), the messages it acts on, copy, download and print in a frame, what a page stores, where it stays and who sees it, a full browser, a frame that left or stopped answering, the deleted and server-lost strips, a restart, also with a draft, a board's pick from its report to its row (the strip's words, what survives what, one row a send whatever becomes of the answer, the 600 ms in which Send pick and Discard do nothing, a flooding page), a note from the page or the viewer to its row (keys, what a draft survives, refusals, the list, where the drawer stands), a blocked host from its strip to the page's policy and back (Network's list, Keep blocked, refusals, an unreadable approvals file, hosts a page makes up; the policy header is the proof, nothing is loaded), the two panels, a link of each kind, over a draft and not, the 600 ms in which Allow and Open do nothing either, the contract's seven states at 1280 and 375 px (what is where, nothing sideways, axe-core, Tab order, nothing draggable, a strip said once and never focused, a screenshot of each in the temp dir), the strips' order, 40 notes and 12 blocked hosts at 375 px, Tab into a page with nothing to focus, the LAN viewer at this machine's own address (a SKIP line without one: at a faked peer's then), the gallery, a worker an older server left, and, with the peer's address faked and its Sec-Fetch headers dropped as plain HTTP drops them, the bounce of a top-level framed page and what the LAN viewer asks for; browser_lib.py's exit 4 where no browser starts.
# Misses: a hostile page (attack.test.sh), what an allowed host's file does, a real second device, what a screen reader says, a page behind an open alert() or print dialog, a page that never stops computing, browsers outside Chromium; a window that really loses and gets the focus (document.hasFocus is faked, and the viewer kept from hearing of a lost one).
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export TMPDIR="$tmp" PYTHONDONTWRITEBYTECODE=1
unset DESIGN_KIT_PORT

rc=0
python3 - "$here" "$tmp/dk" <<'PY' || rc=$?
import base64, contextlib, http.client, http.server, io, json, os, re, signal, socket, struct, subprocess, sys, threading, time, wave, zlib
from urllib.parse import quote, unquote

here, ROOT = sys.argv[1:3]
sys.path.insert(0, os.path.join(here, "__tests__"))
import browser_lib
from browser_lib import FONT, TRY, WRITES, Server, bad, eq, visit

m = browser_lib.check.m  # serve.py

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
NOTED = "artifacts/noted.html"
def noted_page():
    page(NOTED, title="noted", body='<script>document.documentElement.dataset.theme = "sepia"</script><button id="one" onclick="window.pressed = 1">One</button> <input id="field"> <a id="far" href="/decks/old.htm?static=1#/2">far</a>')
noted_page()
page("artifacts/copies.html", body="""<button id="clip" onclick="navigator.clipboard.writeText('by clipboard').then(() => { window.said = 'copied'; }, (e) => { window.said = e.name; })">clip</button>
<button id="exec" onclick="const t = document.createElement('textarea'); t.value = 'by execCommand'; document.body.append(t); t.select(); window.said = document.execCommand('copy'); t.remove()">exec</button>
<a id="data" download="data.txt" href="data:text/plain,x">data</a> <a id="blob" download="blob.txt">blob</a><script>document.querySelector('#blob').href = URL.createObjectURL(new Blob(['y']))</script>""")

def built(script, name, spec):
    """A page one of the kit's builders makes."""
    src = os.path.join(os.path.dirname(ROOT), os.path.basename(name) + ".spec." + ("json" if spec[0] == "{" else "md"))
    with open(src, "w") as fh:
        fh.write(spec)
    subprocess.run([sys.executable, os.path.join(here, script), src, "--out", os.path.join(ROOT, name)], cwd=os.path.dirname(ROOT), check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

DECK, PICKS, OLD = "decks/slides.html", "boards/my, picks.html", "boards/old.html"
built("deck-build.py", DECK, "# Review\n\n## One\n\n- a\n\n## Two\n\n- b\n\n## Three\n\n- c\n")
for board in (PICKS, OLD):
    built("board-build.py", board, json.dumps({"title": "Checkout", "brief": "errors", "device": "phone", "boards": [{"title": t, "tradeoff": "wide", "body": "<h1>%s</h1>" % t} for t in ("One", "Two")]}))

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

def got(path):
    """The policy and the body the server answers this path with."""
    con = http.client.HTTPConnection("127.0.0.1", server.port, timeout=5)
    con.request("GET", path)
    answer = con.getresponse()
    return answer.headers["Content-Security-Policy"], answer.read()

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

OWN_FILES = {"script": 1, "module": 2, "font": ["loaded"], "image": 1, "audio": True, "json": {"three": 3}, "gone": 404}

def files(b):
    image = "[document.querySelector('img').complete, document.querySelector('img').naturalWidth]"
    def framed(name):
        return visit(b, server.url + "/" + quote(name)).frame()
    def raw(name):
        tab = visit(b, server.url + "/" + quote(name) + "?static=1")
        eq("?static=1 opens %s raw, at its own address" % name, lambda: tab.evaluate("[self.origin, location.pathname.startsWith('/_c/'), location.search, document.querySelectorAll('#bar').length]"), ["null", True, "", 0])
        return tab
    for how, at in (("framed", framed), ("raw", raw)):
        eq("a page in a folder named 'a;b, c ü' loads its script, module, font, image, audio and JSON, %s, and reads a 404 for a file that is not there" % how, lambda: at(OWN + "index.html").evaluate(LOADED), OWN_FILES)
        eq("a review page shows its shots/ image, %s" % how, lambda: at("reviews/r.html").wait(image), [True, 1])
        eq("a deck loads no server file, %s" % how, lambda: at("decks/loads.html").evaluate("(async () => [window.script || 0, document.querySelector('img').naturalWidth, await fetch('../shots/one.png').then((r) => r.status, (e) => e.name)])()"), [0, 0, "TypeError"])

def bar(b):
    tab = visit(b, server.url + "/" + BOARD)
    tab.frame()
    eq("the bar holds Gallery, the title, the check result and Notes, in that order", lambda: (tab.wait("document.querySelector('#chip').textContent"), tab.evaluate("[...document.querySelectorAll('#bar a, #bar h1, #bar #chip, #bar button')].filter((e) => e.checkVisibility()).map((e) => [e.localName, e.textContent])"))[1],
       [["a", "Gallery"], ["h1", "fixture"], ["span", "Not checked"], ["button", "Notes"]])
    eq("the Gallery link opens the gallery's own address", lambda: tab.evaluate("document.querySelector('#bar a').getAttribute('href')"), "/_gallery")
    eq("Network hidden while nothing was blocked or allowed", lambda: tab.evaluate("[%s, %s]" % (SHOWN % "#network", SHOWN % "#notes")), [False, True])
    eq("the frame is sandboxed as its policy says, seeded by name, and named for a screen reader", lambda: tab.evaluate("(() => { const f = document.querySelector('iframe'); return [f.getAttribute('sandbox'), f.getAttribute('allow'), f.name, f.title, f.allowFullscreen, /^\\/_c\\/[\\w-]{22}\\.[\\w-]+\\/boards\\/fixture\\.html$/.test(f.getAttribute('src'))]; })()"),
       ["allow-scripts allow-forms allow-modals allow-downloads", "clipboard-write", '{"dk":1,"store":{}}', "fixture", False, True])
    eq("the viewer logs no error and no refused load", lambda: logged(b, tab), [])
    for findings, changed, want, ink in ((0, 0, "Checked, 0 problems", "rgb(22, 101, 52)"), (1, 0, "Checked, 1 problem", "rgb(133, 77, 14)"), (2, 1, "Checked, 2 problems; page changed since", "rgb(85, 83, 77)")):
        put(".checks/results.json", json.dumps({BOARD: {"ts": "2026-11-24T10:00:00Z", "findings": findings, "widths": [375], "mtime_ns": os.stat(os.path.join(ROOT, BOARD)).st_mtime_ns - changed}}))
        tab = visit(b, server.url + "/" + BOARD)
        eq("the chip says what the last check found: " + want, lambda: (tab.wait("document.querySelector('#chip').textContent"), tab.evaluate("[document.querySelector('#chip').textContent, getComputedStyle(document.querySelector('#chip')).color]"))[1], [want, ink])
    title = '<img src=x onerror=alert(1)> & "two"'
    tab = visit(b, server.url + "/artifacts/markup.html")
    eq("a page title holding markup shows as text in the bar", lambda: (tab.frame(), tab.evaluate("[document.title, document.querySelector('#bar h1').textContent, document.querySelector('#bar').querySelectorAll('img').length, document.querySelector('iframe').title]"))[1], [title, title, 0, title])
    with open(os.path.join(here, "viewer.js"), encoding="utf-8") as fh:
        eq("viewer.js builds no markup from text", re.findall(r"innerHTML|outerHTML|insertAdjacentHTML|document\.write|createContextualFragment|DOMParser", fh.read()), [])
    eq("the policy carries require-trusted-types-for 'script', and the browser refuses markup from a string for it", lambda: ["require-trusted-types-for 'script'" in got("/" + BOARD)[0].split("; "), tab.evaluate("(() => { try { document.createElement('p').innerHTML = '<b>b</b>'; return 'built'; } catch (e) { return e.name; } })()")], [True, "TypeError"])
    for w in (1280, 375):
        tab = visit(b, server.url + "/artifacts/long.html", w)
        tab.frame()
        eq("at %d px the frame fills the window under the bar, the title is cut and nothing scrolls sideways" % w, lambda: tab.evaluate("(() => { const bar = document.querySelector('#bar').getBoundingClientRect(), f = document.querySelector('iframe').getBoundingClientRect(), t = document.querySelector('#bar h1'), n = document.querySelector('#notes').getBoundingClientRect(); return [bar.top, f.top === bar.bottom, f.bottom, f.left, f.width, document.documentElement.scrollWidth, getComputedStyle(t).textOverflow, t.scrollWidth > t.clientWidth || innerWidth > 1000, n.right <= innerWidth, %s]; })()" % (SHOWN % "#chip")),
           [0, True, 800, 0, w, w, "ellipsis", True, True, w == 1280])
    eq("at 375 px a long title ends in an ellipsis", lambda: tab.evaluate("(({ scrollWidth, clientWidth }, { textOverflow, overflowX, whiteSpace }) => [scrollWidth > clientWidth, textOverflow, overflowX, whiteSpace])(document.querySelector('#bar h1'), getComputedStyle(document.querySelector('#bar h1')))"), [True, "ellipsis", "hidden", "nowrap"])

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
    "{ dk: 1, t: 'blocked' }", "{ dk: 1, t: 'blocked', host: 7, kind: 'script' }", "{ dk: 1, t: 'blocked', host: '', kind: 'script' }", "{ dk: 1, t: 'blocked', host: 'x'.repeat(254), kind: 'script' }", "{ dk: 1, t: 'blocked', host: 'a.example', kind: 'connect' }", "{ dk: 1, t: 'blocked', host: 'a.example', kind: ['script'] }",
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
    eq("a wrong shape, an unknown type and an anchor with notes off change nothing", lambda: (time.sleep(0.6), tab.evaluate(WHOLE), f.evaluate("printed"))[1:], (before, 0))
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
    for _ in range(2):
        press(tab, "#notes")
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
        tab.wait("Object.entries(localStorage).some(([k, v]) => k.includes(':%s:') && v === 'here')" % one)
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
    encoded = json.dumps("design-kit:/" + quote(PICKS))
    tab = visit(b, at(BOARD))
    tab.evaluate("localStorage.setItem(%s, %s); 1" % (encoded, json.dumps(json.dumps(state))))
    tab = visit(b, at(PICKS))
    eq("a 0.19.3 key percent-encoded whole is read too, and goes", lambda: [tab.frame().evaluate(board), tab.evaluate("localStorage.getItem(%s)" % encoded)], [state, None])
    whose = "localStorage.getItem('design-kit:' + location.pathname)"
    for odd, plain in (("boards/a.html#x.html", "boards/a.html"), ("boards/a.html?x.html", "boards/a.html"), ("boards/q\\a.html", "boards/q/a.html"), ("boards/%2e%2e/a.html", "a.html"), ("boards/a\tb.html", "boards/ab.html")):
        for one in (odd, plain):
            page(one)
        tab.evaluate("localStorage.setItem('design-kit:/%s', 'of %s'); 1" % (plain, plain))
        tab = visit(b, at(odd))
        first = tab.frame().evaluate(whose)
        tab = visit(b, at(plain))
        eq("the state of %s is not taken by %s, which a URL reads as it" % (plain, json.dumps(odd)), lambda: [first, tab.frame().evaluate(whose)], [None, "of " + plain])
        for one in (odd, plain):
            os.unlink(os.path.join(ROOT, one))

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
    writes(tab, tab.frame(), "half a note")
    def newer():
        server.stop()
        server.start(first="m.SERVER_VERSION += 1")
    eq("a viewer older than the server that came back keeps a draft: the frame alone is new", lambda: (reframed(tab, newer).evaluate(H1), tab.evaluate("[!!window.was, document.querySelector('textarea').value]")), ("fixture", [True, "half a note"]))
    press(tab, CANCEL)
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

def recorded(name="decisions.jsonl"):
    try:
        with open(os.path.join(ROOT, name), encoding="utf-8") as fh:
            return [json.loads(line) for line in fh]
    except FileNotFoundError:
        return []

def chosen():
    return [[r["board"], r["picked"], r["knobs"], r["text"]] for r in recorded()]

def forget(name="decisions.jsonl"):
    if recorded(name):
        os.unlink(os.path.join(ROOT, name))

PICK = "#strips [data-kind=pick]"
SEND, DISCARD = PICK + " button.primary", PICK + " button:last-child"
THERE, GONE = "!!document.querySelector('%s')" % PICK, "!document.querySelector('%s')" % PICK
PARTS = "[...document.querySelectorAll('%s > *')].map((e) => [e.localName, e.textContent])" % PICK
ROWS = "[...document.querySelectorAll('%s li')].map((e) => e.textContent)" % PICK
HEAD = "(document.querySelector('%s p') || { textContent: '' }).textContent" % PICK
KEPT = "Object.keys(sessionStorage).filter((k) => k.startsWith('dk-pick:')).map((k) => k.split(':')[2])"
ACTS, PACE = 0.9, 1.7  # s: past the 600 ms in which Send pick and Discard do nothing, and past the 1.5 s in which a page cannot change the strips again

def says(f, picked=None, knobs=None, text=None, **more):
    """The page reports a pick."""
    f.evaluate("parent." + POST % json.dumps(dict({"dk": 1, "t": "pick", "picked": picked, "knobs": knobs or {}, "text": text or {}}, **more)) + "1")

def offered(tab, f, *args, **more):
    """The page reports a pick; its strip is there and can be acted on."""
    says(f, *args, **more)
    if not tab.wait(THERE, 4):
        raise TimeoutError("no pick strip")
    time.sleep(ACTS)

def press(tab, selector, how="click"):
    if how == "click":
        return tab.click(*tab.at(selector))
    tab.evaluate("document.querySelector(%s).focus(); 1" % json.dumps(selector))
    tab.key(how)

def fitted(tab, f):
    """Once the frame is drawn where a strip or the drawer left it: until then Chrome takes a click for where it was."""
    f.wait("innerHeight + ' ' + innerWidth === %s" % json.dumps(tab.evaluate("(({ clientHeight, clientWidth }) => clientHeight + ' ' + clientWidth)(document.querySelector('iframe'))")))
    for one in (f, tab):
        one.evaluate(browser_lib.check.SETTLE_JS)

def toggle(tab, f, times=1):
    """Clicks on the first artboard's Pick this, near enough to each other for the board to report them once."""
    fitted(tab, f)
    for _ in range(times):
        tab.click(*f.at('[data-act="pick"]'))

def picks(b):
    forget()
    saved = {"knobs": {"all": {"space": 12}}, "text": {}, "picked": None}
    tab = visit(b, server.url + "/" + BOARD)
    tab.evaluate("localStorage.setItem('design-kit:/%s', %s); 1" % (OLD, json.dumps(json.dumps(saved))))
    b.chrome.call("Page.navigate", {"url": server.url + "/" + OLD}, tab.sid)
    tab.wait("document.body.dataset.page === '%s'" % OLD)
    f = tab.frame()
    tab.wait(FOCUS + " === 'iframe'")
    time.sleep(0.8)
    eq("a board of 0.19.3 keeps its saved knobs, and saved state alone shows no strip", lambda: [f.evaluate("window.designKit.state()"), tab.evaluate(STRIPS)], [saved, []])
    f.evaluate("window.toasts = []; new MutationObserver(() => toasts.push(document.querySelector('#dk-toast').textContent)).observe(document.querySelector('#dk-toast'), { childList: true }); 1")
    toggle(tab, f)
    want = [["p", "Artboard 1 picked"], ["ul", "All artboards: spacing base 12px"], ["button", "Send pick"], ["button", "Discard"]]
    eq("Pick shows the strip and writes no row", lambda: [tab.wait(HEAD, 3), tab.evaluate(PARTS), recorded()][1:], [want, []])
    eq("old board shows no Recorded before Send", lambda: [time.sleep(0.4), tab.evaluate(HEAD), f.evaluate("toasts")][1:], ["Artboard 1 picked", ["Picked One"]])
    eq("the strip takes no focus", lambda: tab.evaluate(FOCUS), "iframe")
    with open(os.path.join(ROOT, OLD), encoding="utf-8") as fh:
        board = fh.read()
    for what, happen in (("a frame reload", lambda: reframed(tab, lambda: put(OLD, board))), ("a tab reload", lambda: again(b, tab).frame()), ("a server restart", lambda: reframed(tab, lambda: (server.stop(), server.start())))):
        eq("an unsent strip survives " + what, lambda: [happen(), time.sleep(0.2), tab.evaluate(PARTS), recorded()][2:], [want, []])
    b.chrome.call("Page.navigate", {"url": server.url + "/decks/fixture.html"}, tab.sid)
    tab.wait("document.body.dataset.page === 'decks/fixture.html'")
    tab.frame()
    away = tab.evaluate(STRIPS)
    tab.evaluate("history.back(); 1")
    eq("a link away does not show it, and one back does again", lambda: [away, tab.wait("document.body.dataset.page === '%s' && %s" % (OLD, THERE)), tab.evaluate(PARTS)], [[], True, want])
    f = tab.frame()
    tab.wait(FOCUS + " === 'iframe'")
    time.sleep(ACTS)
    tab.click(*f.at(".dk-help"))
    press(tab, SEND)
    row = ["old.html", 1, {"all": {"space": 12}}, {}]
    eq("Send pick writes exactly one row, at the first click that comes from the page", lambda: [tab.wait(GONE), time.sleep(0.2), chosen(), tab.evaluate(KEPT)][2:], [[row], []])
    eq("which a session reads as the user's", lambda: [m.picks.pick_line(r, m._clean, m._hidden)["confirmed"] for r in recorded()], [True])
    f = again(b, tab).frame()
    tab.wait(FOCUS + " === 'iframe'")
    eq("a recorded pick does not come back", lambda: [time.sleep(0.3), tab.evaluate(STRIPS)][1], [])
    toggle(tab, f, 2)
    eq("picking the same artboard again after a Send shows the strip again", lambda: [tab.wait(HEAD, 3), tab.evaluate(PARTS)][1], want)
    time.sleep(ACTS)
    press(tab, DISCARD)
    eq("Discard takes it away and writes nothing", lambda: [tab.wait(GONE), tab.evaluate(KEPT), chosen()], [True, [], [row]])
    toggle(tab, f, 2)
    eq("and after a Discard", lambda: [tab.wait(HEAD, 3), tab.evaluate(PARTS)][1], want)
    toggle(tab, f)
    eq("a null pick reads Changes, no artboard picked", lambda: [tab.wait(HEAD + ".startsWith('Changes')", 4), tab.evaluate(HEAD)][1], "Changes, no artboard picked Updated")
    f.evaluate("document.querySelector('[data-act=\"reset-all\"]').click(); 1")
    eq("a cleared one Pick cleared", lambda: [tab.wait(HEAD + ".startsWith('Pick')", 4), tab.evaluate(PARTS)][1], [["p", "Pick cleared Updated"], ["button", "Send pick"], ["button", "Discard"]])

    tab = visit(b, server.url + "/decks/fixture.html")
    says(tab.frame(), 1, {"all": {"space": 12}})
    eq("a pick from a page outside boards/ shows no strip", lambda: [time.sleep(0.4), tab.evaluate("[%s, %s]" % (STRIPS, KEPT))][1], [[], []])
    forget()
    tab = visit(b, server.url + "/" + BOARD)
    f = tab.frame()
    for wrong in ("picked: 1", "picked: '1', knobs: {}, text: {}", "picked: 1, knobs: [], text: {}", "picked: 1, knobs: {}, text: null", "picked: 1.5, knobs: {}, text: {}"):
        f.evaluate("parent." + POST % ("{ dk: 1, t: 'pick', %s }" % wrong) + "1")
    eq("nor does a report of another shape", lambda: [time.sleep(0.3), tab.evaluate(STRIPS)][1], [])
    offered(tab, f, 2, board="other.html", cid="0" * 16, prompt="do this")
    press(tab, SEND)
    eq("a message naming another board is filed under the viewer's page", lambda: [tab.wait(GONE), chosen(), [r["cid"] == "0" * 16 or "do this" in r["prompt"] for r in recorded()]][1:], [[["fixture.html", 2, {}, {}]], [False]])
    other = "boards/deep/other.html"
    page(other)
    tab = visit(b, server.url + "/" + BOARD)
    offered(tab, tab.frame(), 3)
    b.chrome.call("Page.navigate", {"url": server.url + "/" + other}, tab.sid)
    tab.wait("document.body.dataset.page === '%s'" % other)
    offered(tab, tab.frame(), 4)
    press(tab, SEND)
    eq("another board has a strip of its own, and leaves this one's", lambda: [tab.wait(GONE), chosen()[1:], tab.evaluate(KEPT)][1:], [[["other.html", 4, {}, {}]], [BOARD]])
    os.unlink(os.path.join(ROOT, other))
    second, both = os.path.join(os.path.dirname(ROOT), "second"), "boards/both.html"
    page(both)
    os.makedirs(os.path.join(second, "boards"), exist_ok=True)
    with open(os.path.join(second, both), "w") as fh:
        fh.write("<h1>second</h1>")
    tab = visit(b, server.url + "/" + both)
    offered(tab, tab.frame(), 5)
    try:
        eq("another docroot on the same port is not offered it", lambda: [reframed(tab, lambda: (server.stop(), server.start(root=second))).evaluate(H1), tab.evaluate(STRIPS)], ["second", []])
    finally:
        eq("and it is back with its own", lambda: [reframed(tab, lambda: (server.stop(), server.start())) and tab.evaluate(HEAD)], ["Artboard 5 picked"])

def values(b):
    forget()
    rlo, markup = chr(0x202e), "<img src=x onerror=alert(1)>"
    raw = {"picked": 2,
           "knobs": {"all": {"space": 99, "radius": -3, "hue": 361.5, "type": 0.1, "density": 1.2345, "scheme": "dark", "zoom": 2}, "3": {}, "2": {"scheme": "blue", "space": "12", "radius": True}, "1": {"type": 1.05, "hue": 7}, "100": {"space": 1}, "x": {"space": 1}},
           "text": {"2": {"h1:0": {"was": "One", "now": ""}, "H1": {"was": "a", "now": "b"}, "p:1": {"was": "x"}}, "1": {"h1:0/a:2": {"was": markup, "now": "y" * 600}, "p:0": {"was": chr(0x1f600) * 501, "now": "a" + chr(0xd800) + "b" + rlo + "c"}, "constructor": {"was": "q", "now": "r"}}, "7": {}, "all": {"p:9": {"was": "a", "now": "b"}}}}
    tab = visit(b, server.url + "/" + BOARD)
    tab.evaluate("window.posted = []; { const real = fetch; window.fetch = (at, init) => { if (init && init.body) posted.push(JSON.parse(init.body)); return real(at, init); }; } 1")
    f = tab.frame()
    f.evaluate("parent." + POST % "{ dk: 1, t: 'pick', picked: 100, knobs: { all: { space: NaN, radius: Infinity, hue: -0 } }, text: {} }" + "1")
    eq("an artboard past 99 is none, a number that is none is dropped, one past a bound is moved to it", lambda: [tab.wait(HEAD), tab.evaluate("[%s, %s]" % (HEAD, ROWS))][1], ["Changes, no artboard picked", ["All artboards: corner radius 64px", "All artboards: accent hue 0°"]])
    time.sleep(PACE)
    says(f, **raw)
    tab.wait(HEAD + ".includes('Updated')", 3)
    stored = m.picks.clean_pick(dict(raw, board="fixture.html"), m._clean, m._hidden)[0]
    shown = tab.evaluate(ROWS)
    time.sleep(ACTS)
    press(tab, SEND)
    tab.wait(GONE)
    eq("the viewer clamps a pick as picks.py does", chosen, [[stored[k] for k in ("board", "picked", "knobs", "text")]])
    eq("and posts what it clamped", lambda: [{k: v for k, v in one.items() if k != "cid"} for one in tab.evaluate("posted")], [stored])
    knobs = [m.picks._words({name: v}) for own in stored["knobs"].values() for name, v in own.items()]
    texts = [t.replace(rlo, "U+202E") for edits in stored["text"].values() for path, e in edits.items() for t in (path, e["was"], e["now"])]
    eq("every value sent is in the strip's text, a character that draws nothing as its number", lambda: [t for t in knobs + texts if t not in "\n".join(shown)], [])
    eq("each knob is under its scope, by picks.py's words, each edit as was → now", lambda: [one for one in shown if len(one) < 60],
       ["All artboards: " + w for w in ("spacing base 64px", "corner radius 0px", "accent hue 360°", "type scale ×0.5", "density ×1.23", "dark scheme")]
       + ["Artboard 1: accent hue 7°", "Artboard 1: type scale ×1.05", "Artboard 1 text, constructor: “q” → “r”", "Artboard 2 text, h1:0: “One” → “”"])
    past = {"1": {name: low - 1 for name, (low, _, _) in m.picks.KNOBS.items() if name != "scheme"}, "2": {name: high + 1 for name, (_, high, _) in m.picks.KNOBS.items() if name != "scheme"}, "3": {"scheme": "light"}}
    bounds = m.picks.clean_pick({"board": "fixture.html", "picked": 1, "knobs": past, "text": {}}, m._clean, m._hidden)[0]["knobs"]
    says(f, 1, past)
    eq("each knob past a bound reads as picks.py words the bound", lambda: [tab.wait(HEAD), tab.evaluate(ROWS)][1], ["Artboard %s: %s" % (scope, m.picks._words({name: v})) for scope, own in bounds.items() for name, v in own.items()])
    time.sleep(ACTS)
    press(tab, DISCARD)
    tab.wait(GONE)
    hides = sorted(m.BLANK) + [0x1, 0x200b, 0xe000, 0x378, 0x2028, 0x2029]  # one of Cc, Cf, Co, Cn, Zl and Zp
    says(f, 1, {}, {"1": {"p:0": {"was": "".join(map(chr, hides)), "now": "x"}}})
    eq("every character serve.py counts as blank, and one of each hidden category, is drawn as its number", lambda: [tab.wait(HEAD), tab.evaluate(ROWS)][1], ["Artboard 1 text, p:0: “%s” → “x”" % "".join("U+%X" % c for c in hides)])
    time.sleep(ACTS)
    press(tab, DISCARD)
    tab.wait(GONE)
    offered(tab, f, 1, {}, {str(n): {"p:%d" % i: {"was": "w", "now": "n"} for i in range(40)} for n in (3, 2, 1)})
    eq("of 120 edits the first 100 are sent, lowest artboard first", lambda: [len(tab.evaluate(ROWS))] + [sum("Artboard %d" % n in one for one in tab.evaluate(ROWS)) for n in (1, 2, 3)], [100, 40, 40, 20])
    press(tab, DISCARD)
    tab.wait(GONE)
    letters = chr(0x5d0) + chr(0x5d1)
    says(f, 1, {}, {"1": {"p:0": {"was": letters, "now": markup}}})
    eq("a text edit holding markup shows as text, and neither text reorders the other", lambda: [tab.wait(HEAD), tab.evaluate("[%s, [...document.querySelectorAll('%s li *')].map((e) => [e.localName, getComputedStyle(e).unicodeBidi])]" % (ROWS, PICK))][1], [["Artboard 1 text, p:0: “%s” → “%s”" % (letters, markup)], [["bdi", "isolate"]] * 2])

BOXES = """(() => { const at = (s) => document.querySelector(s).getBoundingClientRect(), bg = (s) => getComputedStyle(document.querySelector(s)).backgroundColor, send = at('SEND'), discard = at('DISCARD');
  return { primary: [bg('SEND'), bg('DISCARD') !== bg('SEND')], under: send.top >= at('PICK ul').bottom, stacked: send.bottom <= discard.top, tall: send.height >= 24, frame: [at('iframe').top - at('#strips').bottom, at('iframe').bottom], wide: [document.documentElement.scrollWidth, document.querySelector('#strips').scrollWidth <= innerWidth] }; })()""".replace("SEND", SEND).replace("DISCARD", DISCARD).replace("PICK", PICK)

LOOK = """(() => { const of = (s) => getComputedStyle(document.querySelector(s)), bar = of('#bar'), send = of('SEND'), discard = of('DISCARD');
  return [matchMedia('(prefers-color-scheme: dark)').matches, [of('html'), of('iframe')].map((s) => s.colorScheme), bar.backgroundColor, bar.borderBottomColor, of('body').color, send.color, discard.backgroundColor, discard.borderTopColor, send.borderRadius]; })()""".replace("SEND", SEND).replace("DISCARD", DISCARD)

def looks(b):
    edits = {"1": {"p:%d" % i: {"was": "was %d" % i, "now": "now %d" % i} for i in range(60)}}
    for w in (1280, 375):
        tab = visit(b, server.url + "/" + BOARD, w)
        offered(tab, tab.frame(), 2, {}, edits)
        eq("40vh list scrolls inside the strip, at %d px" % w, lambda: tab.evaluate("(() => { const u = document.querySelector('%s ul'), r = u.getBoundingClientRect(), s = u.parentElement.getBoundingClientRect(); return [u.children.length, r.height, u.scrollHeight > 2 * u.clientHeight, r.top >= s.top && r.bottom <= s.bottom]; })()" % PICK), [60, 320, True, True])
        tab.evaluate("document.querySelector('%s ul').focus(); 1" % PICK)
        tab.key("End")
        eq("with the keyboard too, at %d px" % w, lambda: tab.wait("document.querySelector('%s ul').scrollTop > 100" % PICK), True)
        eq("Send pick is the primary button, both under the list, stacked when narrow, the frame under them, nothing sideways, at %d px" % w, lambda: tab.evaluate(BOXES),
           {"primary": ["rgb(26, 86, 219)", True], "under": True, "stacked": w == 375, "tall": True, "frame": [0, 800], "wide": [w, True]})
    tab = visit(b, server.url + "/" + BOARD, 1280, 160)
    f = tab.frame()
    offered(tab, f, 2, {}, edits)
    f.evaluate("document.body.append(Object.assign(document.createElement('p'), { id: 'low', style: 'margin-top: 3000px' })); document.querySelector('#low').scrollIntoView(); 1")
    eq("a page cannot scroll the strips away, however low the window", lambda: [time.sleep(0.3), tab.evaluate("[scrollY, document.documentElement.scrollHeight]"), f.evaluate("scrollY > 1000")][1:], [[0, 160], True])
    b.chrome.call("Emulation.setEmulatedMedia", {"features": [{"name": "prefers-color-scheme", "value": "dark"}]}, tab.sid)
    eq("the palette picked, light for a reader whose scheme is dark too, and the frame keeps that scheme for its page", lambda: tab.evaluate(LOOK),
       [True, ["light", "light dark"], "rgb(241, 240, 235)", "rgb(201, 200, 194)", "rgb(27, 27, 26)", "rgb(255, 255, 255)", "rgb(255, 255, 255)", "rgb(140, 138, 130)", "6px"])

@contextlib.contextmanager
def catching(b):
    """caught(tab, do, stage, method, meanwhile), and the requests it still holds: the POST that do() sends to a write route is held before it leaves (Request) or before its answer arrives (Response), then let go by a Fetch command."""
    paused, keep = [], b.chrome.keep
    b.chrome.keep = lambda e: paused.append(e["params"]["requestId"]) if e["method"] == "Fetch.requestPaused" else keep(e)
    def caught(tab, do, stage, method, meanwhile=lambda: None, **params):
        b.chrome.call("Fetch.enable", {"patterns": [{"urlPattern": at, "requestStage": stage} for at in ("*/_decision", "*/_note", "*/_allow")]}, tab.sid)
        do()
        until = time.monotonic() + 3
        while not paused and time.monotonic() < until:
            tab.evaluate("new Promise((r) => setTimeout(r, 30))")
        meanwhile()
        b.chrome.call("Fetch." + method, dict(params, requestId=paused.pop()), tab.sid)
        b.chrome.call("Fetch.disable", {}, tab.sid)
    try:
        yield caught, paused
    finally:
        b.chrome.keep = keep

def once(b):
    forget()
    tab = visit(b, server.url + "/" + BOARD)
    f = tab.frame()
    numbers = lambda: [r["picked"] for r in recorded()]
    again_there = "(document.querySelector('%s') || {}).textContent === 'Send again'" % SEND
    def lost(how="click"):
        caught("Response", how, "failRequest", errorReason="ConnectionReset")
        tab.wait(again_there)
    with catching(b) as (held, paused):
        caught = lambda stage, how, *more, **params: held(tab, lambda: press(tab, SEND, how), stage, *more, **params)
        offered(tab, f, 1)
        x, y = tab.at(SEND)
        for n in (1, 2):
            for kind in ("mousePressed", "mouseReleased"):
                b.chrome.call("Input.dispatchMouseEvent", {"type": kind, "x": x, "y": y, "button": "left", "clickCount": n}, tab.sid)
        eq("double click on Send pick writes one row", lambda: [tab.wait(GONE), time.sleep(0.3), chosen()][2], [["fixture.html", 1, {}, {}]])
        def meanwhile():
            says(f, 3)
            time.sleep(2)
            for control in (SEND, DISCARD):
                press(tab, control)
            eq("while a POST is pending its buttons are disabled, its content stays and a press does nothing", lambda: tab.evaluate("[[...document.querySelectorAll('%s button')].map((b) => b.ariaDisabled), %s]" % (PICK, HEAD)), [["true", "true"], "Artboard 2 picked"])
        offered(tab, f, 2)
        caught("Request", "Enter", "continueRequest", meanwhile)
        eq("then what was on screen is the row, and the newer report is the strip", lambda: [tab.wait(HEAD + " === 'Artboard 3 picked Updated'"), numbers(), len(paused)], [True, [1, 2], 0])
        time.sleep(ACTS)
        press(tab, SEND)
        eq("one row for each Send", lambda: [tab.wait(GONE), numbers()][1], [1, 2, 3])
        offered(tab, f, 4, {"all": {"hue": 10}})
        lost("Enter")
        eq("a lost answer shows Send again, which has the focus; the row is there", lambda: [tab.evaluate("[%s, document.activeElement.textContent]" % PARTS), numbers()],
           [[[["p", "Artboard 4 picked"], ["ul", "All artboards: accent hue 10°"], ["p", "The preview server did not answer"], ["button", "Send again"], ["button", "Discard"]], "Send again"], [1, 2, 3, 4]])
        time.sleep(ACTS)
        press(tab, SEND, " ")
        eq("a retry after a lost answer writes no second row", lambda: [tab.wait(GONE), numbers()], [True, [1, 2, 3, 4]])
        eq("a strip that leaves with the focus gives it to the page", lambda: tab.evaluate(FOCUS), "iframe")
        offered(tab, f, 5)
        lost()
        f = again(b, tab).frame()
        time.sleep(ACTS)
        press(tab, SEND)
        eq("nor one after a tab reload", lambda: [tab.wait(GONE), numbers()], [True, [1, 2, 3, 4, 5]])
        offered(tab, f, 6)
        lost()
        time.sleep(PACE)
        says(f, 7)
        eq("a change made after a lost answer takes its place", lambda: [tab.wait(HEAD + ".startsWith('Artboard 7')"), tab.evaluate(PARTS)][1], [["p", "Artboard 7 picked Updated"], ["button", "Send pick"], ["button", "Discard"]])
        time.sleep(ACTS)
        press(tab, SEND)
        eq("and is sent as a second row", lambda: [tab.wait(GONE), numbers(), len({r["cid"] for r in recorded()})][1:], [[1, 2, 3, 4, 5, 6, 7], 7])
        offered(tab, f, 7)
        press(tab, SEND)
        eq("and the same pick sent anew as one more", lambda: [tab.wait(GONE), numbers()][1], [1, 2, 3, 4, 5, 6, 7, 7])
        forget()
        offered(tab, f, 8)
        lost()
        time.sleep(PACE)
        says(f, 8)
        tab.wait("(document.querySelector('%s') || {}).textContent === 'Send pick'" % SEND, 4)
        time.sleep(ACTS)
        press(tab, SEND)
        eq("a report of the same pick after a lost answer makes no second row of it", lambda: [tab.wait(GONE), numbers()], [True, [8]])
        offered(tab, f, 1)
        says(f, 2)
        press(tab, SEND)
        eq("Send posts the pick on screen, not a newer report that waits to be drawn", lambda: [tab.wait(HEAD + ".startsWith('Artboard 2')", 4), numbers()], [True, [8, 1]])
        time.sleep(ACTS)
        says(f, 3)
        f = again(b, tab).frame()
        eq("a report that waited to be drawn is there after a tab reload", lambda: [tab.wait(HEAD, 4), tab.evaluate(HEAD)][1], "Artboard 3 picked")
        time.sleep(ACTS)
        press(tab, DISCARD)
        tab.wait(GONE)
        forget()
        offered(tab, f, 1)
        server.stop()
        tab.wait(STRIPS + ".length === 2", 8)
        time.sleep(ACTS)
        press(tab, SEND)
        eq("with no server, the reason and Send again", lambda: [tab.wait(again_there), tab.evaluate(PARTS)][1][1:3], [["p", "The preview server did not answer"], ["button", "Send again"]])
        server.start()
        tab.wait(STRIPS + ".length === 1", 12)
        f = tab.frame()
        time.sleep(ACTS)
        press(tab, SEND)
        eq("which sends it once there is one", lambda: [tab.wait(GONE), numbers()][1], [1])
        tab.evaluate("{ const real = AbortSignal.timeout; AbortSignal.timeout = (ms) => real.call(AbortSignal, ms / 20); } 1")
        offered(tab, f, 2)
        os.kill(server.proc.pid, signal.SIGSTOP)
        press(tab, SEND)
        eq("a server that says nothing for 10 s, 20 times as short here, is one that did not answer", lambda: [tab.wait(again_there), tab.evaluate(PARTS)[1]], [True, ["p", "The preview server did not answer"]])
        os.kill(server.proc.pid, signal.SIGCONT)
        time.sleep(ACTS)
        press(tab, SEND)
        eq("and what it had taken is not sent twice", lambda: [tab.wait(GONE), time.sleep(0.3), numbers()][2], [1, 2])
        forget()
        for status, body, why in ((400, b'{"recorded": false, "error": "the reason"}', "the reason"), (403, b"<h1>no</h1>", "the server answered 403"), (413, b'{"error": "the reason"}', "the reason"), (507, b'{"error": "the reason"}', "the reason"),
                                  (500, b'{"error": "the reason"}', "the reason"), (200, b"null", "the server answered 200")):
            offered(tab, f, 2)
            caught("Request", "click", "fulfillRequest", responseCode=status, body=base64.b64encode(body).decode())
            retry = [["button", "Send again"]] if status in (500, 200) else []
            eq("%d shows the reason and %s" % (status, "Send again" if retry else "no Send again"), lambda: [tab.wait("document.querySelectorAll('%s p').length === 2" % PICK), tab.evaluate(PARTS)][1], [["p", "Artboard 2 picked"], ["p", "Not recorded: " + why]] + retry + [["button", "Discard"]])
            if status == 507:
                time.sleep(PACE)
                says(f, 2)
                eq("the same pick reported again after a refusal can be sent again", lambda: [tab.wait("!!document.querySelector('%s')" % SEND), tab.evaluate(PARTS)][1], [["p", "Artboard 2 picked"], ["button", "Send pick"], ["button", "Discard"]])
            time.sleep(ACTS)
            press(tab, DISCARD)
            tab.wait(GONE)
        offered(tab, f, 3, {}, {"1": {"p:%d" % i: {"was": "x" * 500, "now": "y" * 500} for i in range(80)}})
        press(tab, SEND)
        eq("the server's own refusal of a pick past 64 KiB is shown", lambda: [tab.wait("!!document.querySelector('%s .why')" % PICK), tab.evaluate("[document.querySelector('%s .why').textContent, !!document.querySelector('%s')]" % (PICK, SEND)), numbers()][1:], [["Not recorded: body must be 1..65536 bytes", False], []])

# when the strips last changed, and how long after it each press of one of their buttons was made
TIMES = "window.drawn = 0; window.pressed = []; new MutationObserver(() => { drawn = performance.now(); }).observe(document.querySelector('#strips'), { childList: true, subtree: true, attributes: true }); document.querySelector('#strips').addEventListener('click', (e) => { if (e.target.localName === 'button') pressed.push(e.timeStamp - drawn); }, true); 1"
EARLY_SEND = {"click": "click 300 ms after a strip appears writes none", "Enter": "Enter inside the window sends nothing", " ": "Space inside the window sends nothing"}

def resized(b, tab):
    b.chrome.call("Emulation.setDeviceMetricsOverride", {"width": 1200, "height": 800, "deviceScaleFactor": 1, "mobile": False}, tab.sid)

def unseen(b, tab):
    tab.evaluate("document.hasFocus = () => true; 1")  # so the tab's own change alone counts
    other = b.page("about:blank")
    b.chrome.call("Page.bringToFront", {}, tab.sid)
    b.chrome.call("Page.close", {}, other.sid)
    tab.wait("!document.hidden")
    tab.evaluate("delete document.hasFocus; 1")

def elsewhere(tab):
    tab.evaluate("document.hasFocus = () => false; 1")
    time.sleep(0.8)
    tab.evaluate("delete document.hasFocus; 1")

def above(tab, f, on):
    """The storage strip there, above what can be sent, or gone again."""
    f.evaluate("parent." + POST % ("{ dk: 1, t: 'store', items: [['big', %s]] }" % ("'x'.repeat(300 * 1024)" if on else "null")) + "1")
    tab.wait("!!document.querySelector('#strips [data-kind=storage]') === %s" % json.dumps(on), 4)

def consent(b):
    forget()
    tab = visit(b, server.url + "/" + BOARD)
    tab.evaluate(TIMES)
    f = tab.frame()
    for how, said in EARLY_SEND.items():
        for control, name in ((DISCARD, "Discard"), (SEND, "Send pick")):
            says(f, 1)
            tab.wait(THERE, 4)
            time.sleep(0.2)
            tab.evaluate("pressed.length = 0")
            press(tab, control, how)
            time.sleep(0.15)
            eq(said if control == SEND else "nor does Discard act on it: " + said.split(" ")[0], lambda: [tab.evaluate("[pressed.length, pressed[0] < 600, %s]" % THERE), recorded()], [[1, True, True], []])
            time.sleep(0.6)
            press(tab, control, how)
            eq("%s acts after it: %s" % (name, said.split(" ")[0]), lambda: [tab.wait(GONE), time.sleep(0.1), len(recorded())][2], int(control == SEND))
            forget()

    for _ in range(5):  # until a press falls where it should
        says(f, 1)
        tab.wait(THERE, 4)
        tab.evaluate("document.querySelector('%s').focus(); pressed.length = 0; new Promise((r) => setTimeout(r, drawn + 490 - performance.now()))" % SEND)
        tab.key("Enter")
        time.sleep(0.1)
        near = [tab.evaluate("pressed[0] > 450 && pressed[0] < 590"), tab.evaluate(THERE), recorded()]
        time.sleep(0.8)
        if tab.evaluate(THERE):
            press(tab, DISCARD)
            tab.wait(GONE)
        if near[0]:
            break
    eq("nor does a press about 500 ms after it", near, [True, True, []])
    forget()

    said = lambda n, word: (f, 1, {"all": {"space": n}}, {"1": {"h1:0": {"was": "One", "now": word}}})
    says(*said(8, "Uno"))
    tab.wait(THERE)
    time.sleep(PACE)
    tab.evaluate("document.querySelector('%s').focus(); pressed.length = 0; 1" % DISCARD)
    says(*said(9, "Eins"))
    eq("a same-count swap shows Updated, and the focus stays on its button", lambda: [tab.wait(HEAD + ".includes('Updated')"), tab.evaluate("[%s, %s, document.activeElement.textContent]" % (HEAD, ROWS))][1], ["Artboard 1 picked Updated", ["All artboards: spacing base 9px", "Artboard 1 text, h1:0: “One” → “Eins”"], "Discard"])
    press(tab, SEND)
    eq("it is not sent before it was drawn for 600 ms", lambda: [time.sleep(0.2), tab.evaluate("pressed[0] < 600"), recorded()][1:], [True, []])
    time.sleep(0.7)
    press(tab, SEND)
    eq("and is then", lambda: [tab.wait(GONE), [[r["knobs"]["all"]["space"], r["text"]["1"]["h1:0"]["now"]] for r in recorded()]][1], [[9, "Eins"]])

    forget()
    offered(tab, f, 1)
    busy = "const from = performance.now(); while (performance.now() - from < 1000);"
    for n, start, after, name in ((2, busy, 0.75, "a press made before a newer pick was painted does not send that one"), (3, "setTimeout(() => { %s }, 150)" % busy, 0.35, "nor one made 350 ms after, which the viewer gets to later")):
        time.sleep(PACE - ACTS)
        tab.evaluate("document.querySelector('%s').focus(); addEventListener('message', () => { %s }, { once: true }); 1" % (SEND, start))
        says(f, n)
        time.sleep(after)
        tab.key("Enter")
        eq(name, lambda: [tab.wait(HEAD + ".startsWith('Artboard %d')" % n), time.sleep(0.3), recorded()][2], [])
        time.sleep(ACTS)

    def fullscreen():
        b.chrome.call("Runtime.evaluate", {"expression": "document.documentElement.requestFullscreen()", "awaitPromise": True, "userGesture": True}, tab.sid)
        time.sleep(0.8)
        tab.evaluate("document.exitFullscreen()")
    for what, happen in (("another strip appeared above it", lambda: above(tab, f, True)), ("that strip was removed", lambda: above(tab, f, False)), ("a resize", lambda: resized(b, tab)), ("the tab became visible", lambda: unseen(b, tab)), ("the window gained focus", lambda: elsewhere(tab)),
                         ("fullscreen ended", fullscreen), ("a drawer opened", lambda: tab.evaluate("document.querySelector('#drawer').hidden = false; 1")), ("a row changed in it", lambda: tab.evaluate("document.querySelector('#drawer').textContent = 'a row'; 1")), ("it closed", lambda: tab.evaluate("document.querySelector('#drawer').hidden = true; 1"))):
        time.sleep(PACE if "strip" in what else ACTS)
        tab.evaluate("document.querySelector('%s').focus(); pressed.length = 0; 1" % SEND)
        happen()
        tab.key("Enter")
        eq("Send pick does nothing right after " + what, lambda: [time.sleep(0.1), tab.evaluate("[pressed.length, %s]" % THERE), recorded()][1:], [[1, True], []])
    ask = "document.documentElement.requestFullscreen().then(() => 'full', (e) => e.name)"
    eq("requestFullscreen in the frame is refused", lambda: [f.evaluate("document.fullscreenEnabled"), b.chrome.call("Runtime.evaluate", {"expression": ask, "awaitPromise": True, "returnByValue": True, "userGesture": True}, f.sid)["result"]["value"]], [False, "TypeError"])
    time.sleep(ACTS)
    press(tab, SEND)
    eq("and it acts once nothing changed for a while", lambda: [tab.wait(GONE), [r["picked"] for r in recorded()]][1], [3])

    forget()
    tab.evaluate("window.draws = []; window.left = 0; new MutationObserver(() => { if (%s) draws.push(performance.now()); else left++; }).observe(document.querySelector('#strips'), { childList: true }); 1" % THERE)
    f.evaluate("let n = 0; window.flood = setInterval(() => { n++; parent.postMessage({ dk: 1, t: 'pick', picked: 1 + n % 2, knobs: {}, text: {} }, '*'); parent.postMessage({ dk: 1, t: 'store', items: [['big', n % 4 < 2 ? 'x'.repeat(300 * 1024) : null]] }, '*'); }, 40); 1")
    tab.wait(THERE)
    time.sleep(3.6)
    eq("a page that floods reports and storage changes the strips at most once in 1.5 s", lambda: tab.evaluate("[draws.length > 2, Math.min(...draws.slice(1).map((t, i) => t - draws[i])) > 1400]"), [True, True])
    until = time.monotonic() + 6
    while not tab.evaluate("left") and time.monotonic() < until:
        press(tab, DISCARD)
        time.sleep(0.2)
    eq("so Discard acts meanwhile", lambda: tab.evaluate("left > 0"), True)
    f.evaluate("clearInterval(flood); 1")

BOX, TEXT, ON_PAGE = "#drawer [role=group]", "#drawer textarea", "#drawer section > button"
SEND_NOTE, CANCEL = BOX + " button.primary", BOX + " button:last-child"
DRAWN, WRITING = SHOWN % "#drawer", "!!document.querySelector('%s')" % BOX
ON = "(document.querySelector('%s p') || {}).textContent" % BOX
VALUE = "(document.querySelector('%s') || {}).value" % TEXT
WHY = "(document.querySelector('%s .why') || {}).textContent" % BOX
COUNT = "document.querySelector('#notes').textContent"
LINK = "#strips [data-kind=link]"
CHANGE = "document.querySelector('#strips').dataset.changed = performance.now(); 1"  # what a page brings then waits for PACE
ANCHOR = "{ dk: 1, t: 'anchor', anchor: { selector: '#one', tag: 'b', text: 'forged', rect: { x: 1, y: 2, w: 3, h: 4 } }, context: { viewport: { w: 5, h: 6 }, theme: 'forged', console: [] } }"

def noted():
    return recorded("notes.jsonl")

def said(*fields):
    return [[r[f] for f in fields] if fields[1:] else r[fields[0]] for r in noted()]

def types(tab, text):
    tab.chrome.call("Input.insertText", {"text": text}, tab.sid)

def opens(tab, f):
    press(tab, "#notes")
    fitted(tab, f)

def writes(tab, f, text):
    """This text typed in a note on the page, whose Send note can act."""
    if not tab.evaluate(DRAWN):
        opens(tab, f)
    press(tab, ON_PAGE)
    types(tab, text)
    time.sleep(ACTS)

def notes(b):
    forget("notes.jsonl")
    tab = visit(b, server.url + "/" + NOTED)
    f = tab.frame()
    tab.wait(FOCUS + " === 'iframe'")
    state = "[%s, document.querySelector('#notes').getAttribute('aria-expanded'), %s]" % (DRAWN, FOCUS)
    def after(key, at=None):
        if at:
            tab.evaluate("document.querySelector('%s').focus(); 1" % at)
        tab.key(key)
        time.sleep(0.2)
        return tab.evaluate(state)
    on_one = ["On <button> “One”", "textarea"]
    eq("Alt+N opens the notes from the page, the focus left in it, and how to pick is said", lambda: [after("Alt+n"), tab.evaluate("document.querySelector('#drawer [role=status]').textContent.split(',')[0]")], [[True, "true", "iframe"], "Click an element"])
    tab.key("Tab")
    tab.key("Enter")
    eq("Tab then Enter picks an element", lambda: [tab.wait(WRITING), tab.evaluate("[%s, %s]" % (ON, FOCUS)), f.evaluate("window.pressed || 0")][1:], [on_one, 0])
    tab.evaluate("document.querySelector('%s').dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', isComposing: true, bubbles: true })); 1" % TEXT)
    eq("an Escape that ends an IME's composition closes nothing", lambda: tab.evaluate("[%s, %s]" % (DRAWN, WRITING)), [True, True])
    eq("Alt+N in the composer is typing", lambda: [after("Alt+n"), tab.evaluate(WRITING)], [[True, "true", "textarea"], True])
    eq("Escape closes the composer", lambda: [after("Escape"), tab.evaluate(WRITING)], [[True, "true", "notes"], False])
    eq("then the drawer, then focus is on Notes", lambda: after("Escape"), [False, "false", "notes"])
    eq("Alt+N toggles from the viewer, and focuses Notes", lambda: [after("Alt+n", "#bar a"), after("Alt+n")], [[True, "true", "notes"], [False, "false", "notes"]])
    eq("Alt+N toggles from the page", lambda: [after("Alt+n", "iframe"), after("Alt+n")], [[True, "true", "iframe"], [False, "false", "iframe"]])
    f.evaluate("document.querySelector('#field').focus(); 1")
    eq("not in a field of it", lambda: after("Alt+n", "iframe"), [False, "false", "iframe"])
    outlined = "(() => { const o = document.querySelector('[data-design-kit-note]'), at = (e) => JSON.stringify(e.getBoundingClientRect()); return !!o && at(o) === at(document.querySelector('#one')); })()"
    def hovered():
        tab.hover(*f.at("h1"))
        tab.hover(*f.at("#one"))
        return f.wait(outlined, 0.4)
    closed = hovered()
    opens(tab, f)
    eq("hover outlines an element while the notes are open, and not before", lambda: [closed, hovered(), tab.evaluate(FOCUS)], [False, True, "notes"])
    tab.click(*f.at("#one"))
    eq("a click picks an element, and does nothing else", lambda: [tab.wait(WRITING), tab.evaluate("[%s, %s]" % (ON, FOCUS)), f.evaluate("window.pressed || 0")][1:], [on_one, 0])
    types(tab, "half")
    tab.click(*f.at("h1"))
    eq("another click names another element, and keeps the text", lambda: [tab.wait(ON + ".includes('h1')", 4), tab.evaluate("[%s, %s, %s]" % (ON, VALUE, FOCUS))][1], ["On <h1> “noted”", "half", "textarea"])
    time.sleep(ACTS)
    press(tab, SEND_NOTE)
    eq("the note's row is what was typed, on the element picked", lambda: [tab.wait("!" + WRITING), said("page", "kind", "text", "status"), [r["anchor"]["selector"] for r in noted()]][1:], [[[NOTED, "note", "half", "open"]], ["h1"]])
    eq("the drawer says so, counts it and lists it, and the focus is on Notes", lambda: [tab.wait(COUNT + " === 'Notes (1)'"), tab.evaluate("[document.querySelector('#drawer [role=status]').textContent, document.querySelectorAll('#drawer li').length, %s]" % FOCUS)], [True, ["Sent. The session reads it with dk notes.", 1, "notes"]])
    fitted(tab, f)
    tab.click(*f.at("#one"))
    tab.wait(WRITING)
    time.sleep(PACE)
    eq("Escape in the page closes a composer with nothing typed", lambda: [after("Escape", "iframe"), tab.evaluate(WRITING)], [[True, "true", "notes"], False])
    eq("then the drawer", lambda: [after("Escape", "iframe"), f.evaluate("!!document.querySelector('[data-design-kit-note]')")], [[False, "false", "notes"], False])

    f.evaluate("console.error('boom'); 1")
    writes(tab, f, "of the page")
    size = f.evaluate("[innerWidth, innerHeight]")
    f.evaluate("parent." + POST % ANCHOR.replace("'anchor'", "'context'").replace("anchor: {", "x: {", 1) + "1")
    on = tab.evaluate(ON)
    press(tab, SEND_NOTE)
    eq("Note on this page works, with viewport, theme and console context, as they were when it was asked for them", lambda: [on, tab.wait("!" + WRITING), said("text", "anchor", "context")[1:]],
       ["On this page", True, [["of the page", None, {"viewport": {"w": size[0], "h": size[1]}, "theme": "sepia", "console": ["boom"]}]]])
    for wrong in ("anchor: undefined", "anchor: 'x'", "anchor: { ...a, selector: 1 }", "anchor: { ...a, tag: null }", "anchor: { ...a, rect: [] }", "anchor: { ...a, rect: { x: 1, y: 2, w: 3 } }", "anchor: { ...a, rect: { x: NaN, y: 2, w: 3, h: 4 } }",
                  "context: undefined", "context: { ...c, viewport: { w: 1 } }", "context: { ...c, theme: 1 }", "context: { ...c, console: 'x' }", "context: { ...c, console: [1] }", "context: { ...c, console: [,] }", "context: { ...c, console: new Array(2 ** 32 - 1) }"):
        f.evaluate("{ const m = %s, a = m.anchor, c = m.context; parent." % ANCHOR + POST % ("{ ...m, %s }" % wrong) + "} 1")
    eq("an anchor of another shape opens no composer, notes on", lambda: [time.sleep(0.3), tab.evaluate("[%s, %s]" % (DRAWN, WRITING))][1], [True, False])
    f.evaluate("parent." + POST % ANCHOR + "1")
    eq("one of its shape does", lambda: [tab.wait(WRITING), tab.evaluate(ON)][1], "On <b> “forged”")
    types(tab, "on the first")
    time.sleep(ACTS)
    f.evaluate("parent." + POST % ANCHOR.replace("#one", "#two").replace("'b'", "'i'") + "1")
    on = tab.evaluate(ON)
    press(tab, SEND_NOTE)
    eq("a note sent before its composer names a newer element is on the one it names", lambda: [on, tab.wait(COUNT + " === 'Notes (3)'"), [r["anchor"]["selector"] for r in noted() if r["text"] == "on the first"]], ["On <b> “forged”", True, ["#one"]])
    time.sleep(PACE)
    if tab.evaluate(WRITING):
        press(tab, CANCEL)
    press(tab, "#notes")
    f.evaluate("parent." + POST % ANCHOR + "1")
    eq("notes off, none does", lambda: [time.sleep(0.3), tab.evaluate("[%s, %s]" % (DRAWN, WRITING))][1], [False, False])

    tab = visit(b, server.url + "/" + BOARD)
    f = tab.frame()
    opens(tab, f)
    offered(tab, f, 1)
    tab.evaluate(CHANGE)
    f.evaluate("parent." + POST % ANCHOR + "1")
    press(tab, "#notes")
    shut = (time.sleep(PACE), tab.evaluate("[%s, %s]" % (DRAWN, WRITING)))[1]
    tab.evaluate(CHANGE)
    f.evaluate("parent." + POST % ANCHOR + "1")
    opens(tab, f)
    eq("what was picked before the notes were closed, or opened, writes none", lambda: [shut, time.sleep(PACE), tab.evaluate("[%s, %s]" % (DRAWN, WRITING))], [[False, False], None, [True, False]])
    tab.evaluate("document.querySelector('%s').focus(); 1" % SEND)
    def floods(*more):
        f.evaluate("window.n = 0; window.flood = setInterval(() => { n++; const m = %s; m.anchor.text = 'forged ' + n; for (const one of [m, %s]) parent.postMessage(one, '*'); }, 60); 1" % (ANCHOR, ", ".join(more)))
    floods("{ dk: 1, t: 'key', name: n % 2 ? 'notes' : 'escape' }")
    tab.wait(WRITING, 4)
    time.sleep(0.5)
    eq("a page takes no focus from Send pick, and closes no drawer by a key pressed nowhere", lambda: tab.evaluate("[document.activeElement.textContent, %s, %s]" % (DRAWN, WRITING)), ["Send pick", True, True])
    until = time.monotonic() + 6
    while not recorded() and time.monotonic() < until:
        tab.key("Enter")
        time.sleep(0.2)
    f.evaluate("clearInterval(flood); 1")
    eq("nor does it keep Send pick from acting", lambda: len(recorded()), 1)
    if not tab.evaluate(DRAWN):
        opens(tab, f)
    floods()
    tab.wait(WRITING, 4)
    press(tab, TEXT)
    types(tab, "sent")
    until = time.monotonic() + 6
    while len(noted()) < 4 and time.monotonic() < until:
        press(tab, SEND_NOTE)
        time.sleep(0.2)
    f.evaluate("clearInterval(flood); 1")
    eq("nor Send note", lambda: said("text")[3:], ["sent"])
    forget()

def drafts(b):
    forget("notes.jsonl")
    tab = visit(b, server.url + "/" + NOTED)
    f = tab.frame()
    tab.wait(FOCUS + " === 'iframe'")
    opens(tab, f)
    tab.click(*f.at("#one"))
    tab.wait(WRITING)
    types(tab, "half a note")
    draft = "[%s, %s, %s, %s]" % (DRAWN, ON, VALUE, FOCUS)
    kept = [True, "On <button> “One”", "half a note", "textarea"]
    f = reframed(tab, noted_page)
    eq("reload keeps focus in the composer, and a half-typed note survives a save", lambda: [time.sleep(0.3), tab.evaluate(draft)][1], kept)
    eq("the page that came back picks elements too", lambda: [tab.hover(*f.at("#one")), f.wait("!!document.querySelector('[data-design-kit-note]')", 1)][1], True)
    f = reframed(tab, lambda: (server.stop(), server.start()))
    eq("a half-typed note survives a server restart", lambda: [time.sleep(0.3), tab.evaluate(draft)][1], kept)
    escape = "parent." + POST % "{ dk: 1, t: 'key', name: 'escape' }" + "1"
    time.sleep(PACE)
    f.evaluate(escape)
    eq("a half-typed note survives a forged escape", lambda: [time.sleep(0.2), tab.evaluate(draft)][1], kept)
    tab.evaluate("document.querySelector('iframe').focus(); 1")
    f.evaluate(escape)
    eq("also with the focus in the page", lambda: [time.sleep(0.2), tab.evaluate(draft)][1], kept[:3] + ["iframe"])
    tab.evaluate("document.querySelector('%s').focus(); %s" % (TEXT, CHANGE))
    f.evaluate("parent." + POST % "{ dk: 1, t: 'key', name: 'notes' }" + "1")
    tab.evaluate("new Promise((r) => setTimeout(r, 50)).then(() => document.querySelector('iframe').focus())")
    eq("a key forged while the user is in the viewer does nothing, then or once the page has the focus", lambda: [time.sleep(PACE), tab.evaluate(draft)][1], kept[:3] + ["iframe"])
    tab.evaluate(CHANGE)
    f.evaluate("parent." + POST % "{ dk: 1, t: 'key', name: 'notes' }" + "1")
    tab.evaluate("new Promise((r) => setTimeout(r, 50)).then(() => document.querySelector('%s').focus())" % TEXT)
    eq("nor does one of the page once the user is back in the viewer", lambda: [time.sleep(PACE), tab.evaluate(draft)][1], kept)
    press(tab, "#notes")
    hidden = tab.evaluate(DRAWN)
    fitted(tab, f)
    tab.evaluate("window.opened = []; window.open = (...args) => { opened.push(args); }; 1")
    tab.click(*f.at("#far"))
    at = server.url + "/decks/old.htm#/2"
    parts = "[...document.querySelectorAll('%s > *')].map((e) => [e.localName, e.textContent])" % LINK
    here = "[location.pathname, %s, document.body.dataset.page, opened]" % VALUE
    stays = ["/" + NOTED, "half a note", NOTED, []]
    eq("a half-typed note survives a page link click, which shows the link strip", lambda: [hidden, tab.wait("!!document.querySelector('%s')" % LINK, 3), tab.evaluate(parts), tab.evaluate(here)], [False, True, [["p", at], ["button", "Open"], ["button", "Dismiss"]], stays])
    press(tab, LINK + " button")
    eq("Open does nothing in its first 600 ms", lambda: tab.evaluate("opened"), [])
    time.sleep(ACTS)
    press(tab, LINK + " button")
    eq("and then opens the link in a window that knows nothing of this one", lambda: [tab.evaluate("opened"), tab.evaluate("!document.querySelector('%s')" % LINK)], [[[at, "_blank", "noopener,noreferrer"]], True])
    fitted(tab, f)
    tab.click(*f.at("#far"))
    tab.wait("!!document.querySelector('%s')" % LINK, 3)
    fitted(tab, f)
    press(tab, LINK + " button:last-child")
    eq("Dismiss opens nothing", lambda: [tab.evaluate("opened.length"), tab.evaluate("!document.querySelector('%s')" % LINK)], [1, True])
    for href in ("7", "'javascript:alert(1)'", "'data:text/html,x'", "'file:///etc'", "'http://'", "'https://a.example/' + 'x'.repeat(2048)"):
        f.evaluate("parent." + POST % ("{ dk: 1, t: 'link', href: %s }" % href) + "1")
    eq("a link of another scheme or shape shows nothing", lambda: [time.sleep(PACE), tab.evaluate("%s.length" % STRIPS), [e["params"] for e in b.chrome.events if e.get("sessionId") == tab.sid and e["method"] == "Runtime.exceptionThrown"]][1:], [0, []])
    opens(tab, f)
    eq("the drawer opens on the note as it was left", lambda: tab.evaluate(draft), kept[:3] + ["notes"])
    press(tab, CANCEL)
    eq("Cancel drops the draft and focuses Notes, which opened its drawer", lambda: tab.evaluate("[%s, %s]" % (WRITING, FOCUS)), [False, "notes"])
    writes(tab, f, "another")
    press(tab, CANCEL)
    eq("and the button that opened the composer", lambda: tab.evaluate("[%s, document.activeElement.textContent]" % WRITING), [False, "Note on this page"])
    tab.key("Enter")
    eq("the next note begins empty", lambda: tab.evaluate("[%s, %s]" % (VALUE, FOCUS)), ["", "textarea"])
    press(tab, "#notes")
    press(tab, "#notes")
    eq("and is gone once the drawer was closed on it", lambda: tab.evaluate("[%s, %s]" % (DRAWN, WRITING)), [True, False])
    eq("none was sent", noted, [])

def sends(b):
    forget("notes.jsonl")
    tab = visit(b, server.url + "/" + NOTED)
    f = tab.frame()
    tab.evaluate("window.drawn = 0; window.pressed = []; new MutationObserver(() => { drawn = performance.now(); }).observe(document.querySelector('#drawer'), { childList: true, subtree: true, attributes: true }); document.querySelector('#drawer').addEventListener('click', (e) => { if (e.target.className === 'primary') pressed.push(e.timeStamp - drawn); }, true); 1")
    opens(tab, f)
    early = []
    for how in ("click", "Enter", " "):
        press(tab, ON_PAGE)
        types(tab, "by " + how)
        tab.evaluate("pressed.length = 0")
        press(tab, SEND_NOTE, how)
        time.sleep(0.15)
        early.append(tab.evaluate("[pressed.length, pressed[0] < 600, %s]" % VALUE) + [len(noted())])
        time.sleep(0.6)
        if tab.evaluate(WRITING):
            press(tab, SEND_NOTE, how)
            tab.wait("!" + WRITING)
    eq("Send note guarded: click, Enter and Space in the first 600 ms do nothing", early, [[1, True, "by " + how, n] for n, how in enumerate(("click", "Enter", " "))])
    eq("and act after it", lambda: said("text"), ["by click", "by Enter", "by"])
    writes(tab, f, "   ")
    press(tab, SEND_NOTE)
    eq("a note of nothing is not sent, and the composer says why", lambda: [time.sleep(0.2), len(noted()), tab.evaluate("[%s, %s]" % (WHY, FOCUS))][1:], [3, ["A note needs text", "textarea"]])
    press(tab, CANCEL)
    forget("notes.jsonl")

    def double():
        x, y = tab.at(SEND_NOTE)
        for n in (1, 2):
            for kind in ("mousePressed", "mouseReleased"):
                b.chrome.call("Input.dispatchMouseEvent", {"type": kind, "x": x, "y": y, "button": "left", "clickCount": n}, tab.sid)
    sent = lambda: tab.evaluate("[...document.querySelectorAll('%s button')].filter((e) => e.checkVisibility()).map((e) => e.textContent)" % BOX)
    with catching(b) as (held, paused):
        caught = lambda stage, *more, **params: held(tab, lambda: press(tab, SEND_NOTE), stage, *more, **params)
        def lost():
            caught("Response", "failRequest", errorReason="ConnectionReset")
            tab.wait("%s.length > 0" % WHY)
        writes(tab, f, "twice")
        held(tab, double, "Request", "continueRequest")
        eq("a double click on Send note writes one row", lambda: [tab.wait("!" + WRITING), time.sleep(0.3), said("text"), len(paused)][2:], [["twice"], 0])
        forget("notes.jsonl")
        writes(tab, f, "kept")
        for status, body, why in ((400, b'{"recorded": false, "error": "the reason"}', "the reason"), (403, b"<h1>no</h1>", "the server answered 403"), (413, b'{"error": "the reason"}', "the reason"), (507, b'{"error": "the reason"}', "the reason"), (500, b'{"error": "the reason"}', "the reason")):
            caught("Request", "fulfillRequest", responseCode=status, body=base64.b64encode(body).decode())
            retry = status == 500
            eq("a failed note keeps its text: %d shows the reason and %s" % (status, "Send again" if retry else "no Send again"), lambda: [tab.wait("%s.length > 0" % WHY), tab.evaluate("[%s, %s, document.querySelector('%s').readOnly, %s]" % (WHY, VALUE, TEXT, FOCUS)), sent()][1:],
               [["Not recorded: " + why, "kept" + "!" * (status != 400), False, "button" if retry else "textarea"], (["Send again"] if retry else []) + ["Cancel"]])
            if status == 400:
                types(tab, "!")
                eq("an edit takes the reason away and brings Send note back", lambda: [tab.evaluate(WHY), sent()], ["", ["Send note", "Cancel"]])
            elif not retry:
                tab.evaluate("document.querySelector('%s').dispatchEvent(new Event('input', { bubbles: true })); 1" % TEXT)
            time.sleep(ACTS)
        def meanwhile():
            f.evaluate("parent." + POST % ANCHOR + "1")
            time.sleep(1.7)
            for how in ("click", "Enter"):
                press(tab, SEND_NOTE, how)
            press(tab, CANCEL)
            tab.key("Escape")
            eq("while a note is pending its buttons are disabled and its text, its target and the composer stay", lambda: tab.evaluate("[[...document.querySelectorAll('%s button')].map((e) => e.ariaDisabled), document.querySelector('%s').readOnly, %s, %s]" % (BOX, TEXT, VALUE, ON)), [["true", "true"], True, "kept!", "On this page"])
        caught("Request", "continueRequest", meanwhile)
        eq("then it is one row", lambda: [tab.wait("!" + WRITING), time.sleep(0.2), said("text"), len(paused)][2:], [["kept!"], 0])
        writes(tab, f, "answer lost")
        lost()
        eq("a lost answer shows Send again, and the row is there", lambda: [tab.evaluate("[%s, %s]" % (WHY, VALUE)), sent(), said("text")], [["The preview server did not answer", "answer lost"], ["Send again", "Cancel"], ["kept!", "answer lost"]])
        time.sleep(ACTS)
        press(tab, SEND_NOTE)
        eq("a retry after a lost answer writes no second row", lambda: [tab.wait("!" + WRITING), said("text")], [True, ["kept!", "answer lost"]])
        writes(tab, f, "changed")
        lost()
        tab.evaluate("document.querySelector('%s').focus(); 1" % TEXT)
        types(tab, ", after")
        eq("a change after a lost answer is a new note", lambda: [tab.evaluate(WHY), sent()], ["", ["Send note", "Cancel"]])
        time.sleep(ACTS)
        press(tab, SEND_NOTE)
        eq("and is sent as a second row", lambda: [tab.wait("!" + WRITING), said("text")[2:]], [True, ["changed", "changed, after"]])
        writes(tab, f, "changed, after")
        press(tab, SEND_NOTE)
        eq("and the same words sent anew as one more", lambda: [tab.wait("!" + WRITING), said("text")[4:], len(set(said("cid")))], [True, ["changed, after"], 5])
    writes(tab, f, "no server")
    server.stop()
    tab.wait(STRIPS + ".length", 8)
    time.sleep(ACTS)
    press(tab, SEND_NOTE)
    eq("with no server a note keeps its text", lambda: [tab.wait("%s.length > 0" % WHY), tab.evaluate("[%s, %s]" % (WHY, VALUE))], [True, ["The preview server did not answer", "no server"]])
    f = reframed(tab, server.start)
    time.sleep(ACTS)
    press(tab, SEND_NOTE)
    eq("which is sent once there is one", lambda: [tab.wait("!" + WRITING), said("text")[5:]], [True, ["no server"]])

    forget("notes.jsonl")
    wide = chr(0x6f22)
    f.evaluate("for (let i = 0; i < 5; i++) console.error('%s'.repeat(300)); 1" % wide)
    writes(tab, f, wide * 2000)
    press(tab, SEND_NOTE)
    tab.wait("!" + WRITING)
    f.evaluate("parent." + POST % ("{ dk: 1, t: 'anchor', anchor: { selector: '%s'.repeat(9000), tag: 'p', text: '%s'.repeat(9000), rect: { x: 1, y: 2, w: 3, h: 4 } }, context: { viewport: { w: 5, h: 6 }, theme: 't'.repeat(9000), console: [] } }" % (wide, wide)) + "1")
    tab.wait(WRITING)
    types(tab, wide * 2000)
    time.sleep(ACTS)
    press(tab, SEND_NOTE)
    tab.wait("!" + WRITING)
    eq("past the server's 8 KiB a note loses console lines, then the end of its text; what a page says of it is clamped first", lambda: [[len(r["text"]), len(r["context"]["console"]), len(r["anchor"]["selector"]) if r["anchor"] else 0] for r in noted()], [[2000, 2, 0], [1600, 0, 512]])

def lists(b):
    row = lambda n, status="open", reply="", of=NOTED: {"id": "%08d" % n, "ts": "2026-11-24T10:00:00Z", "page": of, "kind": "note", "anchor": {"selector": "h1", "tag": "h1", "text": "noted", "rect": {}} if n % 2 else None, "text": "note <b>%d</b>" % n, "context": {}, "status": status, "reply": reply}
    given = lambda *rows: put("notes.jsonl", "".join(json.dumps(r) + "\n" for r in rows))
    listed = "[...document.querySelectorAll('#drawer li')].map((li) => [...li.children].map((e) => e.textContent))"
    def seen(*rows, w=1280):
        given(*rows)
        tab = visit(b, server.url + "/" + NOTED, w)
        tab.frame()
        tab.wait("document.querySelector('#chip').textContent")
        time.sleep(0.2)
        return tab
    tab = seen(row(1, of=BOARD))
    eq("the Notes button reads Notes with none of this page's", lambda: [tab.evaluate(COUNT), press(tab, "#notes"), tab.evaluate("document.querySelector('#drawer ul').textContent")], ["Notes", None, "No notes on this page yet."])
    two = (row(1, "addressed", "done"), row(2))
    tab = seen(*two)
    eq("and Notes (2) with two, before they are opened", lambda: tab.evaluate(COUNT), "Notes (2)")
    press(tab, "#notes")
    given(*two + (row(3, "dismissed", "no <i>room</i>"),))
    press(tab, "#notes")
    press(tab, "#notes")
    eq("newest first, each with its status and reply, as text, read anew when the drawer opens", lambda: [tab.wait(COUNT + " === 'Notes (3)'"), tab.evaluate(listed)], [True, [["dismissed", "<h1>", "note <b>3</b>", "Reply: no <i>room</i>"], ["open", "Page", "note <b>2</b>"], ["addressed", "<h1>", "note <b>1</b>", "Reply: done"]]])
    boxes = "(() => { const at = (s) => document.querySelector(s).getBoundingClientRect(), d = at('#drawer'), f = at('iframe'), e = document.querySelector('#drawer'); return { drawer: [d.left, d.right, d.top === at('#strips').bottom], frame: [f.left, f.right, f.bottom], meet: innerWidth > 600 ? f.right === d.left && f.top === d.top : f.top === d.bottom, high: d.height <= innerHeight * .6, scrolls: e.scrollHeight > e.clientHeight, sideways: document.documentElement.scrollWidth, chip: %s, check: [%s, document.querySelector('#check').textContent] }; })()" % (SHOWN % "#chip", SHOWN % "#check")
    for w in (1280, 375):
        tab = seen(*[row(n) for n in range(1, 26)], w=w)
        press(tab, "#notes")
        tab.wait("document.querySelector('#drawer li').textContent.includes('25')")
        eq("25 notes list 20, the newest, at %d px" % w, lambda: [tab.evaluate(COUNT), [one[2] for one in tab.evaluate(listed)]], ["Notes (25)", ["note <b>%d</b>" % n for n in range(25, 5, -1)]])
        got = tab.evaluate(boxes)
        if w == 1280:
            eq("the drawer opens below the strips at the right, the frame fills the rest, and the check line is in the bar alone, at 1280 px", got, dict(got, drawer=[976, 1280, True], frame=[0, 976, 800], meet=True, sideways=1280, chip=True, check=[False, "Not checked"]))
        else:
            eq("the drawer is full width, at most 60vh, and scrolls inside itself, and the check line is in the drawer, at 375 px only", got, {"drawer": [0, 375, True], "frame": [0, 375, 800], "meet": True, "high": True, "scrolls": True, "sideways": 375, "chip": False, "check": [True, "Not checked"]})
    forget("notes.jsonl")
    odd = "decks/100%25 #1?.html"
    page(odd)
    tab = visit(b, server.url + "/" + quote(odd))
    writes(tab, tab.frame(), "odd")
    press(tab, SEND_NOTE)
    eq("a note on a page of any name is filed under it, and listed there", lambda: [tab.wait(COUNT + " === 'Notes (1)'"), said("page")], [True, [odd]])
    os.unlink(os.path.join(ROOT, odd))
    forget("notes.jsonl")

# which strips were drawn, in turn, since the document began
SAID = "window.said = []; addEventListener('DOMContentLoaded', () => { const at = document.querySelector('#strips'); if (at) new MutationObserver((all) => { for (const one of all) for (const el of one.addedNodes) said.push(el.dataset.kind); }).observe(at, { childList: true }); });"
CDN, IMAGES, NET, OTHER = "cdn.example.org", "img.example.net", "artifacts/net.html", "artifacts/fixture.html"
EVERY = ["script-src", "style-src", "img-src", "font-src", "media-src"]
BLOCKED = "#strips [data-kind=blocked]"
ALLOW, ROW = BLOCKED + " [data-consent]", "#drawer .hosts button"
ASKS = "[...document.querySelectorAll('%s')].map((s) => [...s.children].map((e) => e.textContent))" % BLOCKED
LISTED = "[...document.querySelectorAll('#drawer .hosts')].map((ul) => [...ul.children].map((li) => [...li.children].map((e) => e.textContent)))"
NETWORK = "(({ hidden, textContent }) => (hidden ? null : textContent))(document.querySelector('#network'))"
PANELS = "[...document.querySelectorAll('#bar button[aria-controls=drawer]')].map((e) => [e.id, e.getAttribute('aria-expanded')]).concat([...document.querySelectorAll('#drawer section')].filter((e) => e.checkVisibility()).map((e) => e.ariaLabel))"

def loads(title="net", body='<script src="https://%s/a.js"></script><link rel="stylesheet" href="https://%s/a.css"><img src="https://%s/i.png" alt="">' % (CDN, CDN, IMAGES)):
    page(NET, title=title, body=body)

def asks(host, kinds, *whys):
    return ["%s blocked: %s" % (host, kinds)] + list(whys) + ["Allow for this page", "Keep blocked"]

def blocked(f, host, kind="script"):
    """The page says it was refused a file of this kind from host."""
    f.evaluate("parent." + POST % json.dumps({"dk": 1, "t": "blocked", "host": host, "kind": kind}) + "1")

def becomes(tab, expression, want, seconds=8):
    """expression's value once it is want, else its last when the seconds run out."""
    tab.wait("JSON.stringify(%s) === %s" % (expression, json.dumps(json.dumps(want, separators=(",", ":"), ensure_ascii=False))), seconds)
    return tab.evaluate(expression)

def policy(name, host=CDN):
    """The directives of this page's policy that name host."""
    csp, _ = got(json.loads(got("/_page?page=" + quote(name))[1])["src"])
    return [directive.split()[0] for directive in csp.split("; ") if "https://" + host in directive.split()]

def approved(hosts=None):
    """.allow.json with these hosts for NET, or none."""
    for name in (".allow.json", ".allow.json.bad"):
        if os.path.exists(os.path.join(ROOT, name)):
            os.unlink(os.path.join(ROOT, name))
    if hosts is not None:
        put(".allow.json", hosts if isinstance(hosts, str) else json.dumps({NET: hosts}))

def approves(b):
    approved()
    loads()
    tab = visit(b, server.url + "/" + NET, source=SAID)
    tab.frame()
    tab.wait(FOCUS + " === 'iframe'")
    of_cdn, of_images = asks(CDN, "scripts, styles"), asks(IMAGES, "images")
    eq("a blocked host shows one strip with its name and kinds, said once", lambda: [becomes(tab, ASKS, [of_cdn, of_images]), tab.evaluate("said")], [[of_cdn, of_images], ["blocked"] * 2])
    eq("and takes no focus", lambda: tab.evaluate(FOCUS), "iframe")
    eq("Network appears with a count when a host is blocked", lambda: tab.evaluate(NETWORK), "Network (2)")
    time.sleep(ACTS)
    tab.evaluate("window.said = []; new MutationObserver((all) => { for (const one of all) for (const el of one.addedNodes) said.push(el.textContent); }).observe(document.querySelector('#strips'), { childList: true, subtree: true }); 1")
    was = policy(NET)
    reframed(tab, lambda: press(tab, ALLOW))
    eq("Allow changes this page's policy only", lambda: [was, policy(NET), policy(OTHER), policy(NET, IMAGES)], [[], EVERY, [], []])
    eq("Allow reloads the frame, which asks for that host no more; the host still blocked is not said again", lambda: [time.sleep(2.8), tab.evaluate("[%s, %s, said]" % (ASKS, NETWORK))][1], [[of_images], "Network (2)", []])
    eq("the browser keeps no approval", lambda: tab.evaluate("[localStorage, sessionStorage].flatMap(Object.entries).filter((one) => one.join().includes('%s'))" % CDN), [])
    press(tab, "#network")
    both = [[[CDN, "Remove"]], [[IMAGES, "images", "Allow"]]]
    eq("Network lists allowed hosts with Remove and blocked ones with Allow, under their names", lambda: tab.evaluate("[%s, [...document.querySelectorAll('#drawer h3')].map((e) => e.textContent), [...document.querySelectorAll('%s')].map((e) => e.ariaLabel)]" % (LISTED, ROW)), [both, ["Allowed", "Blocked"], ["Remove: " + CDN, "Allow: " + IMAGES]])
    eq("the list survives a restart", lambda: [bool(reframed(tab, lambda: (server.stop(), server.start()))), policy(NET), tab.evaluate(LISTED)], [True, EVERY, both])
    again(b, tab)
    press(tab, "#network")
    eq("and a tab reload", lambda: becomes(tab, LISTED, both), both)
    time.sleep(ACTS)
    tab.evaluate("document.querySelector('%s').focus(); 1" % ROW)
    reframed(tab, lambda: tab.key("Enter"))
    eq("Remove takes it away, the focus stays at its host, and it is asked for as the page loads it again", lambda: [policy(NET), becomes(tab, ASKS, [of_images, of_cdn]), tab.evaluate("document.activeElement.ariaLabel"), tab.evaluate(LISTED)],
       [[], [of_images, of_cdn], "Allow: " + CDN, [[[IMAGES, "images", "Allow"], [CDN, "scripts, styles", "Allow"]]]])
    fitted(tab, tab.frame())
    press(tab, BLOCKED + "[data-key='%s'] button:last-child" % CDN)
    eq("Keep blocked takes the strip away", lambda: becomes(tab, ASKS, [of_images]), [of_images])
    listed = tab.evaluate(LISTED)
    reframed(tab, lambda: loads("saved"))
    eq("Keep blocked survives a frame reload, and Network lists the host with Allow", lambda: [time.sleep(2.8), tab.evaluate("[%s, %s]" % (ASKS, LISTED))][1], [[of_images], listed])
    again(b, tab)
    tab.wait(NETWORK)
    press(tab, "#network")
    listed[0].reverse()
    eq("and a reload of the tab", lambda: [becomes(tab, LISTED, listed), time.sleep(0.5), tab.evaluate(ASKS)], [listed, None, [of_images]])
    time.sleep(PACE)
    def twice():
        for _ in range(2):
            press(tab, "#drawer [data-host='%s']" % CDN)
            time.sleep(0.15)
    reframed(tab, twice)
    eq("Allow in Network allows a host kept blocked, a double click too", lambda: [policy(NET), becomes(tab, LISTED, both), time.sleep(0.5), policy(NET)], [EVERY, both, None, EVERY])
    reframed(tab, lambda: loads("empty", ""))
    eq("a host the page asks no more for leaves the list", lambda: [becomes(tab, NETWORK, "Network (1)"), tab.evaluate("[%s, %s]" % (ASKS, LISTED))], ["Network (1)", [[], both[:1]]])
    time.sleep(ACTS)
    tab.evaluate("document.querySelector('%s').focus(); 1" % ROW)
    reframed(tab, lambda: tab.key("Enter"))
    eq("Network hidden again with no host left", lambda: [becomes(tab, NETWORK, None), tab.evaluate("[%s, %s]" % (DRAWN, FOCUS)), policy(NET)], [None, [False, "iframe"], []])
    reframed(tab, lambda: loads())
    eq("and there again with one, asked for anew where Allow had ended Keep blocked", lambda: [becomes(tab, ASKS, [of_cdn, of_images]), tab.evaluate(NETWORK)], [[of_cdn, of_images], "Network (2)"])
    tab = visit(b, server.url + "/" + NET)
    eq("Keep blocked lasts for the tab", lambda: becomes(tab, ASKS, [of_cdn, of_images]), [of_cdn, of_images])
    for _ in range(2):
        fitted(tab, tab.frame())
        press(tab, BLOCKED + " button:last-child")
    reframed(tab, lambda: loads("empty again", ""))
    eq("with none allowed the last blocked host hides Network too", lambda: [becomes(tab, NETWORK, None), tab.evaluate(ASKS)], [None, []])
    reframed(tab, lambda: loads())
    becomes(tab, NETWORK, "Network (2)")
    approved([IMAGES])
    reframed(tab, lambda: loads("by another tab"))
    eq("an approval made elsewhere is taken at the next load", lambda: [tab.evaluate(NETWORK), press(tab, "#network"), tab.evaluate(LISTED)], ["Network (2)", None, [[[IMAGES, "Remove"]], [[CDN, "scripts, styles", "Allow"]]]])

def refuses(b):
    loads()
    of_images = asks(IMAGES, "images")
    full = ["h%d.example.org" % n for n in range(20)]
    approved(full)
    tab = visit(b, server.url + "/" + NET)
    becomes(tab, ASKS, [asks(CDN, "scripts, styles"), of_images])
    time.sleep(ACTS)
    press(tab, ALLOW)
    why = "Not recorded: a page may load from at most 20 hosts; remove one first"
    eq("a cap's refusal names the cap, and Allow stays", lambda: becomes(tab, ASKS, [asks(CDN, "scripts, styles", why), of_images]), [asks(CDN, "scripts, styles", why), of_images])
    press(tab, "#network")
    eq("Network says so too", lambda: tab.evaluate("[document.querySelector('#drawer section:last-child [role=status]').textContent, %s]" % NETWORK), [CDN + ": " + why, "Network (22)"])
    with catching(b) as (caught, paused):
        def meanwhile():
            for how in ("click", "Enter"):
                press(tab, ALLOW, how)
            eq("while a POST is pending its host's buttons are disabled and a press posts nothing more", lambda: [time.sleep(0.3), tab.evaluate("[...document.querySelectorAll('[data-host=\"%s\"]')].map((e) => e.ariaDisabled)" % CDN), len(paused)], [None, ["true", "true"], 1])
        time.sleep(ACTS)
        caught(tab, lambda: press(tab, ALLOW), "Request", "failRequest", meanwhile, errorReason="ConnectionReset")
    lost = asks(CDN, "scripts, styles", "The preview server did not answer")
    eq("a lost answer is said, and Allow acts again", lambda: [becomes(tab, ASKS, [lost, of_images]), tab.evaluate("document.querySelector('%s').ariaDisabled" % ALLOW)], [[lost, of_images], None])
    approved("{")
    reframed(tab, lambda: loads("unreadable"))
    broken = "Approvals file unreadable; all hosts blocked"
    eq("an unreadable approvals file blocks all hosts, and the viewer says so", lambda: [becomes(tab, ASKS + ".map((parts) => parts[1])", [broken, "Allow for this page"]), policy(NET, full[0]), tab.evaluate("[document.querySelector('#drawer section:last-child div .why').textContent, %s]" % NETWORK)], [[broken, "Allow for this page"], [], [broken, "Network (2)"]])
    time.sleep(ACTS)
    reframed(tab, lambda: press(tab, ALLOW))
    with open(os.path.join(ROOT, ".allow.json.bad")) as fh:
        eq("the next Allow keeps that file aside and starts a new one", lambda: [fh.read(), policy(NET), becomes(tab, ASKS, [of_images]), tab.evaluate("[...document.querySelectorAll('#drawer section:last-child .why')].map((e) => e.textContent)")], ["{", EVERY, [of_images], [""]])
    approved()

    tab = visit(b, server.url + "/" + OTHER)
    f = tab.frame()
    for n in range(10):
        blocked(f, "h%d.example" % n)
    ten = [asks("h%d.example" % n, "scripts") for n in range(10)]
    count = "(document.querySelector('#strips [data-kind=more]') || {}).textContent"
    eq("ten blocked hosts are ten strips", lambda: [becomes(tab, ASKS, ten) == ten, tab.evaluate(count)], [True, None])
    blocked(f, "h0.example", "font")
    ten[0] = asks("h0.example", "scripts, fonts")
    eq("a strip that changes stays where it is", lambda: becomes(tab, ASKS, ten) == ten, True)
    blocked(f, "h10.example")
    eq("an eleventh blocked host becomes a count", lambda: [becomes(tab, count, "1 more host blocked; Network lists it"), tab.evaluate(ASKS) == ten, tab.evaluate(NETWORK)], ["1 more host blocked; Network lists it", True, "Network (11)"])
    press(tab, BLOCKED + " button:last-child", "Enter")
    eq("and the tenth strip once one was kept blocked", lambda: [becomes(tab, ASKS, ten[1:] + [asks("h10.example", "scripts")]) == ten[1:] + [asks("h10.example", "scripts")], tab.evaluate("%s === undefined" % count)], [True, True])
    f.evaluate("for (let n = 11; n < 49; n++) parent.postMessage({ dk: 1, t: 'blocked', host: 'h' + n + '.example', kind: 'img' }, '*'); 1")
    time.sleep(1.2)
    f.evaluate("for (let n = 49; n < 99; n++) parent.postMessage({ dk: 1, t: 'blocked', host: 'h' + n + '.example', kind: 'img' }, '*'); 1")
    time.sleep(1.2)
    f.evaluate("for (let n = 99; n < 120; n++) parent.postMessage({ dk: 1, t: 'blocked', host: 'h' + n + '.example', kind: 'img' }, '*'); 1")
    eq("no more than 100 are listed, whatever a page names", lambda: [becomes(tab, NETWORK, "Network (100)"), time.sleep(PACE), tab.evaluate("[%s, %s, [...document.querySelectorAll('#strips > *')].map((s) => s.dataset.kind)]" % (NETWORK, count))], ["Network (100)", None, ["Network (100)", "89 more hosts blocked; Network lists them", ["blocked"] * 10 + ["more"]]])
    tab = visit(b, server.url + "/" + OTHER)
    f = tab.frame()
    odd = "<img src=x onerror=alert(1)>" + chr(0x202e)
    blocked(f, odd, "font")
    shown = asks(odd.replace(chr(0x202e), "U+202E"), "fonts")
    eq("a host holding markup shows as text, a character that draws nothing as its number", lambda: becomes(tab, ASKS, [shown]), [shown])
    tab = visit(b, server.url + "/" + OTHER)
    blocked(tab.frame(), "127.0.0.1")
    tab.wait(ASKS + ".length")
    time.sleep(ACTS)
    press(tab, ALLOW)
    shown = asks("127.0.0.1", "scripts", "Not recorded: host must be a public https host name with no port, such as cdn.example.org")
    eq("a host the server refuses stays blocked, for the server's reason", lambda: [becomes(tab, ASKS, [shown]), policy(OTHER, "127.0.0.1"), os.path.exists(os.path.join(ROOT, ".allow.json"))], [[shown], [], False])

PLACED = """(() => { const at = (s) => document.querySelector(s).getBoundingClientRect(), d = at('#drawer'), f = at('iframe'), p = at('BLOCKED p'), a = at('ALLOW'), k = at('BLOCKED button:last-child'), wide = innerWidth > 600;
  return { drawer: [d.left, d.right, d.top === at('#strips').bottom, wide || d.height <= innerHeight * .6], frame: wide ? f.right === d.left : f.top === d.bottom, stacked: wide ? a.left >= p.right && a.top === k.top : a.top >= p.bottom && k.top >= a.bottom,
    tall: [...document.querySelectorAll('BLOCKED button, ROW')].every((e) => e.getBoundingClientRect().height >= 24), sideways: [document.documentElement.scrollWidth, document.querySelector('#strips').scrollWidth <= innerWidth, document.querySelector('#drawer').scrollWidth <= document.querySelector('#drawer').clientWidth] }; })()""".replace("BLOCKED", BLOCKED).replace("ALLOW", ALLOW).replace("ROW", ROW)

def panels(b):
    approved([CDN])
    loads()
    for w in (1280, 375):
        tab = visit(b, server.url + "/" + NET, w)
        tab.wait(ASKS + ".length")
        press(tab, "#network")
        eq("the list opens below the strips, in the drawer's place, the strip's buttons beside its text or under it, nothing sideways, at %d px" % w, lambda: tab.evaluate(PLACED),
           {"drawer": [976 if w == 1280 else 0, w, True, True], "frame": True, "stacked": True, "tall": True, "sideways": [w, True, True]})
    tab = visit(b, server.url + "/" + NET)
    f = tab.frame()
    tab.wait(ASKS + ".length")
    blocked(f, CDN.upper())
    eq("a host that is allowed is not asked for, whatever the page says", lambda: [time.sleep(PACE), tab.evaluate("[%s, %s]" % (ASKS, NETWORK))][1], [[asks(IMAGES, "images")], "Network (2)"])
    writes(tab, f, "half a note")
    notes_open, network_open, none_open = [["network", "false"], ["notes", "true"], "Notes on this page"], [["network", "true"], ["notes", "false"], "Network"], [["network", "false"], ["notes", "false"]]
    def after(selector=None, key=None):
        if selector:
            press(tab, selector, key or "click")
        time.sleep(0.2)
        return tab.evaluate(PANELS)
    def hovered():
        fitted(tab, f)
        tab.hover(*f.at("h1"))
        return f.wait("!!document.querySelector('[data-design-kit-note]')", 0.4)
    eq("one panel open at a time", lambda: [after(), after("#network"), hovered(), after("#notes"), hovered(), tab.evaluate(VALUE)], [notes_open, network_open, False, notes_open, True, "half a note"])
    press(tab, "#network")
    eq("Escape closes Network, keeps a half-typed note, and focus returns to Network", lambda: [after("#network", "Escape"), tab.evaluate("[%s, %s]" % (FOCUS, VALUE))], [none_open, ["network", "half a note"]])
    press(tab, "#network")
    time.sleep(PACE)
    eq("also from its list, and from the page", lambda: [after(ROW, "Escape"), tab.evaluate(FOCUS), press(tab, "#network"), time.sleep(PACE), after("iframe", "Escape"), tab.evaluate(FOCUS)], [none_open, "network", None, None, none_open, "network"])
    press(tab, "#network")
    tab.evaluate("document.querySelector('#network').focus(); 1")
    eq("Alt+N opens the notes in its place", lambda: [tab.key("Alt+n"), after(), tab.evaluate(FOCUS)], [None, notes_open, "notes"])
    approved()

LINKS = "artifacts/links.html"

def links(b):
    page(LINKS, body="".join('<p><a id="%s" href="%s">%s</a></p>' % (one, href, one) for one, href in (("out", "https://out.example/a?b=1#c"), ("mail", "mailto:a@b.example?subject=x"), ("js", "javascript:window.ran = 1"), ("data", "data:text/html,x"), ("file", "file:///etc/hosts"),
                                                                                           ("page", "../decks/old.htm?static=1&key=k#/2"), ("folder", "/motion/one/?x"), ("image", "/shots/one.png?x#y"))))
    tab = visit(b, server.url + "/" + LINKS)
    f = tab.frame()
    tab.evaluate("window.opened = []; window.open = (...args) => { opened.push(args); }; 1")
    here, offers = "[location.href, document.querySelectorAll('iframe').length, opened]", "[...document.querySelectorAll('%s > *')].map((e) => e.textContent)" % LINK
    stays = [server.url + "/" + LINKS, 1, []]
    def goes(href):
        f.evaluate("parent." + POST % json.dumps({"dk": 1, "t": "link", "href": href}) + "1")
    goes(server.url + "/decks/old.htm")
    eq("a page-to-page link no one clicked does nothing", lambda: [time.sleep(0.4), tab.evaluate("[%s, %s]" % (here, STRIPS))][1], [stays, []])
    for one, href in (("js", "javascript:alert(1)"), ("data", "data:text/html,x"), ("file", "file:///etc/hosts")):
        tab.click(*f.at("#" + one))
        goes(href)
        eq("%s: link shows nothing" % href.split(":")[0], lambda: [time.sleep(0.4), tab.evaluate("[%s, %s]" % (here, STRIPS))][1], [stays, []])
    tab.click(*f.at("#out"))
    at = "https://out.example/a?b=1#c"
    eq("an https link shows its full address", lambda: [becomes(tab, offers, [at, "Open", "Dismiss"]), time.sleep(ACTS), tab.evaluate(here)], [[at, "Open", "Dismiss"], None, stays])
    press(tab, LINK + " button")
    eq("and opens only on Open", lambda: [tab.evaluate("opened"), becomes(tab, offers, [])], [[[at, "_blank", "noopener,noreferrer"]], []])
    tab.evaluate("opened.length = 0")
    goes("https://one.example/")
    becomes(tab, offers, ["https://one.example/", "Open", "Dismiss"])
    time.sleep(ACTS)
    goes("https://two.example/")
    press(tab, LINK + " button")
    eq("Open opens the address shown, not a newer one that waits to be", lambda: tab.evaluate("opened.map(([href]) => href)"), ["https://one.example/"])
    becomes(tab, offers, ["https://two.example/", "Open", "Dismiss"])
    press(tab, LINK + " button:last-child")
    becomes(tab, offers, [])
    for one, at in (("mail", "mailto:a@b.example?subject=x"), ("image", server.url + "/shots/one.png#y")):
        fitted(tab, f)
        tab.click(*f.at("#" + one))
        eq("so does %s; Dismiss opens nothing" % ("a mailto link" if one == "mail" else "a file of this server, its query dropped"), lambda: [becomes(tab, offers, [at, "Open", "Dismiss"]), fitted(tab, f), press(tab, LINK + " button:last-child"), becomes(tab, offers, []), tab.evaluate("opened.length")], [[at, "Open", "Dismiss"], None, None, [], 1])
    for one, at, name in (("page", "/decks/old.htm#/2", "decks/old.htm"), ("folder", "/motion/one/", "motion/one/index.html"), ("h1", "//decks/old.htm", "decks/old.htm")):
        fitted(tab, f)
        tab.click(*f.at("#" + one if one != "h1" else one))
        if one == "h1":
            goes(server.url + at)
        eq("a page-to-page link opens in the viewer without its query: " + at, lambda: [tab.wait("document.body.dataset.page === '%s'" % name), tab.evaluate("location.href"), tab.frame().evaluate("location.search + location.hash")], [True, server.url + at, at[at.find("#"):] if "#" in at else ""])
        tab.evaluate("history.back(); 1")
        tab.wait("document.body.dataset.page === '%s'" % LINKS)
        f = tab.frame()
    tab.click(*f.at("h1"))
    asked_for = server.url + "/shots/one.png"
    f.evaluate("let n = 0; const flood = setInterval(() => { for (let i = 0; i < 10; i++, n++) parent." + POST % json.dumps({"dk": 1, "t": "link", "href": asked_for}) + "if (n === 500) clearInterval(flood); }, 12); 1")
    time.sleep(2.5)
    eq("500 link messages act at most 50 times", lambda: tab.evaluate("(() => { const acted = performance.getEntriesByType('resource').filter((e) => e.name === %s).map((e) => e.startTime); return [Math.max(...acted.map((t) => acted.filter((u) => u >= t && u < t + 990).length)) <= 50, acted.length >= 40]; })()" % json.dumps(asked_for)), [True, True])
    eq("and leave one strip, with Dismiss", lambda: tab.evaluate("[%s, document.querySelectorAll('%s').length]" % (offers, LINK)), [[asked_for, "Open", "Dismiss"], 1])

KEPT_HOST, GUARDED = "kept.example.org", "boards/guarded.html"

def guards(b):
    forget()
    approved()
    page(GUARDED, body='<script src="https://%s/a.js"></script>' % CDN)
    tab = visit(b, server.url + "/" + GUARDED)
    f = tab.frame()
    tab.evaluate("window.did = []; window.open = () => { did.push('open'); }; { const real = fetch; window.fetch = (at, init) => { if (init && init.body) did.push(at); return real(at, init); }; } window.presses = 0; document.addEventListener('click', (e) => { if ('consent' in e.target.dataset) presses++; }, true); 1")
    blocked(f, KEPT_HOST)
    tab.wait(ASKS + ".length === 2", 6)
    press(tab, BLOCKED + "[data-key='%s'] button:last-child" % KEPT_HOST, "Enter")
    says(f, 1)
    f.evaluate("parent." + POST % json.dumps({"dk": 1, "t": "link", "href": "https://out.example/"}) + "1")
    tab.wait("!!document.querySelector('%s') && %s" % (LINK, THERE), 6)
    eq("pick, blocked and link are in that order, whichever came first", lambda: tab.evaluate("[...document.querySelectorAll('#strips > *')].map((s) => s.dataset.kind)"), ["pick", "blocked", "link"])
    press(tab, "#network")
    tab.evaluate("document.querySelector('#drawer section:last-child').style.paddingBottom = '2000px'; 1")
    controls, rows = [SEND, ALLOW, LINK + " button", "#drawer .hosts [data-consent]"], "document.querySelectorAll('#drawer .hosts li').length"
    def changed_row():
        blocked(f, KEPT_HOST, "font")
        tab.wait("document.querySelector('#drawer').textContent.includes('scripts, fonts')", 4)
    def row(n):
        def there():
            if n == 2:
                blocked(tab.frame(), KEPT_HOST)
            tab.wait(rows + " === %d" % n, 8)
        return there
    def left_row():
        reframed(tab, lambda: page(GUARDED, title="again", body='<script src="https://%s/a.js"></script>' % CDN))
        row(1)()
    def moved():
        tab.evaluate("document.querySelector('#drawer').scrollBy(0, 20); 1")
        tab.evaluate(browser_lib.check.SETTLE_JS)
    def updated():
        says(f, 2)
        tab.wait(HEAD + ".includes('Updated')", 4)
    for what, happen in (("a strip appeared and moved others", lambda: above(tab, f, True)), ("a strip left", lambda: above(tab, f, False)), ("a strip changed", updated), ("a Network row changed", changed_row), ("a Network row left", left_row), ("a Network row appeared", row(2)), ("Network rows moved", moved),
                         ("a drawer closed", lambda: tab.key("Escape")), ("a drawer opened", lambda: press(tab, "#network")), ("a resize", lambda: resized(b, tab)), ("the tab became visible", lambda: unseen(b, tab)), ("the window gained focus", lambda: elsewhere(tab))):
        time.sleep(PACE if "strip" in what or "row" in what else ACTS)
        tab.evaluate("presses = 0")
        happen()
        shown = controls[:3] if what == "a drawer closed" else controls
        def pressed():
            for how in ("click", "Enter", " "):
                for control in shown:
                    press(tab, control, how)
            time.sleep(0.2)
            return tab.evaluate("[presses, did]")
        eq("Open, Send pick, strip Allow and Network Allow guarded after " + what, pressed, [3 * len(shown), []])
    for control, how, want in ((LINK + " button", "Enter", "open"), (SEND, " ", "/_decision"), (ALLOW, "Enter", "/_allow"), ("#drawer [data-host='%s']" % KEPT_HOST, "click", "/_allow")):
        if KEPT_HOST in control:
            blocked(tab.frame(), KEPT_HOST)
            tab.wait(rows + " === 2", 4)
        time.sleep(ACTS)
        press(tab, control, how)
        eq("and once nothing changed for a while it acts: %s on %s" % (how.strip() or "Space", control.split(" button")[0].split(" [data-consent]")[0]), lambda: [tab.wait("did.length"), tab.evaluate("did.splice(0)")][1], [want])
        tab.wait("!document.querySelector('[aria-disabled=true]')")
        time.sleep(0.5)
    forget()
    approved()

KINDS_SHOWN = "[...document.querySelectorAll('#strips > *')].map((s) => s.dataset.kind)"
SEEN = """(() => {
  const words = (s) => [...document.querySelectorAll(s)].filter((e) => e.checkVisibility()).map((e) => e.textContent || e.localName);
  return [words('#bar > *'), words('#strips :is(p, li, button)'), words('#drawer :is(h2, h3, #check, button, textarea, .st, .reply, bdi)'), words('#frame :is(iframe, p, button, a)')];
})()"""
# the rules of the Visual contract's placement that do not hold
ASTRAY = """(() => {
  const all = (s) => [...document.querySelectorAll(s)].filter((e) => e.checkVisibility()), box = (s) => document.querySelector(s).getBoundingClientRect();
  const w = innerWidth, h = innerHeight, wide = w > 600, bar = box('#bar'), strips = box('#strips'), drawer = box('#drawer'), main = box('#frame'), open = drawer.height > 0, frame = document.querySelector('iframe');
  const items = all('#bar > *').map((e) => e.getBoundingClientRect()), last = all('#bar button').map((e) => e.getBoundingClientRect()).pop();
  const stands = (e) => { const r = e.getBoundingClientRect(), was = e.previousElementSibling.getBoundingClientRect(); return wide ? e.previousElementSibling.localName !== 'button' || r.top === was.top && r.left > was.right : r.top >= was.bottom; };
  const scroll = (e) => ['auto', 'scroll'].includes(getComputedStyle(e).overflowX) && e.scrollWidth > e.clientWidth;
  return Object.entries({
    'the bar is above all, in one line, its buttons at the right': bar.top === 0 && bar.left === 0 && bar.right === w && items[0].left === 12 && items.every((r, i) => Math.abs(r.top + r.bottom - bar.top - bar.bottom + 1) < 3 && (!i || r.left > items[i - 1].right)) && (!last || last.right === w - 12),
    'the strips are under the bar, across the window': strips.top === bar.bottom && strips.left === 0 && strips.right === w,
    "a strip's buttons are in a row, or stacked under its text when narrow": all('#strips button').every(stands),
    'the drawer is below the strips, at the right, or full width and at most 60vh when narrow': !open || drawer.top === strips.bottom && drawer.right === w && (wide ? drawer.left > w / 2 && drawer.bottom === h : drawer.left === 0 && drawer.height <= h * .6),
    'the frame area fills the rest': main.left === 0 && main.top === (open && !wide ? drawer.bottom : strips.bottom) && main.right === (open && wide ? drawer.left : w) && main.bottom === h,
    'the frame fills its area': !frame || ['top', 'left', 'right', 'bottom'].every((k) => frame.getBoundingClientRect()[k] === main[k]),
    'nothing is wider than the window': document.documentElement.scrollWidth === w && !all('body *').some((e) => { const r = e.getBoundingClientRect(); return r.left < 0 || r.right > w || scroll(e); }),
    'the window does not scroll': document.documentElement.scrollHeight === h,
  }).filter(([, holds]) => !holds).map(([rule]) => rule);
})()"""
with open(browser_lib.check.AXE_PATH, encoding="utf-8") as fh:
    AXE = fh.read()
AXE_RUN = "axe.run(document, { iframes: false, rules: { 'target-size': { enabled: true } } }).then((r) => (r.passes.length > 9 ? r.violations.map((v) => [v.id, v.nodes.map((n) => n.html.slice(0, 120))]) : ['axe checked next to nothing']))"
STOP = "((e) => e.localName + ': ' + (e.ariaLabel || e.textContent).slice(0, 40))"
STOPS = "[...document.querySelectorAll('*')].filter((e) => e.tabIndex >= 0 && e.checkVisibility())"
# a list that scrolls is one, so that a keyboard can scroll it
OTHERS = STOPS + ".filter((e) => e.tabIndex > 0 || !/^(a|button|textarea|iframe)$/.test(e.localName)).map((e) => %s(e) + (e.tabIndex > 0 ? ', tabindex ' + e.tabIndex : ''))" % STOP
DRAGGED = "[...document.querySelectorAll('*')].filter((e) => e.draggable).map((e) => e.outerHTML.slice(0, 80))"
PRESSES = re.compile("(aux|dbl)?click|contextmenu|(mouse|pointer|touch|key)(down|up|start|end|press)")

def reached(tab):
    """What Tab reaches from the top of the viewer, each once, until it leaves the viewer."""
    tab.evaluate("document.querySelector('#bar a').focus(); 1")
    tab.key("Shift+Tab")
    stops = []
    for _ in range(60):
        tab.key("Tab")
        at = tab.evaluate("document.activeElement === document.body ? '' : %s(document.activeElement)" % STOP)
        if not at or at in stops[:1]:
            break
        if at not in stops[-1:]:
            stops.append(at)
    return stops

def listens(b, tab):
    """(type, tag) of every listener of the viewer's window and document."""
    heard = set()
    for of in ("window", "document"):
        at = b.chrome.call("Runtime.evaluate", {"expression": of}, tab.sid)["result"]["objectId"]
        for one in b.chrome.call("DOMDebugger.getEventListeners", {"objectId": at, "depth": -1}, tab.sid)["listeners"]:
            node = b.chrome.call("DOM.describeNode", {"backendNodeId": one["backendNodeId"]}, tab.sid)["node"]["localName"] if of == "document" else of
            heard.add((one["type"], node))
    return heard

def own_address():
    """This machine's own address on its network, or None."""
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
        try:
            s.connect(("192.0.2.1", 9))
            at = s.getsockname()[0]
        except OSError:
            return None
    return None if at.startswith("127.") else at

@contextlib.contextmanager
def away():
    """The preview as another device opens it, (its URL, what its first request adds, the port): at this machine's own address and with the LAN key, or at Far where it has none."""
    if not LAN:
        srv = threaded(Far)
        try:
            yield "http://127.0.0.1:%d" % srv.server_port, "", srv.server_port
        finally:
            srv.shutdown()
        return
    there = Server(ROOT)
    there.start("--lan")
    try:
        with open(os.path.join(ROOT, ".preview.key")) as fh:
            yield "http://%s:%d" % (LAN, there.port), "?key=" + fh.read().strip(), there.port
    finally:
        there.stop()

def leave_it(port, name):
    """The line of decision 25."""
    return "Open http://127.0.0.1:%d/%s on the computer running the server to leave notes, picks or approvals." % (port, quote(name))

ALLOWED = "fonts.example.org"

def note_rows(n, of):
    """n notes on this page, the newest last, as the server keeps them."""
    return "".join(json.dumps({"id": "%08d" % i, "ts": "2026-11-24T10:00:00Z", "page": of, "kind": "note", "anchor": None, "text": "note %d" % i, "context": {}, "status": ("dismissed", "open", "addressed")[i % 3], "reply": "done" if i % 3 == 2 else ""}) + "\n" for i in range(1, n + 1))

def states(b, w, there):
    """Each state of the contract on the fixture board at this width: its name, its tab, what is in the bar, the strips, the drawer and the frame area, which strips were drawn, and what has the focus."""
    left, frame = ["Gallery", "fixture"] + ["Not checked"] * (w == 1280), ["iframe"]
    def opened(url=server.url + "/" + BOARD):
        tab = visit(b, url, w, source=SAID)
        tab.wait("document.body.dataset.page === '%s' && !!document.querySelector('iframe')" % BOARD)
        f = tab.frame()
        tab.wait(FOCUS + " === 'iframe'")
        fitted(tab, f)
        return tab, f
    forget()
    forget("notes.jsonl")
    approved()
    put(".checks/results.json", "{}")
    tab, f = opened()
    tab.wait("document.querySelector('#chip').textContent")
    yield "empty", tab, [left + ["Notes"], [], [], frame], [], "iframe"
    tab, f = opened()
    says(f, 2, {"all": {"space": 12}}, {"1": {"h1:0": {"was": "One", "now": "Two"}}})
    tab.wait(THERE, 4)
    fitted(tab, f)
    yield "pick", tab, [left + ["Notes"], ["Artboard 2 picked", "All artboards: spacing base 12px", "Artboard 1 text, h1:0: “One” → “Two”", "Send pick", "Discard"], [], frame], ["pick"], "iframe"
    put(".allow.json", json.dumps({BOARD: [ALLOWED]}))
    tab, f = opened()
    f.evaluate("".join("parent." + POST % json.dumps({"dk": 1, "t": "blocked", "host": host, "kind": kind}) for host, kind in ((CDN, "script"), (CDN, "style"), (IMAGES, "img"))) + "1")
    tab.wait(ASKS + ".length === 2", 4)
    time.sleep(PACE)
    fitted(tab, f)
    asked_for = asks(CDN, "scripts, styles") + asks(IMAGES, "images")
    yield "blocked", tab, [left + ["Network (3)", "Notes"], asked_for, [], frame], ["blocked"] * 2, "iframe"
    tab.evaluate("document.querySelector('iframe').focus(); said.length = 0; 1")
    press(tab, "#network")
    fitted(tab, f)
    yield "network", tab, [left + ["Network (3)", "Notes"], asked_for, ["Network", "Allowed", ALLOWED, "Remove", "Blocked", CDN, "Allow", IMAGES, "Allow"], frame], [], "network"
    approved()
    put("notes.jsonl", note_rows(3, BOARD))
    tab, f = opened()
    opens(tab, f)
    press(tab, ON_PAGE)
    fitted(tab, f)
    yield "notes", tab, [left + ["Notes (3)"], [], ["Notes on this page"] + ["Not checked"] * (w == 375) + ["Note on this page", "textarea", "Send note", "Cancel", "dismissed", "addressed", "Reply: done", "open"], frame], [], "textarea"
    forget("notes.jsonl")
    tab, f = opened()
    f.evaluate("location.href = 'https://out.example/'; 1")
    tab.wait("!document.querySelector('iframe')")
    yield "stopped", tab, [left + ["Notes"], [], [], [text for _, text in STOPPED]], [], "p"
    url, key, port = there
    tab, f = opened(url + "/" + BOARD + key)
    tab.wait(STRIPS + ".length", 3)
    fitted(tab, f)
    yield "LAN", tab, [left[:2], [leave_it(port, BOARD)], [], frame], ["lan"], "iframe"

def walk(b):
    shots = os.path.join(os.path.dirname(ROOT), "shots")
    os.makedirs(shots)
    walked, violations, order, others, dragged = {}, {}, {}, {}, {}
    with away() as there:
        for w in (1280, 375):
            for name, tab, seen, said, focus in states(b, w, there):
                at = "%s at %d px" % (name, w)
                eq("placed as the contract says: " + at, lambda: [tab.evaluate(SEEN), tab.evaluate(ASTRAY)], [seen, []])
                eq("strips announce once and never take focus: " + at, lambda: tab.evaluate("[said, [...document.querySelectorAll('[aria-live]')].map((e) => e.id + ' ' + e.ariaLive), %s]" % FOCUS), [said, ["strips polite"], focus])
                shot = os.path.join(shots, "%s-%d.png" % (name, w))
                with open(shot, "wb") as fh:
                    fh.write(base64.b64decode(b.chrome.call("Page.captureScreenshot", {}, tab.sid)["data"]))
                with open(shot, "rb") as fh:
                    walked[at] = list(struct.unpack(">II", fh.read(24)[16:]))
                tab.evaluate(AXE + "; 1", 20)
                violations[at] = tab.evaluate(AXE_RUN, 30)
                others[at] = tab.evaluate(OTHERS)
                dragged[at] = tab.evaluate(DRAGGED) + sorted(one for one in listens(b, tab) if one[0].startswith(("drag", "drop")) or PRESSES.fullmatch(one[0]) and one[1] not in ("button", "a", "textarea") and one != ("keydown", "window"))
                want = tab.evaluate(STOPS + ".map(%s)" % STOP)
                order[at] = [reached(tab), want]
    eq("7 states walked at 375 and 1280, with a screenshot of each", walked, {"%s at %d px" % (name, w): [w, 800] for w in (1280, 375) for name in ("empty", "pick", "blocked", "network", "notes", "stopped", "LAN")})
    eq("0 axe violations in 7 states at 375 and 1280", {at: found for at, found in violations.items() if found}, {})
    eq("Tab order equals DOM order, in every state", {at: both for at, both in order.items() if both[0] != both[1] or len(both[0]) < 2}, {})
    eq("each stop is a button, a link, a textarea, the frame or the pick's list, none with a positive tabindex", {at: found for at, found in others.items() if found}, {"pick at %d px" % w: ["ul: Changes"] for w in (1280, 375)})
    eq("nothing draggable, and nothing else takes a press", {at: found for at, found in dragged.items() if found}, {})

def ordered(b):
    forget()
    approved()
    tab = quick(b, visit(b, server.url + "/" + BOARD, source=SAID))
    f = tab.frame()
    blocked(f, CDN)
    tab.wait(ASKS + ".length", 4)
    says(f, 1)
    tab.wait(THERE, 4)
    tab.evaluate("window.deaf = true")
    three = ["page", "pick", "blocked"]
    eq("three strips in contract order: not answering, pick to send, blocked host, whichever came first", lambda: becomes(tab, KINDS_SHOWN, three), three)
    tab.evaluate("document.querySelector('iframe').focus(); 1")
    f.evaluate("parent." + POST % json.dumps({"dk": 1, "t": "link", "href": "https://out.example/"}) + "parent." + POST % "{ dk: 1, t: 'store', items: [['big', 'x'.repeat(300 * 1024)]] }" + "1")
    tab.wait("!!document.querySelector('%s')" % LINK, 4)
    server.stop()
    every = ["page", "server", "storage", "pick", "blocked", "link"]
    eq("and all six, each said once, the focus still in the page", lambda: [becomes(tab, KINDS_SHOWN, every), tab.evaluate("[said.sort(), %s]" % FOCUS)], [every, [sorted(every), "iframe"]])
    server.start()
    forget()

def tabs(b):
    ring = "[%s, getComputedStyle(document.querySelector('iframe')).outlineStyle]" % FOCUS
    tab = visit(b, server.url + "/" + DECK)
    tab.frame()
    tab.wait(FOCUS + " === 'iframe'")
    on_load = tab.evaluate(ring)
    tab.evaluate("document.querySelector('#notes').focus(); 1")
    tab.key("Tab")
    eq("Tab from the last control reaches a page with nothing to focus, with a ring there was none of on load", lambda: [on_load, tab.evaluate(ring)], [["iframe", "none"], ["iframe", "solid"]])
    tab.key("ArrowRight")
    eq("whose keys then work", lambda: tab.wait("location.hash === '#/2'"), True)
    tab.key("Shift+Tab")
    eq("Shift+Tab goes back, and the ring away", lambda: tab.evaluate(ring), ["notes", "none"])
    tab = visit(b, server.url + "/" + NOTED)
    f = tab.frame()
    tab.wait(FOCUS + " === 'iframe'")
    tab.evaluate("document.querySelector('#notes').focus(); 1")
    for _ in range(2):
        tab.key("Tab")
    eq("in a page with controls the next Tab is on the first of them", lambda: [tab.evaluate(FOCUS), f.evaluate(FOCUS)], ["iframe", "one"])

def crowds(b):
    put("notes.jsonl", note_rows(40, NOTED))
    tab = visit(b, server.url + "/" + NOTED, 375)
    tab.frame()
    press(tab, "#notes")
    tab.wait("document.querySelectorAll('#drawer li').length === 20")
    tab.hover(*tab.at("#drawer"))
    x, y = tab.at("#drawer")
    b.chrome.call("Input.dispatchMouseEvent", {"type": "mouseWheel", "x": x, "y": y, "deltaX": 0, "deltaY": 300}, tab.sid)
    eq("drawer scrolls at 60vh, inside itself, with 40 notes at 375 px", lambda: [tab.evaluate(COUNT), tab.wait("document.querySelector('#drawer').scrollTop > 100"), tab.evaluate("[document.querySelector('#drawer').getBoundingClientRect().height, scrollY, document.documentElement.scrollHeight]")], ["Notes (40)", True, [480, 0, 800]])
    forget("notes.jsonl")
    approved()
    tab = visit(b, server.url + "/" + OTHER, 375)
    f = tab.frame()
    f.evaluate("for (let n = 0; n < 12; n++) parent.postMessage({ dk: 1, t: 'blocked', host: 'h' + n + '.example', kind: 'script' }, '*'); 1")
    tab.wait("!!document.querySelector('#strips [data-kind=more]')", 4)
    high = []
    for _ in range(3):
        high.append(tab.evaluate("[document.querySelector('iframe').getBoundingClientRect().height, document.querySelector('#drawer').hidden]"))
        press(tab, "#network", "Enter")
    eq("with 12 blocked hosts at 375 px the page keeps a fifth of the window, before their list is open, while it is and after", high, [[160, True], [160, False], [160, True]])

def lan(b):
    if not LAN:
        print("SKIP: no non-loopback address — the LAN viewer ran at a faked peer address only")
    with away() as (url, key, port):
        tab = visit(b, url + "/" + quote(OWN + "index.html") + key)
        tab.wait("!!document.querySelector('iframe')")
        eq("on the LAN address the page shows, and its own-folder files load", lambda: [(f := tab.frame()).evaluate(H1), f.evaluate(LOADED)], ["fixture", OWN_FILES])
        words = "document.body.innerText.split('\\n').filter(Boolean)"
        want = ["Gallery", "fixture", leave_it(port, OWN + "index.html")]
        eq("under Gallery and the title alone, with where to leave notes, picks or approvals", lambda: becomes(tab, words, want), want)
        tab = visit(b, url + "/" + BOARD)
        f = tab.frame()
        want[2] = leave_it(port, BOARD)
        tab.wait(STRIPS + ".length")
        says(f, 1, {"all": {"space": 12}})
        blocked(f, CDN)
        for how in ("{ dk: 1, t: 'key', name: 'notes' }", ANCHOR, ANCHOR.replace("'anchor'", "'context'").replace("anchor: {", "x: {", 1)):
            f.evaluate("parent." + POST % how + "1")
        for at in ("iframe", "#bar a"):
            tab.evaluate("document.querySelector('%s').focus(); 1" % at)
            tab.key("Alt+n")
        eq("LAN viewer has no composer, Send pick or Allow", lambda: [time.sleep(PACE), tab.evaluate("[%s, document.querySelectorAll('textarea, section, ul, [role=group], [data-consent], [data-host]').length, %s]" % (words, STOPS + ".map(%s)" % STOP))][1], [want, 0, ["a: Gallery", "iframe: "]])

SECRET = "secret typed into the note"
LEAKS = {}  # how many characters of it a looping page got, by the case

def point(tab, at, press=True, source="mouse"):
    """The pointer at (x, y) as the system moves it there, and pressed: the viewer is told of it entering and leaving its frame, as it is not of DevTools' own mouse."""
    x, y = at
    moves = [{"name": "pointerMove", "x": x, "y": y}] if source == "mouse" else []
    presses = [{"name": "pointerDown", "x": x, "y": y}, {"name": "pause", "duration": 60}, {"name": "pointerUp"}] if press else []
    tab.evaluate("new Promise((done) => chrome.gpuBenchmarking.pointerActionSequence(%s, done))" % json.dumps([{"source": source, "actions": moves + presses}]), 10)

def steals(b):
    forget()
    forget("notes.jsonl")
    field, thief = '<input id="i">', '<input id="i"><script>setInterval(() => document.querySelector("#i").focus(), %d)</script>'
    page("artifacts/thief.html", body=thief % 100)
    page("artifacts/fast.html", body=thief % 5)
    page("boards/thief.html", body=thief % 100)
    page("artifacts/field.html", body=field)
    def composing(name, of_page=True):
        """A note begun on this page, or on an element of it, by a pointer that then rests over the composer, or over the element."""
        tab = visit(b, server.url + "/" + name)
        f = tab.frame()
        point(tab, f.at("h1"))
        point(tab, tab.at("#notes"))
        fitted(tab, f)
        point(tab, tab.at(ON_PAGE) if of_page else f.at("h1"))
        tab.wait(WRITING, 4)
        if of_page:
            point(tab, tab.at(TEXT))
        time.sleep(0.3)
        return tab, f
    def kept(name, of_page=True):
        """How many characters typed at 60 ms a key stay in the composer."""
        tab, f = composing(name, of_page)
        for c in SECRET:
            tab.key(c)
            time.sleep(0.06)
        LEAKS["%s, a note on %s" % (name, "the page" if of_page else "an element")] = len(f.evaluate("document.querySelector('#i').value"))
        return len(tab.evaluate(VALUE))
    eq("of 26 characters typed in the composer at least 23 stay there, with a page that takes the focus every 100 ms", lambda: kept("artifacts/thief.html") >= 23, True)
    eq("also where the pointer rests over the element the note is on", lambda: kept("artifacts/thief.html", False) >= 23, True)
    eq("and at least 13 with one that does every 5 ms", lambda: kept("artifacts/fast.html") >= 13, True)
    print("NOTE: characters of 26 that a looping page got: %s" % json.dumps(LEAKS))

    tab = visit(b, server.url + "/boards/thief.html")
    f = tab.frame()
    point(tab, f.at("h1"))  # a page in which nothing was pressed takes no focus
    offered(tab, f, 1)
    point(tab, tab.at("#notes"), press=False)
    tab.evaluate("document.querySelector('#notes').focus(); 1")
    tab.key("Tab")
    tab.evaluate("window.on = []; setInterval(() => on.push(document.activeElement.textContent === 'Send pick'), 10); 1")
    eq("with a keyboard Send pick keeps the focus from it", lambda: [time.sleep(1), tab.evaluate("on.filter(Boolean).length > 0.8 * on.length")][1], True)
    for _ in range(5):  # one may fall in the moment the page has it
        tab.key("Enter")
        if tab.wait(GONE, 0.5):
            break
    eq("and acts once nothing changed for 600 ms", chosen, [["thief.html", 1, {}, {}]])
    forget()

    take, deaf = "document.querySelector('#i').focus(); 1", "addEventListener('blur', (e) => e.stopImmediatePropagation(), true)"  # in a deaf viewer
    page("boards/field.html", body=field)
    tab = visit(b, server.url + "/boards/field.html", source=deaf)
    f = tab.frame()
    def taken():
        f.evaluate(take)
        return tab.evaluate(FOCUS)
    point(tab, f.at("h1"))
    point(tab, tab.at("#notes"))
    offered(tab, f, 1)
    tab.evaluate("document.querySelector('#notes').focus(); 1")
    tab.key("Tab")
    time.sleep(PACE)
    tab.evaluate("{ const real = setTimeout; window.setTimeout = (fn, ms) => (ms === 16 ? 0 : real(fn, ms)); } new Promise((r) => setTimeout(r, 100))")  # and one that gives nothing back by itself
    was = taken()
    says(f, 2)
    eq("Send pick has the focus back where its strip is drawn anew meanwhile", lambda: [was, tab.wait(HEAD + ".includes('Updated')", 4), tab.evaluate("document.activeElement.textContent")], ["iframe", True, "Send pick"])
    time.sleep(PACE)
    was = taken()
    f.evaluate("parent." + POST % ANCHOR + "1")
    eq("and where a composer is opened", lambda: [was, tab.wait(WRITING, 4), tab.evaluate("document.activeElement.textContent")], ["iframe", True, "Send pick"])
    point(tab, tab.at(TEXT))
    types(tab, "half")
    for _ in range(8):  # all it gives back in 16 ms
        taken()
        f.evaluate("parent." + POST % "{ dk: 1, t: 'key', name: 'escape' }" + "1")
        tab.wait(FOCUS + " === 'textarea'", 1)
    was = taken()
    f = reframed(tab, lambda: page("boards/field.html", title="saved", body=field))
    eq("the composer has it back where the page is framed anew", lambda: [was, time.sleep(0.3), tab.evaluate("[%s, %s]" % (FOCUS, VALUE))][::2], ["iframe", ["textarea", "half"]])
    point(tab, f.at("h1"))
    point(tab, tab.at(TEXT))
    was = taken()
    f.evaluate("location.href = 'https://out.example/'; 1")
    eq("and where the page leaves", lambda: [was, tab.wait("!document.querySelector('iframe')"), time.sleep(0.3), tab.evaluate("[%s, %s]" % (FOCUS, VALUE))][::3], ["iframe", ["textarea", "half"]])
    forget()

    tab = visit(b, server.url + "/artifacts/field.html")
    f = tab.frame()
    def at_notes():
        tab.evaluate("document.querySelector('#notes').focus(); 1")
        time.sleep(0.6)  # past what counts as typing
    point(tab, f.at("h1"))
    point(tab, tab.at("#title"), press=False)
    at_notes()
    f.evaluate(take)
    eq("a page's focus() that takes it from a viewer control is undone", lambda: [time.sleep(0.3), tab.evaluate(FOCUS)][1], "notes")
    at_notes()
    point(tab, f.at("#i"))
    eq("a click in the page moves the focus there, and it stays", lambda: [time.sleep(0.3), tab.evaluate(FOCUS), f.evaluate(FOCUS)][1:], ["iframe", "i"])
    at_notes()
    tab.evaluate("document.querySelector('iframe').focus(); 1")
    eq("nor is a focus the viewer gives its frame undone", lambda: [time.sleep(0.3), tab.evaluate(FOCUS)][1], "iframe")
    tab.evaluate("document.querySelector('#bar a').focus(); 1")
    for _ in range(2):
        tab.key("Shift+Tab")
    eq("nor one Shift+Tab takes there, around the first control", lambda: [time.sleep(0.3), tab.evaluate(FOCUS), f.evaluate(FOCUS)][1:], ["iframe", "i"])
    tab.evaluate("document.querySelector('#notes').focus(); 1")
    tab.key("Escape")
    f.evaluate(take)
    eq("with the pointer over the page, and a key pressed in the viewer less than 500 ms ago, a page's focus() is undone", lambda: [time.sleep(0.2), tab.evaluate(FOCUS)][1], "notes")
    for _ in range(2):
        point(tab, tab.at("#notes"), source="touch")
        time.sleep(0.2)
    time.sleep(0.6)
    point(tab, f.at("#i"), source="touch")
    eq("a finger's tap in the page after one in the viewer moves the focus there", lambda: [time.sleep(0.3), tab.evaluate(FOCUS)][1], "iframe")

    point(tab, tab.at("#notes"))
    time.sleep(0.6)
    f.evaluate("{ const c = new MessageChannel(), from = performance.now(); let said = 0; c.port1.onmessage = () => { %s; if (performance.now() > from + 20 * said && ++said) parent.%s if (said < 30) c.port2.postMessage(0); }; c.port2.postMessage(0); } 1" % (take[:-3], POST % "{ dk: 1, t: 'key', name: 'escape' }"))
    eq("a key that a page taking the focus without a pause says was pressed there does nothing", lambda: [time.sleep(1), tab.evaluate("[%s, %s]" % (DRAWN, FOCUS))][1], [True, "notes"])

    f.evaluate("document.open(); document.write('<!doctype html><h1>undone</h1><input id=\"i\">'); document.close(); 1")
    point(tab, tab.at(ON_PAGE))
    tab.wait(WRITING)
    types(tab, "half")
    time.sleep(0.6)
    point(tab, f.at("#i"))
    tab.key("x")
    eq("a click in a page that takes its clicks for itself moves the focus there with the composer open, and what is typed next", lambda: [time.sleep(0.3), tab.evaluate("[%s, %s]" % (FOCUS, VALUE)), f.evaluate("document.querySelector('#i').value")][1:], [["iframe", "half"], "x"])

    tab = visit(b, server.url + "/artifacts/field.html", source=deaf)
    f = tab.frame()
    point(tab, f.at("h1"))
    point(tab, tab.at("#title"), press=False)
    time.sleep(1.2)  # past the last strips drawn for this load
    at_notes()
    f.evaluate(take)
    eq("one the viewer is not told of, as while its window has no focus, is given back too", lambda: [time.sleep(0.3), tab.evaluate(FOCUS)][1], "notes")

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
    again = Server(ROOT, older.server_port)
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
    loads()
    tab = visit(b, url + "/" + NET)
    tab.frame()
    line = [leave_it(srv.server_port, NET)]
    eq("and no host to approve: no strip of one, no Network", lambda: [time.sleep(1.5), tab.evaluate("[%s, %s]" % (STRIPS, NETWORK))][1], [line, None])
    tab = visit(b, url + "/" + NOTED)
    tab.click(*tab.frame().at("#far"))
    eq("a page-to-page link opens in the viewer there too", lambda: [tab.wait("document.body.dataset.page === 'decks/old.htm'"), tab.evaluate("location.href")], [True, url + "/decks/old.htm#/2"])
    tab = visit(b, url + "/" + BOARD)
    says(tab.frame(), 1, {"all": {"space": 12}})
    line = [leave_it(srv.server_port, BOARD)]
    eq("and has no pick to send", lambda: [time.sleep(0.4), tab.evaluate("[%s, %s]" % (STRIPS, KEPT))][1], [line, []])
    del asked[:]
    tab.wait(FOCUS + " === 'iframe'")
    for at in ("iframe", "#bar a"):
        tab.evaluate("document.querySelector('%s').focus(); 1" % at)
        tab.key("Alt+n")
    tab.frame().evaluate("parent." + POST % ANCHOR + "1")
    eq("and no notes: no list, no composer, nothing asked of the server", lambda: [time.sleep(0.4), tab.evaluate("[%s, document.querySelector('#drawer').childElementCount]" % DRAWN), [p for p in asked if p.startswith("/_notes")]][1:], [[False, 0], []])
    srv.shutdown()

LAN = own_address()
if LAN:
    browser_lib.check.NO_NETWORK[:] = [flag + ", EXCLUDE " + LAN if "resolver" in flag else flag for flag in browser_lib.check.NO_NETWORK] + ["--proxy-bypass-list=" + LAN]  # the browser's only way to it
def run(b, *parts):
    for part in parts:
        try:
            part(b)
        except Exception as exc:
            print("FAIL: %s stopped: %r" % (part.__name__, exc))
            bad.append(part.__name__)

server = Server(ROOT)
server.start()
try:
    with browser_lib.browser(1500) as b:
        run(b, kinds, files, bar, reload, bridge, place, copies, prints, stops, hangs, keeps, full, drops, gone, lost, picks, values, looks, once, consent, notes, drafts, sends, lists, approves, refuses, panels, links, guards, walk, ordered, tabs, crowds, lan, gallery, worker, far)
    browser_lib.check.NO_NETWORK.append("--enable-gpu-benchmarking")  # point()'s
    with browser_lib.browser(300) as b:
        run(b, steals)
finally:
    server.stop()
sys.exit(1 if bad else 0)
PY
[ "$rc" != 4 ] || [ "${DESIGN_KIT_REQUIRE_BROWSER:-}" = 1 ] || { echo "PASS viewer.test.sh (no browser: nothing ran)"; exit 0; }
[ "$rc" = 0 ] || { echo "FAIL: viewer.test.sh (exit $rc)"; exit 1; }
echo "PASS viewer.test.sh"
