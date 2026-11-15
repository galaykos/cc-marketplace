#!/usr/bin/env bash
# Drives the shipped shell live through serve.py (no ?static=1, so Pick and Note are there) in a headless Chromium over its DevTools pipe, with real clicks and key presses, on pages of one to six frames: sideways scroll and frames per row at 375 and 1280, a jump link, Pick and Note per frame under its position letter, a pick's stored row and Picked state with a middle frame removed, number keys, Flip mode, title buttons that wrap; on pages marked pass 1, 2 and 12 and one with no pass mark, the pass number a pick and a note store and Picked only while the newest stored pick is on the page's own pass; on pages that author palette, style and type presets, the switcher row (its own line, order, labels, the first option active, a kind with one option or none, a creative pass, a page with no pass mark, Tab, Enter and Space, no reload, one such page loaded with ?static=1) and what a look restyles: every frame's content and nav bar, never the header, a title, a caption or a tradeoff list. --emit DIR only writes those pages into DIR.
# Misses: Firefox and Safari; touch and what a screen reader says; Stacked mode, the width presets, print; a note's stored row beyond its pass number; a page rewritten in place to its next pass (the earlier round's pick is posted under the pass 2 page's path instead); a pass mark that is no whole number; how a wrapped title looks (walked by eye); the switcher row at 375 (walked by eye); of a look, all but a frame's paper, ink, nav bar, one button's corner and font (so spacing, shadow, soft ink, line, surface and primary), Moss's dark set, and print; an option name that holds a double quote or a backslash; aria-pressed once the attribute is set by hand; a shell rule keyed on a look attribute being there, whatever its value. With no Chromium-family browser it prints SKIP and exits 0, or exits 1 under PREVIEW_REQUIRE_BROWSER=1.
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

# build_pages <dir>: layout-1.html to layout-6.html (that many frames), layout-gap.html (six, the third block deleted), pass-2.html and pass-12.html (three, the body marked pass 2 and pass 12), pass-none.html (three, no pass marks), look-5.html (five, with palettes Neutral, Berry and Moss, styles Soft and Sharp, types Sans and Serif), look-one.html (three, one palette, one style, one type), look-creative.html (three, a creative pass with two palettes) and look-other.html (three, no pass marks, look-5's presets and one frame's own radius), from the shipped shell.
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


MARKS = ' data-vd-pass-kind="layout" data-vd-pass="1"'


def marked(text, marks):
    """The page with these pass marks on its body in place of the shell's."""
    assert MARKS in text, "the shell's body does not carry%s" % MARKS
    return text.replace(MARKS, marks)


def write(name, text):
    with open(os.path.join(out, name), "w", encoding="utf-8") as h:
        h.write(text)


# Opens every frame of a look page: the nav bar a palette repaints and a button whose corners a style turns.
APP_BAR = """<div class="vd-nav"><span class="vd-brand">Ledgerly</span> <a href="#" aria-current="page">Invoices</a> <a href="#">Customers</a></div>
<div class="vd-toolbar"><span class="vd-input">Search invoices</span> <span class="vd-btn vd-primary">New invoice</span></div>
"""
# The runner's NEUTRAL, BERRY, BERRY_DARK, MOSS and SERIF hold these values as the browser reports them.
NEUTRAL = 'html[data-vd-palette="Neutral"] .vd-content {}'
BERRY = """html[data-vd-palette="Berry"] .vd-content { --vd-paper: #fff5f8; --vd-surface: #fde7ee; --vd-ink: #3b0a1f; --vd-ink-soft: #7a2e4a; --vd-line: #f3c4d3;
  --vd-primary: #be185d; --vd-on-primary: #ffffff; --vd-nav-bg: #831843; --vd-nav-ink: #fff5f8; --vd-nav-ink-soft: rgba(255, 245, 248, .8); }
html[data-vd-palette="Berry"][data-vd-scheme="dark"] .vd-content { --vd-paper: #1f0a14; --vd-surface: #2b0f1c; --vd-ink: #fde7ee; --vd-ink-soft: #f0a6c0; --vd-line: #5c1f38;
  --vd-primary: #f472b6; --vd-on-primary: #1f0a14; --vd-nav-bg: #4a0d28; --vd-nav-ink: #fde7ee; --vd-nav-ink-soft: rgba(253, 231, 238, .75); }"""
