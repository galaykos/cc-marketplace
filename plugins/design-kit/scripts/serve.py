#!/usr/bin/env python3
"""design-kit preview server — one localhost URL for every design-kit surface.

Serves a docroot (default ./.design-kit) on 127.0.0.1:8124: / a gallery (flow strip, token badges), /_events SSE reload (0.75 s mtime poll), /_index.json, /<path> static with a reload client injected (never for a headless browser or ?static=1) that shows a "server stopped" bar and reloads when the server is back; POST /_decision, the one write route, appends a pick to decisions.jsonl — loopback peer, Host and Origin, X-Design-Kit-Decision header, <= 8 KiB of JSON, else 403 / 413 / 400. Never served (404 to GET and HEAD, origin- or absolute-form target): dot paths, auth/, the IGNORED state files, *.versions.json, directory listings. --lan binds 0.0.0.0, asks every non-loopback peer for the key in <docroot>/.preview.key (?key= once, then an HttpOnly SameSite=Strict cookie; else 403) and exits after DESIGN_KIT_LAN_MINUTES (60); every mode exits after DESIGN_KIT_IDLE_MINUTES (240; 0 = off) with no request that passed the key gate and no open stream, and on a self-exit (idle limit, LAN limit, Ctrl-C; not a kill) removes .preview.pid/.url/.bind while the pid file names it.
Misses: whoever holds the keyed URL reads every non-state file under the docroot, signed-in screenshots included, and the key crosses the network in clear (plain HTTP); a page served from this origin can still POST /_decision, so a bundled page carrying third-party script can plant a pick; export and publish are scripts, not routes, and nothing restores an old version; port 8123 is never the default (the taskmaster/ui-ux mockup server); nothing proves a browser rendered a page.
Why, limits, history: rationale/derivations/plugin-design-kit.md § plugins/design-kit/scripts/serve.py
"""
import argparse
import hashlib
import hmac
import html
import io
import json
import os
import posixpath
import re
import secrets
import stat
import sys
import threading
import time
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, parse_qsl, unquote, urlencode, urlsplit

# Stream lost: a role=status bar (no animation, so nothing to reduce), retries at 1, 2, 4 ... 30 s; back: reload.
RELOAD_SNIPPET = (
    '<script data-design-kit-reload>'
    '(function(){var b,d=0;function go(){var s;try{s=new EventSource("/_events")}catch(e){return}'
    's.onopen=function(){if(b){b.remove();location.reload()}};'
    's.onmessage=function(e){if(e.data==="reload")location.reload()};'
    's.onerror=function(){s.close();if(!b){b=document.createElement("div");b.setAttribute("role","status");'
    'b.style.cssText="position:fixed;left:8px;bottom:8px;z-index:2147483647;padding:4px 10px;border-radius:4px;'
    'background:#222;color:#fff;font:13px system-ui,sans-serif;pointer-events:none";'
    '(document.body||document.documentElement).appendChild(b);b.textContent="Preview server stopped; retrying"}'
    'd=Math.min(d?d*2:1000,30000);setTimeout(go,d)}}go()})();'
    '</script>'
)
PAGE_EXT = (".html", ".htm")
KEY_FILE = ".preview.key"
KEY_COOKIE = "design_kit_key"  # not "key": cookies ignore the port, and taskmaster's server shares the host
IGNORED = {".preview.pid", ".preview.url", ".preview.bind", KEY_FILE, "_index.json", "workshop.json", "decisions.jsonl", "usage.jsonl"}
PRIVATE_DIRS = {"auth"}
LOOPBACK_HOSTS = ("127.0.0.1", "localhost", "::1")
DECISION_MAX = 8 * 1024
LOOPBACK = ("127.0.0.1", "::1", "::ffff:127.0.0.1")


def lan_gate(key, peer, query, cookie):
    """One request's LAN-key verdict: "pass", "set" (a right ?key=: set the cookie, redirect without it) or "deny".
    key is None when not in LAN mode; a loopback peer always passes."""
    if key is None or peer in LOOPBACK:
        return "pass"
    want = key.encode()
    if hmac.compare_digest((parse_qs(query).get("key") or [""])[0].encode(), want):
        return "set"
    # Split by hand: SimpleCookie drops the whole header when any other cookie in it is malformed for it.
    for part in (cookie or "").split(";"):
        name, sep, value = part.strip().partition("=")
        if sep and name == KEY_COOKIE and hmac.compare_digest(value.encode(), want):
            return "pass"
    return "deny"


