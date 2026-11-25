"""browser_lib.py - a headless Chrome for this folder's harnesses, started and read by render-check.py's Chrome (DevTools pipe, sandbox on, NO_NETWORK flags), with real mouse and keys.
Misses: browsers outside Chromium; a child frame Chrome keeps in its parent's process (frame() finds only one with a process of its own, which a sandboxed frame gets).
"""
import contextlib
import importlib.util
import os
import sys
import time

SCRIPTS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_spec = importlib.util.spec_from_file_location("dkcheck", os.path.join(SCRIPTS, "render-check.py"))
check = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(check)

MODS = {"Alt": 1, "Control": 2, "Meta": 4, "Shift": 8}
KEYS = {"Tab": 9, "Enter": 13, "Escape": 27, "PageUp": 33, "PageDown": 34, "End": 35, "Home": 36, "ArrowLeft": 37, "ArrowUp": 38, "ArrowRight": 39, "ArrowDown": 40}
CENTRE = "(() => { const e = document.querySelector(%s); if (!e) return null; const r = e.getBoundingClientRect(); return [r.left + r.width / 2, r.top + r.height / 2, r.left, r.top]; })()"


def _bits(mods):
    return sum(MODS[m] for m in mods.split("+") if m)


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