MOSS = """html[data-vd-palette="Moss"] .vd-content { --vd-paper: #f7faf5; --vd-surface: #e9f2e4; --vd-ink: #14230f; --vd-ink-soft: #40573a; --vd-line: #c9dcc0;
  --vd-primary: #3f6212; --vd-on-primary: #ffffff; --vd-nav-bg: #1a2e14; --vd-nav-ink: #f7faf5; --vd-nav-ink-soft: rgba(247, 250, 245, .8); }
html[data-vd-palette="Moss"][data-vd-scheme="dark"] .vd-content { --vd-paper: #10180d; --vd-surface: #1a2615; --vd-ink: #e9f2e4; --vd-ink-soft: #a9c29f; --vd-line: #2f4426;
  --vd-primary: #a3e635; --vd-on-primary: #10180d; --vd-nav-bg: #223319; --vd-nav-ink: #e9f2e4; --vd-nav-ink-soft: rgba(233, 242, 228, .75); }"""
SOFT = 'html[data-vd-style="Soft"] .vd-content { --vd-radius: 12px; --vd-space: 8px; --vd-shadow: 0 2px 6px rgba(0, 0, 0, .08), 0 8px 24px rgba(0, 0, 0, .08); }'
SHARP = 'html[data-vd-style="Sharp"] .vd-content { --vd-radius: 0; --vd-space: 6px; --vd-shadow: none; }'
SANS = 'html[data-vd-type="Sans"] .vd-content {}'
SERIF = 'html[data-vd-type="Serif"] .vd-content { --vd-font: Georgia, "Times New Roman", serif; }'


def look(n, palettes=(), styles=(), types=(), css=""):
    """page(n) with the app bar opening every frame, these rules in the shell's palette, style and type slots, and css closing its custom block."""
    s = page(n).replace('<div class="vd-content">', '<div class="vd-content">' + APP_BAR)
    for slot, rules in (("palettes", palettes), ("styles", styles), ("types", types)):
        assert "/* SLOT: %s */" % slot in s, "the shell has no slot %s" % slot
        s = s.replace("/* SLOT: %s */" % slot, "\n".join(rules))
    assert s.count("</style>\n</head>") == 1, "the shell's custom block does not close the head"
    return s.replace("</style>\n</head>", css + "\n</style>\n</head>")


for n in range(1, 7):
    write("layout-%d.html" % n, page(n))
write("layout-gap.html", page(6, drop="C"))
write("pass-2.html", marked(page(3), ' data-vd-pass-kind="layout" data-vd-pass="2"'))
write("pass-none.html", marked(page(3), ""))
write("pass-12.html", marked(page(3), ' data-vd-pass-kind="layout" data-vd-pass="12"'))
write("look-5.html", look(5, [NEUTRAL, BERRY, MOSS], [SOFT, SHARP], [SANS, SERIF]))
write("look-one.html", look(3, [BERRY], [SHARP], [SERIF]))
write("look-creative.html", marked(look(3, [NEUTRAL, BERRY]), ' data-vd-pass-kind="creative" data-vd-pass="1"'))
write("look-other.html", marked(look(3, [NEUTRAL, BERRY, MOSS], [SOFT, SHARP], [SANS, SERIF], css="#vd-b .vd-content{--vd-radius:0}"), ""))
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
# Picks as serve.py stored them before rows carried a pass (no "pass" key): B on the page with no pass mark, A on a page marked pass 1.
printf '{"id": "0a1b2c3%s", "ts": "2026-11-01T09:00:00Z", "page": "%s", "kind": "pick", "variant": "%s", "anchor": null, "text": "", "context": {"viewport": {"w": 1280, "h": 800}, "theme": "baseline light", "states": {}, "console": []}, "status": "open", "reply": "", "handed_out": false}\n' \
  d pass-none.html B e layout-2.html A >"$T/docroot/.feedback.jsonl"
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
from urllib.request import ProxyHandler, Request, build_opener

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


