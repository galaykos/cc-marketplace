#!/usr/bin/env bash
# Drives isolate.py as units, no server: host_ok, inside, scriptable; content tokens forged, moved and cut; the policies as whole text; may_load by folder; inject against decoy heads and markup two parsers read differently; hosts and .allow.json (bad files, symlinks, caps, a failed write).
# Misses: what the server and a browser do with the answers (serve.test.sh, viewer.test.sh, attack.test.sh); that open_segment compares in constant time; set_allow with two writers at once under serve.py's own lock; a symlink swapped between inside() and the open.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
python3 - "$here/isolate.py" "$tmp" <<'PY' || { echo "FAIL: isolate.py units"; exit 1; }
import _markupbase, base64, contextlib, hashlib, hmac, html.parser, importlib.util, json, mimetypes, os, re, stat, sys

def load():
    spec = importlib.util.spec_from_file_location("dkisolate", sys.argv[1]); mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)
    return mod

m = load()
tmp, bad = sys.argv[2], []

def check(fn, cases, want):
    for args in cases:
        try:
            got = getattr(m, fn)(*args)
        except Exception as exc:
            got = repr(exc)
        if got is not want:
            bad.append("FAIL: %s%r is %s, want %s" % (fn, tuple(args), got, want))

def eq(name, fn, want):
    try:
        got = fn()
    except Exception as exc:
        got = repr(exc)
    if got != want:
        bad.append("FAIL: %s: got %.300r, want %.300r" % (name, got, want))

check("host_ok", [[v] for v in (
    "localhost", "LocalHost", "localhost:8124", "127.0.0.1", "127.0.0.1:8124", "192.168.1.9:8124", "0.0.0.0",
    "[::1]", "[::1]:8124", "[FE80::1]:80", "[::ffff:127.0.0.1]:8124")], True)
check("host_ok", [[v] for v in (
    None, "", " ", "evil.example", "evil.example:8124", "localhost.evil", "localhost.", "127.0.0.1.", "localhost.:8124",
    "127.0.0.1.evil.example", "foo.localhost", "local_host", "127.1", "0x7f.0.0.1", "2130706433", "256.0.0.1", "...",
    "localhost:", "localhost:x", "localhost:8124:1", "127.0.0.1:-1", "::1", "[::1", "[127.0.0.1]", "[localhost]", "[::g]",
    "[::1]evil.example", "evil.example[::1]", "[::1].evil.example", "[fe80::1%eth0]", "x@127.0.0.1", "127.0.0.1@evil.example",
    "127.0.0.1/x", "evil.example/@127.0.0.1", "127.0.0.1?x", "127.0.0.1#x", "127.0.0.1\\x", "http://127.0.0.1", "//127.0.0.1",
    "127.0.0.1\t", "127.0.0.1\n", " 127.0.0.1", "local\thost", "127.0.0.1, evil.example", "localhoſt", "١٢٧.0.0.1")], False)

root, out = os.path.join(tmp, "root"), os.path.join(tmp, "root-out")
os.makedirs(os.path.join(root, "a")); os.makedirs(out)
for p in (os.path.join(root, "a", "p.html"), os.path.join(out, "p.html")):
    open(p, "w").close()
at = lambda *p: os.path.join(root, *p)
os.symlink(os.path.join(out, "p.html"), at("file-out")); os.symlink(out, at("dir-out")); os.symlink(os.path.join(out, "gone"), at("dangling-out"))
os.symlink(at("a", "p.html"), at("file-in")); os.symlink("a", at("dir-in")); os.symlink(at("dir-out"), at("a", "twice-out"))
os.symlink(root, os.path.join(tmp, "linked-root"))
check("inside", [(root, root), (root, at("a", "p.html")), (root, at("a", "gone")), (root, at("file-in")), (root, at("dir-in", "p.html")),
                 (os.path.join(tmp, "linked-root"), at("a", "p.html")), (root, os.path.join(tmp, "linked-root", "a")),
                 (root + os.sep, at("a")), (os.sep, at("a"))], True)
check("inside", [(root, tmp), (root, out), (root, at("..", "root-out", "p.html")), (root, at("file-out")), (root, at("dir-out")),
                 (root, at("dir-out", "p.html")), (root, at("dir-out", "gone")), (root, at("dangling-out")), (root, at("a", "twice-out", "p.html")),
                 (root, at("a\0b"))], False)

