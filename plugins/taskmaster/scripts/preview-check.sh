#!/usr/bin/env bash
# preview-check.sh [--docroot DIR] [--page PATH] [--widths 375,768,1280] (defaults .cc-artifacts/taskmaster/mockups, current.html): loads the page from this docroot's serve.py (started through preview.sh when none answers, said on stderr) in a headless Chromium-family browser driven over its DevTools pipe, one exact width at a time; check.js and axe-core run in an isolated world page script cannot reach (E1 load, E2 layout, E3 axe-core, E4 stand-in content, E5 variants; console and uncaught errors read from the browser), and this script writes each width's record and a full-page PNG to DIR/.checks/<page>-<hash>/; E6 compares the widest PNG with the newest ledger pass that differs from the page. Every stdout line is one escaped JSON object: a finding (seen at several widths once, with "widths"), an E6 "advisory" that counts as no finding, a {"not_reported": width, "reason": ...}, then one {"summary": ...}.
# Exit: 0 no findings; 1 findings; 2 bad argument, or --page names no .html file inside DIR; 3 no serve.py with the /_checks route (preview.sh could not start one, or one from before this version runs: --stop, then rerun); 4 no Chromium-family browser (PREVIEW_BROWSER, PATH, macOS bundles, Playwright's cache); 5 some width not reported (the check timed out or failed, or no screenshot), the rest still printed; 6 python3 missing, the browser failed, a signal, or the run passed 60 s, with what was collected still printed.
# Misses: what each check misses (see the derivation); whether the model acts on a finding; page script still runs and can change what is measured, so a clean check is not proof the page is fine; nothing leaves the machine (no proxy, DNS, download or WebRTC UDP), so a page leaning on a CDN reads as broken, yet loopback stays reachable; E6 is pixels at one width against the newest differing ledger pass, which can belong to another decision.
# Why, limits, history: rationale/derivations/plugin-taskmaster.md § plugins/taskmaster/scripts/preview-check.sh
set -u
here="$(cd "$(dirname "$0")" && pwd)"

usage() { echo "usage: preview-check.sh [--docroot DIR] [--page PATH] [--widths W,W,...]" >&2; exit 2; }
docroot=".cc-artifacts/taskmaster/mockups"; page="current.html"; widths="375,768,1280"
while [ $# -gt 0 ]; do
  case "$1" in
    --docroot) [ $# -ge 2 ] || usage; docroot=$2; shift ;;
    --page) [ -n "${2:-}" ] || usage; page=$2; shift ;;
    --widths) [ $# -ge 2 ] || usage; widths=$2; shift ;;
    -h | --help) sed -n '2,4p' "$0"; exit 0 ;;
    *) usage ;;
  esac
  shift
done
command -v python3 >/dev/null 2>&1 || { echo "preview-check.sh: python3 not found" >&2; exit 6; }
python3 - "$docroot" "$page" "$widths" <<'PY' || exit 2
import re, sys
from pathlib import Path
docroot, page, widths = sys.argv[1:4]
root, page = Path(docroot).resolve(), page.lstrip("/")
if not re.fullmatch(r"[0-9]{3,4}(,[0-9]{3,4}){0,5}", widths) or not all(200 <= int(w) <= 3840 for w in widths.split(",")):
    print("preview-check.sh: --widths takes up to six comma-separated widths from 200 to 3840", file=sys.stderr)
    sys.exit(2)
target = (root / page).resolve()
if (not root.is_dir() or any(not s or s.startswith(".") for s in page.split("/")) or not page.lower().endswith((".html", ".htm"))
        or root not in target.parents or not target.is_file()):
    print("preview-check.sh: --page %s names no .html file inside %s" % (page, root), file=sys.stderr)
    sys.exit(2)
PY