def open_page(name, width, static=False):
    """Load a docroot page in a fresh tab at this viewport width: live, returning once its Pick and Note buttons and its check badge are in place, or with ?static=1, once it has loaded."""
    cdp.tab()
    cdp.call("Emulation.setDeviceMetricsOverride", {"width": width, "height": 800, "deviceScaleFactor": 1, "mobile": False})
    cdp.loaded = False
    nav = cdp.call("Page.navigate", {"url": base + quote(name) + ("?static=1" if static else "")})
    if nav.get("errorText"):
        raise RuntimeError("could not load %s: %s" % (name, nav["errorText"]))
    until = time.monotonic() + 15
    while not cdp.loaded:
        cdp.recv(until)
    cdp.call("Page.bringToFront")
    if not static and not wait("!document.getElementById('vd-fb').hidden && !document.getElementById('vd-check-badge').hidden"):
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


NAMED_KEYS = {"Tab": ("Tab", 9, ""), "Enter": ("Enter", 13, "\r"), "Space": (" ", 32, " ")}


def key(char):
    """A real press of one letter or digit key, or of Tab, Enter or Space by name, sent to whatever has focus."""
    if char in NAMED_KEYS:
        value, vk, text = NAMED_KEYS[char]
        ev = {"key": value, "code": char, "windowsVirtualKeyCode": vk}
    else:
        ev, text = {"key": char, "code": ("Digit" if char.isdigit() else "Key") + char.upper(), "windowsVirtualKeyCode": ord(char.upper())}, char
    cdp.call("Input.dispatchKeyEvent", dict(ev, type="keyDown", text=text))
    cdp.call("Input.dispatchKeyEvent", dict(ev, type="keyUp"))


def rows(name):
    """The feedback rows serve.py holds for a page."""
    with opener.open(base + "_feedback?page=" + quote(name), timeout=5) as resp:
        return json.loads(resp.read().decode("utf-8"))["rows"]


def seed_pick(name, letter, number):
    """Store a pick of this frame on this pass number for a page through serve.py, the way the page's own post does."""
    body = json.dumps({"page": name, "kind": "pick", "variant": letter, "pass": number}).encode("utf-8")
    with opener.open(Request(base + "_feedback", body, {"Content-Type": "application/json", "X-Preview-Feedback": "1"}), timeout=5) as resp:
        resp.read()


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
PICK_B = '#vd-b button[aria-label^="Pick variant"]'
PICK, PICKED = ["Pick", "false"], ["Picked", "true"]


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


def pick_states():
    """Each frame's Pick button as [text, aria-pressed], in frame order."""
    return [[b["text"], b["pressed"]] for f in js(FRAMES) for b in f["buttons"] if b["name"].startswith("Pick variant")]


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
    state = pick_states()
    case("a pick on the fourth frame stores D and shows Picked there only",
         marked and picks == ["D"] and state == [["Picked", "true"] if i == 3 else ["Pick", "false"] for i in range(5)],
         "stored picks %s, Pick buttons %s" % (picks, state))


def pick_b(name):
    """Pick the second frame of the open page; returns whether B then reads Picked, and the page's stored picks as [letter, pass]."""
    click(PICK_B)
    shown = wait("document.querySelector(%s).getAttribute('aria-pressed') === 'true'" % json.dumps(PICK_B))
    return shown, [[r["variant"], r.get("pass")] for r in rows(name) if r["kind"] == "pick"]