check("scriptable", [[v] for v in ("text/xml", "application/xml", "image/svg+xml", "application/xhtml+xml", "application/atom+xml", "model/xml",
                                   "IMAGE/SVG+XML", "text/xml; charset=utf-8")], True)
check("scriptable", [[v] for v in ("", "text/html", "text/plain", "image/png", "application/pdf", "application/octet-stream", "application/xml-dtd",
                                   "text/plain; x=+xml")], False)

# tokens
HOSTILE, A, B = "motion/a;b, c ü/index.html", "decks/a.html", "decks/b.html"
b64 = lambda raw: base64.urlsafe_b64encode(raw).decode().rstrip("=")
for mode, end in (("f", ""), ("s", ".s")):
    eq("a segment is the token, the page and the mode %r" % mode, lambda: m.segment(HOSTILE, mode),
       b64(hmac.new(getattr(m, "SECRET", b""), mode.encode() + b"\0" + HOSTILE.encode(), hashlib.sha256).digest())[:22] + "." + b64(HOSTILE.encode()) + end)
    eq("a %r segment opens its own page" % mode, lambda: [m.open_segment(m.segment(p, mode)) for p in (HOSTILE, A)], [(mode, HOSTILE), (mode, A)])
eq("a content URL is percent-encoded", lambda: m.content_url(HOSTILE, "s").replace(m.segment(HOSTILE, "s"), "SEG"), "/_c/SEG/motion/a%3Bb%2C%20c%20%C3%BC/index.html")
eq("framed token used as static opens nothing", lambda: m.open_segment(m.segment(A, "f") + ".s"), None)
eq("static token used as framed opens nothing", lambda: m.open_segment(m.segment(A, "s")[:-2]), None)
eq("a token of another page opens nothing", lambda: m.open_segment(m.segment(A, "f")[:23] + b64(B.encode())), None)
eq("a token of another server start opens nothing", lambda: load().open_segment(m.segment(A, "f")), None)
eq("the secret is 32 bytes", lambda: len(m.SECRET), 32)
eq("a segment cut short opens nothing", lambda: [n for n in range(len(m.segment(A, "s"))) if m.open_segment(m.segment(A, "s")[:n])], [])
ABC = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
def altered(seg):
    return [(n, c) for n, was in enumerate(seg) for c in ABC if c != was and m.open_segment(seg[:n] + c + seg[n + 1:])]
for page in (A, A + "x", A + "xy"):  # the last base64 character holds 0, 4 or 2 unused bits
    eq("a segment with one character changed opens nothing", lambda: altered(m.segment(page, "f")), [])
eq("a signed page that is not UTF-8 opens nothing", lambda: m.open_segment(b64(hmac.new(m.SECRET, b"f\0\xff", hashlib.sha256).digest())[:22] + "." + b64(b"\xff")), None)
for name, forge in (("nothing", lambda s: ""), ("a dot", lambda s: "."), ("a newline after", lambda s: s + "\n"), ("a newline before", lambda s: "\n" + s), ("a space", lambda s: s + " "), ("padding", lambda s: s + "="),
                    ("a dot after", lambda s: s + "."), ("a mode there is not", lambda s: s + ".f"), ("two modes", lambda s: s + ".s.s"), ("an encoded dot", lambda s: s.replace(".", "%2e")),
                    ("a lone base64 character", lambda s: s[:23] + "A"), ("+ in the page", lambda s: s[:23] + "+" + s[24:]), ("a letter outside ASCII", lambda s: s + "é"), ("a path", lambda s: s + "/decks/a.html")):
    eq("a malformed segment opens nothing: " + name, lambda: m.open_segment(forge(m.segment(A, "f"))), None)

# policies
AT = "127.0.0.1:8124"
def policy(mode, page, hosts=()):
    return m.page_policy(mode, page, "SEG", list(hosts), AT)
def wanted(own="", hosts="", base="'none'", last="; frame-ancestors http://" + AT):
    load = "data: blob:" + own + hosts
    return ("sandbox allow-scripts allow-forms allow-modals allow-downloads; default-src 'none'; script-src 'unsafe-inline' 'unsafe-eval' " + load + "; style-src 'unsafe-inline' " + load
            + "; img-src " + load + "; font-src " + load + "; media-src " + load + "; connect-src data: blob:" + own + "; worker-src blob:; frame-src data: blob:; object-src 'none'; base-uri " + base
            + "; form-action 'none'" + last)
