#!/usr/bin/env bash
# Drives frame.js in headless Chrome: fixture pages under isolate.py's own segments, policy and injection, framed by a fixture parent that keeps every message the viewer would get. Storage, the pick stand-in, hash, blocked hosts, links, note mode, commands, a static page, the top-level bounce; browser_lib.py's exit 4 where no browser starts.
# Misses: serve.py and the viewer (serve.test.sh, viewer.test.sh); Firefox and Safari; a hostile page, which frame.js cannot hold (attack.test.sh).
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export TMPDIR="$tmp" PYTHONDONTWRITEBYTECODE=1

printf '#!/bin/sh\nexit 1\n' > "$tmp/dies"; chmod +x "$tmp/dies"
for exe in /nonexistent "$tmp/dies"; do
  for need in 0 1; do
    want=SKIP; [ "$need" = 0 ] || want=FAIL
    rc=0; out="$(DESIGN_KIT_BROWSER="$exe" DESIGN_KIT_REQUIRE_BROWSER="$need" python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import browser_lib
with browser_lib.browser(): print("started")' "$here/__tests__" 2>&1)" || rc=$?
    case "$rc:$out" in "4:$want: "*) ;; *) echo "FAIL: a browser that cannot start ($exe, DESIGN_KIT_REQUIRE_BROWSER=$need): want exit 4 and $want, got exit $rc: $out"; exit 1 ;; esac
  done
done

rc=0
python3 - "$here" <<'PY' || rc=$?
import http.server, importlib.util, json, os, re, sys, threading, time
from urllib.parse import unquote, urlsplit

here = sys.argv[1]
sys.path.insert(0, os.path.join(here, "__tests__"))
import browser_lib

spec = importlib.util.spec_from_file_location("dkisolate", os.path.join(here, "isolate.py"))
iso = importlib.util.module_from_spec(spec)
spec.loader.exec_module(iso)
with open(os.path.join(here, "frame.js"), "rb") as fh:
    SOURCE = fh.read()
CLIENT = b"<script data-design-kit-frame>" + SOURCE + b"</script>"
bad = []

def eq(name, fn, want):
    try:
        got = fn() if callable(fn) else fn
    except Exception as exc:
        got = repr(exc)
    print("ok: " + name if got == want else "FAIL: %s: got %.400s, want %.400s" % (name, json.dumps(got), json.dumps(want)))
    if got != want:
        bad.append(name)

