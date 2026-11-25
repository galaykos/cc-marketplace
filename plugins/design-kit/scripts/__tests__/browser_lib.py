"""browser_lib.py - what this folder's browser harnesses share: a headless Chrome, started and read by render-check.py's Chrome (DevTools pipe, sandbox on, NO_NETWORK flags), with real mouse and keys; a person's visit; serve.py in a process of its own; eq(), and the names of what failed in bad.
Misses: browsers outside Chromium; a child frame Chrome keeps in its parent's process (frame() finds only one with a process of its own, which a sandboxed frame gets); DevTools' mouse tells a page nothing of the pointer over its frame.
"""
import base64
import contextlib
import importlib.util
import os
import socket
import subprocess
import sys
import time
import zlib

SCRIPTS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_spec = importlib.util.spec_from_file_location("dkcheck", os.path.join(SCRIPTS, "render-check.py"))
check = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(check)

MODS = {"Alt": 1, "Control": 2, "Meta": 4, "Shift": 8}
KEYS = {"Tab": 9, "Enter": 13, "Escape": 27, "PageUp": 33, "PageDown": 34, "End": 35, "Home": 36, "ArrowLeft": 37, "ArrowUp": 38, "ArrowRight": 39, "ArrowDown": 40}
UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36"
# a TrueType font of one glyph
FONT = zlib.decompress(base64.b64decode("eNqNj71KA0EUhc/MbDTKYiSg9RYphYBFsLBwEYNYJKBoJegQY1LsmqArxM5HsPAJUltaWARJaeFDWKawjK3rmZk1ERXxLnvnfvdvzkAAmMc1FIL6Xnn14GV/iZk7/seNWHfhIwGET15pRVen6jF3T14jl9pNfaJnN/vkQ3KlzURuWZTJt7YeJz01YgTxQJePOg1t8uQhTz/WvS48fhDP5OBMx025XSyQX8k73c5FQl00ae4LoMRY3CCH/5j4CrV6bQsbCBGqIOUuFeDps0eM5cBud1PKZn2qMhmjznCYps6nw2zzdJYKBc0Q8O5bvYNJT6bjqLD+xntHv0p1CvKQ091Op9lovfg2Ik3FVSdWsl0yewF+zMC+p2Lq3hyrkuxiiQU3x9hjtJjFM4yLqGIXTbRwiQga5+SqnfzTPgDQQD77"))
TRY = "const t = (f) => { try { f(); return 'ok'; } catch (e) { return e instanceof DOMException ? e.name : String(e); } };"
# 120 writes a second to one key, then what is put in
WRITES = "localStorage.clear(); new Promise((done) => { let n = 0; const from = performance.now(), tick = () => { localStorage.took = performance.now() - from; localStorage.setItem('count', String(++n)); if (n < 120) setTimeout(tick, 8); else { %s; done(1); } }; tick(); })"
SERVE = "import importlib.util, sys; s = importlib.util.spec_from_file_location('dkserve', sys.argv[1]); m = importlib.util.module_from_spec(s); s.loader.exec_module(m); exec(sys.argv[2]); sys.exit(m.main(sys.argv[3:]))"
bad = []
CENTRE = "(() => { const e = document.querySelector(%s); if (!e) return null; const r = e.getBoundingClientRect(); return [r.left + r.width / 2, r.top + r.height / 2, r.left, r.top]; })()"


def _bits(mods):
    return sum(MODS[m] for m in mods.split("+") if m)


def eq(name, fn, want):
    """Prints ok, or FAIL and what came instead, for what fn is or returns; a FAIL's name goes to bad."""
    try:
        got = fn() if callable(fn) else fn
    except Exception as exc:
        got = repr(exc)
    print("ok: " + name if got == want else "FAIL: %s: got %.900s, want %.400s" % (name, check.json.dumps(got, default=sorted), check.json.dumps(want, default=sorted)))
    if got != want:
        bad.append(name)