OWN = "http://" + AT + "/_c/SEG/motion/a%3Bb%2C%20c%20%C3%BC/"
REVIEW = "http://" + AT + "/_c/SEG/reviews/diff/ http://" + AT + "/_c/SEG/shots/"
eq("the policy of a page that loads no server file", lambda: policy("f", A), wanted())
eq("the static policy is the same without frame-ancestors", lambda: policy("s", A), wanted(last=""))
eq("a host is a script, style, image, font and media source, never connect", lambda: policy("f", A, ["cdn.jsdelivr.net", "a.io"]), wanted(hosts=" https://cdn.jsdelivr.net https://a.io"))
eq("an own folder is a source and the base", lambda: policy("f", HOSTILE, ["a.io"]), wanted(" " + OWN, " https://a.io", OWN))
eq("a review page's two image folders are its sources", lambda: policy("s", "reviews/p.html"), wanted(" " + REVIEW, "", REVIEW, ""))
eq("own_urls", lambda: [m.own_urls(p, "SEG", AT) for p in (HOSTILE, "reviews/p.html", A)], [[OWN], REVIEW.split(" "), []])
for folder in ("a;b, c ü", "x; script-src *", "x\r\nSet-Cookie: a=b", "'self'", "x\N{LINE SEPARATOR}\N{NO-BREAK SPACE}\t", "a%2fb", "https:", "*", '"<>#?'):
    page = "motion/" + folder + "/index.html"
    def one_policy():
        own = m.own_urls(page, "SEG", AT)[0]
        return [bool(re.fullmatch(r"http://127\.0\.0\.1:8124/_c/SEG/motion/[A-Za-z0-9._~%-]+/", own)), policy("f", page) == wanted(" " + own, "", own)]
    eq("hostile folder name stays one policy: %r" % folder, one_policy, [True, True])
CONTROL = ("default-src 'none'; script-src %s; style-src %s; connect-src 'self'; img-src data:; frame-src http://127.0.0.1:8124/_c/; base-uri 'none'; form-action 'none'; "
           "frame-ancestors 'none'; require-trusted-types-for 'script'; worker-src 'none'")
eq("viewer policy", lambda: m.viewer_policy(AT), CONTROL % ("http://127.0.0.1:8124/_viewer.js", "http://127.0.0.1:8124/_viewer.css"))
eq("gallery policy", lambda: m.gallery_policy(AT, "c2hh"), CONTROL % ("'sha256-c2hh'", "'unsafe-inline'"))

# same-server files
mimetypes.add_type("text/html", ".dkpage"); mimetypes.add_type("text/plain", ".htm")
def loads(page, paths, want):
    for path in paths:
        parts = path.split("/") if isinstance(path, str) else path
        eq("may_load: %s %s %r" % (page, "loads" if want else "does not load", path), lambda: m.may_load(page, parts), want)
ELSEWHERE = ["boards/a.png", "boards/x/a.png", "decks/a.png", "artifacts/a.js", "previews/a.css", "a.png", "design-system/tokens.json", "shots/s/desktop/p.png", "reviews/diff/p.png", "film/x/a.js", "motion/x/a.js"]
for page in ("boards/a.html", "decks/a.html", "artifacts/a.html", "previews/kit.html", "a.html", "index.html", "motion/a.html", "film/a.htm"):
    loads(page, ELSEWHERE + [page], False)
for page, own in (("motion/x/index.html", "motion/x"), ("film/x/index.html", "film/x"), ("film/x/comp/a.htm", "film/x/comp"), ("previews/x/a.html", "previews/x")):
    loads(page, [own + "/" + f for f in ("a.js", "data.json", "a.svg", "a.xhtml", "noext", "fonts/deep/a.woff2", "a.html.txt", "a b;c.png")], True)
    loads(page, [own + "/" + f for f in ("index.html", "other.html", "sub/index.htm", "OTHER.HTML", "a.Htm", "a.html.br", "data:,a.dkpage", "a.DKPAGE", ".frames/1.png", ".env", "sub/.git/config", "sub/..", "sub/../a.js", "./a.js", "sub//a.js", "")]
          + [own, own + "y/a.js", own.rsplit("/", 1)[0] + "/a.js", own.rsplit("/", 1)[0] + "/y/a.js", own.upper() + "/a.js", ".checks/results.json", "../" + own + "/a.js", own + "/../y/a.js"], False)
    loads(page, [own.split("/") + [p] for p in ("../y/a.js", "s/../../../decks/a.png", "s\\..\\..\\..\\..\\decks\\a.png", "a.js\0.png", "/a.js")] + [[own, "a.js"], [], [""]], False)
