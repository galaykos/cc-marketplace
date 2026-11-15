#!/usr/bin/env bash
# Drives the shipped shell live through serve.py (no ?static=1, so Pick and Note are there) in a headless Chromium over its DevTools pipe, with real clicks and key presses, on pages of one to six frames: sideways scroll and frames per row at 375 and 1280, a jump link, Pick and Note per frame under its position letter, a pick's stored row and Picked state with a middle frame removed, number keys, Flip mode, title buttons that wrap. --emit DIR only writes those pages into DIR.
# Misses: Firefox and Safari; touch and what a screen reader says; Stacked mode, the width presets, print; a note's stored row; how a wrapped title looks (walked by eye). With no Chromium-family browser it prints SKIP and exits 0, or exits 1 under PREVIEW_REQUIRE_BROWSER=1.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
SHELL_HTML="$here/../../skills/visual-decisions/assets/shell.html"
SERVE="$here/../../skills/visual-decisions/assets/serve.py"
summary() { echo "shell-controls tests: $1 passed, $2 failed"; }
skip() { echo "SKIP: $1"; summary 0 0; [ "${PREVIEW_REQUIRE_BROWSER:-}" = 1 ] && exit 1; exit 0; }

emit=""
if [ "${1:-}" = --emit ]; then
  [ -n "${2:-}" ] || { echo "usage: shell-controls.test.sh [--emit DIR]" >&2; exit 2; }
  emit=$2
fi
command -v python3 >/dev/null 2>&1 || skip "python3 not found"  # skip: nothing here runs without python3; PREVIEW_REQUIRE_BROWSER=1 exits 1 instead

