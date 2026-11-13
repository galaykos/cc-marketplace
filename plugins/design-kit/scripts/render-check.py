#!/usr/bin/env python3
"""render-check.py — `dk check <page> [--widths 375,768,1280]`: the served page in a headless Chromium at each width (a board: each artboard at its own size); every line printed is one escaped JSON object: a finding, a note (change, not checked, skipped, dropped, capped), then the summary; exit 0 none, 1 findings, 2 bad arguments, 4 not checked.
Drives the browser board-export.sh finds over the DevTools pipe (python3 stdlib), since the CLI screenshot never lays out below 500 px; axe-core and check.js run in an isolated world page script cannot reach (E1-E4 come back over DevTools), the browser's console, exception and network events add E1, E6 compares the widest shot with the last check's (Pillow for how much and where).
Misses: what check.js misses; page script still runs and can change what is measured, so a clean check is not proof; nothing leaves the machine (no proxy, DNS, download or WebRTC UDP), so a page that needs the network is checked without it; loopback stays reachable; E6 sees the widest width only.
Why, limits, history: rationale/derivations/plugin-design-kit.md § plugins/design-kit/scripts/render-check.py
"""
import argparse
import base64
import hashlib
import importlib.util
import json
import os
import pathlib
import re
import select
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from urllib.parse import quote, urlsplit

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("dkserve", os.path.join(HERE, "serve.py"))
m = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(m)

TOTAL_S = 60  # the whole run, every width: one deadline every read honours
LOAD_S = 10  # one page's load event
CHECK_S = 15  # check.js, from the load event to its answer
SHOT_MAX_H = 6000
PIXEL = 10  # a pixel counts as changed when a channel moves by more than this (dk review's threshold)
# A dead proxy for everything but loopback (it wins over any proxy in the environment), no name resolution, no WebRTC UDP that skips the proxy.
NO_NETWORK = ["--proxy-server=http://127.0.0.1:9", "--host-resolver-rules=MAP * ~NOTFOUND, EXCLUDE 127.0.0.1",
              "--webrtc-ip-handling-policy=disable_non_proxied_udp", "--force-webrtc-ip-handling-policy=disable_non_proxied_udp"]
OURS = ("/favicon.ico",)
ORDER = {"E1": 0, "E2": 1, "E3": 2, "E4": 3}
CHECK_ID = re.compile(r"E[1-4](\.[a-z][a-z0-9-]{0,40})?")
WORLD = "design-kit-check"  # the isolated world check.js and axe-core run in
EVENT_CAP = 400  # console, exception, log and network events kept per page; the rest are counted
PER_ID = 10  # browser-event findings kept per id
with open(os.path.join(HERE, "check.js"), encoding="utf-8") as _fh:
    CHECK_JS = _fh.read()
AXE_PATH = os.path.join(os.path.dirname(HERE), "vendor", "axe-core", "axe.min.js")
SETTLE_JS = """(async () => { if (document.fonts) await document.fonts.ready;
  await new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r))); return true; })()"""
HEIGHT_JS = "Math.max(document.documentElement.scrollHeight, document.body ? document.body.scrollHeight : 0)"


def die(msg, rc):
    print("dk check: " + msg, file=sys.stderr)
    sys.exit(rc)


def note(kind, at, text):
    return {"note": kind, "at": at, "text": str(text)[:400]}


def resolve(docroot, page):
    """(real path, docroot-relative path) of a servable page under the docroot, from a path as typed, a docroot-relative one or a preview URL."""
    root = os.path.realpath(docroot)
    tries = []
    if re.match(r"https?://", page):
        tries.append(os.path.join(root, *m._parts(urlsplit(page).path)))
    else:
        tries += [page, os.path.join(docroot, page)] if not os.path.isabs(page) else [page]
    for t in tries:
        real = os.path.realpath(t)
        if os.path.isfile(real) and (real + os.sep).startswith(root + os.sep):
            rel = os.path.relpath(real, root).replace(os.sep, "/")
            if not real.lower().endswith(m.PAGE_EXT):
                die("%s is not an .html page" % page, 2)
            if not m._servable(rel.split("/")):
                die("%s is never served (a dot path, auth/ or a state file), so it cannot be checked" % page, 2)
            return real, rel
    die("no page %s under %s" % (page, docroot), 2)