loads("film/x/comp/a.htm", ["film/x/a.js"], False)
loads("motion/x/index.html", ["film/x/a.js", "shots/s/p.png", "reviews/diff/p.png", "decks/a.png"], False)
for page in ("reviews/p.html", "reviews/sub/p.html"):
    loads(page, [d + "/" + f for d in ("reviews/diff", "shots", "shots/s/desktop") for f in ("p.png", "p.jpg", "p.jpeg", "p.gif", "p.webp", "p.avif", "P.PNG")], True)
    loads(page, [d + "/" + f for d in ("reviews/diff", "shots") for f in ("p.svg", "p.json", "p.js", "p.html", "p.png.html", "p.png.txt", "png", ".png", ".x/p.png", "../p.png")]
          + ["reviews/p.png", "reviews/sub/p.png", "reviews/sub/a.js", "reviews/diff", "shots", "shotsx/p.png", "reviews/diffx/p.png", "decks/p.png", "motion/x/p.png"], False)

# injection: the tag goes between the two halves, whatever html.parser's version makes of a comment and a "<!["
Parser, Base = html.parser.HTMLParser, _markupbase.ParserBase
newer = Parser.parse_html_declaration
def older(self, i):
    return self.parse_marked_section(i) if self.rawdata.startswith("<![", i) else newer(self, i)
RULES = ((Parser.parse_comment, newer), (Base.parse_comment, older))
def lands(name, before, after):
    for rules in RULES:
        Parser.parse_comment, Parser.parse_html_declaration = rules
        eq(name, lambda: m.inject(before + after, b"<T>"), before + b"<T>" + after)
    Parser.parse_comment, Parser.parse_html_declaration = RULES[0]
TOP, REST = b"<!doctype html>\n<html lang=\"en\">\n<head>", b"<title>x</title></head><body>x</body></html>"
lands("inject goes after the head", TOP, REST)
lands("inject goes after a head with attributes", b"<!DOCTYPE HTML><HTML><HEAD prefix='og: x' @a.b = \"1\" data-a=1 hidden>", REST)
lands("inject goes after the first of two heads", TOP, b"<head>" + REST)
lands("inject goes after the head when there is no html", b"<!doctype html><head>", REST)
lands("inject goes after the head when there is no doctype", b"<html><head/>", REST)
lands("inject goes after html when there is no head", b"<!doctype html><html>", b"<body><h1>x")
lands("inject goes after the doctype when there is no html", b"<!doctype html>", b"\n<h1>x")
lands("inject goes after a lone doctype", b"<!doctype html>", b"")
lands("inject goes first when there is no doctype, html or head", b"", b"<h1>x</h1>")
lands("inject goes first in a file of text", b"", b"plain & simple")
lands("inject fills an empty file", b"", b"")
lands("inject puts a new copy before a saved one", TOP, b"<script data-design-kit-frame>old</script>" + REST)
lands("inject counts bytes, past a byte order mark, letters outside ASCII and every line end", b"\xef\xbb\xbf\r\n<!-- \xc3\xbc\xe2\x80\xa8\r\n\r\x85 -->\n<!doctype html>\r<html>\n\n<head\n>", REST)
lands("inject reads past an XML declaration and conditional comments", b"<?xml version='1.0'?><!doctype html><!--[if IE]><html class=ie><![endif]--><!--[if !IE]><!--><html><!--<![endif]--><head>", REST)
lands("inject skips a head inside a comment", b"<!------ <head> -- ------><!doctype html><!-- <head> --><html><!-- <head> --><head>", REST)
lands("inject skips a head inside a comment when there is no real one", b"<!doctype html><html>", b"<!-- <head> --><body>x")
lands("inject skips a head inside an attribute", b"<!doctype html><html data-a=\"<head>\" data-b='<head>'><head>", REST)
lands("inject skips a head inside an attribute when there is no real one", b"<!doctype html><html>", b"<body title='<head>'>x")
for tag in (b"script", b"style", b"textarea", b"title", b"template"):
    decoy, name = b"<" + tag + b"><head></" + tag + b">", "inject skips a head inside a " + tag.decode()
    lands(name, TOP, decoy + REST)
    lands(name + " when there is no real one", b"<!doctype html><html>", b"<body>" + decoy)
    lands(name + " and a head tag too late for a browser to open one", b"<!doctype html><html>", decoy + b"<head>" + REST)