# build_pages <dir>: layout-1.html to layout-6.html (that many frames) and layout-gap.html (six, the third block deleted), from the shipped shell.
build_pages() {
  python3 - "$SHELL_HTML" "$1" <<'EOF'
import os, re, sys
shell = open(sys.argv[1], encoding="utf-8").read()
out = sys.argv[2]

TABLE = """<table class="vd-table">
<thead><tr><th scope="col">Customer</th> <th scope="col" class="vd-num">Amount</th> <th scope="col">Status</th></tr></thead>
<tbody>
<tr><td>Harbor Freight</td> <td class="vd-num">$4,120</td> <td><span class="vd-chip vd-ok">Paid</span></td></tr>
<tr><td>Lumen Dental</td> <td class="vd-num">$860</td> <td><span class="vd-chip vd-warn">Due Friday</span></td></tr>
<tr><td>Okafor Builders</td> <td class="vd-num">$12,400</td> <td><span class="vd-chip vd-err">Overdue</span></td></tr>
</tbody></table>"""
CARDS = """<div class="vd-cards">
<div class="vd-card"><h3>Harbor Freight</h3> <p>$4,120</p> <span class="vd-chip vd-ok">Paid</span></div>
<div class="vd-card"><h3>Lumen Dental</h3> <p>$860</p> <span class="vd-chip vd-warn">Due Friday</span></div>
<div class="vd-card"><h3>Okafor Builders</h3> <p>$12,400</p> <span class="vd-chip vd-err">Overdue</span></div>
</div>"""
SPLIT = """<div class="vd-split">
<div class="vd-list">
<div class="vd-row" aria-current="true"><span>Harbor Freight</span> <span class="vd-num">$4,120</span></div>
<div class="vd-row"><span>Lumen Dental</span> <span class="vd-num">$860</span></div>
<div class="vd-row"><span>Okafor Builders</span> <span class="vd-num">$12,400</span></div>
</div>
<div class="vd-detail"><h3>Harbor Freight</h3> <p>$4,120</p> <span class="vd-chip vd-ok">Paid</span></div>
</div>"""
SUMMARY = """<div class="vd-kpis">
<div class="vd-kpi"><b>$17,380</b> <span>Billed</span></div>
<div class="vd-kpi"><b>$12,400</b> <span>Overdue</span></div>
<div class="vd-kpi"><b>$860</b> <span>Due Friday</span></div>
</div>
<div class="vd-row"><span>Harbor Freight</span> <span class="vd-chip vd-ok">Paid</span></div>
<div class="vd-row"><span>Lumen Dental</span> <span class="vd-chip vd-warn">Due Friday</span></div>
<div class="vd-row"><span>Okafor Builders</span> <span class="vd-chip vd-err">Overdue</span></div>"""
GROUPED = """<h3>Overdue</h3>
<div class="vd-row"><span>Okafor Builders</span> <span class="vd-num">$12,400</span></div>
<h3>Due Friday</h3>
<div class="vd-row"><span>Lumen Dental</span> <span class="vd-num">$860</span></div>
<h3>Paid</h3>
<div class="vd-row"><span>Harbor Freight</span> <span class="vd-num">$4,120</span></div>"""
ACCORDION = """<div class="vd-accordion">
<div class="vd-acc-item open"><div class="vd-acc-head">Okafor Builders</div> <div class="vd-acc-body">$12,400 <span class="vd-chip vd-err">Overdue</span></div></div>
<div class="vd-acc-item"><div class="vd-acc-head">Lumen Dental</div> <div class="vd-acc-body">$860 <span class="vd-chip vd-warn">Due Friday</span></div></div>
<div class="vd-acc-item"><div class="vd-acc-head">Harbor Freight</div> <div class="vd-acc-body">$4,120 <span class="vd-chip vd-ok">Paid</span></div></div>
</div>"""
# label, caption, content, two tradeoffs; frame A takes the first. Every content holds the same three invoices, a space between its elements: preview-check.sh's E5 compares the variants' words, and joins the text of touching elements into one.
VARIANTS = [
    ("Table", "Dense table, scans by column.", TABLE, "Amounts line up for comparison", "Tight on a phone"),
    ("Cards", "One card per customer.", CARDS, "Reads well on a phone", "Fewer rows per screen"),
    # No-break spaces: this label cannot fold, so at 375 the title's three buttons cannot all sit beside it.
    ("Split&nbsp;list&nbsp;and&nbsp;detail", "Pick a customer, read the invoice beside it.", SPLIT, "The invoice opens without leaving the list", "Two columns fold into one on a phone"),
    ("Summary first", "Totals above the list.", SUMMARY, "What is owed reads before any row", "The list starts lower on the screen"),
    ("Grouped by status", "Overdue first, paid last.", GROUPED, "What needs chasing is on top", "A customer is harder to find by name"),
    ("Accordion", "One line per customer, opened for the amount.", ACCORDION, "Most customers per screen", "An amount takes a click"),
]


def page(n, drop=""):
    """The shell with its first n frames filled (A onward) and the rest deleted; a letter in drop is filled, then its frame deleted too."""
    s = shell
    fills = {"title": "How should the invoice list read?", "question": "How should the invoice list read?",
             "axis": "layout", "pass": "pass 1 of 1", "theme-note": "baseline theme"}
    for letter, (label, caption, content, pro, con) in zip("ABCDEF"[:n], VARIANTS):
        fills.update({"variant-%s-label" % letter: label, "variant-%s-caption" % letter: caption, "variant-%s-content" % letter: content,
                      "tradeoffs-%s" % letter: '<li data-n="1">%s</li><li data-n="2">%s</li>' % (pro, con)})
    for k, v in fills.items():
        assert "<!-- SLOT: %s -->" % k in s, "the shell has no slot %s" % k
        s = s.replace("<!-- SLOT: %s -->" % k, v)
    for letter in "ABCDEF"[n:] + drop:
        # C to F ship inside markers; B has none, so its section goes by id.
        block = (r"\s*<!-- FRAME-%s-START -->.*?<!-- FRAME-%s-END -->" % (letter, letter) if letter in "CDEF"
                 else r'\s*<section class="vd-frame" id="vd-%s".*?</section>' % letter.lower())
        s, found = re.subn(block, "", s, flags=re.S)
        assert found == 1, "the shell has no frame block %s" % letter
    return s


def write(name, text):
    with open(os.path.join(out, name), "w", encoding="utf-8") as h:
        h.write(text)


for n in range(1, 7):
    write("layout-%d.html" % n, page(n))
write("layout-gap.html", page(6, drop="C"))
EOF
}

if [ -n "$emit" ]; then
  mkdir -p "$emit" && build_pages "$emit"
  exit
fi