STATE, LINKS, NOTES, OWN = "boards/state.html", "decks/links.html", "artifacts/notes.html", "motion/a b/index.html"
KEPT = "design-kit:/" + STATE
PAGES = {
    STATE: "<title>state</title><script>window.early = [typeof localStorage.getItem, localStorage.getItem('seeded')]</script></head><body><h1>state</h1>",
    OWN: "<title>own</title><script>console.error('page script ran'); new Image().src = 'ran.png'</script></head><body><h1>own</h1>",
    "boards/older.html": "<title>older</title></head><body><h1>older</h1>" + CLIENT.decode(),
    LINKS: """<title>links</title><style>a { display: block; width: 300px; font: 14px/18px sans-serif } svg { display: block }</style></head><body>
<a id="out" href="https://out.example/p?q=1#h">out</a><a id="blank" target="_blank" href="http://blank.example/">blank</a>
<div onclick="event.stopPropagation()"><a id="stopped" href="https://stopped.example/">stopped</a></div>
<a id="handled" href="https://handled.example/">handled</a><a id="late" href="https://late.example/">late</a>
<a id="js" href="javascript:void 0">js</a><a id="data" href="data:text/html,x">data</a><a id="file" href="file:///etc/hosts">file</a><a id="tel" href="tel:123">tel</a>
<a id="rel" href="other.html?x=1#/2">rel</a><a id="abs" href="/boards/b.html">abs</a><a id="hash" href="#sec">hash</a><a id="mail" href="mailto:a@b.example">mail</a>
<a id="save" download="x.txt" href="data:text/plain,x">save</a><a id="blob" download="y.txt">blob</a><a id="own" download href="data.json">own</a><a id="long" href="https://long.example/__LONG__">long</a><a id="most" href="https://most.example/__MOST__">most</a>
<svg width="60" height="20"><a id="svg" href="https://svg.example/"><rect width="60" height="20"/></a></svg><a id="ctrl" href="https://ctrl.example/">ctrl</a><a id="middle" href="https://middle.example/">middle</a><a id="right" href="https://right.example/">right</a><a id="edited" contenteditable="true" href="https://edited.example/">edited</a><a id="last" href="https://last.example/">last</a>
<script>document.querySelector('#blob').href = URL.createObjectURL(new Blob(['y'])); document.addEventListener('click', (e) => { if (e.target.id === 'handled') e.preventDefault(); }); window.addEventListener('click', (e) => { if (e.target.id === 'late') e.preventDefault(); });</script>"""
    .replace("__LONG__", "x" * (2049 - len("https://long.example/"))).replace("__MOST__", "x" * (2048 - len("https://most.example/"))),
    NOTES: """<title>notes</title><style>body { margin: 0; min-height: 2000px } p, button, input, li { display: block; margin: 10px; width: 200px; height: 30px; box-sizing: border-box }</style></head><body data-theme="dark"><p id="words" tabindex="0" data-card="one">Hello  <b>there</b></p><button id="go">Go</button><input id="field"><ul><li>first</li><li id="twice">second</li><li id="twice" data-kind="a&quot;b">third</li></ul>
<script>window.clicks = []; window.keys = [];
for (const t of ['mousedown', 'click']) document.addEventListener(t, (e) => clicks.push(t + ' ' + e.target.id));
document.addEventListener('keydown', (e) => keys.push([e.key, e.defaultPrevented]));
addEventListener('beforeprint', () => { window.printed = (window.printed || 0) + 1; }); window.heard = []; addEventListener('message', (e) => heard.push(e.data));</script>""",
}
PARENT = """<!doctype html><title>parent</title><body style="margin:0"><script>
let frame, win; const got = [];
addEventListener('message', (e) => {
  if (e.data === 'reload the tab') location.reload();
  if (e.source !== win || !e.data || e.data.dk !== 1) return;
  got.push(e.data);
  if (e.data.t === 'store') sessionStorage.last = JSON.stringify(e.data);
});
function show(src, store, name) {
  if (frame) frame.remove();
  got.length = 0;
  frame = document.createElement('iframe');
  frame.setAttribute('sandbox', 'allow-scripts allow-forms allow-modals allow-downloads');
  frame.name = name === undefined ? JSON.stringify({ dk: 1, store: store }) : name;
  frame.style.cssText = 'position:absolute;left:40px;top:60px;width:800px;height:560px;border:0';
  frame.src = src;
  document.body.append(frame);
  win = frame.contentWindow;
}
function say(m) { win.postMessage(Object.assign({ dk: 1 }, m), '*'); }
function reports(t) { return got.filter((m) => m.t === t); }
</script>"""
asked = []