EVIL = b"<script>evil()</script>"
for name, before, after in (
        ("a script before the head", b"<!doctype html><html>", EVIL + b"<head>"), ("an element with a handler before the head", b"<!doctype html>", b"<img src=x onerror=evil()><html><head>"),
        ("text before the head", b"<!doctype html><html>", b"x<head>"), ("an end tag before the head", b"<!doctype html>", b"</p a='>" + EVIL + b"<head>'><head>"),
        ("a comment a browser ends at once", b"<!doctype html>", b"<!-->" + EVIL + b"--><head>"), ("a comment a browser ends after a dash", b"<!doctype html>", b"<!--->" + EVIL + b"--><head>"),
        ("a comment a browser ends at --!>", b"<!doctype html>", b"<!-- --!>" + EVIL + b"--><head>"), ("a comment only some parsers end at -- >", b"<!doctype html>", b"<!-- -- ><head>" + EVIL),
        ("a CDATA section", b"<!doctype html>", b"<![CDATA[>" + EVIL + b"]]><head>"), ("an unknown section", b"<!doctype html>", b"<![x[>" + EVIL + b"]]><head>"),
        ("a quote only some parsers open", b"<!doctype html>", b"<html a==\">" + EVIL + b"\"><head>"), ("a quote that never closes", b"<!doctype html>", b"<html a=\"><head>" + EVIL),
        ("a name that is not html", b"<!doctype html>", b"<html\0><head>" + EVIL), ("UTF-16 under a byte order mark", b"", b"\xfe\xff<html><head>" + EVIL.decode().encode("utf-16-be")),
        ("a head past the first 64 KiB", b"<!doctype html>", b" " * 65536 + b"<head>")):
    lands("inject stops before " + name, before, after)

# hosts
for value in ("cdn.jsdelivr.net", "a.io", "3.a-b.xn--p1ai", "a" * 63 + ".net", "a." * 125 + "net", "notlocal.example", "local.example", "internal.example"):
    eq("allowed_host takes %s" % value[:40], lambda: m.allowed_host(value), value)
eq("allowed_host answers lower case", lambda: m.allowed_host("CDN.jsDelivr.NET"), "cdn.jsdelivr.net")
check("allowed_host", [[v] for v in (
    None, 7, True, ["cdn.jsdelivr.net"], "", " ", ".", "com", "127.0.0.1", "127.1", "0x7f.0.0.1", "0177.0.0.1", "2130706433", "0x7f000001", "10.0.0.0x1", "::1", "[::1]", "cdn.jsdelivr.net:443",
    "localhost", "LOCALHOST", "foo.localhost", "foo.LocalHost", "printer.local", "x.internal", "router.home.arpa", "home.arpa", "cdn.jsdelivr.net.", ".cdn.jsdelivr.net", "cdn..net",
    "cdn.jsdelivr.net\n", "\ncdn.jsdelivr.net", "cdn.\tjsdelivr.net", "cdn.jsdelivr.net\0", "cdn.jsdelivr.net\x7f", " cdn.jsdelivr.net", "cdn.jsdelivr.net ", "*.jsdelivr.net", "*", "cdn.*",
    "http://cdn.jsdelivr.net", "https://cdn.jsdelivr.net", "//cdn.jsdelivr.net", "cdn.jsdelivr.net/x", "x@cdn.jsdelivr.net", "cdn.jsdelivr.net?x", "cdn.jsdelivr.net; script-src *", "cdn.jsdelivr.net,a.io",
    "a.io b.io", "'self'", "-a.net", "a-.net", "a_b.net", "a.b", "ab.c", "a.1net", "a.net-", "ü.net", "cdn.jsdelivr.nét", "a" * 64 + ".net", "a." * 125 + "info")], None)