. "$here/../find-browser.sh"
browser="$(find_browser)" || skip "no Chromium-family browser here (PREVIEW_BROWSER, PATH, Playwright's cache): the shell's controls are not exercised"  # skip: a machine without a browser cannot run any case; PREVIEW_REQUIRE_BROWSER=1 exits 1 instead
sandbox=""; { [ "$(id -u)" = 0 ] || [ "${PREVIEW_BROWSER_NO_SANDBOX:-}" = 1 ]; } && sandbox="--no-sandbox"

T="$(mktemp -d)"
srv=""
cleanup() {
  [ -n "$srv" ] && { kill "$srv" 2>/dev/null; wait "$srv" 2>/dev/null; }
  rm -rf "$T"
}
trap cleanup EXIT
mkdir -p "$T/docroot" "$T/tmp"
export TMPDIR="$T/tmp"

build_pages "$T/docroot" 2>"$T/build.err" || { echo "FAIL fixture pages: not built from the shipped shell: $(tail -n 1 "$T/build.err")"; summary 0 1; exit 1; }
port="$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')"
python3 "$SERVE" --docroot "$T/docroot" --port "$port" >"$T/serve.log" 2>&1 &
srv=$!
for _ in $(seq 1 50); do
  grep -q '^Serving ' "$T/serve.log" 2>/dev/null && break
  kill -0 "$srv" 2>/dev/null || break
  sleep 0.1
done
grep -q '^Serving ' "$T/serve.log" 2>/dev/null || { echo "FAIL server start: serve.py did not start: $(tail -n 1 "$T/serve.log")"; summary 0 1; exit 1; }

python3 - "http://127.0.0.1:$port/" "$browser" "$sandbox" <<'PY'
import fcntl, json, os, select, shutil, signal, subprocess, sys, tempfile, time
from urllib.parse import quote
from urllib.request import ProxyHandler, build_opener

base, browser, sandbox = sys.argv[1:4]
opener = build_opener(ProxyHandler({}))
passed = failed = 0


def case(name, ok, detail=""):
    """One case: counted when ok, else one FAIL line."""
    global passed, failed
    if ok:
        passed += 1
    else:
        failed += 1
        print("FAIL %s: %s" % (name, detail), flush=True)


class Browser:
    """Chrome over --remote-debugging-pipe, as scripts/preview-check.sh drives it: NUL-terminated JSON on fds 3 (to it) and 4 (from it)."""

    def __init__(self):
        self.profile = tempfile.mkdtemp(prefix="vd-controls-")
        to_r, self.to_w = os.pipe()
        self.from_r, from_w = os.pipe()
        a, b = fcntl.fcntl(to_r, fcntl.F_DUPFD_CLOEXEC, 10), fcntl.fcntl(from_w, fcntl.F_DUPFD_CLOEXEC, 10)
        os.close(to_r)
        os.close(from_w)
        args = [browser, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--no-first-run", "--no-default-browser-check",
                "--disable-background-networking", "--disable-extensions", "--disable-sync", "--no-pings",
                "--proxy-server=http://127.0.0.1:9", "--host-resolver-rules=MAP * ~NOTFOUND, EXCLUDE 127.0.0.1",
                "--user-data-dir=" + self.profile, "--remote-debugging-pipe"] + ([sandbox] if sandbox else []) + ["about:blank"]
        self.proc = subprocess.Popen(["bash", "-c", 'exec "$@" 3<&%d 4>&%d %d<&- %d>&-' % (a, b, a, b), "bash"] + args,
                                     pass_fds=(a, b), stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                                     stderr=subprocess.DEVNULL, start_new_session=True)
        os.close(a)
        os.close(b)
        self.buf, self.next_id, self.loaded, self.session, self.target = b"", 0, False, None, None

    def tab(self):
        """A fresh tab, the last one closed: a page left in the back/forward cache keeps its /events stream open, and past six of those nothing loads."""
        if self.target:
            self.call("Target.closeTarget", {"targetId": self.target}, tab=False)
        self.target = self.call("Target.createTarget", {"url": "about:blank"}, tab=False)["targetId"]
        self.session = self.call("Target.attachToTarget", {"targetId": self.target, "flatten": True}, tab=False)["sessionId"]
        self.call("Page.enable")

    def recv(self, until):
        while b"\0" not in self.buf:
            wait = until - time.monotonic()
            if wait <= 0:
                raise TimeoutError("the browser did not answer in time")
            if select.select([self.from_r], [], [], wait)[0]:
                chunk = os.read(self.from_r, 1 << 20)
                if not chunk:
                    raise EOFError("the browser exited")
                self.buf += chunk
        raw, _, self.buf = self.buf.partition(b"\0")
        msg = json.loads(raw)
        if msg.get("method") == "Page.loadEventFired":
            self.loaded = True
        return msg

    def call(self, method, params=None, timeout=15, tab=True):
        self.next_id += 1
        msg = {"id": self.next_id, "method": method, "params": params or {}}
        if tab and self.session:
            msg["sessionId"] = self.session
        os.write(self.to_w, json.dumps(msg).encode("utf-8") + b"\0")
        until = time.monotonic() + timeout
        while True:
            got = self.recv(until)
            if got.get("id") == self.next_id:
                if "error" in got:
                    raise RuntimeError("%s: %s" % (method, got["error"].get("message")))
                return got.get("result", {})

    def close(self):
        try:
            self.call("Browser.close", timeout=3, tab=False)
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
        shutil.rmtree(self.profile, ignore_errors=True)