. "$here/find-browser.sh"
browser="$(find_browser)" || { echo "preview-check.sh: no Chromium-family browser found (PREVIEW_BROWSER, PATH, Playwright's cache); nothing checked" >&2; exit 4; }
# Chrome's sandbox stays on: off only as root, where Chrome refuses to start with it, or on PREVIEW_BROWSER_NO_SANDBOX=1.
sandbox=""; { [ "$(id -u)" = 0 ] || [ "${PREVIEW_BROWSER_NO_SANDBOX:-}" = 1 ]; } && sandbox="--no-sandbox"
limit=""; command -v timeout >/dev/null 2>&1 && limit="timeout 90"

# exec, so a caller's TERM or HUP reaches the driver, which closes the browser and removes its profile before it exits.
exec python3 - "$docroot" "$page" "$widths" "$browser" "$sandbox" "$limit" "$here" <<'PY'
import base64, fcntl, hashlib, json, math, os, secrets, select, shutil, signal, subprocess, sys, tempfile, time, unicodedata
from pathlib import Path
from urllib.error import HTTPError
from urllib.parse import quote, urlsplit
from urllib.request import ProxyHandler, build_opener

docroot, page, widths, browser, sandbox, limit, here = sys.argv[1:8]
root, page = Path(docroot).resolve(), page.lstrip("/")
widths = [int(w) for w in widths.split(",")]
started = time.monotonic()
DEADLINE = started + 60
PER_WIDTH = 20
HEIGHT = 800  # the emulated viewport; screenshots cover the whole page, up to MAX_SHOT
MAX_SHOT = 8000
WORLD = "vd-check"  # the isolated world check.js and axe-core run in
KEEP = 60  # findings kept per width; the rest are counted as dropped
EVENTS = 200  # console and exception events kept per page; the rest are counted
CHECK_IDS = ("E1", "E2", "E3", "E4", "E5")
opener = build_opener(ProxyHandler({}))
# preview-feedback.sh's output rule: variation selectors and blank-rendering letters escape too, though not C*.
BLANK = set(range(0xFE00, 0xFE10)) | set(range(0xE0100, 0xE01F0)) | set(range(0x180B, 0x1810)) | {0x115F, 0x1160, 0x3164, 0xFFA0, 0x2800}


def hidden(c):
    cat = unicodedata.category(c)
    return cat[0] == "C" or cat in ("Zl", "Zp") or ord(c) in BLANK


def show(obj):
    """One JSON line; control, format, private-use, unassigned, separator and blank-rendering characters escaped, as preview-feedback.sh prints rows."""
    out = json.dumps(obj, ensure_ascii=False)
    return "".join(json.dumps(c)[1:-1] if hidden(c) else c for c in out)


def say(msg):
    print("preview-check.sh: " + msg, file=sys.stderr, flush=True)


def clip(value, n):
    return value[:n].encode("utf-8", "replace").decode("utf-8") if isinstance(value, str) else ""


def get_json(url):
    with opener.open(url, timeout=3) as resp:
        return json.loads(resp.read().decode("utf-8"))


def probe():
    """(port, /_checks answer) for this docroot's live preview.sh server; (port, None) when it lacks the route; None when none answers."""
    try:
        pid = int((root / ".preview.pid").read_text().strip())
        port = urlsplit((root / ".preview.url").read_text().strip()).port
        os.kill(pid, 0)
    except (OSError, ValueError):
        return None
    if not port:
        return None
    try:
        return port, get_json("http://127.0.0.1:%d/_checks?page=%s" % (port, quote(page)))
    except HTTPError:
        return port, None
    except (OSError, ValueError):
        return None


def inside(name):
    """True for a docroot-relative page that still exists as a file inside the docroot."""
    if not isinstance(name, str) or any(not s or s.startswith(".") for s in name.split("/")):
        return False
    try:
        target = (root / name).resolve()
        return root in target.parents and target.is_file()
    except (OSError, ValueError):
        return False


def prune(keep):
    """Remove the record folders of pages deleted since their check (their records and stamp name the page)."""
    for d in (root / ".checks").iterdir():
        if d == keep or d.is_symlink() or not d.is_dir():
            continue
        names = set()
        for f in list(d.glob("*.json"))[:20]:
            try:
                rec = json.loads(f.read_text(encoding="utf-8"))
            except (OSError, ValueError):
                continue
            if isinstance(rec, dict) and isinstance(rec.get("page"), str):
                names.add(rec["page"])
        if names and not any(inside(n) for n in names):
            shutil.rmtree(d, ignore_errors=True)