def split_target(target):
    """A target's (path, query), origin- or absolute-form, fragment dropped: the one parse routes, the gate and send_head share."""
    if target.startswith("/"):
        path, _, query = target.split("#", 1)[0].partition("?")
        return path, query
    try:
        u = urlsplit(target)
    except ValueError:
        return target, ""
    return u.path or "/", u.query


def _parts(path):
    """A target path's docroot-relative segments; none climbs out."""
    return [p for p in posixpath.normpath(unquote(path)).split("/") if p and p not in (".", "..")]


def without_key(path, query):
    """Where a first keyed visit is sent: the same path (one leading slash, so never another host), every field but key."""
    rest = urlencode([(k, v) for k, v in parse_qsl(query, keep_blank_values=True) if k != "key"])
    return "/" + path.lstrip("/") + ("?" + rest if rest else "")


def _lan_key(root):
    """Reuses .preview.key only as a regular file holding a key; anything else is unlinked, never followed, and replaced O_EXCL at 0600."""
    p = os.path.join(root, KEY_FILE)
    try:
        fd = os.open(p, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_NONBLOCK", 0))
    except OSError:
        fd = None
    if fd is not None:
        with os.fdopen(fd, "rb") as fh:
            if stat.S_ISREG(os.fstat(fd).st_mode):
                key = fh.read(256).decode("ascii", "replace").strip()
                if re.fullmatch(r"[A-Za-z0-9_-]{22,}", key):
                    if hasattr(os, "fchmod"):
                        os.fchmod(fd, 0o600)
                    return key
    try:
        os.unlink(p)
    except FileNotFoundError:
        pass
    key = secrets.token_urlsafe(16)
    with os.fdopen(os.open(p, os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0), 0o600), "w") as fh:
        fh.write(key + "\n")
    return key


def _servable(parts):
    """False for state, session and hidden files: they sit in the docroot but are not pages."""
    if not parts:
        return True
    if any(p.startswith(".") for p in parts) or parts[0].lower() in PRIVATE_DIRS:
        return False
    name = parts[-1].lower()
    return name not in IGNORED and not name.endswith(".versions.json")


def _loopback_host(value):
    """True when a Host header or an Origin names this machine (a rebound DNS name does not)."""
    if "//" not in value:
        value = "//" + value
    try:
        return urlsplit(value).hostname in LOOPBACK_HOSTS
    except ValueError:
        return False


TOKENS_META = re.compile(r'<meta\s+name="design-kit-tokens"\s+content="([0-9a-f]{12})[^"]*"', re.I)


def _tokens_sha(root):
    """sha12 of ../design-system/tokens.json relative to the docroot, or None."""
    p = os.path.join(os.path.dirname(root), "design-system", "tokens.json")
    try:
        with open(p, "rb") as fh:
            return hashlib.sha256(fh.read()).hexdigest()[:12]
    except OSError:
        return None


def _stamp_of(path):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            head = fh.read(8192)
    except OSError:
        return None
    m = TOKENS_META.search(head)
    return m.group(1) if m else None


def _walk_pages(root):
    pages = []
    current = _tokens_sha(root)
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if not d.startswith(".")]
        for fn in filenames:
            if fn.startswith(".") or fn in IGNORED or not fn.lower().endswith(PAGE_EXT):
                continue
            full = os.path.join(dirpath, fn)
            rel = os.path.relpath(full, root).replace(os.sep, "/")
            group = rel.split("/")[0] if "/" in rel else "(root)"
            stamp = _stamp_of(full)
            pages.append({
                "path": rel,
                "group": group,
                "mtime": int(os.stat(full).st_mtime),
                "title": _title_of(full) or fn,
                "tokens": {"stamp": stamp, "current": (stamp == current) if (stamp and current) else None},
            })
    pages.sort(key=lambda p: (-p["mtime"], p["path"]))
    return pages