def js(expression):
    """The value of a JavaScript expression in the page; a promise is awaited."""
    res = cdp.call("Runtime.evaluate", {"expression": expression, "awaitPromise": True, "returnByValue": True})
    if res.get("exceptionDetails"):
        raise RuntimeError("page script threw: %s" % json.dumps(res["exceptionDetails"])[:300])
    return res.get("result", {}).get("value")


def wait(condition, ms=5000):
    """True once the JavaScript condition holds, False when it still does not after ms."""
    return js("new Promise(done => { const t0 = Date.now(); (function poll() { if (%s) done(true); else if (Date.now() - t0 > %d) done(false);"
              " else setTimeout(poll, 20); })(); })" % (condition, ms))


def open_page(name, width):
    """Load a docroot page live in a fresh tab at this viewport width; returns once its Pick and Note buttons and its check badge are in place."""
    cdp.tab()
    cdp.call("Emulation.setDeviceMetricsOverride", {"width": width, "height": 800, "deviceScaleFactor": 1, "mobile": False})
    cdp.loaded = False
    nav = cdp.call("Page.navigate", {"url": base + quote(name)})
    if nav.get("errorText"):
        raise RuntimeError("could not load %s: %s" % (name, nav["errorText"]))
    until = time.monotonic() + 15
    while not cdp.loaded:
        cdp.recv(until)
    cdp.call("Page.bringToFront")
    if not wait("!document.getElementById('vd-fb').hidden && !document.getElementById('vd-check-badge').hidden"):
        raise RuntimeError("%s: the feedback controls or the check badge never appeared" % name)


def style(selector, prop):
    """One computed style property of the first element matching the selector."""
    return js("getComputedStyle(document.querySelector(%s)).getPropertyValue(%s)" % (json.dumps(selector), json.dumps(prop)))


def click(selector):
    """A real mouse click on the centre of the first element matching the selector; it must be the topmost element there."""
    at = js("(() => { const el = document.querySelector(%s); if (!el) return null; el.scrollIntoView({ block: 'center', inline: 'center' });"
            " const r = el.getBoundingClientRect(), x = r.left + r.width / 2, y = r.top + r.height / 2, hit = document.elementFromPoint(x, y);"
            " return { x, y, hit: !!hit && el.contains(hit) }; })()" % json.dumps(selector))
    if not at or not at["hit"]:
        raise RuntimeError("cannot click %s: %s" % (selector, "something covers it" if at else "no such element"))
    for kind in ("mousePressed", "mouseReleased"):
        cdp.call("Input.dispatchMouseEvent", {"type": kind, "x": at["x"], "y": at["y"], "button": "left", "clickCount": 1})


def key(char):
    """A real press of one letter or digit key, sent to whatever has focus."""
    ev = {"key": char, "code": ("Digit" if char.isdigit() else "Key") + char.upper(), "windowsVirtualKeyCode": ord(char.upper())}
    cdp.call("Input.dispatchKeyEvent", dict(ev, type="keyDown", text=char))
    cdp.call("Input.dispatchKeyEvent", dict(ev, type="keyUp"))