def write_json(path, obj):
    """Replace path through a dot temp file and a rename, so the badge never reads half a record."""
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), prefix=".", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(obj, handle, ensure_ascii=False)
        os.replace(tmp, str(path))
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


found = probe()
if found is None:
    run = subprocess.run(["bash", os.path.join(here, "preview.sh"), "--docroot", str(root)], capture_output=True, text=True)
    if run.returncode != 0:
        say("no preview server answered for %s and preview.sh could not start one (exit %d): %s"
            % (root, run.returncode, ((run.stderr or run.stdout).strip().splitlines() or [""])[-1]))
        sys.exit(3)
    say("started the preview server: " + next((l[len("preview: "):] for l in run.stdout.splitlines() if l.startswith("preview: http")), str(root)))
    found = probe()
if not found or not isinstance(found[1], dict) or not isinstance(found[1].get("dir"), str):
    say("the server for %s has no render-check routes (started before this version?): run preview.sh --stop, then rerun" % root)
    sys.exit(3)
port, checks = found
base = "http://127.0.0.1:%d/" % port
folder = (root / checks["dir"]).resolve()
if folder.parent != root / ".checks":
    say("the server named %s for the records, outside %s/.checks" % (folder, root))
    sys.exit(3)
for part in (folder.parent, folder):
    try:
        os.mkdir(part, 0o700)
    except FileExistsError:
        pass
    if part.is_symlink() or not part.is_dir():
        say("%s is not a directory" % part)
        sys.exit(6)
for old in list(folder.glob("*.json")) + list(folder.glob("*.png")):
    old.unlink()
prune(folder)
assets = Path(here).parent
try:
    CHECK_JS = (assets / "skills" / "visual-decisions" / "assets" / "check.js").read_text(encoding="utf-8")
    AXE_JS = (assets / "vendor" / "axe-core" / "axe.min.js").read_text(encoding="utf-8")
    digest = hashlib.sha256((root / page).read_bytes()).hexdigest()  # the bytes checked: the badge counts records only while the file still holds them
except OSError as exc:
    say("cannot read %s" % exc)
    sys.exit(6)


class Stop(Exception):
    pass


def stop(signum, _frame):
    for s in (signal.SIGTERM, signal.SIGHUP, signal.SIGINT):
        signal.signal(s, signal.SIG_IGN)  # timeout(1) signals the driver and then its group: one stop is enough
    raise Stop("stopped by signal %d" % signum)