def widths_of(text):
    try:
        ws = [int(w) for w in text.split(",") if w.strip()]
    except ValueError:
        ws = []
    if not 1 <= len(ws) <= 6 or any(not 240 <= w <= 3840 for w in ws):
        die("--widths takes 1 to 6 comma-separated widths from 240 to 3840 px (got %s)" % text, 2)
    return list(dict.fromkeys(ws))


def height_for(w):
    return 812 if w <= 480 else 1024 if w <= 1024 else 800


class Chrome:
    """One headless browser on a DevTools pipe: Chrome reads commands on fd 3 and writes replies on fd 4, each JSON ending in NUL."""

    def __init__(self, exe, deadline):
        self.deadline = deadline  # absolute: no read waits past it
        self.answered = False  # the browser answered a command: a later failure is not a sandbox that never started
        self.profile = tempfile.mkdtemp(prefix="dk-check-")
        try:
            cmd_r, self.cmd_w = os.pipe()
            self.out_r, out_w = os.pipe()

            def wire():
                a, b = os.dup(cmd_r), os.dup(out_w)
                os.dup2(a, 3)
                os.dup2(b, 4)

            # The sandbox stays on, as for dk notes --shot: off only as root, where Chrome refuses it, or on DESIGN_KIT_BROWSER_NO_SANDBOX=1.
            sandbox = []
            if os.geteuid() == 0 or os.environ.get("DESIGN_KIT_BROWSER_NO_SANDBOX") == "1":
                sandbox = ["--no-sandbox"]
                print("dk check: the browser's sandbox is off (%s)" % ("running as root" if os.geteuid() == 0 else "DESIGN_KIT_BROWSER_NO_SANDBOX=1"),
                      file=sys.stderr)
            self.proc = subprocess.Popen(
                [exe, "--headless=new", "--disable-gpu", *sandbox, "--hide-scrollbars", "--no-first-run", "--no-default-browser-check",
                 "--remote-debugging-pipe", "--user-data-dir=" + self.profile, *NO_NETWORK, "about:blank"],
                stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                preexec_fn=wire, close_fds=False, start_new_session=True)
        except BaseException:
            shutil.rmtree(self.profile, ignore_errors=True)
            raise
        os.close(cmd_r)
        os.close(out_w)
        self.buf, self.seq, self.events, self.kept, self.lost, self.urls = b"", 0, [], {}, {}, {}

    def read(self, deadline):
        while b"\0" not in self.buf:
            left = deadline - time.monotonic()
            if left <= 0 or not select.select([self.out_r], [], [], left)[0]:
                raise TimeoutError("the %d s limit ran out" % TOTAL_S if time.monotonic() >= self.deadline else "no answer from the browser in time")
            chunk = os.read(self.out_r, 1 << 16)
            if not chunk:
                raise EOFError("the browser exited")
            self.buf += chunk
        raw, self.buf = self.buf.split(b"\0", 1)
        msg = json.loads(raw)
        if msg.get("method") == "Page.javascriptDialogOpening":
            # alert(), confirm() and prompt() block the page until answered: accept, as a user clicking OK would
            self.send("Page.handleJavaScriptDialog", {"accept": True}, msg.get("sessionId"))
        return msg

    def send(self, method, params=None, session=None):
        self.seq += 1
        msg = {"id": self.seq, "method": method, "params": params or {}}
        if session:
            msg["sessionId"] = session
        data = json.dumps(msg).encode() + b"\0"
        while data:
            data = data[os.write(self.cmd_w, data):]
        return self.seq

    def keep(self, e):
        """Store the events E1 reads; past EVENT_CAP a page's are only counted, so a page logging in a loop cannot fill memory."""
        sid, name, p = e.get("sessionId"), e["method"], e.get("params") or {}
        if name == "Network.requestWillBeSent":
            urls = self.urls.setdefault(sid, {})
            if len(urls) < 5000:
                urls[p.get("requestId")] = str((p.get("request") or {}).get("url", ""))
            return
        wanted = (name == "Page.loadEventFired" or name in ("Network.loadingFailed", "Runtime.exceptionThrown")
                  or (name == "Network.responseReceived" and isinstance((p.get("response") or {}).get("status"), int) and p["response"]["status"] >= 400)
                  or (name == "Runtime.consoleAPICalled" and p.get("type") in ("error", "assert"))
                  or (name == "Log.entryAdded" and (p.get("entry") or {}).get("level") == "error"))
        if not wanted:
            return
        if name != "Page.loadEventFired":
            if self.kept.get(sid, 0) >= EVENT_CAP:
                self.lost[sid] = self.lost.get(sid, 0) + 1
                return
            self.kept[sid] = self.kept.get(sid, 0) + 1
        self.events.append(e)

    def call(self, method, params=None, session=None, timeout=10.0, last=False):
        want = self.send(method, params, session)
        deadline = time.monotonic() + timeout
        if not last:
            deadline = min(deadline, self.deadline)
        while True:
            r = self.read(deadline)
            if r.get("id") == want:
                self.answered = True
                if "error" in r:
                    raise RuntimeError("%s: %s" % (method, r["error"].get("message", r["error"])))
                return r.get("result", {})
            if "method" in r:
                self.keep(r)

    def wait_for(self, session, method, timeout):
        deadline = min(time.monotonic() + timeout, self.deadline)
        seen = 0
        while True:
            for e in self.events[seen:]:
                if e.get("sessionId") == session and e["method"] == method:
                    return True
            seen = len(self.events)
            try:
                r = self.read(deadline)
            except TimeoutError:
                return False
            if "method" in r:
                self.keep(r)

    def evaluate(self, session, expression, timeout, context=None):
        params = {"expression": expression, "awaitPromise": True, "returnByValue": True}
        if context:
            params["contextId"] = context
        r = self.call("Runtime.evaluate", params, session, timeout)
        if r.get("exceptionDetails"):
            raise RuntimeError(r["exceptionDetails"].get("text", "exception"))
        return r.get("result", {}).get("value")

    def open(self, w, h):
        tid = self.call("Target.createTarget", {"url": "about:blank"})["targetId"]
        sid = self.call("Target.attachToTarget", {"targetId": tid, "flatten": True})["sessionId"]
        for domain in ("Page", "Runtime", "Network", "Log"):
            self.call(domain + ".enable", session=sid)
        self.call("Emulation.setDeviceMetricsOverride", {"width": w, "height": h, "deviceScaleFactor": 1, "mobile": False}, sid)
        return tid, sid

    def shoot(self, sid, w, h, path, context=None):
        tall = self.evaluate(sid, HEIGHT_JS, 5, context)
        tall = int(tall) if isinstance(tall, (int, float)) and not isinstance(tall, bool) and 0 < tall < 1e7 else h
        png = self.call("Page.captureScreenshot", {"format": "png", "captureBeyondViewport": True,
                                                   "clip": {"x": 0, "y": 0, "width": w, "height": min(max(h, tall), SHOT_MAX_H), "scale": 1}}, sid, 20)
        with open(path, "wb") as fh:
            fh.write(base64.b64decode(png["data"]))

    def close_target(self, tid, sid):
        try:
            if tid:
                self.call("Target.closeTarget", {"targetId": tid}, timeout=5, last=True)
        except Exception:
            pass
        self.events = [e for e in self.events if e.get("sessionId") != sid]
        self.urls.pop(sid, None)

    def close(self):
        try:
            self.call("Browser.close", timeout=5, last=True)
        except Exception:
            pass
        try:
            self.proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            os.killpg(self.proc.pid, signal.SIGKILL)
            self.proc.wait()
        for fd in (self.cmd_w, self.out_r):
            try:
                os.close(fd)
            except OSError:
                pass
        shutil.rmtree(self.profile, ignore_errors=True)