def rows(name):
    """The feedback rows serve.py holds for a page."""
    with opener.open(base + "_feedback?page=" + quote(name), timeout=5) as resp:
        return json.loads(resp.read().decode("utf-8"))["rows"]


# Per frame: its box and title box in page coordinates, its badge, and its title buttons by accessible name.
FRAMES = """(() => {
  const box = el => { const r = el.getBoundingClientRect(); return { left: r.left, top: r.top + scrollY, right: r.right, bottom: r.bottom + scrollY, width: r.width }; };
  return Array.from(document.querySelectorAll('.vd-frame')).map(f => ({
    box: box(f), title: box(f.querySelector('h2')), badge: f.querySelector('.vd-badge').textContent,
    buttons: Array.from(f.querySelectorAll('h2 button')).map(b => ({
      name: b.getAttribute('aria-label') || b.textContent, text: b.textContent, pressed: b.getAttribute('aria-pressed'), box: box(b) })) }));
})()"""
# Each jump link's text and the position of the frame it leads to.
JUMPS = """Array.from(document.querySelectorAll('nav[aria-label="Jump to variant"] a')).map(a =>
  [a.textContent, Array.from(document.querySelectorAll('.vd-frame')).indexOf(document.getElementById(a.hash.slice(1)))])"""
FOCUSED = "Array.from(document.querySelectorAll('.vd-frame')).indexOf(document.activeElement)"
INNER = ("(() => { const m = document.getElementById('vd-frames'), c = getComputedStyle(m);"
         " return m.clientWidth - parseFloat(c.paddingLeft) - parseFloat(c.paddingRight); })()")
LETTERS = "ABCDEF"
EACH = ["one frame has", "two frames each have", "three frames each have", "four frames each have", "five frames each have", "six frames each have"]
NTH = ["first", "second", "third", "fourth", "fifth", "sixth"]


def group(name, body):
    """Run one page's cases; a page that never loads or a control that cannot be clicked fails under this name, and the next group still runs."""
    try:
        body()
    except Exception as exc:
        case(name, False, "stopped: %s: %s" % (type(exc).__name__, exc))


def each_count(n):
    name = "layout-%d.html" % n
    open_page(name, 375)
    wide = js("[document.documentElement.scrollWidth, document.documentElement.clientWidth]")
    case("one to six frames no sideways scroll at 375 with Pick and Note", wide[0] <= wide[1],
         "%s: the page is %d px wide in a %d px viewport" % (name, wide[0], wide[1]))
    frames = js(FRAMES)
    names = [[b["name"] for b in f["buttons"]] for f in frames]
    want = [["Focus", "Pick variant " + L, "Note on variant " + L] for L in LETTERS[:n]]
    case("%s Pick and Note" % EACH[n - 1], len(frames) == n and all(set(w) <= set(g) for w, g in zip(want, names)),
         "%s: want %s in the titles, got %s" % (name, want, names))
    jumps = js(JUMPS)
    case("one to six frames each have a jump link reading their letter", jumps == [[L, i] for i, L in enumerate(LETTERS[:n])],
         "%s: got [text, frame position] %s" % (name, jumps))
    inner = js(INNER)
    boxes = [f["box"] for f in frames]
    stacked = all(b["width"] >= inner - 1 for b in boxes) and all(b["top"] >= a["bottom"] for a, b in zip(boxes, boxes[1:]))
    case("frames stack one per row at 375", stacked,
         "%s: the row is %d px wide, frames are at %s" % (name, inner, [[round(b["left"]), round(b["top"]), round(b["width"])] for b in boxes]))


def rows_at_1280():
    open_page("layout-6.html", 1280)
    tops = [round(f["box"]["top"]) for f in js(FRAMES)]
    case("six frames share rows at 1280", len(tops) == 6 and len(set(tops)) < 6, "frame tops: %s" % tops)