class Browser:
    """Chrome over --remote-debugging-pipe: NUL-terminated JSON on fds 3 (to it) and 4 (from it)."""

    def __init__(self, profile):
        to_r, self.to_w = os.pipe()
        self.from_r, from_w = os.pipe()
        # Above fd 9, so the redirects below cannot clobber one with the other.
        a, b = fcntl.fcntl(to_r, fcntl.F_DUPFD_CLOEXEC, 10), fcntl.fcntl(from_w, fcntl.F_DUPFD_CLOEXEC, 10)
        os.close(to_r)
        os.close(from_w)
        args = (limit.split() if limit else []) + [
            browser, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--no-first-run", "--no-default-browser-check",
            "--disable-background-networking", "--disable-extensions", "--disable-sync", "--no-pings",
            # Nothing leaves the machine: a dead proxy for all but loopback (it wins over a proxy in the environment), no name resolution, no WebRTC UDP past the proxy.
            "--proxy-server=http://127.0.0.1:9", "--host-resolver-rules=MAP * ~NOTFOUND, EXCLUDE 127.0.0.1",
            "--webrtc-ip-handling-policy=disable_non_proxied_udp", "--force-webrtc-ip-handling-policy=disable_non_proxied_udp",
            "--user-data-dir=" + profile, "--remote-debugging-pipe"] + ([sandbox] if sandbox else []) + ["about:blank"]
        self.proc = subprocess.Popen(["bash", "-c", 'exec "$@" 3<&%d 4>&%d %d<&- %d>&-' % (a, b, a, b), "bash"] + args,
                                     pass_fds=(a, b), stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                                     stderr=subprocess.DEVNULL, start_new_session=True)
        os.close(a)
        os.close(b)
        self.buf, self.next_id, self.events, self.session, self.lost = b"", 0, [], None, 0

    def recv(self, until):
        while b"\0" not in self.buf:
            wait = min(until, DEADLINE) - time.monotonic()
            if wait <= 0:
                raise TimeoutError("passed 60 s" if time.monotonic() >= DEADLINE else "timed out")
            ready, _, _ = select.select([self.from_r], [], [], wait)
            if ready:
                chunk = os.read(self.from_r, 1 << 20)
                if not chunk:
                    raise EOFError("the browser exited")
                self.buf += chunk
        raw, _, self.buf = self.buf.partition(b"\0")
        msg = json.loads(raw)
        if msg.get("method") == "Page.javascriptDialogOpening":
            self.send("Page.handleJavaScriptDialog", {"accept": True}, msg.get("sessionId"))
        if msg.get("method") in ("Inspector.detached", "Target.targetCrashed"):
            raise EOFError("the page crashed or was detached")
        return msg

    def keep(self, msg):
        """Keep the load event, console errors and uncaught exceptions; past EVENTS only count them, so a page logging in a loop cannot fill memory."""
        name, p = msg.get("method"), msg.get("params") or {}
        if name == "Page.loadEventFired":
            self.events.append(msg)
        elif name == "Runtime.exceptionThrown" or (name == "Runtime.consoleAPICalled" and p.get("type") == "error"):
            if len(self.events) < EVENTS:
                self.events.append(msg)
            else:
                self.lost += 1

    def send(self, method, params=None, session=None):
        self.next_id += 1
        msg = {"id": self.next_id, "method": method, "params": params or {}}
        if session:
            msg["sessionId"] = session
        os.write(self.to_w, json.dumps(msg).encode("utf-8") + b"\0")
        return self.next_id

    def call(self, method, params=None, timeout=10, page_session=True, until=None):
        want = self.send(method, params, self.session if page_session else None)
        until = until or time.monotonic() + timeout
        while True:
            msg = self.recv(until)
            if msg.get("id") == want:
                if "error" in msg:
                    raise RuntimeError("%s: %s" % (method, msg["error"].get("message")))
                return msg.get("result", {})
            if "method" in msg:
                self.keep(msg)

    def event(self, method, timeout):
        until = time.monotonic() + timeout
        while True:
            for i, msg in enumerate(self.events):
                if msg.get("method") == method and msg.get("sessionId") == self.session:
                    del self.events[i]
                    return msg
            msg = self.recv(until)
            if "method" in msg:
                self.keep(msg)

    def open(self):
        target = self.call("Target.createTarget", {"url": "about:blank"}, page_session=False)["targetId"]
        self.session = self.call("Target.attachToTarget", {"targetId": target, "flatten": True}, page_session=False)["sessionId"]
        self.call("Page.enable")
        self.call("Runtime.enable")
        # check.js's error listener must be in place before the page's first resource fails: every new document gets it, in its own world.
        self.call("Page.addScriptToEvaluateOnNewDocument", {"source": CHECK_JS, "worldName": WORLD})

    def go(self, url, width, timeout=PER_WIDTH):
        self.call("Emulation.setDeviceMetricsOverride", {"width": width, "height": HEIGHT, "deviceScaleFactor": 1, "mobile": False})
        self.events, self.lost = [], 0
        nav = self.call("Page.navigate", {"url": url})
        if nav.get("errorText"):
            raise RuntimeError("could not load %s: %s" % (url, nav["errorText"]))
        self.event("Page.loadEventFired", timeout)
        return nav.get("frameId")

    def check(self, frame):
        """check.js's answer from its isolated world, and that world's context id; axe-core is evaluated there first."""
        until = time.monotonic() + PER_WIDTH
        ctx = self.call("Page.createIsolatedWorld", {"frameId": frame, "worldName": WORLD}, until=until)["executionContextId"]
        self.call("Runtime.evaluate", {"expression": AXE_JS, "contextId": ctx}, until=until)
        res = self.call("Runtime.evaluate", {"expression": "window.__vdRun()", "contextId": ctx, "awaitPromise": True, "returnByValue": True},
                        until=until)
        if res.get("exceptionDetails"):
            raise RuntimeError("the check script stopped (%s)" % clip(res["exceptionDetails"].get("text"), 100))
        return res.get("result", {}).get("value"), ctx

    def errors(self, ctx):
        """E1 console errors and uncaught errors of the page's own script, as check.js reported them before it moved to its own world."""
        out = []
        for msg in self.events:
            name, p = msg.get("method"), msg.get("params") or {}
            if name == "Runtime.consoleAPICalled" and p.get("executionContextId") != ctx:
                words = []
                for a in p.get("args") or []:
                    v = a.get("value") if "value" in a else str(a.get("description") or a.get("className") or a.get("type", "")).split("\n")[0]
                    words.append(v if isinstance(v, str) else json.dumps(v))
                out.append(clip(" ".join(words), 300))
            elif name == "Runtime.exceptionThrown":
                d = p.get("exceptionDetails") or {}
                if d.get("executionContextId") == ctx:
                    continue
                desc = str((d.get("exception") or {}).get("description") or d.get("text") or "error").split("\n")[0]
                url = str(d.get("url") or "")
                out.append(clip("uncaught " + desc + (" at %s:%d" % (url.split("/")[-1], int(d.get("lineNumber") or 0) + 1) if url else ""), 300))
        return out

    def value(self, expression, timeout=PER_WIDTH):
        res = self.call("Runtime.evaluate", {"expression": expression, "awaitPromise": True, "returnByValue": True}, timeout=timeout)
        return res.get("result", {}).get("value")

    def shot(self, width):
        size = self.call("Page.getLayoutMetrics")
        size = size.get("cssContentSize") or size.get("contentSize") or {}
        height = max(1, min(int(math.ceil(size.get("height", HEIGHT))), MAX_SHOT))
        return self.call("Page.captureScreenshot", {"format": "png", "captureBeyondViewport": True,
                                                    "clip": {"x": 0, "y": 0, "width": width, "height": height, "scale": 1}}, timeout=30)["data"]

    def close(self):
        global DEADLINE
        DEADLINE = max(DEADLINE, time.monotonic() + 3)  # past the run's deadline, Browser.close still gets its 3 s
        try:
            self.call("Browser.close", timeout=3, page_session=False)
        except Exception:
            pass
        try:
            self.proc.wait(5)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(self.proc.pid, signal.SIGKILL)
            except OSError:
                pass
            self.proc.wait()
        for fd in (self.to_w, self.from_r):
            os.close(fd)