class Fixture(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_GET(self):
        asked.append(self.path)
        host, path = self.headers["Host"], urlsplit(self.path).path
        body, policy = PARENT, "frame-src http://%s/_c/" % host
        if path.startswith("/_c/"):
            seg, _, rest = path[4:].partition("/")
            opened, rest = iso.open_segment(seg), unquote(rest)
            if not opened or rest != opened[1]:
                return self.send_error(404)
            body = ("<!doctype html><html lang=\"en\"><head>" + PAGES[rest]).encode()
            body = body if urlsplit(self.path).query == "bare" else iso.inject(body, CLIENT)
            policy = iso.page_policy(opened[0], rest, seg, [], host)
        elif path == "/saved.html":
            body, policy = b"<!doctype html><head>" + CLIENT, ""
        elif path != "/parent":
            body, policy = "<!doctype html><title>page URL</title>", ""
        body = body.encode() if isinstance(body, str) else body
        self.send_response(200)
        for name, value in (("Content-Type", "text/html; charset=utf-8"), ("Content-Security-Policy", policy), ("Content-Length", str(len(body))), ("Cache-Control", "no-store")) + iso.COMMON:
            self.send_header(name, value)
        self.end_headers()
        self.wfile.write(body)

def framed(b, page, store=None, mode="f", after=""):
    tab = b.page(BASE + "/parent")
    tab.evaluate("show(%s, %s)" % (json.dumps(iso.content_url(page, mode) + after), json.dumps(store or {})))
    tab.wait("reports('ready').length", 2)
    return tab, tab.frame()

def reports(tab, kind, *fields):
    """What the frame reported of this kind: one field's values, or each report's several."""
    return [m.get(fields[0]) if len(fields) == 1 else [m.get(f) for f in fields] for m in tab.evaluate("reports(%s)" % json.dumps(kind))]

def stores(tab):
    return [m.get("items") or ("clear" if m.get("clear") is True else m) for m in tab.evaluate("reports('store')")]

def tabs(b):
    return sorted(t["url"] for t in b.chrome.call("Target.getTargets")["targetInfos"] if t["type"] == "page" and t["url"].startswith("http"))

TRY = "const t = (f) => { try { f(); return 'ok'; } catch (e) { return e instanceof DOMException ? e.name : String(e); } };"
WRITES = "localStorage.clear(); let n = 0; const from = performance.now(), tick = () => { localStorage.took = performance.now() - from; localStorage.setItem('count', String(++n)); if (n < 120) setTimeout(tick, 8); else { %s; } }; tick(); 1"
DECISION = "fetch(%s).then(async (r) => [r.status, r.ok, await r.text()])"
POST = "method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Design-Kit-Decision': '1' }, body: JSON.stringify({ board: 'other.html', picked: 2, knobs: { all: { space: 8 } }, text: {}, prompt: 'run this', extra: 1 })"
NOT_RECORDED = [409, False, '{"recorded":false}']

def files():
    eq("frame.js is at most 12 KB", len(SOURCE) <= 12 * 1024, True)
    eq("frame.js holds nothing that ends or escapes its script element", re.findall(rb"(?i)</script|<script|<!--", SOURCE), [])
    code = b"\n".join(l for l in SOURCE.splitlines() if not l.startswith(b"//"))
    eq("frame.js is one function that stops where a client already runs", bool(re.fullmatch(rb"\(function \(\) \{\s+if \(window\.__designKitFrame\) return; window\.__designKitFrame = true;.*\}\)\(\);\s*", code, re.S)), True)
    eq("frame.js has at most three header lines and the pointer", [l.startswith(b"//") for l in SOURCE.splitlines()[:5]].count(True) <= 4, True)

def storage(b):
    tab, f = framed(b, STATE, {"seeded": "yes", KEPT: "knobs"})
    eq("the frame's origin is null", lambda: f.evaluate("self.origin"), "null")
    eq("the client runs before the page's first script", lambda: f.evaluate("window.early"), ["function", "yes"])
    eq("localStorage seeded from window.name reads back", lambda: f.evaluate(
        "[localStorage.getItem('seeded'), localStorage.seeded, 'seeded' in localStorage, localStorage.length, Object.keys(localStorage).sort(), localStorage.key(0), localStorage.getItem('none'), localStorage.none === undefined, 'none' in localStorage]"),
       ["yes", "yes", True, 2, sorted(["seeded", KEPT]), "seeded", None, True, False])
    eq("a key holding the content path reads what was stored without it", lambda: f.evaluate("localStorage.getItem('design-kit:' + location.pathname)"), "knobs")
    f.evaluate("localStorage.setItem('design-kit:' + location.pathname, 'moved'); 1")
    eq("a key holding the content path is stored without it", lambda: (tab.wait("reports('store').length"), stores(tab), f.evaluate("Object.keys(localStorage).sort()"))[1:], ([[[KEPT, "moved"]]], sorted(["seeded", KEPT])))
    eq("a key set, read and deleted as a property", lambda: f.evaluate("localStorage.theme = 1; const was = localStorage.theme; delete localStorage.seeded; [was, localStorage.getItem('theme'), localStorage.getItem('seeded')]"), ["1", "1", None])
    eq("a deleted key is reported as null", lambda: (tab.wait("reports('store').length > 1"), stores(tab)[1:])[1], [[["theme", "1"], ["seeded", None]]])
    tab.evaluate("got.length = 0")
    f.evaluate("localStorage.setItem('a', '1'); localStorage.clear(); localStorage.clear(); localStorage.setItem('b', '2'); 1")
    eq("clear() is one message, before what is written after it", lambda: (tab.wait("reports('store').length > 1"), stores(tab))[1], ["clear", [["b", "2"]]])
    f.evaluate("sessionStorage.setItem('only', 'here'); sessionStorage.x = '1'; localStorage.setItem('c', '3'); 1")
    eq("sessionStorage is memory only", lambda: (tab.wait("reports('store').length > 2"), stores(tab)[2:], f.evaluate("[sessionStorage.getItem('only'), sessionStorage.length, localStorage.getItem('only')]"))[1:], ([[["c", "3"]]], ["here", 2, None]))
    tab.evaluate("got.length = 0; say({ t: 'storefull', k: 'b' }); say({ t: 'storefull', k: 'none' }); say({ t: 'ping', n: 1 })")
    tab.wait("reports('pong').length")
    f.evaluate("localStorage.setItem('c', '4'); 1")
    eq("a key the viewer could not save goes out again with the next write", lambda: (tab.wait("reports('store').length"), stores(tab))[1], [[["b", "2"], ["c", "4"]]])
    tab.evaluate("got.length = 0")
    f.evaluate("localStorage.setItem('c', '5'); 1")
    tab.evaluate("say({ t: 'ping', n: 1 })")
    eq("a ping brings the waiting writes before its pong", lambda: (tab.wait("reports('pong').length"), tab.evaluate("got.map((m) => m.t)"))[1], ["store", "pong"])
    eq("a write past 256 KB throws QuotaExceededError and the page goes on", lambda: f.evaluate(
        TRY + "const k = 256 * 1024; localStorage.clear(); [t(() => localStorage.setItem('k', 'x'.repeat(k - 1))), t(() => localStorage.setItem('k', 'x'.repeat(k))), localStorage.getItem('k').length, t(() => localStorage.setItem('j', '')), t(() => { localStorage.j = 1; }), localStorage.length,"
        " t(() => localStorage.setItem('k', 'small')), t(() => localStorage.setItem('j', 'y'.repeat(k - 7))), t(() => localStorage.setItem('j', 'y'.repeat(k - 6))), (localStorage.removeItem('k'), t(() => localStorage.setItem('j', 'y'.repeat(k - 1)))), t(() => localStorage.setItem('j', '1'))]"),
       ["ok", "QuotaExceededError", 262143, "QuotaExceededError", "QuotaExceededError", 1, "ok", "ok", "QuotaExceededError", "ok", "ok"])
    eq("a key past 256 characters is refused", lambda: f.evaluate("[t(() => localStorage.setItem('k'.repeat(256), '1')), t(() => localStorage.setItem('k'.repeat(257), '1'))]"), ["ok", "QuotaExceededError"])
    tab.evaluate("got.length = 0")

    f.evaluate(WRITES % "location.reload()")
    tab.wait("reports('ready').length", 10)
    sent = [dict(items) for items in stores(tab) if items != "clear" and "count" in dict(items)]
    eq("last of 120 writes survives pagehide", lambda: sent[-1]["count"], "120")
    eq("120 writes are sent at most every 100 ms, the latest value of each key", lambda: 4 <= len(sent) <= float(sent[-1]["took"]) / 100 + 2, True)
    f = tab.frame()
    eq("a page that reloads itself reads its last write, and its sessionStorage is gone", lambda: f.evaluate("[localStorage.count, sessionStorage.length]"), ["120", 0])
    f.evaluate("addEventListener('beforeunload', () => localStorage.setItem('late', 'kept')); location.reload(); 1")
    eq("a write from the page's own beforeunload handler is sent and survives its reload", lambda: (tab.wait("reports('ready').length > 1"), stores(tab)[-1], tab.frame().evaluate("localStorage.late"))[1:], ([["late", "kept"]], "kept"))
    tab.frame().evaluate(WRITES % "parent.postMessage('reload the tab', '*')")
    eq("last of 120 writes survives a tab reload", lambda: (tab.wait("!got.length && !frame", 10), tab.evaluate("JSON.parse(sessionStorage.last).items.find((i) => i[0] === 'count')"))[1], ["count", "120"])

    for name, seed in (("no name", ""), ("a name that is not JSON", "{"), ("JSON null", "null"), ("another object", '{"store":{"a":"1"}}'), ("no store", '{"dk":1}'), ("values that are not text", '{"dk":1,"store":{"a":1,"b":null,"c":{}}}')):
        tab.evaluate("show(%s, {}, %s)" % (json.dumps(iso.content_url(STATE, "f")), json.dumps(seed)))
        eq("a seed of %s leaves an empty storage that works" % name, lambda: (tab.wait("reports('ready').length"), tab.frame().evaluate("const n = localStorage.length; localStorage.setItem('a', '2'); [n, localStorage.a]"))[1], [0, "2"])

def sends(b):
    tab, f = framed(b, STATE)
    eq("a POST to /_decision answers 409 and not recorded", lambda: f.evaluate(DECISION % ("'/_decision', { %s }" % POST)), NOT_RECORDED)
    eq("a POST to /_decision is one pick message of picked, knobs and text", lambda: (tab.wait("reports('pick').length"), tab.evaluate("reports('pick')"))[1], [{"dk": 1, "t": "pick", "picked": 2, "knobs": {"all": {"space": 8}}, "text": {}}])
    tab.evaluate("got.length = 0")
    for form in ("new Request('/_decision', { %s })" % POST, "new URL('/_decision', location.href), { %s }" % POST.replace("POST", "post"), "location.origin + '/_decision?x', { %s }" % POST):
        eq("so is " + form[:30], lambda: f.evaluate(DECISION % form), NOT_RECORDED)
    eq("a body that is not a pick answers the same", lambda: [f.evaluate(DECISION % "'/_decision', { method: 'POST', body: '%s' }" % body) for body in ("{", "null")], [NOT_RECORDED] * 2)
    eq("any other fetch is the browser's own", lambda: f.evaluate("Promise.all([fetch('/_decision'), fetch('/_note', { method: 'POST' }), fetch('https://out.example/_decision', { method: 'POST' })].map((p) => p.then((r) => r.status, (e) => e.name)).concat(fetch('data:,hi').then((r) => r.text())))"), ["TypeError", "TypeError", "TypeError", "hi"])
    eq("only the three posts were picks, and none reached the server", lambda: (reports(tab, "pick", "picked"), [p for p in asked if "_decision" in p or "_note" in p]), ([2, 2, 2], []))

def hashes(b):
    tab, f = framed(b, STATE, after="?still=1#/7")
    eq("ready carries the hash", lambda: reports(tab, "ready", "hash"), ["#/7"])
    seen = []
    for step, want in (("history.replaceState(null, '', '#/3')", "#/3"), ("history.pushState(null, '', '#board=2')", "#board=2"), ("location.hash = 'a.b_c-%20&d'", "#a.b_c-%20&d"),
                       ("location.hash = 'a:b'", None), ("location.hash = 'x'.repeat(129)", None), ("location.hash = 'x'.repeat(128)", "#" + "x" * 128), ("History.prototype.replaceState.call(history, null, '', location.pathname + '?still=1')", "#")):
        f.evaluate(step + "; 1")
        if want:
            seen.append(want)
            tab.wait("reports('hash').length >= %d" % len(seen))
        else:
            time.sleep(0.2)
    eq("replaceState, pushState and location.hash report the hash, one out of shape reports nothing", lambda: reports(tab, "hash", "hash"), seen)
    f.evaluate("for (let i = 0; i < 60; i++) history.replaceState(null, '', '#/' + i); 1")
    eq("60 changes at once report the last", lambda: (tab.wait("reports('hash').length > %d" % len(seen)), reports(tab, "hash", "hash")[len(seen):])[1], ["#/59"])

def blocked(b):
    tab, f = framed(b, STATE)
    img = "new Image().src = '%s';"
    f.evaluate(img % "https://one.example/a.png" + "1")
    eq("a blocked https image reports its host and kind", lambda: (tab.wait("reports('blocked').length"), reports(tab, "blocked", "host", "kind"))[1], [["one.example", "img"]])
    f.evaluate(img % "https://one.example/a.png" + img % "https://one.example/b.png" + img % "http://plain.example/a.png" + img % "https://port.example:8443/a.png" + """
      const add = (tag, o) => document.head.append(Object.assign(document.createElement(tag), o));
      add('script', { src: 'https://one.example/a.js' }); add('link', { rel: 'stylesheet', href: 'https://one.example/a.css' }); add('video', { src: 'https://one.example/a.mp4' });
      new FontFace('f', "url('https://one.example/a.woff2')").load().catch(() => {}); fetch('https://connect.example/').catch(() => {});
      document.dispatchEvent(new SecurityPolicyViolationEvent('securitypolicyviolation', { blockedURI: 'https://forged.example/a.png', effectiveDirective: 'img-src', bubbles: true })); 1""")
    tab.wait("reports('blocked').length > 4")
    f.evaluate("".join(img % ("https://h%d.example/" % n) for n in range(2, 13)) + "1")
    tab.wait("reports('blocked').length > 13")
    f.evaluate("add('script', { src: 'https://h2.example/a.js' }); 1")
    tab.wait("reports('blocked').some((m) => m.host === 'h2.example' && m.kind === 'script')")
    told = reports(tab, "blocked", "host", "kind")
    eq("each kind of a host is reported once", lambda: sorted(k for h, k in told if h == "one.example"), ["font", "img", "media", "script", "style"])
    eq("http, a port, a fetch and a forged event report nothing", lambda: [h for h, _ in told if not re.fullmatch(r"(one|h\d+)\.example", h)], [])
    eq("at most 10 hosts are reported, and a known one may gain a kind", lambda: (len({h for h, _ in told}), told[-1]), (10, ["h2.example", "script"]))

def links(b):
    tab, f = framed(b, LINKS)
    before = tabs(b)
    f.evaluate("window.alive = 1")
    tab.click(*f.at("#out"))
    eq("an https link click reports it and stays", lambda: (tab.wait("reports('link').length"), reports(tab, "link", "href"), f.evaluate("window.alive"))[1:], (["https://out.example/p?q=1#h"], 1))
    tab.evaluate("got.length = 0")
    tab.click(*f.at("#js"))
    for link in ("js", "blank", "stopped", "handled", "late", "data", "file", "tel", "rel", "abs", "hash", "mail", "save", "blob", "own", "long", "most", "svg", "edited"):
        tab.click(*f.at("#" + link))
    tab.click(*f.at("#ctrl"), mods="Control")
    tab.click(*f.at("#middle"), button="middle")
    tab.click(*f.at("#right"), button="right")
    tab.click(*f.at("#last"))
    tab.wait("reports('link').some((m) => m.href.includes('last'))")
    here_url = BASE + "/"
    eq("javascript:, data:, file:, tel:, a link the page handled or is editing, a hash and an over-long address report nothing; the rest report once, the content path removed", lambda: [h[:60] for h in reports(tab, "link", "href")],
       ["http://blank.example/", "https://stopped.example/", here_url + "decks/other.html?x=1#/2", here_url + "boards/b.html", "mailto:a@b.example", here_url + "decks/data.json", "https://most.example/" + "x" * 39, "https://svg.example/", "https://ctrl.example/", "https://middle.example/", "https://last.example/"])
    eq("the page stays through every click, and its links keep their target", lambda: f.evaluate("[window.alive, location.hash, document.querySelector('#out').hasAttribute('target'), document.querySelector('#blank').target]"), [1, "#sec", False, "_blank"])
    eq("no click opened a tab, and the downloads began", lambda: (tabs(b), b.chrome.downloads), (before, ["x.txt", "y.txt"]))
    tab.evaluate("got.length = 0")
    f.evaluate("document.querySelector('#out').focus(); 1")
    tab.key("Enter")
    eq("Enter on a link reports it", lambda: (tab.wait("reports('link').length"), reports(tab, "link", "href"))[1], ["https://out.example/p?q=1#h"])

def notes(b):
    tab, f = framed(b, NOTES)
    outline = "(() => { const e = document.querySelector('[data-design-kit-note]'); if (!e) return null; const r = e.getBoundingClientRect(); return [r.left, r.top, r.width, r.height]; })()"
    words = {"selector": "#words", "tag": "p", "text": "Hello there", "rect": {"x": 10, "y": 10, "w": 200, "h": 30}}
    tab.hover(*f.at("#words")); tab.click(*f.at("#go"))
    tab.evaluate("win.postMessage({ t: 'notes', on: true }, '*')")
    f.evaluate("window.postMessage({ dk: 1, t: 'notes', on: true }, '*'); window.postMessage({ dk: 1, t: 'ping', n: 9 }, '*'); window.dispatchEvent(new MessageEvent('message', { source: parent, data: { dk: 1, t: 'notes', on: true } })); const n = document.createElement('iframe'); n.srcdoc = '<script>parent.postMessage({ dk: 1, t: \"notes\", on: true }, \"*\")<\\/script>'; document.body.append(n); new Promise((r) => { n.onload = () => setTimeout(r, 100, 1); })")
    tab.hover(*f.at("#words")); tab.click(*f.at("#go")); tab.key("Enter")
    eq("note mode off: no outline, no anchor, and the page gets its clicks, whoever else says notes", lambda: (f.evaluate(outline), tab.evaluate("got.map((m) => m.t)"), f.evaluate("clicks.filter((c) => c === 'click go').length")), (None, ["ready"], 3))
    f.evaluate("document.querySelector('iframe').remove(); document.activeElement.blur(); clicks.length = heard.length = 0")
    tab.evaluate("say({ t: 'notes', on: true }); say({ t: 'ping', n: 4 })")
    tab.wait("reports('pong').length")
    tab.key("Enter")
    tab.hover(*f.at("#words"))
    eq("note mode outlines on hover", lambda: f.wait(outline), [10, 10, 200, 30])
    f.evaluate("scrollTo(0, 4)")
    eq("the outline follows a scroll", lambda: f.wait(outline + "[1] === 6"), True)
    f.evaluate("scrollTo(0, 0)")
    f.evaluate("document.querySelector('#go').click(); document.body.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true })); 1")
    tab.click(*f.at("#words"))
    eq("a click picks the element", lambda: (tab.wait("reports('anchor').length"), reports(tab, "anchor", "anchor"))[1], [words])
    eq("the anchor comes with its context", lambda: reports(tab, "anchor", "context"), [{"viewport": {"w": 800, "h": 560}, "theme": "dark", "console": []}])
    eq("a picking click does not reach the page, a click by script does", lambda: f.evaluate("clicks"), ["click go"])
    f.evaluate("clicks.length = 0")
    tab.key("Tab")
    eq("Tab outlines the focused element", lambda: f.wait("document.activeElement.id === 'go' && " + outline), [10, 50, 200, 30])
    tab.key("Enter"); tab.key("Shift+Tab"); tab.key("Enter")
    eq("Tab then Enter picks an element", lambda: (tab.wait("reports('anchor').length > 2"), [a["selector"] for a in reports(tab, "anchor", "anchor")], f.evaluate("clicks"))[1:], (["#words", "#go", "#words"], []))
    tab.click(45, 600)
    eq("a click beside every element reports no anchor element", lambda: (tab.wait("reports('anchor').length > 3"), reports(tab, "anchor", "anchor")[3:])[1], [None])
    for n in (1, 2, 3):
        tab.click(*f.at("li:nth-child(%d)" % n))
    eq("a selector finds its own element, whatever shares its id", lambda: (tab.wait("reports('anchor').length > 6"), [f.evaluate("document.querySelector(%s).textContent" % json.dumps(a["selector"])) for a in reports(tab, "anchor", "anchor")[4:]])[1], ["first", "second", "third"])
    eq("the viewer's messages do not reach the page's own listeners", lambda: f.evaluate("heard"), [])
    tab.evaluate("got.length = 0; say({ t: 'notes', on: false }); say({ t: 'ping', n: 5 })")
    tab.wait("reports('pong').length")
    tab.hover(*f.at("#words")); tab.click(*f.at("#go")); tab.key("Enter")
    eq("note mode off again: the outline goes and no anchor is sent", lambda: (f.evaluate(outline), reports(tab, "anchor", "anchor"), f.evaluate("clicks")), (None, [], ["mousedown go", "click go", "click go"]))

    tab.evaluate("got.length = 0")
    tab.click(*f.at("#field")); f.evaluate("keys.length = 0")
    tab.key("Alt+n")
    eq("Alt+N in a text field is typing", lambda: (f.evaluate("keys"), tab.evaluate("got")), ([["n", False]], []))
    tab.click(*f.at("#go")); f.evaluate("keys.length = 0")
    tab.key("Alt+n"); tab.key("Escape"); tab.key("Control+p"); tab.key("n")
    eq("Alt+N, Escape and Ctrl+P are reported by name", lambda: (tab.wait("reports('key').length > 2"), reports(tab, "key", "name"))[1], ["notes", "escape", "print"])
    eq("with note mode off the page still gets Escape, never the two chords", lambda: f.evaluate("keys"), [["Escape", False], ["n", False]])
    f.evaluate("dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' })); 1")
    tab.evaluate("say({ t: 'ping', n: 6 })")
    eq("a key made by script is not reported", lambda: (tab.wait("reports('pong').length"), len(reports(tab, "key", "name")))[1], 3)
    eq("nothing printed before the viewer says print", lambda: f.evaluate("window.printed || 0"), 0)
    tab.evaluate("say({ t: 'print' })")
    eq("print prints the page", lambda: f.wait("window.printed"), 1)
    eq("a ping is answered with its number, a ping from the page is not", lambda: reports(tab, "pong", "n"), [6])
    f.evaluate("console.error('dropped'); console.error('y'.repeat(299) + '\U0001f600\U0001f600'); console.error('boom', Object.create(null), new Error('why')); setTimeout(() => { throw new Error('thrown'); }); Promise.reject(new Error('rejected')); document.body.append(Object.assign(new Image(), { src: 'data:image/png,x' })); new Promise((r) => setTimeout(r, 200, 1))")
    tab.evaluate("say({ t: 'ask' })")
    eq("ask is answered with viewport, theme and the last five console lines, once", lambda: (tab.wait("reports('context').length"), [[c["viewport"], c["theme"], sorted(c["console"])] for c in reports(tab, "context", "context")])[1],
       [[{"w": 800, "h": 560}, "dark", ["Uncaught Error: thrown", "boom [object Object] why", "failed to load data:image/png,x", "unhandled rejection: rejected", "y" * 299 + "\U0001f600"]]])
    said = []
    for step in ("delete document.body.dataset.theme; document.documentElement.className = 'darken light'", "document.documentElement.className = ''; document.body.style.background = 'rgb(20, 20, 30)'", "document.body.style.background = ''; document.documentElement.style.colorScheme = 'dark'", "document.documentElement.style.colorScheme = ''"):
        f.evaluate(step + "; 1")
        tab.evaluate("got.length = 0; say({ t: 'ask' })")
        tab.wait("reports('context').length")
        said += [c["theme"] for c in reports(tab, "context", "context")]
    eq("the theme is read from an attribute, a class, the background, then color-scheme", lambda: said, ["light", "dark", "dark", ""])

def elsewhere(b):
    tab, f = framed(b, "boards/older.html")
    eq("a page holding an older copy runs one client", lambda: (f.evaluate("document.querySelectorAll('[data-design-kit-frame]').length"), len(reports(tab, "ready", "hash"))), (2, 1))
    native = "[console.error, history.replaceState].every((fn) => /native code/.test(fn))"
    tab, f = framed(b, STATE, mode="s", after="#/1")
    f.evaluate("localStorage.setItem('a', '1'); history.replaceState(null, '', '#/2'); new Image().src = 'https://one.example/'; 1")
    eq("a static page only installs the stand-ins", lambda: (f.evaluate("[localStorage.a, sessionStorage.length, %s]" % native), f.evaluate(DECISION % ("'/_decision', { %s }" % POST)), time.sleep(0.3), tab.evaluate("got")), (["1", 0, True], NOT_RECORDED, None, []))
    tab = b.page(BASE + iso.content_url(STATE, "s") + "?x=1#/2")
    eq("a static page opens top-level", lambda: tab.evaluate("[self.origin, location.hash, localStorage.length, window.early[0]]"), ["null", "#/2", 0, "function"])
    tab = b.page(BASE + "/saved.html")
    eq("a saved copy outside the content path changes nothing", lambda: tab.evaluate("localStorage.setItem('dk', '1'); [%s, localStorage.constructor === Storage, /native code/.test(fetch), self.origin !== 'null']" % native), [True, True, True, True])

def bounce(b):
    def ran(tab):
        said = [e for e in b.chrome.events if e.get("sessionId") == tab.sid and e["method"] == "Runtime.consoleAPICalled" and e["params"]["args"][0].get("value") == "page script ran"]
        return [len(said), len([p for p in asked if p.endswith("ran.png")])]
    url = BASE + iso.content_url(OWN, "f")
    tab = b.page(url + "?bare")
    eq("without the client a top-level framed page runs and stays", lambda: (tab.wait("location.pathname.startsWith('/_c/')"), time.sleep(0.2), ran(tab)), (True, None, [1, 1]))
    del asked[:]
    tab = b.page(url + "?still=1#/2")
    eq("a top-level framed page leaves for its page URL, query and hash kept", lambda: (tab.wait("document.title === 'page URL'"), tab.evaluate("location.href"))[1], BASE + "/" + OWN.replace(" ", "%20") + "?still=1#/2")
    eq("page script did not run before the bounce", lambda: (time.sleep(0.2), ran(tab))[1], [0, 0])

server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Fixture)
server.daemon_threads = True
threading.Thread(target=server.serve_forever, daemon=True).start()
BASE = "http://127.0.0.1:%d" % server.server_address[1]
files()
if bad:
    sys.exit(1)
try:
    with browser_lib.browser() as b:
        for part in (storage, sends, hashes, blocked, links, notes, elsewhere, bounce):
            try:
                part(b)
            except Exception as exc:
                print("FAIL: %s stopped: %r" % (part.__name__, exc))
                bad.append(part.__name__)
finally:
    server.shutdown()
sys.exit(1 if bad else 0)
PY
[ "$rc" != 4 ] || [ "${DESIGN_KIT_REQUIRE_BROWSER:-}" = 1 ] || { echo "PASS frame.test.sh (no browser: only the checks before one)"; exit 0; }
[ "$rc" = 0 ] || { echo "FAIL: frame.test.sh (exit $rc)"; exit 1; }
echo "PASS frame.test.sh"