class Server:
    """serve.py on root, at its own port, in a process of its own: what it signed dies with it."""

    def __init__(self, root, port=0):
        with socket.socket() as s:
            s.bind(("127.0.0.1", 0))
            self.port = port or s.getsockname()[1]
        self.root, self.url, self.proc = root, "http://127.0.0.1:%d" % self.port, None

    def start(self, *more, root=None, first=""):
        """Until it answers; first is Python to run before it serves, where serve.py is m."""
        self.proc = subprocess.Popen([sys.executable, "-c", SERVE, os.path.join(SCRIPTS, "serve.py"), first, "--docroot", root or self.root, "--port", str(self.port), *more],
                                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=dict(os.environ, DESIGN_KIT_IDLE_MINUTES="0"))
        for _ in range(100):
            try:
                return socket.create_connection(("127.0.0.1", self.port), 1).close()
            except OSError:
                time.sleep(0.05)
        self.stop()
        raise OSError("serve.py did not start on port %d" % self.port)

    def stop(self):
        if self.proc:
            self.proc.kill()
            self.proc.wait()


class _Driver(check.Chrome):
    """render-check.py's Chrome, keeping each session's child frames and what pages began to download."""

    def __init__(self, exe, deadline):
        self.children, self.downloads = {}, []
        super().__init__(exe, deadline)

    def keep(self, e):
        name, p = e["method"], e.get("params") or {}
        of = self.children.setdefault(e.get("sessionId"), [])
        if name == "Target.attachedToTarget" and p["targetInfo"]["type"] == "iframe":
            of.append(p["sessionId"])
        elif name == "Target.detachedFromTarget" and p["sessionId"] in of:
            of.remove(p["sessionId"])
        elif name == "Browser.downloadWillBegin":
            self.downloads.append(p["suggestedFilename"])
        else:
            super().keep(e)


class Document:
    """One document: the tab's, or a frame's."""

    def __init__(self, chrome, sid):
        self.chrome, self.sid = chrome, sid

    def evaluate(self, expression, seconds=5):
        """The value of expression (a promise is awaited); RuntimeError with the page's own words when it throws."""
        r = self.chrome.call("Runtime.evaluate", {"expression": expression, "awaitPromise": True, "returnByValue": True}, self.sid, seconds)
        if r.get("exceptionDetails"):
            raise RuntimeError((r["exceptionDetails"].get("exception") or {}).get("description") or r["exceptionDetails"].get("text", "exception"))
        return r.get("result", {}).get("value")

    def wait(self, expression, seconds=5):
        """expression's value once it is truthy, else its last value when the seconds run out."""
        until = time.monotonic() + seconds
        while True:
            try:
                got = self.evaluate(expression)
            except RuntimeError:  # the document is being replaced
                got = None
            if got or time.monotonic() >= until:
                return got
            time.sleep(0.03)

    def at(self, selector):
        """(x, y), the centre of an element, in this document's viewport."""
        return tuple(self.evaluate(CENTRE % check.json.dumps(selector))[:2])


class Frame(Document):
    """A child frame with a process of its own."""

    def __init__(self, tab, sid):
        super().__init__(tab.chrome, sid)
        self.tab = tab

    def at(self, selector):
        """(x, y), the centre of an element of the frame, in the tab's viewport, where click() and hover() take it."""
        left, top = self.tab.evaluate(CENTRE % '"iframe"')[2:]
        x, y = super().at(selector)
        return left + x, top + y


