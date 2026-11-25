"""isolate.py - what keeps a page from acting as the user, for serve.py: what the control origin must not answer (host_ok, inside, scriptable, COMMON), what a page is (is_page), its signed content URL (segment, open_segment), the files it may load (may_load), its policy and the viewer's and gallery's, where the in-frame client goes (inject), and .allow.json, the hosts the user approved, each checked again at read. Imported by path, imports nothing from serve.py.
Misses: a symlink swapped between inside() and the open; text/html that is not .html or .htm (.shtml) is not scriptable() here; may_load sees path parts only, so state files, auth/ and symlinks stay with _servable and inside; a public name that resolves to a private address is an allowed host; a policy at a bracketed IPv6 Host matches nothing, since a CSP source cannot hold one; a UTF-16 page gets the client first and reads as garbage.
Why, limits, history: rationale/derivations/plugin-design-kit.md § plugins/design-kit/scripts/isolate.py
"""
import base64
import hashlib
import hmac
import ipaddress
import json
import os
import re
import secrets
import tempfile
from html.parser import HTMLParser
from http.server import SimpleHTTPRequestHandler
from urllib.parse import quote, urlsplit

COMMON = (("X-Content-Type-Options", "nosniff"), ("Referrer-Policy", "no-referrer"), ("X-DNS-Prefetch-Control", "off"))
XML_POLICY = "default-src 'none'; style-src 'unsafe-inline'; img-src data:; sandbox"
# Checked before urlsplit, which drops tabs and newlines and skips userinfo.
HOST_FORM = re.compile(r"(localhost|[0-9.]+|\[[0-9a-f:.]+\])(:[0-9]{1,5})?", re.I | re.A)
SECRET = secrets.token_bytes(32)
CONTENT = "/_c/"
VIEWER_JS, VIEWER_CSS = "/_viewer.js", "/_viewer.css"
SANDBOX = "allow-scripts allow-forms allow-modals allow-downloads"
SUFFIX = {"f": "", "s": ".s"}  # framed, static
SEGMENT = re.compile(r"[A-Za-z0-9_-]{22}\.([A-Za-z0-9_-]+)(\.s)?")
PAGE_EXT = (".html", ".htm")
IMAGES = (".png", ".jpg", ".jpeg", ".gif", ".webp", ".avif")
# (the page's first path part or None for any, its fewest parts, folders or none for its own, file endings): a page follows the first that fits it, one that fits none loads no server file.
FOLDER_RULES = (
    ("reviews", 2, ("reviews/diff", "shots"), IMAGES),
    (None, 3, (), ("",)),
)
HEAD_SPAN = 64 * 1024
# A start tag that every parser ends at the same character.
PLAIN_TAG = re.compile(r"""<[a-z]+([ \t\r\n\f]+[^\s"'<>/=]+([ \t\r\n\f]*=[ \t\r\n\f]*("[^"]*"|'[^']*'|[^\s"'<>=`]+))?)*[ \t\r\n\f]*/?>""", re.I | re.A)
HOST_NAME = re.compile(r"(?=.{4,253}$)([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z][a-z0-9-]{0,61}[a-z0-9]")
LOCAL_NAMES = (".localhost", ".local", ".internal", ".home.arpa")
ALLOW = ".allow.json"
ALLOW_HOSTS = 20
ALLOW_PAGES = 500


def host_ok(value):
    """True for localhost, an IPv4 or a bracketed IPv6 literal, with an optional port: the Hosts DNS rebinding cannot make a browser send."""
    if not HOST_FORM.fullmatch(value or ""):
        return False
    try:
        host = urlsplit("//" + value).hostname
        return host == "localhost" or ipaddress.ip_address(host).version == (6 if value[0] == "[" else 4)
    except ValueError:
        return False


def inside(root, path):
    """True when path, every symlink followed, is root or lies under it."""
    try:
        root, path = os.path.realpath(root), os.path.realpath(path)
    except ValueError:  # a NUL byte
        return False
    return path == root or path.startswith(os.path.join(root, ""))


def scriptable(ctype):
    """True for an XML type: a browser runs the script inside one opened as a document."""
    return ctype.split(";")[0].strip().lower().endswith(("/xml", "+xml"))