# approvals
base = os.path.join(tmp, "allow"); root = os.path.join(base, "root"); os.makedirs(root)
FILE, BAD = os.path.join(root, ".allow.json"), os.path.join(root, ".allow.json.bad")
CDN = "cdn.jsdelivr.net"
pages, locks, left, on_lock = {A, B, HOSTILE}, [], [], []
@contextlib.contextmanager
def lock(path):
    locks.append(path)
    for act in on_lock:
        act()
    yield
    left.append(text())
def text(path=FILE):
    try:
        with open(path, "rb") as fh:
            return fh.read()
    except OSError:
        return None
def put(content):
    for p in (FILE, BAD):
        if os.path.lexists(p):
            os.unlink(p)
    if content is not None:
        with open(FILE, "wb") as fh:
            fh.write(content if isinstance(content, bytes) else json.dumps(content).encode())
def allow(page, host, on=True):
    return m.set_allow(root, page, host, on, pages.__contains__, lock)
def refused(page, host, on=True, says=""):
    was = text()
    hosts, why = allow(page, host, on)
    return "refused" if hosts is None and says in why and text() == was and not os.path.lexists(BAD) else (hosts, why, text())

eq("no .allow.json allows nothing", lambda: m.read_allow(root), ({}, None))
eq("Allow lists the host", lambda: (allow(A, CDN), m.read_allow(root)), (([CDN], None), ({A: [CDN]}, None)))
eq(".allow.json is 0600 and alone", lambda: (stat.S_IMODE(os.lstat(FILE).st_mode), os.listdir(root)), (0o600, [".allow.json"]))
eq("the lock is .allow.lock, and the file is written before it goes", lambda: (set(locks), left[-1] == text()), ({os.path.join(root, ".allow.lock")}, True))
on_lock.append(lambda: put({B: [CDN]}))
eq("what another writer listed before the lock came is kept", lambda: (allow(A, CDN)[1], m.read_allow(root)), (None, ({A: [CDN], B: [CDN]}, None)))
on_lock.clear(); put({A: [CDN]})
eq("a second host and a second page", lambda: (allow(A, "FONTS.example.org"), allow(HOSTILE, CDN), m.read_allow(root)),
   (([CDN, "fonts.example.org"], None), ([CDN], None), ({A: [CDN, "fonts.example.org"], HOSTILE: [CDN]}, None)))
eq("a host allowed twice is listed once", lambda: sorted(allow(A, CDN)[0]), [CDN, "fonts.example.org"])
eq("Remove takes one host of one page", lambda: (allow(A, CDN, False), m.read_allow(root)), ((["fonts.example.org"], None), ({A: ["fonts.example.org"], HOSTILE: [CDN]}, None)))
eq("removing the last host drops the page", lambda: (allow(A, "fonts.example.org", False), json.loads(text())), (([], None), {HOSTILE: [CDN]}))
for host in ("localhost", "127.0.0.1", "http://" + CDN, CDN + "\n", None, [CDN]):
    eq("a refused host writes nothing: %r" % (host,), lambda: refused(A, host, says="host"), "refused")
for on in ("false", "true", 0, 1, None, []):
    eq("allow must be true or false, not %r" % (on,), lambda: refused(A, CDN, on, "allow"), "refused")
for page in ("decks/gone.html", "", None, [A], {}):
    eq("a page that is not there is refused: %r" % (page,), lambda: refused(page, CDN, says="page"), "refused")

put({A: [CDN, "127.0.0.1", "evil.local", "a.b;script-src *", "*", 7, None, [CDN], "CDN.example.org"], B: ["localhost"]})
eq("a bad host inside .allow.json allows nothing", lambda: m.read_allow(root), ({A: [CDN, "cdn.example.org"], B: []}, None))
eq("the next write drops the bad hosts", lambda: (allow(A, "a.io"), json.loads(text())), (([CDN, "cdn.example.org", "a.io"], None), {A: [CDN, "cdn.example.org", "a.io"]}))
put({A: [CDN], "decks/gone.html": [CDN], "../../etc/x.html": [CDN]})
eq("entries of pages that are gone are dropped on a write", lambda: (allow(B, CDN), json.loads(text())), (([CDN], None), {A: [CDN], B: [CDN]}))
put({"decks/gone.html": [CDN, "a.io"], A: [CDN]})
eq("Remove on a page that is gone leaves no host of it", lambda: (allow("decks/gone.html", "a.io", False), json.loads(text())), (([], None), {A: [CDN]}))