def previous_pass():
    """For current.html or a ledger pass: the newest ledger pass (serve.py's /_versions.json) older than the page whose bytes differ, else None."""
    try:
        versions = get_json(base + "_versions.json").get("versions") or []
        own = (root / page).read_bytes()
        own_mtime = (root / page).stat().st_mtime
    except (OSError, ValueError):
        return None
    if page != "current.html" and page not in [v.get("name") for v in versions if isinstance(v, dict)]:
        return None
    for v in versions:
        name = v.get("name") if isinstance(v, dict) else None
        if not isinstance(name, str) or name == page or not isinstance(v.get("mtime"), (int, float)) or v["mtime"] > own_mtime + 1:
            continue
        try:
            if (root / name).read_bytes() != own:
                return name
        except OSError:
            continue
    return None


DIFF = """(async (a, b) => {
  const load = src => new Promise((ok, no) => { const i = new Image(); i.onload = () => ok(i); i.onerror = () => no(new Error('png')); i.src = src; });
  const [ia, ib] = await Promise.all([load(a), load(b)]);
  const w = Math.max(ia.width, ib.width), h = Math.max(ia.height, ib.height);
  const px = img => { const c = document.createElement('canvas'); c.width = w; c.height = h; const g = c.getContext('2d'); g.drawImage(img, 0, 0); return g.getImageData(0, 0, w, h).data; };
  const da = px(ia), db = px(ib);
  let changed = 0, x0 = w, y0 = h, x1 = -1, y1 = -1;
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const k = (y * w + x) * 4;
    if (da[k + 3] !== db[k + 3] || Math.abs(da[k] - db[k]) > 24 || Math.abs(da[k + 1] - db[k + 1]) > 24 || Math.abs(da[k + 2] - db[k + 2]) > 24) {
      changed++; if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y;
    }
  }
  return { w, h, now: [ia.width, ia.height], before: [ib.width, ib.height], changed, box: changed ? [x0, y0, x1, y1] : null };
})(%s, %s)"""