def is_page(name):
    """True for a name serve.py sends as text/html, or ending .html or .htm."""
    # "/" before the name: guess_type reads "data:,x.html" as a URL.
    return name.lower().endswith(PAGE_EXT) or SimpleHTTPRequestHandler.guess_type(SimpleHTTPRequestHandler, "/" + name) == "text/html"


def nofollow(path, flags):
    """An opener for open(): a symlink at path is an OSError."""
    return os.open(path, flags | getattr(os, "O_NOFOLLOW", 0))


def replace_file(path, data):
    """Puts data, bytes, at path in one step and 0600, a symlink there replaced; when that fails path is as it was and nothing is left beside it."""
    # a dot name: never served, never listed, never a reload
    fd, tmp = tempfile.mkstemp(prefix="." + os.path.basename(path).lstrip(".") + ".", dir=os.path.dirname(path))
    try:
        with os.fdopen(fd, "wb") as fh:
            fh.write(data)
        os.replace(tmp, path)
    except BaseException:
        os.unlink(tmp)
        raise


def _b64url(raw):
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode("ascii")


def segment(page, mode):
    """The signed first part of page's content URL; mode is "f" (framed) or "s" (static)."""
    name = page.encode("utf-8")
    token = _b64url(hmac.new(SECRET, mode.encode("ascii") + b"\0" + name, hashlib.sha256).digest())[:22]
    return token + "." + _b64url(name) + SUFFIX[mode]


def content_url(page, mode):
    return "%s%s/%s" % (CONTENT, segment(page, mode), quote(page))


def open_segment(seg):
    """(mode, page) when seg is exactly what segment makes for them in this process, else None."""
    form = SEGMENT.fullmatch(seg)
    if not form:
        return None
    mode, name = "s" if form.group(2) else "f", form.group(1)
    try:
        page = base64.urlsafe_b64decode(name + "=" * (-len(name) % 4)).decode("utf-8")
    except ValueError:
        return None
    return (mode, page) if hmac.compare_digest(segment(page, mode), seg) else None


def _folders(page):
    """(folder, file endings) for each docroot folder page may load files from."""
    parts = page.split("/")
    for first, fewest, folders, endings in FOLDER_RULES:
        if first in (None, parts[0]) and len(parts) >= fewest:
            return [(folder, endings) for folder in folders or ("/".join(parts[:-1]),)]
    return []


def may_load(page, parts):
    """True when page may load the docroot file at these path parts, if _servable and inside agree."""
    if not parts or any(not p or p[0] == "." or re.search(r"[/\\\0]", p) for p in parts):
        return False
    path = "/".join(parts)
    if is_page(path):
        return False
    return any(path.startswith(folder + "/") and path.lower().endswith(endings) for folder, endings in _folders(page))


def own_urls(page, seg, host):
    """The absolute URL of each folder page may load from, safe to place in a policy."""
    return ["http://%s%s%s/%s/" % (host, CONTENT, seg, quote(folder)) for folder, _ in _folders(page)]


def page_policy(mode, page, seg, hosts, host):
    """The policy of every answer under page's segment; hosts are read_allow's, host the request's Host once host_ok took it."""
    own = own_urls(page, seg, host)
    connect = " ".join(["data: blob:"] + own)
    load = " ".join([connect] + ["https://" + h for h in hosts])
    policy = [
        "sandbox " + SANDBOX,
        "default-src 'none'",
        "script-src 'unsafe-inline' 'unsafe-eval' " + load,
        "style-src 'unsafe-inline' " + load,
        "img-src " + load,
        "font-src " + load,
        "media-src " + load,
        "connect-src " + connect,
        "worker-src blob:",
        "frame-src data: blob:",
        "object-src 'none'",
        "base-uri " + (" ".join(own) or "'none'"),
        "form-action 'none'",
    ]
    if mode != "s":
        policy.append("frame-ancestors http://" + host)
    return "; ".join(policy)


def _control_policy(host, script, style):
    return ("default-src 'none'; script-src %s; style-src %s; connect-src 'self'; img-src data:; frame-src http://%s%s; base-uri 'none'; form-action 'none'; "
            "frame-ancestors 'none'; require-trusted-types-for 'script'; worker-src 'none'" % (script, style, host, CONTENT))


def viewer_policy(host):
    return _control_policy(host, "http://" + host + VIEWER_JS, "http://" + host + VIEWER_CSS)