def short(u, origin):
    return u[len(origin):] if u.startswith(origin + "/") else u


def browser_findings(events, urls, sid, origin, own):
    """E1 from what the browser saw on one page: console errors, uncaught exceptions, failed and refused loads; own is the isolated world's context id."""
    out = []
    for e in events:
        if e.get("sessionId") != sid:
            continue
        name, p = e["method"], e.get("params", {})
        if own and (p.get("executionContextId") == own or (p.get("exceptionDetails") or {}).get("executionContextId") == own):
            continue
        if name == "Network.responseReceived":
            resp = p.get("response", {})
            u, status = resp.get("url", ""), resp.get("status", 0)
            if isinstance(status, int) and status >= 400 and urlsplit(u).path not in OURS:
                out.append({"check": "E1.resource", "selector": None, "text": "HTTP %d %s" % (status, short(u, origin)),
                            "detail": "the page's %s request answered %d" % (str(p.get("type", "resource")).lower(), status)})
        elif name == "Network.loadingFailed" and not p.get("canceled"):
            u = urls.get(p.get("requestId"), "")
            if not u or urlsplit(u).path in OURS and u.startswith(origin):
                continue
            if u.startswith(("http://", "https://", "ws://", "wss://")) and not u.startswith(origin + "/"):
                out.append({"check": "E1.external", "selector": None, "text": u,
                            "detail": "not loaded: a check sends nothing off this machine, and a shared page should not need it either"})
            else:
                out.append({"check": "E1.resource", "selector": None, "text": short(u, origin),
                            "detail": "failed to load: %s" % p.get("errorText", "")})
        elif name == "Runtime.exceptionThrown":
            d = p.get("exceptionDetails", {})
            desc = (d.get("exception") or {}).get("description") or d.get("text") or "exception"
            out.append({"check": "E1.exception", "selector": None, "text": str(desc).split("\n")[0],
                        "detail": "uncaught, at %s:%d" % (short(str(d.get("url", "")), origin) or "inline", int(d.get("lineNumber") or 0) + 1)})
        elif name == "Runtime.consoleAPICalled" and p.get("type") in ("error", "assert"):
            words = [str(a.get("value") if "value" in a else (a.get("description") or a.get("type", ""))).split("\n")[0] for a in p.get("args", [])]
            out.append({"check": "E1.console", "selector": None, "text": " ".join(words) or "console.error()", "detail": "console.%s" % p["type"]})
        elif name == "Log.entryAdded":
            en = p.get("entry", {})
            if en.get("level") == "error" and en.get("source") not in ("network", "javascript", "console-api"):
                out.append({"check": "E1.console", "selector": None, "text": en.get("text", ""), "detail": "browser %s error" % en.get("source", "")})
    kept, seen = [], {}
    for f in out:
        seen[f["check"]] = seen.get(f["check"], 0) + 1
        if seen[f["check"]] <= PER_ID:
            kept.append(dict(f, text=str(f["text"])[:200], detail=str(f["detail"])[:300]))
    return kept, len(out) - len(kept)