def posts_the_pass(name, number):
    shown, picks = pick_b(name)
    case("pick posts the pass number", shown and picks[-1:] == [["B", number]],
         "%s is marked pass %d: stored picks as [letter, pass] %s, B reads Picked: %s" % (name, number, picks, shown))


def pick_on_pass_one():
    # The feedback file started with a pick of A for this page that has no pass key (written beside the pages).
    open_page("layout-2.html", 1280)
    state = pick_states()
    case("a stored pick that has no pass is not picked on a page marked pass 1", state == [PICK] * 2, "Pick buttons %s" % state)
    posts_the_pass("layout-2.html", 1)


def a_new_pass():
    # A pass is written over the path of the one before and rows are kept by path: the earlier round's pick is still stored under this page.
    seed_pick("pass-2.html", "B", 1)
    open_page("pass-2.html", 1280)
    state = pick_states()
    case("pass 2 opens with nothing picked", state == [PICK] * 3, "the one stored pick is B on pass 1; Pick buttons %s" % state)
    posts_the_pass("pass-2.html", 2)
    seed_pick("pass-2.html", "A", 1)
    open_page("pass-2.html", 1280)
    state = pick_states()
    case("a newer pick from another pass leaves nothing picked", state == [PICK] * 3,
         "stored picks are B on pass 1, B on pass 2, then A on pass 1; Pick buttons on the pass 2 page %s" % state)


def note_on_pass_two():
    open_page("pass-2.html", 1280)
    click('#vd-a button[aria-label^="Note on variant"]')
    typing = wait("document.activeElement === document.getElementById('vd-fb-text')")
    key("n")
    click('#vd-fb-box button[type="submit"]')
    sent = wait("document.getElementById('vd-fb-box').hidden")
    notes = [[r["variant"], r["text"], r.get("pass")] for r in rows("pass-2.html") if r["kind"] == "note"]
    case("a note posts the pass number", typing and sent and notes == [["A", "n", 2]],
         "stored notes as [letter, text, pass] %s; the note box took focus: %s, closed after Send: %s" % (notes, typing, sent))


def an_unmarked_page():
    # The feedback file started with a pick of B for this page that has no pass key (written beside the pages).
    open_page("pass-none.html", 1280)
    state = pick_states()
    case("a page with no pass mark shows a stored pick that has no pass", state == [PICK, PICKED, PICK], "Pick buttons %s" % state)


def pick_on_a_refused_mark():
    # serve.py stores a pass outside 1 to 9 as none: a page that kept 12 as its own pass would never match the row its pick left.
    open_page("pass-12.html", 1280)
    shown, picks = pick_b("pass-12.html")
    case("a pick on a page marked pass 12 is stored with no pass and reads Picked", shown and picks == [["B", None]],
         "stored picks as [letter, pass] %s, B reads Picked: %s" % (picks, shown))


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