def gallery_policy(host, sha):
    """sha: the base64 SHA-256 of the gallery's one inline script."""
    return _control_policy(host, "'sha256-%s'" % sha, "'unsafe-inline'")


class _Stop(Exception):
    pass


class _Opening(HTMLParser):
    """at: the end of the last doctype or <html>, or of the first <head>, before anything else a browser could build an element from."""

    def __init__(self, text):
        super().__init__()
        self.at, self.text = 0, text
        self.lines = [0] + [m.end() for m in re.finditer("\n", text)]

    def _offset(self):
        line, column = self.getpos()
        return self.lines[line - 1] + column

    def handle_decl(self, decl):
        self.at = self._offset() + len("<!%s>" % decl)

    def handle_starttag(self, tag, attrs):
        raw = self.get_starttag_text()
        if tag not in ("html", "head") or not PLAIN_TAG.fullmatch(raw):
            raise _Stop
        self.at = self._offset() + len(raw)
        if tag == "head":
            raise _Stop

    def handle_endtag(self, tag):
        raise _Stop

    def handle_data(self, data):
        if data.strip("\xef\xbb\xbf \t\r\n\f"):  # the first three: a UTF-8 byte order mark read as Latin-1
            raise _Stop

    def handle_comment(self, data):
        # A browser also ends one at "<!-->", "<!--->" and "--!>", and never at "-- >"; html.parser differs by version.
        if data.startswith((">", "->")) or "--!>" in data or not self.text.startswith("<!--%s-->" % data, self._offset()):
            raise _Stop

    def unknown_decl(self, data):
        raise _Stop


def inject(body, tag):
    """body with tag after its <head>, else its <html>, else its doctype, else first: before any element a browser could run."""
    opening = _Opening(body[:HEAD_SPAN].decode("latin-1"))
    try:
        opening.feed(opening.text)
    except (_Stop, AssertionError, NotImplementedError):  # the last two: an older Python at a malformed "<!["
        pass
    return body[:opening.at] + tag + body[opening.at:]


def allowed_host(value):
    """value in lower case when a page may be given it as an https host, else None."""
    host = value.lower() if isinstance(value, str) else ""
    return host if HOST_NAME.fullmatch(host) and not ("." + host).endswith(LOCAL_NAMES) else None


def read_allow(root):
    """({page: [host, ...]}, None), or ({}, why) when the approvals file is not one."""
    try:
        with open(os.path.join(root, ALLOW), "rb", opener=nofollow) as fh:
            kept = json.loads(fh.read().decode("utf-8"))
        if not isinstance(kept, dict) or not all(isinstance(hosts, list) for hosts in kept.values()):
            raise ValueError("not a list of hosts for each page")
    except FileNotFoundError:
        return {}, None
    except (OSError, ValueError, RecursionError):
        return {}, "approvals file unreadable; all hosts blocked"
    return {page: [h for h in map(allowed_host, hosts) if h] for page, hosts in kept.items()}, None


def set_allow(root, page, host, allow, exists, lock):
    """(page's hosts, None) once host is added or removed, or (None, why), nothing written; exists(page) says a page is there, lock is serve.py's locked. OSError when the file cannot be written."""
    host = allowed_host(host)
    if not host:
        return None, "host must be a public https host name with no port, such as cdn.example.org"
    if not isinstance(allow, bool):
        return None, "allow must be true or false"
    if not isinstance(page, str) or allow and not exists(page):
        return None, "no such page"
    path = os.path.join(root, ALLOW)
    with lock(os.path.join(root, ".allow.lock")):
        entries, broken = read_allow(root)
        if broken and not allow:
            return [], None
        entries = {p: hosts for p, hosts in entries.items() if hosts and exists(p)}
        hosts = [h for h in entries.pop(page, []) if h != host]
        if allow and len(hosts) >= ALLOW_HOSTS:
            return None, "a page may load from at most %d hosts; remove one first" % ALLOW_HOSTS
        if allow and len(entries) >= ALLOW_PAGES:
            return None, "at most %d pages may have allowed hosts; remove the hosts of one first" % ALLOW_PAGES
        if allow:
            hosts.append(host)
        if hosts:
            entries[page] = hosts
        if broken:
            os.replace(path, path + ".bad")
        replace_file(path, json.dumps(entries, indent=1).encode("ascii"))
    return hosts, None