def take(result):
    """check.js's answer as (findings, dropped, skipped, capped), or a reason it is not one: only the named fields, each clamped."""
    if not isinstance(result, dict):
        return "the check script returned nothing usable"
    if result.get("error"):
        return "the check script stopped: %s" % str(result["error"])[:200]
    rows = result.get("findings") if isinstance(result.get("findings"), list) else []
    found = []
    for f in rows[:60]:
        if isinstance(f, dict) and isinstance(f.get("check"), str) and CHECK_ID.fullmatch(f["check"]):
            sel = f.get("selector")
            found.append({"check": f["check"], "selector": sel[:300] if isinstance(sel, str) else None,
                          "text": str(f.get("text", ""))[:200], "detail": str(f.get("detail", ""))[:300]})
    dropped = result.get("dropped")
    dropped = (dropped if isinstance(dropped, int) and not isinstance(dropped, bool) and 0 <= dropped < 10 ** 7 else 0) + len(rows) - len(found)
    texts = lambda k: [str(x)[:200] for x in (result.get(k) if isinstance(result.get(k), list) else []) if isinstance(x, str)][:10]
    return found, dropped, texts("skipped"), texts("capped")


def prune(root, checks, results):
    """Shots folders and results of pages no longer under the docroot go; results is changed in place."""
    shots = os.path.join(checks, "shots")
    for d, dirs, files in os.walk(shots, topdown=False):
        rel = os.path.relpath(d, shots)
        if rel != "." and rel.lower().endswith(m.PAGE_EXT) and not os.path.isfile(os.path.join(root, rel)) and not os.path.islink(d):
            shutil.rmtree(d, ignore_errors=True)
        elif rel != "." and not os.listdir(d):
            os.rmdir(d)
    for page in [k for k in results if not (isinstance(k, str) and os.path.isfile(os.path.join(root, *m._parts(k))))]:
        del results[page]