def _title_of(path):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            head = fh.read(4096)
    except OSError:
        return None
    lo = head.lower()
    i = lo.find("<title>")
    if i < 0:
        return None
    j = lo.find("</title>", i)
    return html.unescape(head[i + 7:j].strip()) if j > i else None


def _newest_mtime(root):
    newest = 0.0
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if not d.startswith(".")]
        for fn in filenames:
            if fn in IGNORED:
                continue
            try:
                m = os.stat(os.path.join(dirpath, fn)).st_mtime
            except OSError:
                continue
            newest = max(newest, m)
    return newest


def _read_json(path, default):
    try:
        with open(path, "r", encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return default


def _decisions(root):
    rows = []
    try:
        with open(os.path.join(root, "decisions.jsonl"), "r", encoding="utf-8") as fh:
            for line in fh:
                try:
                    rows.append(json.loads(line))
                except ValueError:
                    continue
    except OSError:
        pass
    return rows


def flow_steps(root):
    """The workshop's flow as (label, detail, state) triples — state is done|open|todo.
    Read from workshop.json (dk.sh) and decisions.jsonl (the board)."""
    ws = _read_json(os.path.join(root, "workshop.json"), {})
    dec = _decisions(root)
    unread = [d for d in dec if not d.get("consumed")]
    steps = []
    sysd = ws.get("system") or {}
    steps.append(("system", ("tokens " + sysd["stamp"]) if sysd.get("stamp") else "not extracted", "done" if sysd.get("stamp") else "todo"))
    b = ws.get("board") or {}
    if b.get("file"):
        picked = b.get("picked")
        if not picked and dec:
            last = dec[-1]
            picked = last.get("picked")
        detail = os.path.basename(b["file"]) + (" · picked %s" % picked if picked else " · no pick yet")
        if unread:
            detail += " · %d unread" % len(unread)
        steps.append(("board", detail, "open" if unread or not picked else "done"))
    else:
        steps.append(("board", "no board", "todo"))
    sc = ws.get("scratch") or {}
    if sc.get("slug"):
        steps.append(("scratch", sc["slug"] + (" · kept" if sc.get("kept") else " · cleaned"), "open" if sc.get("kept") else "done"))
    else:
        steps.append(("scratch", "not rendered", "todo"))
    arts = ws.get("artifacts") or []
    if arts:
        a = arts[-1]
        steps.append(("artifact", "%s v%s" % (a.get("slug"), a.get("version")), "done"))
    else:
        steps.append(("artifact", "none", "todo"))
    d = ws.get("deck") or {}
    if d.get("file"):
        steps.append(("deck", os.path.basename(d["file"]) + (" · pdf" if d.get("pdf") else ""), "done"))
    else:
        steps.append(("deck", "none", "todo"))
    return steps


def _flow_html(root):
    steps = flow_steps(root)
    if all(st == "todo" for _, _, st in steps):
        return ""
    cells = []
    for label, detail, st in steps:
        cells.append(f"<li class=\"{st}\"><b>{html.escape(label)}</b><span>{html.escape(detail)}</span></li>")
    return "<ol class=\"flow\">" + "".join(cells) + "</ol>"


def _gallery_html(pages, live=True, root=None):
    groups = {}
    for p in pages:
        groups.setdefault(p["group"], []).append(p)
    parts = [
        "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\">",
        "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">",
        "<title>design-kit gallery</title>",
        "<style>body{font:15px/1.45 system-ui,sans-serif;margin:0;padding:24px;background:#f6f6f4;color:#1c1c1a}",
        "h1{font-size:20px;margin:0 0 16px}h2{font-size:14px;letter-spacing:.02em;margin:24px 0 8px;color:#55554f}",
        ".grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:14px}",
        "a.card{display:block;background:#fff;border:1px solid #dedcd6;border-radius:8px;overflow:hidden;text-decoration:none;color:inherit}",
        "a.card iframe{width:100%;height:160px;border:0;pointer-events:none;background:#fff}",
        "a.card .t{padding:8px 10px;font-weight:600;font-size:13px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}",
        "a.card .p{padding:0 10px 8px;font-size:12px;color:#77756e}",
        ".empty{color:#77756e}",
        "ol.flow{list-style:none;display:flex;gap:8px;padding:0;margin:0 0 20px;flex-wrap:wrap}",
        "ol.flow li{background:#fff;border:1px solid #dedcd6;border-radius:8px;padding:6px 10px;font-size:12px;display:grid;gap:2px;min-width:120px}",
        "ol.flow li b{font-size:11px;letter-spacing:.03em;text-transform:uppercase;color:#77756e}ol.flow li.done{border-color:#7fb58a}ol.flow li.open{border-color:#e0a33a}ol.flow li.todo{opacity:.6}",
        ".badge{display:inline-block;font-size:11px;padding:1px 6px;border-radius:999px;margin-left:6px;vertical-align:middle}.badge.ok{background:#e3f3e6;color:#1f6b30}.badge.stale{background:#fbeccc;color:#8a5a00}",
        "</style></head><body>",
        "<h1>design-kit gallery</h1>",
        _flow_html(root) if root else "",
    ]
    if not pages:
        parts.append("<p class=\"empty\">Nothing here yet. A deck, board, artifact or preview appears the moment a command writes one.</p>")
    for group, items in groups.items():
        parts.append(f"<h2>{html.escape(group)}</h2><div class=\"grid\">")
        for p in items:
            href = "/" + "/".join(html.escape(seg) for seg in p["path"].split("/"))
            when = time.strftime("%Y-%m-%d %H:%M", time.localtime(p["mtime"]))
            tok = p.get("tokens") or {}
            badge = ""
            if tok.get("current") is True:
                badge = "<span class=\"badge ok\" title=\"built with the current design-system/tokens.json\">tokens current</span>"
            elif tok.get("current") is False:
                badge = "<span class=\"badge stale\" title=\"design-system/tokens.json changed after this page was built — rebuild it\">tokens moved since build</span>"
            parts.append(
                f"<a class=\"card\" href=\"{href}\"><iframe loading=\"lazy\" src=\"{href}?static=1\" title=\"{html.escape(p['title'])}\"></iframe>"
                f"<div class=\"t\">{html.escape(p['title'])}{badge}</div><div class=\"p\">{html.escape(p['path'])} · {when}</div></a>"
            )
        parts.append("</div>")
    parts.append((RELOAD_SNIPPET if live else "") + "</body></html>")
    return "".join(parts)


class Handler(SimpleHTTPRequestHandler):
    root = "."
    state = None  # shared: {"version": int, "last": monotonic time a request ended, "streams": open /_events count}
    streams_lock = threading.Lock()
    key = None  # the LAN key; None when bound to loopback only

    def log_message(self, *_):
        pass

    def _gate(self):
        """True to go on; else the cookie page of a first keyed visit, or the 403, has been sent.
        That page redirects by meta refresh, not 303: a 303 ends a link followed from another site, where Chrome withholds a SameSite=Strict cookie."""
        path, query = split_target(self.path)
        verdict = lan_gate(self.key, self.client_address[0], query, self.headers.get("Cookie"))
        self._admitted = verdict != "deny"
        if verdict == "set" and self.command != "POST":
            clean = html.escape(without_key(path, query))
            body = f'<!doctype html><meta http-equiv="refresh" content="0;url={clean}"><a href="{clean}">Open the preview</a>'.encode()
            self.send_response(HTTPStatus.OK)
            self.send_header("Set-Cookie", f"{KEY_COOKIE}={self.key}; Path=/; HttpOnly; SameSite=Strict")
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            if self.command != "HEAD":
                self.wfile.write(body)
            return False
        if verdict == "deny":
            self.send_error(HTTPStatus.FORBIDDEN, "this preview needs its key: open the LAN URL that carries ?key=")
        return self._admitted

    def do_HEAD(self):
        if self._gate():
            super().do_HEAD()

    def handle_one_request(self):
        self._admitted = False
        try:
            super().handle_one_request()
        finally:
            if self._admitted:
                self.state["last"] = time.monotonic()

    def translate_path(self, path):
        return os.path.join(self.root, *_parts(split_target(path)[0]))

    def send_head(self):
        """GET and HEAD: 404 unless servable; the stdlib branch opens translate_path(self.path), the same pure mapping checked here."""
        path = split_target(self.path)[0]
        parts = _parts(path)
        if not _servable(parts):
            self.send_error(HTTPStatus.NOT_FOUND)
            return None
        full = os.path.join(self.root, *parts)
        if os.path.isdir(full) and path.endswith("/"):
            full = next((os.path.join(full, i) for i in ("index.html", "index.htm") if os.path.isfile(os.path.join(full, i))), full)
        if not (os.path.isfile(full) and full.lower().endswith(PAGE_EXT)):
            return super().send_head()
        try:
            with open(full, "rb") as fh:
                body = fh.read()
        except OSError:
            self.send_error(HTTPStatus.NOT_FOUND)
            return None
        i = body.lower().rfind(b"</body>")
        if i >= 0 and b"data-design-kit-reload" not in body and self._wants_live():
            body = body[:i] + RELOAD_SNIPPET.encode() + body[i:]
        self._head(len(body), "text/html; charset=utf-8")
        return io.BytesIO(body)

    def do_GET(self):
        if not self._gate():
            return
        path = split_target(self.path)[0]
        if path == "/_events":
            return self._events()
        if path == "/_index.json":
            return self._json(_walk_pages(self.root))
        if path in ("/", "/index.html") and not os.path.exists(os.path.join(self.root, "index.html")):
            return self._html(_gallery_html(_walk_pages(self.root), live=self._wants_live(), root=self.root))
        return super().do_GET()

    def list_directory(self, path):
        self.send_error(HTTPStatus.NOT_FOUND)
        return None

    def do_POST(self):
        if not self._gate():
            return
        if split_target(self.path)[0] != "/_decision":
            return self.send_error(HTTPStatus.NOT_IMPLEMENTED)
        if self.client_address[0] not in LOOPBACK:
            return self._reject(HTTPStatus.FORBIDDEN, "decisions are recorded from this machine only")
        origin = self.headers.get("Origin")
        if not _loopback_host(self.headers.get("Host") or "") or (origin and not _loopback_host(origin)):
            return self._reject(HTTPStatus.FORBIDDEN, "decisions are recorded from a page opened on this machine's own address")
        if not self.headers.get("X-Design-Kit-Decision"):
            return self._reject(HTTPStatus.FORBIDDEN, "missing X-Design-Kit-Decision header")
        try:
            length = int(self.headers.get("Content-Length") or "0")
        except ValueError:
            return self._reject(HTTPStatus.BAD_REQUEST, "bad Content-Length")
        if length <= 0 or length > DECISION_MAX:
            return self._reject(HTTPStatus.REQUEST_ENTITY_TOO_LARGE if length > DECISION_MAX else HTTPStatus.BAD_REQUEST, "body must be 1..%d bytes" % DECISION_MAX)
        raw = self.rfile.read(length)
        try:
            body = json.loads(raw.decode("utf-8"))
            if not isinstance(body, dict):
                raise ValueError("not an object")
        except (ValueError, UnicodeDecodeError) as exc:
            return self._reject(HTTPStatus.BAD_REQUEST, "invalid JSON: %s" % exc)
        row = {
            "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "board": str(body.get("board") or "")[:256],
            "picked": body.get("picked") if isinstance(body.get("picked"), int) else None,
            "knobs": body.get("knobs") if isinstance(body.get("knobs"), dict) else {},
            "text": body.get("text") if isinstance(body.get("text"), dict) else {},
            "prompt": str(body.get("prompt") or "")[:4096],
            "consumed": False,
        }
        with open(os.path.join(self.root, "decisions.jsonl"), "a", encoding="utf-8") as fh:
            fh.write(json.dumps(row, ensure_ascii=False) + "\n")
        self._json({"recorded": True, "ts": row["ts"]})

    def _reject(self, status, why):
        body = json.dumps({"recorded": False, "error": why}).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _wants_live(self):
        """Headless browsers taking a screenshot or a print must not get the
        reload snippet: its open EventSource never goes idle, so a virtual-time
        budget never expires and the capture hangs. `?static=1` opts any client out."""
        if "static=1" in split_target(self.path)[1]:
            return False
        return "headless" not in (self.headers.get("User-Agent") or "").lower()

    def _events(self):
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "keep-alive")
        self.end_headers()
        seen = self.state["version"]
        with self.streams_lock:
            self.state["streams"] += 1
        try:
            while True:
                if self.state["version"] != seen:
                    seen = self.state["version"]
                    self.wfile.write(b"data: reload\n\n")
                else:
                    self.wfile.write(b": ping\n\n")
                self.wfile.flush()
                time.sleep(0.75)
        except (BrokenPipeError, ConnectionResetError, OSError):
            return
        finally:
            with self.streams_lock:
                self.state["streams"] -= 1

    def _json(self, obj):
        self._bytes(json.dumps(obj, indent=1).encode(), "application/json")

    def _html(self, text):
        self._bytes(text.encode(), "text/html; charset=utf-8")

    def _head(self, length, ctype):
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(length))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()

    def _bytes(self, body, ctype):
        self._head(len(body), ctype)
        self.wfile.write(body)