for name, content in (("empty", b""), ("cut", b'{"decks/a.html": ["cdn.jsd'), ("a list", b'["cdn.jsdelivr.net"]'), ("a string", b'"x"'), ("null", b"null"), ("a host that is not in a list", {A: CDN}),
                      ("hosts as an object", {A: {CDN: True}}), ("not UTF-8", b'{"\xff": []}'), ("UTF-16", json.dumps({A: [CDN]}).encode("utf-16")), ("nested deep", b"[" * 200000)):
    put(content)
    was = text()
    eq("a malformed .allow.json allows nothing: " + name, lambda: [m.read_allow(root)[0], bool(m.read_allow(root)[1])], [{}, True])
    eq("Remove leaves a malformed file: " + name, lambda: (allow(A, CDN, False), text() == was, os.path.exists(BAD)), (([], None), True, False))
    eq("a refused Allow leaves a malformed file: " + name, lambda: refused(A, "localhost"), "refused")
    eq("the next Allow keeps the bad file aside: " + name, lambda: (allow(A, "a.io"), text(BAD) == was, m.read_allow(root)), ((["a.io"], None), True, ({A: ["a.io"]}, None)))
put(None); os.mkdir(FILE)
eq("a folder named .allow.json allows nothing", lambda: [m.read_allow(root)[0], bool(m.read_allow(root)[1])], [{}, True])
os.rmdir(FILE)
out, gone = os.path.join(base, "out.json"), os.path.join(base, "gone.json")
with open(out, "w", encoding="utf-8") as fh:
    json.dump({A: [CDN]}, fh)
was = text(out)
for name, target in (("another file", out), ("no file", gone)):
    put(None); os.symlink(target, FILE)
    eq("a symlink to %s allows nothing" % name, lambda: [m.read_allow(root)[0], bool(m.read_allow(root)[1])], [{}, True])
    eq("Allow never writes through a symlink to " + name, lambda: (allow(A, "a.io"), os.path.islink(FILE), os.readlink(BAD) == target, os.path.exists(gone), text(out) == was), ((["a.io"], None), False, True, False, True))

eq("the caps are 20 hosts and 500 pages", lambda: (m.ALLOW_HOSTS, m.ALLOW_PAGES), (20, 500))
m.ALLOW_HOSTS, m.ALLOW_PAGES = 2, 2
put({A: [CDN, "a.io"]})
eq("a host past the cap is refused, the cap named", lambda: refused(A, "b.io", says="2 hosts"), "refused")
eq("a host listed already is not past the cap", lambda: sorted(allow(A, "a.io")[0]), ["a.io", CDN])
eq("Remove makes room for a host", lambda: (allow(A, CDN, False)[1], allow(A, "b.io")), (None, (["a.io", "b.io"], None)))
put({A: [CDN], B: [CDN]})
eq("a page past the cap is refused, the cap named", lambda: refused(HOSTILE, CDN, says="2 pages"), "refused")
eq("a listed page may gain a host at the page cap", lambda: allow(B, "a.io"), ([CDN, "a.io"], None))
pages.discard(B)
eq("a page that is gone makes room", lambda: (allow(HOSTILE, CDN), json.loads(text())), (([CDN], None), {A: [CDN], HOSTILE: [CDN]}))
pages.add(B); put({A: [CDN, "a.io", "b.io", "c.io"], B: [CDN], HOSTILE: [CDN]})
eq("Remove works on a file past both caps", lambda: allow(A, "c.io", False), ([CDN, "a.io", "b.io"], None))

put({A: [CDN]})
with open(FILE, encoding="utf-8") as reader:
    eq("a reader of the old file sees it whole", lambda: (allow(A, "a.io")[1], json.load(reader), json.loads(text())), (None, {A: [CDN]}, {A: [CDN, "a.io"]}))
was, names, replace = text(), sorted(os.listdir(root)), os.replace
def full(*_):
    raise OSError(28, "No space left on device")
os.replace = full
eq("a failed write is an OSError", lambda: allow(A, CDN, False), repr(OSError(28, "No space left on device")))
os.replace = replace
eq("a failed write changes no file and leaves none", lambda: (text() == was, sorted(os.listdir(root)) == names), (True, True))
print("\n".join(bad), end="\n" if bad else "")
sys.exit(1 if bad else 0)
PY
echo "PASS isolate.test.sh"