def compare(a, b):
    """dk review's comparison: the union canvas, white-filled, a pixel changed when a channel moves by more than PIXEL."""
    try:
        from PIL import Image, ImageChops
    except ImportError:
        with open(a, "rb") as fa, open(b, "rb") as fb:
            return {"engine": False, "same": fa.read() == fb.read()}
    ia, ib = Image.open(a).convert("RGB"), Image.open(b).convert("RGB")
    size = (max(ia.size[0], ib.size[0]), max(ia.size[1], ib.size[1]))
    pads = []
    for im in (ia, ib):
        canvas = Image.new("RGB", size, (255, 255, 255))
        canvas.paste(im, (0, 0))
        pads.append(canvas)
    r, g, bl = ImageChops.difference(*pads).split()
    delta = ImageChops.lighter(ImageChops.lighter(r, g), bl).point(lambda v: 255 if v > PIXEL else 0)
    changed = delta.histogram()[255]
    return {"engine": True, "ratio": changed / float(size[0] * size[1]), "box": delta.getbbox()}


def change_line(label, versus, result):
    if not result["engine"]:
        return note("change", label, "%s: %s (no diff engine: install Pillow for how much and where)" % (
            versus, "same pixels" if result["same"] else "changed"))
    if not result["box"]:
        return note("change", label, "%s: no pixel changed" % versus)
    x0, y0, x1, y1 = result["box"]
    return note("change", label, "%s: %.2f%% of pixels changed, inside x %d-%d, y %d-%d" % (versus, 100 * result["ratio"], x0, x1, y0, y1))


def previous_version(real, head):
    """An artifact's previous bundled version, .versions/<slug>/v<N-1>.html beside it, and its name; else None. The slug comes from the page, so it must be one plain name inside .versions/."""
    a = re.search(r'<meta\s+name="design-kit-artifact"\s+content="([A-Za-z0-9][A-Za-z0-9._-]{0,99}) v(\d{1,6})[ "]', head)
    if not a or int(a.group(2)) < 2:
        return None
    versions = os.path.realpath(os.path.join(os.path.dirname(real), ".versions"))
    p = os.path.realpath(os.path.join(versions, a.group(1), "v%d.html" % (int(a.group(2)) - 1)))
    return (p, "v%d" % (int(a.group(2)) - 1)) if p.startswith(versions + os.sep) and os.path.isfile(p) else None