LOOK = "look-5.html"
# Per frame: its content's paper and ink, its nav bar's fill and text, its button's corner, its font. Then the shell's own parts: the header's paper, ink, rule, font and a control's corner, and per frame its paper, title, badge, caption, tradeoff list and corner.
LOOK_PROBE = """(() => {
  const css = (el, p) => getComputedStyle(el).getPropertyValue(p);
  const frames = Array.from(document.querySelectorAll('.vd-frame')), header = document.getElementById('vd-header');
  return {
    look: ['palette', 'style', 'type'].map(k => document.documentElement.getAttribute('data-vd-' + k)),
    frames: frames.map(f => { const c = f.querySelector('.vd-content'), nav = c.querySelector('.vd-nav');
      return { colours: [css(c, 'background-color'), css(c, 'color'), css(nav, 'background-color'), css(nav, 'color')],
               corner: css(c.querySelector('.vd-btn'), 'border-top-left-radius'), font: css(c, 'font-family') }; }),
    shell: [css(header, 'background-color'), css(header, 'color'), css(header, 'border-bottom-color'), css(header, 'font-family'),
            css(header.querySelector('.vd-seg'), 'border-top-left-radius')].concat(frames.flatMap(f => {
      const h = f.querySelector('h2'), cap = f.querySelector('.vd-caption'), t = f.querySelector('.vd-tradeoffs');
      return [css(f, 'background-color'), css(f, 'border-top-left-radius'), css(h, 'background-color'), css(h.querySelector('.vd-badge'), 'background-color'),
              css(cap, 'color'), css(cap, 'font-family'), css(t, 'background-color'), css(t, 'color'), css(t, 'font-family')]; }))
  };
})()"""
# Each switcher in page order: its kind, role, accessible name, the text drawn just left of it, its box, and its options as [name, text, aria-pressed].
SWITCHERS = """Array.from(document.querySelectorAll('[data-vd-switcher]')).map(g => { const r = g.getBoundingClientRect();
  return { kind: g.dataset.vdSwitcher, role: g.getAttribute('role'), name: g.getAttribute('aria-label'),
           label: document.elementFromPoint(r.left - 14, r.top + r.height / 2).textContent, left: r.left, top: r.top,
           options: Array.from(g.querySelectorAll('button')).map(b => [b.dataset.vdOption, b.textContent, b.getAttribute('aria-pressed')]) }; })"""
# The switcher button that has focus as [kind, option], or null when focus is anywhere else.
AT_OPTION = """(() => { const a = document.activeElement, g = a && a.closest('[data-vd-switcher]');
  return g && a.localName === 'button' ? [g.dataset.vdSwitcher, a.dataset.vdOption] : null; })()"""
# A frame's content paper, ink, nav bar and nav text under the shell's neutrals and under the palettes build_pages writes.
NEUTRAL = ["rgb(255, 255, 255)", "rgb(24, 24, 27)", "rgb(24, 24, 27)", "rgb(255, 255, 255)"]
BERRY = ["rgb(255, 245, 248)", "rgb(59, 10, 31)", "rgb(131, 24, 67)", "rgb(255, 245, 248)"]
BERRY_DARK = ["rgb(31, 10, 20)", "rgb(253, 231, 238)", "rgb(74, 13, 40)", "rgb(253, 231, 238)"]
MOSS = ["rgb(247, 250, 245)", "rgb(20, 35, 15)", "rgb(26, 46, 20)", "rgb(247, 250, 245)"]
SERIF = 'Georgia, "Times New Roman", serif'
OPTIONS = [["palette", ["Neutral", "Berry", "Moss"]], ["style", ["Soft", "Sharp"]], ["type", ["Sans", "Serif"]]]


def switch(kind, name):
    """Click one option of one switcher."""
    click('[data-vd-switcher="%s"] [data-vd-option="%s"]' % (kind, name))


def listed(switchers=None):
    """Switchers as [kind, option names] in page order: the open page's, or those of a SWITCHERS answer already read."""
    return [[s["kind"], [o[0] for o in s["options"]]] for s in (js(SWITCHERS) if switchers is None else switchers)]


def colours(probe):
    return [f["colours"] for f in probe["frames"]]


def moved(before, after):
    """The positions of the shell's own values that differ between two probes."""
    return [i for i, (a, b) in enumerate(zip(before["shell"], after["shell"])) if a != b]


def palette_restyles():
    open_page(LOOK, 1280)
    before = js(LOOK_PROBE)
    switch("palette", "Berry")
    after = js(LOOK_PROBE)
    pressed = [o[2] for o in js(SWITCHERS)[0]["options"]]
    case("palette restyles every frame and not the header",
         colours(before) == [NEUTRAL] * 5 and colours(after) == [BERRY] * 5 and not moved(before, after)
         and after["look"][0] == "Berry" and pressed == ["false", "true", "false"],
         "per frame [paper, ink, nav bar, nav text] was %s, under Berry %s (want %s); shell values that moved: %s; html says %s, options pressed %s"
         % (colours(before), colours(after), BERRY, moved(before, after), after["look"], pressed))
    click("#vd-scheme-toggle")
    dark = js(LOOK_PROBE)
    case("a palette's dark set paints the frames under the dark scheme", colours(dark) == [BERRY_DARK] * 5 and dark["shell"][0] == "rgb(27, 27, 31)",
         "per frame %s (want %s); the header's paper is %s (want the shell's dark neutral)" % (colours(dark), BERRY_DARK, dark["shell"][0]))