def wrapped_title():
    # The third frame's label cannot fold (see build_pages), so its buttons have to wrap.
    open_page("layout-3.html", 375)
    frames = js(FRAMES)
    plain, tight = frames[0], frames[2]
    lines = {round(b["box"]["top"]) for b in tight["buttons"]}
    inside = all(b["box"]["bottom"] <= tight["title"]["bottom"] + 0.5 and b["box"]["left"] >= tight["title"]["left"] - 0.5
                 and b["box"]["right"] <= tight["title"]["right"] + 0.5 for b in tight["buttons"])
    widths = [[round(b["box"]["width"], 1) for b in f["buttons"]] for f in (tight, plain)]
    case("title buttons that wrap stay inside the title at full width at 375", len(lines) > 1 and inside and widths[0] == widths[1],
         "button lines %d (want over 1), inside the title %s, widths %s against %s on one line; title bottom %.1f, button bottoms %s"
         % (len(lines), inside, widths[0], widths[1], tight["title"]["bottom"], [round(b["box"]["bottom"], 1) for b in tight["buttons"]]))


def middle_frame_removed():
    # Frames by id are a, b, d, e, f here: a letter that followed the id would skip C.
    open_page("layout-gap.html", 1280)
    seen = [[f["badge"]] + [b["name"] for b in f["buttons"] if b["name"] != "Focus"] for f in js(FRAMES)]
    jumps = js(JUMPS)
    case("with a middle frame removed the frames still read A to E in order",
         seen == [[L, "Pick variant " + L, "Note on variant " + L] for L in "ABCDE"] and jumps == [[L, i] for i, L in enumerate("ABCDE")],
         "got [badge, Pick, Note] %s and jump links %s" % (seen, jumps))
    click('#vd-e button[aria-label^="Pick variant"]')
    marked = wait("document.querySelector('#vd-e button[aria-label^=\"Pick variant\"]').getAttribute('aria-pressed') === 'true'")
    picks = [r["variant"] for r in rows("layout-gap.html") if r["kind"] == "pick"]
    state = [[b["text"], b["pressed"]] for f in js(FRAMES) for b in f["buttons"] if b["name"].startswith("Pick variant")]
    case("a pick on the fourth frame stores D and shows Picked there only",
         marked and picks == ["D"] and state == [["Picked", "true"] if i == 3 else ["Pick", "false"] for i in range(5)],
         "stored picks %s, Pick buttons %s" % (picks, state))


def number_keys():
    open_page("layout-6.html", 1280)
    for n in range(1, 7):
        key(str(n))
        got = js(FOCUSED)
        case("key %d focuses the %s frame" % (n, NTH[n - 1]), got == n - 1, "focus is on frame position %d (-1: on no frame)" % got)


def key_past_the_last():
    open_page("layout-3.html", 375)
    key("2")
    before = js("[%s, scrollY]" % FOCUSED)
    key("5")
    after = js("[%s, scrollY]" % FOCUSED)
    case("a key past the last frame does nothing", before[0] == 1 and after == before,
         "[focused frame position, scrollY] was %s after key 2, then %s after key 5 on three frames" % (before, after))


def flip_mode():
    # Flip shows one frame at a time, so a jump link cannot scroll to its frame: the link has to show it.
    open_page("layout-6.html", 1280)
    click('[data-vd-set-mode="flip"]')
    click('nav[aria-label="Jump to variant"] a:nth-of-type(4)')
    shown = [i for i, L in enumerate("abcdef") if style("#vd-" + L, "display") != "none"]
    focused = js(FOCUSED)
    case("in Flip mode a jump link shows and focuses its frame", shown == [3] and focused == 3,
         "frames shown %s, focus on frame position %d" % (shown, focused))


cdp = None
try:
    cdp = Browser()
    for n in range(1, 7):
        group("layout-%d.html at 375" % n, lambda: each_count(n))
    group("six frames at 1280", rows_at_1280)
    group("wrapped title buttons", wrapped_title)
    group("a middle frame removed", middle_frame_removed)
    group("number keys", number_keys)
    group("a key past the last frame", key_past_the_last)
    group("Flip mode", flip_mode)
except Exception as exc:
    case("browser start", False, "%s: %s" % (type(exc).__name__, exc))
finally:
    if cdp:
        cdp.close()

print("shell-controls tests: %d passed, %d failed" % (passed, failed))
sys.exit(1 if failed else 0)
PY