def _watch(root, state, stop):
    last = _newest_mtime(root)
    while not stop.is_set():
        time.sleep(0.75)
        now = _newest_mtime(root)
        if now != last:
            last = now
            state["version"] += 1


def _idle_exit(srv, state, limit_s, stop):
    while not stop.wait(min(30.0, max(0.5, limit_s / 10))):
        if state["streams"] == 0 and time.monotonic() - state["last"] >= limit_s:
            print(f"design-kit: no request and no open page for {limit_s / 60:g} min; exiting", file=sys.stderr, flush=True)
            srv.shutdown()
            return


def _drop_state(root):
    """On the way out: remove .preview.pid, .url and .bind while the pid file still names this process (not a successor's)."""
    try:
        with open(os.path.join(root, ".preview.pid"), encoding="ascii") as fh:
            if fh.read().strip() != str(os.getpid()):
                return
    except (OSError, ValueError):
        return
    for name in (".preview.url", ".preview.bind", ".preview.pid"):
        try:
            os.unlink(os.path.join(root, name))
        except OSError:
            pass


def _minutes(name, default):
    try:
        return float(os.environ.get(name, default))
    except ValueError:
        return default


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--docroot", default=".design-kit")
    ap.add_argument("--port", type=int, default=int(os.environ.get("DESIGN_KIT_PORT", "8124")))
    ap.add_argument("--lan", action="store_true", help="bind 0.0.0.0 so devices on your network can open it")
    args = ap.parse_args(argv)
    root = os.path.abspath(args.docroot)
    os.makedirs(root, exist_ok=True)
    state = {"version": 0, "last": time.monotonic(), "streams": 0}
    Handler.root = root
    Handler.state = state
    try:
        Handler.key = _lan_key(root) if args.lan else None
    except OSError as exc:
        print(f"serve.py: cannot keep the LAN key in {os.path.join(root, KEY_FILE)} — {exc}", file=sys.stderr)
        return 4
    bind = "0.0.0.0" if args.lan else "127.0.0.1"
    try:
        srv = ThreadingHTTPServer((bind, args.port), Handler)
    except OSError as exc:
        print(f"serve.py: cannot bind {bind}:{args.port} — {exc}", file=sys.stderr)
        return 4
    srv.daemon_threads = True
    stop = threading.Event()
    lan_minutes = _minutes("DESIGN_KIT_LAN_MINUTES", 60.0)
    if args.lan and lan_minutes > 0:
        timer = threading.Timer(lan_minutes * 60, srv.shutdown)
        timer.daemon = True
        timer.start()
    idle_minutes = _minutes("DESIGN_KIT_IDLE_MINUTES", 240.0)
    if idle_minutes > 0:
        threading.Thread(target=_idle_exit, args=(srv, state, idle_minutes * 60, stop), daemon=True).start()
        print(f"design-kit: idle shutdown after {idle_minutes:g} min with no request and no open page (DESIGN_KIT_IDLE_MINUTES; 0 = off)", file=sys.stderr, flush=True)
    else:
        print("design-kit: idle shutdown off (DESIGN_KIT_IDLE_MINUTES=0)", file=sys.stderr, flush=True)
    threading.Thread(target=_watch, args=(root, state, stop), daemon=True).start()
    print(f"design-kit: serving {root} on http://{bind}:{args.port}/" + (f"?key={Handler.key}" if Handler.key else ""), flush=True)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        stop.set()
        srv.server_close()
        _drop_state(root)
    return 0


if __name__ == "__main__":
    sys.exit(main())