def style_and_type():
    open_page(LOOK, 1280)
    soft = js(LOOK_PROBE)
    switch("style", "Sharp")
    sharp = js(LOOK_PROBE)
    switch("type", "Serif")
    serif = js(LOOK_PROBE)
    corners = [[f["corner"] for f in p["frames"]] for p in (soft, sharp)]
    fonts = [[f["font"] for f in p["frames"]] for p in (sharp, serif)]
    own = soft["shell"][3]
    case("style and type restyle frames only",
         corners == [["12px"] * 5, ["0px"] * 5] and fonts == [[own] * 5, [SERIF] * 5] and own != SERIF
         and not moved(soft, sharp) and not moved(soft, serif) and serif["look"] == ["Neutral", "Sharp", "Serif"],
         "button corners per frame under Soft then Sharp %s; content fonts under Sans then Serif %s against the header's %s; shell values that moved: %s under Sharp, %s under Serif; html says %s"
         % (corners, fonts, own, moved(soft, sharp), moved(soft, serif), serif["look"]))


def labelled_in_order():
    # 2560 wide: a row with no line of its own would fit beside the first row's controls here.
    open_page(LOOK, 2560)
    got = js(SWITCHERS)
    look = js(LOOK_PROBE)["look"]
    first_row = js("document.querySelector('[data-vd-set-mode]').getBoundingClientRect().bottom")
    shown = [[s["kind"], s["role"], s["name"], s["label"]] for s in got]
    lefts, tops = [s["left"] for s in got], [s["top"] for s in got]
    first = [[o[2] for o in s["options"]] for s in got]
    case("switchers are labelled groups in a second row in the order Palette, Style, Type with the first option active",
         shown == [["palette", "group", "Palette", "Palette"], ["style", "group", "Style", "Style"], ["type", "group", "Type", "Type"]]
         and lefts == sorted(lefts) and len(set(tops)) == 1 and tops[0] >= first_row and listed(got) == OPTIONS
         and all(o[0] == o[1] for s in got for o in s["options"])
         and first == [["true", "false", "false"], ["true", "false"], ["true", "false"]] and look == ["Neutral", "Soft", "Sans"],
         "[kind, role, name, text beside it] %s at left edges %s and tops %s, the first row's controls end at %s; options %s; html says %s"
         % (shown, lefts, tops, first_row, [s["options"] for s in got], look))


def by_keyboard():
    open_page(LOOK, 1280)
    stops, kept = [], []
    for _ in range(60):
        key("Tab")
        at = js(AT_OPTION)
        if not at:
            if stops:
                break
            continue
        stops.append(at)
        how = {"Berry": "Enter", "Moss": "Space"}.get(at[1])
        if how:
            js("void (window.vdHeld = document.activeElement)")
            key(how)
            kept.append([how] + js("[document.documentElement.getAttribute('data-vd-palette'), document.activeElement.getAttribute('aria-pressed'),"
                                   " document.activeElement === window.vdHeld]"))
    case("switcher operated by keyboard keeps focus",
         stops == [[kind, name] for kind, names in OPTIONS for name in names]
         and kept == [["Enter", "Berry", "true", True], ["Space", "Moss", "true", True]],
         "Tab stopped on %s; each press as [key, html palette after it, the focused button's aria-pressed, focus still on that button] %s" % (stops, kept))