class Tab(Document):
    """A tab: its own document, its frames, and the user's mouse and keys."""

    def frame(self, seconds=10):
        """The newest child frame, once its document is painted; TimeoutError when none came."""
        until = time.monotonic() + seconds
        while time.monotonic() < until:
            self.evaluate("new Promise((r) => setTimeout(r, 30))")  # lets attach and detach events in
            for sid in self.chrome.children.get(self.sid, [])[-1:]:
                frame = Frame(self, sid)
                try:
                    if frame.evaluate("document.readyState === 'complete'"):
                        frame.evaluate(check.SETTLE_JS)
                        return frame
                except RuntimeError:  # replaced meanwhile
                    pass
        raise TimeoutError("no child frame with a process of its own")

    def hover(self, x, y):
        """Move the mouse to (x, y)."""
        self.chrome.call("Input.dispatchMouseEvent", {"type": "mouseMoved", "x": x, "y": y}, self.sid)

    def click(self, x, y, mods="", button="left"):
        """Move the mouse to (x, y) and click; mods as in key(): "Control", "Control+Shift"."""
        self.hover(x, y)
        for kind in ("mousePressed", "mouseReleased"):
            self.chrome.call("Input.dispatchMouseEvent", {"type": kind, "x": x, "y": y, "button": button, "clickCount": 1, "modifiers": _bits(mods)}, self.sid)

    def key(self, name):
        """Press and release a key where the focus is: "Tab", "n", " ", "Shift+Tab", "Control+p"."""
        mods, _, key = name.rpartition("+")
        bits = _bits(mods)
        code = key if key in KEYS else "Space" if key == " " else ("Key" if key.isalpha() else "Digit") + key.upper()
        text = "\r" if key == "Enter" else key if key not in KEYS and not bits & 7 else ""
        event = {"key": key, "code": code, "windowsVirtualKeyCode": KEYS.get(key) or ord(key.upper()), "modifiers": bits}
        self.chrome.call("Input.dispatchKeyEvent", dict(event, type="keyDown", text=text) if text else dict(event, type="rawKeyDown"), self.sid)
        self.chrome.call("Input.dispatchKeyEvent", dict(event, type="keyUp"), self.sid)


class Browser:
    """The browser: chrome is its DevTools pipe, chrome.downloads the file names pages began to download (all refused)."""

    def __init__(self, chrome):
        self.chrome = chrome

    def page(self, url, w=1280, h=800):
        """A new tab at url, loaded."""
        tid, sid = self.chrome.open(w, h)
        window = self.chrome.call("Browser.getWindowForTarget", {"targetId": tid})["windowId"]
        self.chrome.call("Browser.setWindowBounds", {"windowId": window, "bounds": {"width": w, "height": h + 200}})  # an older Chrome drops a frame's mouse events outside the real window
        self.chrome.call("Target.setAutoAttach", {"autoAttach": True, "waitForDebuggerOnStart": False, "flatten": True}, sid)
        self.chrome.call("Page.navigate", {"url": url}, sid)
        if not self.chrome.wait_for(sid, "Page.loadEventFired", 10):
            raise TimeoutError("%s did not finish loading" % url)
        return Tab(self.chrome, sid)


def tabs(b):
    """The target ids of the open tabs."""
    return {t["targetId"] for t in b.chrome.call("Target.getTargets")["targetInfos"] if t["type"] == "page"}


def close(b, ids):
    for one in ids:
        try:
            b.chrome.call("Target.closeTarget", {"targetId": one})
        except RuntimeError:  # on its way out already
            pass


def visit(b, url, w=1280, h=800, source=""):
    """The one open tab, at url, with a person's user agent: a headless one is sent to the raw page, and each viewer left open keeps one of the six connections Chrome gives a host; source before any script of a document."""
    old = tabs(b)
    tab = b.page("about:blank", w, h)
    close(b, old)
    b.chrome.call("Emulation.setUserAgentOverride", {"userAgent": UA}, tab.sid)
    b.chrome.call("Page.addScriptToEvaluateOnNewDocument", {"source": source}, tab.sid)
    b.chrome.call("Page.navigate", {"url": url}, tab.sid)
    tab.wait("location.href !== 'about:blank' && document.readyState === 'complete'", 10)
    return tab


def _no_browser(why):
    print("%s: %s" % ("FAIL" if os.environ.get("DESIGN_KIT_REQUIRE_BROWSER") == "1" else "SKIP", why))
    sys.exit(4)


@contextlib.contextmanager
def browser(seconds=120):
    """A Browser for at most that long; where none starts, prints FAIL under DESIGN_KIT_REQUIRE_BROWSER=1, else SKIP, and exits 4."""
    exe = check.find_browser()[0]
    if not exe:
        _no_browser(check.NO_BROWSER)
    try:
        chrome = _Driver(exe, time.monotonic() + seconds)
    except OSError as exc:
        _no_browser("the browser did not start: %s" % exc)
    try:
        try:
            chrome.call("Browser.setDownloadBehavior", {"behavior": "deny", "eventsEnabled": True})
        except (OSError, EOFError, RuntimeError, TimeoutError) as exc:
            _no_browser("the browser did not start: %s" % exc)
        yield Browser(chrome)
    finally:
        chrome.close()