def pct(x):
    return ("%.6f" % x).rstrip("0").rstrip(".") or "0"


def record_of(answer, errs, lost, w):
    """One width's record: check.js's findings (named fields, clamped, E1-E5 only) and the browser's E1 errors, KEEP of them; the rest counted."""
    raw = answer.get("findings") if isinstance(answer.get("findings"), list) else []
    rows = [{"check": f["check"], "selector": clip(f.get("selector"), 300) or None, "text": clip(f.get("text"), 120), "detail": clip(f.get("detail"), 400)}
            for f in raw if isinstance(f, dict) and f.get("check") in CHECK_IDS]
    shown = errs[:10]  # check.js's own cap: ten findings per check and text
    rows += [{"check": "E1", "selector": None, "text": "console error", "detail": e} for e in shown]
    dropped = len(raw) - (len(rows) - len(shown)) + len(errs) - len(shown) + lost
    return {"page": page, "page_sha256": digest, "run": token, "width": w, "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "findings": rows[:KEEP], "dropped": dropped + max(0, len(rows) - KEEP)}


token = secrets.token_hex(6)
records, collected, shots, missing, notes, advisories = {}, {}, [], [], [], []
previous = None
cdp = None
profile = None
code = 0
capped = 0
for s in (signal.SIGTERM, signal.SIGHUP, signal.SIGINT):
    signal.signal(s, stop)
try:
    profile = tempfile.mkdtemp(prefix="vd-check-")
    if sandbox:
        say("the browser's sandbox is off (%s)" % ("running as root" if os.geteuid() == 0 else "PREVIEW_BROWSER_NO_SANDBOX=1"))
    cdp = Browser(profile)
    cdp.call("Browser.setDownloadBehavior", {"behavior": "deny"}, page_session=False)  # a page cannot save a file of its choosing
    cdp.open()
    pngs = {}
    for w in widths:
        reason, answer, ctx = None, None, None
        try:
            frame = cdp.go(base + quote(page) + "?static=1", w)
            answer, ctx = cdp.check(frame)
            if not isinstance(answer, dict):
                reason = "the check returned nothing usable"
        except TimeoutError as exc:
            if time.monotonic() >= DEADLINE:
                raise
            reason = "the check did not finish in %d s (%s)" % (PER_WIDTH, exc)
        except RuntimeError as exc:
            reason = "the check could not run: %s" % exc
        if isinstance(answer, dict):
            collected[w] = record_of(answer, cdp.errors(ctx), cdp.lost, w)
            capped += int(answer["capped"]) if isinstance(answer.get("capped"), int) and answer["capped"] > 0 else 0
        try:
            pngs[w] = cdp.shot(w)
            path = folder / ("%d.png" % w)
            path.write_bytes(base64.b64decode(pngs[w]))
            shots.append(str(path))
        except (TimeoutError, RuntimeError, OSError, ValueError) as exc:
            if time.monotonic() >= DEADLINE:
                raise
            pngs.pop(w, None)
            reason = reason or "no screenshot (%s)" % exc
        if reason:
            missing.append(w)
            notes.append({"not_reported": w, "reason": reason})
        else:
            write_json(folder / ("%d.json" % w), collected[w])
            records[w] = collected[w]

    try:
        previous = previous_pass()
        widest = max(pngs) if pngs else None
        if previous and widest:
            cdp.go(base + quote(previous) + "?static=1", widest)
            cdp.value("Promise.race([document.fonts ? document.fonts.ready : null, new Promise(r => setTimeout(r, 3000))]).then(() => 1)")
            before = cdp.shot(widest)
            (folder / ("previous-%d.png" % widest)).write_bytes(base64.b64decode(before))
            cdp.go("about:blank", widest)
            d = cdp.value(DIFF % (json.dumps("data:image/png;base64," + pngs[widest]), json.dumps("data:image/png;base64," + before)), timeout=30)
            if isinstance(d, dict) and d.get("w"):
                share = 100.0 * d["changed"] / (d["w"] * d["h"])
                box = d.get("box")
                where = ", inside x %d-%d, y %d-%d" % (box[0], box[2], box[1], box[3]) if box else ""
                advisories.append({
                    "check": "E6", "advisory": True, "width": widest, "widths": [widest], "selector": None,
                    "text": "changed since the previous pass" if d["changed"] else "no visible change since the previous pass",
                    "detail": "%s%% of pixels (%d) differ at %dpx%s; page %dx%d now, %dx%d in %s" % (
                        pct(share), d["changed"], widest, where, d["now"][0], d["now"][1], d["before"][0], d["before"][1], previous),
                })
    except (OSError, EOFError, RuntimeError, TimeoutError, ValueError, KeyError, TypeError) as exc:
        advisories.append({"check": "E6", "advisory": True, "width": max(widths), "widths": [max(widths)], "selector": None,
                           "text": "could not compare with the previous pass", "detail": "%s (%s)" % (clip(str(exc), 200), previous)})
except (OSError, EOFError, RuntimeError, TimeoutError, ValueError, KeyError, Stop) as exc:
    say("the browser run failed: %s" % exc)
    code = 6
except Exception as exc:  # our own failure never exits 1 ("findings"); only the type is named
    say("the browser run failed: unexpected %s" % type(exc).__name__)
    code = 6
finally:
    for s in (signal.SIGTERM, signal.SIGHUP, signal.SIGINT):
        signal.signal(s, signal.SIG_IGN)  # a signal from here on would raise where nothing catches it; the run ends within seconds
    if cdp:
        cdp.close()
    if profile:
        shutil.rmtree(profile, ignore_errors=True)

for w in widths:
    if w not in records and w not in missing:
        missing.append(w)
        notes.append({"not_reported": w, "reason": "not reached: the run stopped"})
try:
    write_json(folder / "run.json", {"page": page, "run": token, "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "widths": sorted(records)})
except OSError:
    pass
merged = {}
for w in widths:
    for f in (collected.get(w) or {}).get("findings") or []:
        key = (f.get("check"), f.get("selector"), f.get("text"), f.get("detail"))
        if key in merged:
            merged[key]["widths"].append(w)
        else:
            merged[key] = {"check": key[0], "width": w, "widths": [w], "selector": key[1], "text": key[2], "detail": key[3]}
dropped = sum(int((collected.get(w) or {}).get("dropped") or 0) for w in widths)
by_check = {}
for f in merged.values():
    by_check[f["check"]] = by_check.get(f["check"], 0) + 1
for line in list(merged.values()) + advisories + notes:
    print(show(line))
print(show({"summary": {"page": page, "widths": sorted(records), "findings": len(merged), "dropped": dropped, "by_check": by_check,
                        "not_reported": sorted(missing), "capped": capped, "shots": shots, "previous": previous,
                        "seconds": round(time.monotonic() - started, 1)}}))
sys.stdout.flush()
sys.exit(code or (5 if missing else 1 if merged or dropped else 0))
PY