def no_reload():
    open_page(LOOK, 1280)
    js("void (window.vdStayed = true)")
    was = js("[location.href, history.length]")
    cdp.loaded = False
    for kind, name in (("palette", "Berry"), ("style", "Sharp"), ("type", "Serif")):
        switch(kind, name)
    # A reload asked for by a click replaces the document a few milliseconds later, so the mark is read after that window.
    gone = wait("window.vdStayed !== true", 300)
    now = js("[location.href, history.length]")
    look = js(LOOK_PROBE)["look"]
    case("option change does not reload", look == ["Berry", "Sharp", "Serif"] and not gone and not cdp.loaded and now == was,
         "html says %s; the mark set before the clicks is gone: %s; a load event fired: %s; [address, history length] was %s, is %s"
         % (look, gone, cdp.loaded, was, now))


def one_option():
    open_page("look-one.html", 1280)
    got = [listed(), js(LOOK_PROBE)["look"]]
    case("one-option switcher hidden", got == [[], [None, None, None]],
         "one palette, one style and one type are authored: switchers shown %s, html says %s" % tuple(got))


def creative_pass():
    open_page("look-creative.html", 1280)
    got = listed()
    case("a creative pass shows the switcher with two options and none for a kind with no options", got == [["palette", ["Neutral", "Berry"]]],
         "two palettes, no style and no type are authored: switchers shown %s" % got)


def another_pass_kind():
    # The page carries look-5's presets and no pass marks, and its second frame alone sets its own radius, as a theme-axis pass does.
    open_page("look-other.html", 1280)
    probe = js(LOOK_PROBE)
    got = [listed(), probe["look"]]
    case("a page of another pass kind shows no switcher row", got == [[], [None, None, None]], "switchers shown %s, html says %s" % tuple(got))
    corners = [f["corner"] for f in probe["frames"]]
    case("a per-frame preset still turns one frame only", corners == ["8px", "0px", "8px"], "button corners per frame %s" % corners)


def static_page():
    open_page(LOOK, 1280, static=True)
    got = listed()
    case("a page loaded with ?static=1 lists its switchers", got == OPTIONS, "switchers shown %s" % got)
    before = js(LOOK_PROBE)
    js("document.documentElement.setAttribute('data-vd-palette', 'Moss')")
    after = js(LOOK_PROBE)
    case("static page honours the palette attribute", colours(before) == [NEUTRAL] * 5 and colours(after) == [MOSS] * 5 and not moved(before, after),
         "per frame [paper, ink, nav bar, nav text] was %s, with data-vd-palette set to Moss %s (want %s); shell values that moved: %s"
         % (colours(before), colours(after), MOSS, moved(before, after)))


cdp = None
try:
    cdp = Browser()
    for n in range(1, 7):
        group("layout-%d.html at 375" % n, lambda: each_count(n))
    group("six frames at 1280", rows_at_1280)
    group("wrapped title buttons", wrapped_title)
    group("a middle frame removed", middle_frame_removed)
    group("a pick on pass 1", pick_on_pass_one)
    group("a new pass", a_new_pass)
    group("a note on pass 2", note_on_pass_two)
    group("a page with no pass mark", an_unmarked_page)
    group("a pass mark outside 1 to 9", pick_on_a_refused_mark)
    group("number keys", number_keys)
    group("a key past the last frame", key_past_the_last)
    group("Flip mode", flip_mode)
    group("palette restyles every frame and not the header", palette_restyles)
    group("style and type restyle frames only", style_and_type)
    group("switchers are labelled groups in order", labelled_in_order)
    group("switcher operated by keyboard keeps focus", by_keyboard)
    group("option change does not reload", no_reload)
    group("one-option switcher hidden", one_option)
    group("a creative pass", creative_pass)
    group("a page of another pass kind", another_pass_kind)
    group("static page honours the palette attribute", static_page)
except Exception as exc:
    case("browser start", False, "%s: %s" % (type(exc).__name__, exc))
finally:
    if cdp:
        cdp.close()

print("shell-controls tests: %d passed, %d failed" % (passed, failed))
sys.exit(1 if failed else 0)
PY