def main(argv=None):
    started = time.monotonic()
    ap = argparse.ArgumentParser(prog="dk check", description="Render checks of one served page.")
    ap.add_argument("--docroot", required=True)
    ap.add_argument("--widths")
    ap.add_argument("page")
    a = ap.parse_args(argv)
    widths = widths_of(a.widths) if a.widths else [375, 768, 1280]
    real, rel = resolve(a.docroot, a.page)
    with open(real, "rb") as fh:
        data = fh.read()
        mtime_ns = os.fstat(fh.fileno()).st_mtime_ns  # with the bytes, so an edit during the run reads as changed since
    head = data[:65536].decode("utf-8", "replace")
    # the page's own metas: ids of at most 3 digits, sizes held to what a browser and a PNG can take
    boards = re.findall(r'<meta\s+name="design-kit-board"\s+content="(\d{1,3}):(\d{1,12})x(\d{1,12})"', head)
    extra = []
    if boards:
        if a.widths:
            print("dk check: a board is checked at each artboard's own size; --widths is ignored", file=sys.stderr)
        extra = [n for n, _, _ in boards[8:]]
        jobs = [{"label": "artboard-%d" % int(n), "w": min(max(int(w), 240), 3840), "h": min(max(int(h), 100), SHOT_MAX_H),
                 "hash": "#board=%d" % int(n), "artboard": int(n)} for n, w, h in boards[:8]]
    else:
        jobs = [{"label": str(w), "w": w, "h": height_for(w), "hash": ""} for w in widths]
    for j in jobs:
        j["at"] = ("artboard %d" % j["artboard"]) if boards else "%d px" % j["w"]

    which = subprocess.run(["bash", os.path.join(HERE, "board-export.sh"), "--which"], capture_output=True, text=True)
    if which.returncode != 0 or not which.stdout.strip():
        sys.stderr.write(which.stderr)
        die("no Chromium-family browser found (Chrome, Chromium, Edge, Playwright's, or DESIGN_KIT_BROWSER); not checked", 4)
    exe = which.stdout.strip().splitlines()[-1]
    try:
        with open(AXE_PATH, encoding="utf-8") as fh:
            axe = fh.read()
    except OSError as exc:
        die("cannot read %s (%s); not checked" % (AXE_PATH, exc.strerror or exc), 4)
    up = subprocess.run(["bash", os.path.join(HERE, "preview.sh"), "--docroot", a.docroot], capture_output=True, text=True)
    for line in (up.stdout + up.stderr).splitlines():
        if not line.startswith("preview: http"):
            print(line, file=sys.stderr)
    try:
        with open(os.path.join(a.docroot, ".preview.url"), encoding="ascii") as fh:
            port = urlsplit(fh.read().strip()).port
    except (OSError, ValueError):
        port = None
    if up.returncode != 0 or not port:
        die("the preview server did not start; not checked", 4)
    # 127.0.0.1, not the URL file's host: a LAN server's address is not loopback
    origin = "http://127.0.0.1:%d" % port

    root = os.path.realpath(a.docroot)
    try:
        checks = m.checks_dir(root)
    except OSError as exc:
        die("%s (a symlink?); nothing written, not checked" % exc, 4)
    shots = os.path.join(checks, "shots", *rel.split("/"))
    os.makedirs(shots, mode=0o700, exist_ok=True)
    try:
        with open(os.path.join(shots, "last.json"), encoding="utf-8") as fh:
            last = json.load(fh)
    except (OSError, ValueError):
        last = {}
    last = last if isinstance(last, dict) else {}
    sha = hashlib.sha256(data).hexdigest()
    moved = bool(last) and last.get("sha") != sha
    for j in jobs:
        cur = os.path.join(shots, j["label"] + ".png")
        if moved and os.path.isfile(cur):
            os.replace(cur, os.path.join(shots, "prev-" + j["label"] + ".png"))

    for j in jobs:
        j["url"] = "%s/%s?static=1%s" % (origin, quote(rel), j["hash"])
    e6 = jobs if boards else [max(jobs, key=lambda j: j["w"])]
    changes, prior = [], previous_version(real, head) if not last else None

    def stop(signum, _frame):
        raise SystemExit(4)
    for s in (signal.SIGTERM, signal.SIGHUP, signal.SIGINT):
        signal.signal(s, stop)

    try:
        ch = Chrome(exe, started + TOTAL_S)
    except OSError as exc:
        die("could not start %s: %s; not checked" % (exe, exc.strerror or exc), 4)
    failed = None
    try:
        # first command: a page cannot save a file of its choosing during a check
        ch.call("Browser.setDownloadBehavior", {"behavior": "deny"})
        stuck = None  # a page that hangs, or never runs the check, does the same at every width
        for j in jobs:
            left = started + TOTAL_S - time.monotonic()
            if stuck or left < 5:
                j["why"] = stuck or "the %d s limit ran out" % TOTAL_S
                continue
            tid = sid = ctx = None
            try:
                tid, sid = ch.open(j["w"], j["h"])
                nav = ch.call("Page.navigate", {"url": j["url"]}, sid)
                if nav.get("errorText"):
                    j["why"] = "the browser could not open it: " + str(nav["errorText"])[:200]
                    continue
                if not ch.wait_for(sid, "Page.loadEventFired", min(LOAD_S, left)):
                    j["hung"] = "the page did not finish loading in %d s" % min(LOAD_S, left)
                    continue
                # check.js and axe-core run in a world of their own: the page's script can neither read nor replace them, nor answer for them
                until = time.monotonic() + CHECK_S
                try:
                    ctx = ch.call("Page.createIsolatedWorld", {"frameId": nav.get("frameId") or tid, "worldName": WORLD}, sid, CHECK_S)["executionContextId"]
                    try:
                        ch.evaluate(sid, axe, max(0.1, until - time.monotonic()), ctx)
                    except RuntimeError:
                        pass  # check.js says axe-core did not load
                    got = take(ch.evaluate(sid, CHECK_JS, max(0.1, until - time.monotonic()), ctx))
                except TimeoutError:
                    if time.monotonic() >= ch.deadline:
                        raise
                    j["hung"] = "the page kept the browser busy for %d s after loading" % CHECK_S
                    continue
                except RuntimeError as exc:
                    got = "the check script stopped: %s (the page navigated away?)" % str(exc)[:200]
                if isinstance(got, str):
                    j["why"] = got
                else:
                    j["result"] = got
                ch.shoot(sid, j["w"], j["h"], os.path.join(shots, j["label"] + ".png"), ctx)
            except (TimeoutError, RuntimeError, OSError) as exc:
                if j.get("result"):
                    j["shot"] = "no screenshot: %s" % exc
                else:
                    j["why"] = j.get("why") or ("the %d s limit ran out" % TOTAL_S if time.monotonic() >= ch.deadline else "the browser failed: %s" % exc)
            finally:
                if sid:
                    j["events"], j["lost"] = browser_findings(ch.events, ch.urls.get(sid, {}), sid, origin, ctx)
                    j["lost"] += ch.lost.get(sid, 0)
                ch.close_target(tid, sid)
                if j.get("hung") or (j.get("why") and not j.get("result")):
                    stuck = "skipped: at %s %s" % (j["at"], j.get("hung") or j["why"])
        for j in e6:
            png, prev = os.path.join(shots, j["label"] + ".png"), os.path.join(shots, "prev-" + j["label"] + ".png")
            if not os.path.isfile(png):
                continue
            if last and not moved:
                changes.append(note("change", j["at"], "the file is byte-identical to the last check's (%s)" % str(last.get("ts", "?"))[:32]))
            elif moved and os.path.isfile(prev):
                changes.append(change_line(j["at"], "vs the last check (%s)" % str(last.get("ts", "?"))[:32], compare(prev, png)))
            elif prior and started + TOTAL_S - time.monotonic() > 5:
                tid = sid = None
                try:
                    tid, sid = ch.open(j["w"], j["h"])
                    ch.call("Page.navigate", {"url": pathlib.Path(prior[0]).as_uri() + j["hash"]}, sid)
                    if not ch.wait_for(sid, "Page.loadEventFired", LOAD_S):
                        raise TimeoutError("it did not finish loading in %d s" % LOAD_S)
                    ch.evaluate(sid, SETTLE_JS, 5)
                    ch.shoot(sid, j["w"], j["h"], prev)
                    changes.append(change_line(j["at"], "vs %s (.versions/)" % prior[1], compare(prev, png)))
                except (TimeoutError, RuntimeError, OSError) as exc:
                    changes.append(note("change", j["at"], "%s could not be rendered to compare (%s)" % (prior[1], exc)))
                finally:
                    ch.close_target(tid, sid)
            else:
                changes.append(note("change", j["at"], "nothing to compare (no earlier shot of this page, and no earlier version kept)"))
    except (OSError, EOFError, RuntimeError, TimeoutError) as exc:
        failed = exc
    finally:
        ch.close()
    if failed:
        # only a browser that never answered may be one whose sandbox cannot start here; turning it off is the user's call
        die("the browser failed (%s); not checked%s" % (failed, "" if ch.answered or os.geteuid() == 0 else
            ". If this browser cannot start its sandbox here, ask the user whether to rerun with DESIGN_KIT_BROWSER_NO_SANDBOX=1"
            " (the page then runs unsandboxed)"), 4)

    shot = lambda j: os.path.join(shots, j["label"] + ".png")
    drawn = [j for j in jobs if boards and os.path.isfile(shot(j))]
    for x, one in enumerate(drawn):
        for other in drawn[x + 1:]:
            if (one["w"], one["h"]) != (other["w"], other["h"]) or other.get("twin"):
                continue
            r = compare(shot(one), shot(other))
            if (r["engine"] and not r["box"]) or (not r["engine"] and r["same"]):
                other["twin"] = {"check": "E4.identical", "selector": "#board-%d" % other["artboard"],
                                 "text": "artboards %d and %d render the same" % (one["artboard"], other["artboard"]),
                                 "detail": "two directions on one board should differ: change one or drop it"}
    merged, notes, checked = {}, [], []
    dropped = 0
    for j in jobs:
        found = list(j.get("events", [])) + ([j["twin"]] if j.get("twin") else [])
        if j.get("hung"):
            found.append({"check": "E1.no-report", "selector": None, "text": j["hung"], "detail": "the checks did not finish at this width"})
        if j.get("lost"):
            notes.append(note("dropped", j["at"], "%d more console, error and load findings were not kept" % j["lost"]))
            dropped += j["lost"]
        if j.get("result"):
            rows, gone, skipped, capped = j["result"]
            checked.append(j)
            found += rows
            if gone:
                notes.append(note("dropped", j["at"], "%d more findings were not kept" % gone))
                dropped += gone
            notes += [note("skipped", j["at"], x) for x in skipped] + [note("capped", j["at"], x) for x in capped]
        elif j.get("hung"):
            checked.append(j)
        else:
            notes.append(note("not checked", j["at"], j.get("why", "no findings arrived")))
        notes += [note("shot", j["at"], j["shot"])] if j.get("shot") else []
        for f in found:
            key = (f.get("check"), f.get("selector"), f.get("text"))
            if key not in merged:
                merged[key] = {"check": f.get("check"), "width": j["w"], "widths": [], "selector": f.get("selector"),
                               "text": f.get("text"), "detail": f.get("detail")}
                if boards:
                    merged[key]["artboards"] = []
            if j["w"] not in merged[key]["widths"]:
                merged[key]["widths"].append(j["w"])
            if boards and j["artboard"] not in merged[key]["artboards"]:
                merged[key]["artboards"].append(j["artboard"])
    if extra:
        notes.append(note("not checked", ", ".join("artboard %d" % int(n) for n in extra), "a check covers the first 8 artboards"))
    findings = sorted(merged.values(), key=lambda f: ORDER.get(str(f["check"]).split(".")[0], 9))
    counts = {}
    for f in findings:
        g = str(f["check"]).split(".")[0]
        counts[g] = counts.get(g, 0) + 1
    labels = [j["label"] for j in jobs]
    for line in findings + changes + notes:
        print(m.show(line))
    print(m.show({"summary": {"page": rel, "at": labels, "checked": [j["label"] for j in checked],
                              "findings": len(findings), "dropped": dropped, "by_check": counts,
                              "shots": os.path.join(a.docroot, m.CHECKS, "shots", *rel.split("/")) + "/",
                              "pngs": [l + ".png" for l in labels if os.path.isfile(os.path.join(shots, l + ".png"))],
                              "seconds": round(time.monotonic() - started, 1)}}))
    sys.stdout.flush()
    stamp = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    if checked:
        with open(os.path.join(shots, "last.json"), "w", encoding="utf-8") as fh:
            json.dump({"sha": sha, "ts": stamp}, fh)
    results_path = os.path.join(checks, m.CHECK_RESULTS)
    with m.locked(os.path.join(checks, ".lock")):
        try:
            with open(results_path, encoding="utf-8") as fh:
                results = json.load(fh)
        except (OSError, ValueError):
            results = {}
        results = results if isinstance(results, dict) else {}
        if checked:
            results[rel] = {"ts": stamp, "findings": len(findings), "widths": [j["w"] for j in checked], "mtime_ns": mtime_ns}
        prune(root, checks, results)
        fd, tmp = tempfile.mkstemp(dir=checks, prefix=".results-", suffix=".tmp")
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            json.dump(results, fh, indent=1)
        os.replace(tmp, results_path)
    if not checked:
        return 4
    if findings:
        return 1
    return 4 if len(checked) < len(jobs) or any(n.get("note") == "skipped" for n in notes) else 0  # a check that did not run is not a clean page


if __name__ == "__main__":
    try:
        sys.exit(main())
    except SystemExit:
        raise
    except Exception as exc:  # never exit 1 ("findings") on our own failure, and print no page-controlled text
        die("stopped on an unexpected %s; not checked" % type(exc).__name__, 4)
