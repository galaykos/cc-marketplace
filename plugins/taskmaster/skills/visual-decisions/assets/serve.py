#!/usr/bin/env python3
# Never served (404): a dot-prefixed file or folder at any depth (the .preview.* state files included), a directory listing. --lan: a non-loopback peer needs the key (?key= once, then an HttpOnly SameSite=Strict cookie, 403 otherwise), /_restore, /_feedback and /_checks stay loopback-only (the loopback URL is printed too), the key file is never followed through a symlink, the server exits after PREVIEW_LAN_MINUTES (60).
# Every mode exits after PREVIEW_IDLE_MINUTES (240) with no completed request that passed the key gate and no open event stream; 0 turns either limit off. Restore writes a dot temp file, then renames it over current.html. POST /_feedback (X-Preview-Feedback, local Host/Origin, 1..8192 bytes of a JSON pick or note; else 403/413/400) appends one clamped row (numbers to +-1e7, a lone surrogate as ?) to .feedback.jsonl under a flock on .feedback.lock, 507 once that file would pass 2 MiB; GET /_feedback?page= returns that page's rows. Render check: no route serves check.js or takes findings (scripts/preview-check.sh runs it in an isolated world and writes .checks/<page>-<hash>/<width>.json itself); GET /_checks?page= counts those records while the page's bytes still match (a page key with a control character is no page: 404), and a new run.json there streams a "checked" event. Harnesses: plugins/taskmaster/scripts/__tests__/serve.test.sh, preview-check.test.sh.
# Misses: a page served from here, third-party script included, can post a pick or a note, and note text is unverified; a deleted file (only changed or new paths are pushed); a ninth open stream (503); a symlink in the docroot is followed out of it; under --lan read routes skip the Origin/Host check and the key crosses the network in plain HTTP; the synthesized landing and gallery pages never reload; a kill mid-Restore leaves a .restore-*.tmp dot file behind.
# Why, limits, history: rationale/derivations/plugin-taskmaster.md § plugins/taskmaster/skills/visual-decisions/assets/serve.py
"""Threaded static file server with an SSE push-reload lane.

First rung of the mockup preview launch chain: static files under a docroot
(default ``taskmaster-docs/mockups``) plus ``GET /events``, a Server-Sent
Events stream that fires the changed file's docroot-relative path whenever a
watcher thread notices an mtime change. ``ThreadingHTTPServer`` means one
open SSE connection never blocks concurrent static requests.

Stdlib only. Usage:

    python3 serve.py [--port N] [--docroot DIR] [--lan]
"""

import argparse
import contextlib
import functools
import hashlib
import html
import hmac
import http.server
import ipaddress
import json
import math
import os
import queue
import re
import secrets
import shutil
import socket
import stat
import sys
import tempfile
import threading
import time
from pathlib import Path
from urllib.parse import parse_qsl, unquote, urlencode

try:
    import fcntl
except ImportError:
    fcntl = None

IDLE_MINUTES_DEFAULT = 240
LAN_MINUTES_DEFAULT = 60
LAN_KEY_FILE = ".preview.key"
KEY_COOKIE = "taskmaster_preview_key"
URLSAFE = set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
MAX_SSE_CLIENTS = 8
POLL_INTERVAL_SECONDS = 0.75
KEEPALIVE_SECONDS = 15
LOCAL_HOSTNAMES = {"localhost", "127.0.0.1", "::1"}
# Reserved per-purpose destinations other flows write to (see the landing map).
PER_PURPOSE_FILES = ("theme.html", "walkthrough.html", "diagram.html", "api.html", "modules.html", "compose.html")
# Per-purpose files are live destinations, not past passes of current.html: never offered as a restorable version.
LEDGER_EXCLUDED = {"current.html", "index.html"} | set(PER_PURPOSE_FILES)
# Restore demands a header no cross-origin <form> can set, forcing a CORS preflight this server never answers; Host/Origin alone would pass another localhost port.
RESTORE_HEADER = "X-Preview-Restore"
MAX_RESTORE_BODY = 4096
FEEDBACK_HEADER = "X-Preview-Feedback"
FEEDBACK_FILE = ".feedback.jsonl"
# scripts/preview-feedback.sh takes the same flock before it replaces the file, so an append never lands in the old copy.
FEEDBACK_LOCK = ".feedback.lock"
MAX_FEEDBACK_BODY = 8192
MAX_FEEDBACK_FILE = 2 * 1024 * 1024  # appends stop here (507): a page looping posts must not fill the disk
PIXELS = 10 ** 7  # every posted number is clamped to +-PIXELS
VARIANTS = ("A", "B", "C")
CHECKS_DIR = ".checks"  # dot-named, so never served: one folder per page, one record per width, written by scripts/preview-check.sh only
CHECK_STAMP = "run.json"  # preview-check.sh writes it last in a page's folder: the watcher streams "checked" for that page


def hostname_from_netloc(netloc):
    """Strip a port from a Host/Origin authority, IPv6-literal aware."""
    if not netloc:
        return ""
    if netloc.startswith("["):
        end = netloc.find("]")
        return netloc[1:end] if end != -1 else netloc
    return netloc.split(":", 1)[0]


def is_private(request_path):
    """True when any segment of the request path starts with a dot: dot files and folders, this server's own state files."""
    # Split as SimpleHTTPRequestHandler.translate_path does; urlsplit would read '//.env/' as a host.
    path = unquote(request_path.split("?", 1)[0].split("#", 1)[0])
    return any(segment.startswith(".") for segment in path.split("/"))


def peer_is_loopback(peer):
    try:
        addr = ipaddress.ip_address(peer)
    except ValueError:
        return False
    return (getattr(addr, "ipv4_mapped", None) or addr).is_loopback


def _same_key(given, key):
    return given is not None and hmac.compare_digest(given.encode("utf-8"), key.encode("utf-8"))


def lan_access(lan, peer, query_key, cookie_key, key):
    """The LAN key rule: 'open' (loopback, not LAN, or a valid cookie), 'grant' (a valid ?key=), or 'deny'."""
    if not lan or peer_is_loopback(peer):
        return "open"
    if key and _same_key(query_key, key):
        return "grant"
    if key and _same_key(cookie_key, key):
        return "open"
    return "deny"


def clean_location(request_path):
    """The request path without its key= parameter, rooted so it can never be read as another host."""
    path, _, query = request_path.partition("?")
    rest = [(k, v) for k, v in parse_qsl(query, keep_blank_values=True) if k != "key"]
    return "/" + path.lstrip("/\\") + ("?" + urlencode(rest) if rest else "")


def cookie_value(header, name):
    for part in header.split(";"):
        key, sep, value = part.strip().partition("=")
        if sep and key == name:
            return value
    return None


def load_or_create_key(docroot):
    """The LAN key, reused only from a regular dot-file holding one; anything else is unlinked, never followed, and replaced O_EXCL at 0600."""
    path = str(docroot / LAN_KEY_FILE)
    try:
        fd = os.open(path, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_NONBLOCK", 0))
    except OSError:
        fd = None
    if fd is not None:
        with os.fdopen(fd, "rb") as handle:
            if stat.S_ISREG(os.fstat(fd).st_mode):
                try:
                    key = handle.read(256).decode("utf-8").strip()
                except ValueError:
                    key = ""
                if len(key) >= 16 and set(key) <= URLSAFE:
                    if hasattr(os, "fchmod"):
                        os.fchmod(fd, 0o600)
                    return key
    try:
        os.unlink(path)
    except FileNotFoundError:
        pass
    key = secrets.token_urlsafe(24)
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0), 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        handle.write(key + "\n")
    return key


def _clean(text):
    """text with each lone surrogate made "?": a page slicing through an emoji posts one, and UTF-8 cannot write it."""
    return text.encode("utf-8", "replace").decode("utf-8")


def _clip(value, limit):
    return _clean(value[:limit]) if isinstance(value, str) else ""


def _number(value):
    """A posted number clamped to +-PIXELS; NaN, Infinity, a bool or a non-number is 0."""
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return 0
    if isinstance(value, float) and not math.isfinite(value):
        return 0
    if abs(value) >= PIXELS:
        return PIXELS if value > 0 else -PIXELS
    return value if isinstance(value, int) else round(value, 1)


def page_key(value):
    """A docroot-relative page path: leading slashes dropped, at most 256 characters."""
    return _clean(value.lstrip("/")[:256]) if isinstance(value, str) else ""


def feedback_row(body):
    """The row stored for a posted pick or note, or None when the body is neither; every field clamped, unknown keys dropped."""
    kind = body.get("kind")
    variant = body.get("variant") if body.get("variant") in VARIANTS else None
    text = _clip(body.get("text"), 2000)
    if not ((kind == "pick" and variant) or (kind == "note" and text.strip())):
        return None
    if kind == "pick":
        text = ""  # the page shows neither on a pick, and wait would hand them to the agent
    anchor = body.get("anchor")
    if kind == "note" and isinstance(anchor, dict) and _clip(anchor.get("selector"), 512):
        rect = anchor.get("rect") if isinstance(anchor.get("rect"), dict) else {}
        anchor = {
            "selector": _clip(anchor.get("selector"), 512),
            "tag": _clip(anchor.get("tag"), 32),
            "text": _clip(anchor.get("text"), 200),
            "rect": {k: _number(rect.get(k)) for k in ("x", "y", "w", "h")},
        }
    else:
        anchor = None
    context = body.get("context") if isinstance(body.get("context"), dict) else {}
    viewport = context.get("viewport") if isinstance(context.get("viewport"), dict) else {}
    states = context.get("states") if isinstance(context.get("states"), dict) else {}
    console = context.get("console") if isinstance(context.get("console"), list) else []
    return {
        "id": secrets.token_hex(4),
        "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "page": page_key(body.get("page")),
        "kind": kind,
        "variant": variant,
        "anchor": anchor,
        "text": text,
        "context": {
            "viewport": {k: _number(viewport.get(k)) for k in ("w", "h")},
            "theme": _clip(context.get("theme"), 16),
            "states": dict([(_clip(k, 32), _clip(v, 32)) for k, v in states.items() if isinstance(v, str)][:16]),
            "console": [_clip(s, 300) for s in console if isinstance(s, str)][-5:],
        },
        "status": "open",
        "reply": "",
        "handed_out": False,
    }


@contextlib.contextmanager
def feedback_lock(docroot):
    fd = os.open(str(docroot / FEEDBACK_LOCK), os.O_WRONLY | os.O_CREAT | getattr(os, "O_NOFOLLOW", 0), 0o600)
    try:
        if fcntl:
            fcntl.flock(fd, fcntl.LOCK_EX)
        yield
    finally:
        os.close(fd)


def append_feedback(docroot, row):
    """Append one row; False, writing nothing, when the file would pass MAX_FEEDBACK_FILE."""
    line = (json.dumps(row, ensure_ascii=False) + "\n").encode("utf-8")
    with feedback_lock(docroot):
        fd = os.open(str(docroot / FEEDBACK_FILE),
                     os.O_WRONLY | os.O_APPEND | os.O_CREAT | getattr(os, "O_NOFOLLOW", 0), 0o600)
        try:
            if os.fstat(fd).st_size + len(line) > MAX_FEEDBACK_FILE:
                return False
            os.write(fd, line)
        finally:
            os.close(fd)
    return True


def read_feedback(docroot):
    """Every parseable row of the feedback file; a missing file or a torn line reads as nothing."""
    try:
        fd = os.open(str(docroot / FEEDBACK_FILE), os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
    except OSError:
        return []
    rows = []
    with os.fdopen(fd, "r", encoding="utf-8", errors="replace") as handle:
        for line in handle:
            try:
                row = json.loads(line)
            except ValueError:
                continue
            if isinstance(row, dict):
                rows.append(row)
    return rows


def check_page(docroot, value):
    """(page key, file) for an existing .html file inside docroot with no dot segment and no control character, else None."""
    key = page_key(value)
    if (any(not seg or seg.startswith(".") for seg in key.split("/")) or not key.lower().endswith((".html", ".htm"))
            or re.search(r"[\x00-\x1f\x7f-\x9f]", key)):
        return None
    try:
        target = (docroot / key).resolve()
        return (key, target) if docroot in target.parents and target.is_file() else None
    except (OSError, ValueError):
        return None


def check_dir(docroot, key):
    """A page's private record folder: .checks/<readable name>-<first 10 hex of the key's sha1>."""
    safe = re.sub(r"[^A-Za-z0-9._-]+", "_", key)[:80]
    return docroot / CHECKS_DIR / "{}-{}".format(safe, hashlib.sha1(key.encode("utf-8")).hexdigest()[:10])


def file_sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_checks(docroot, key, digest):
    """The badge's view of a page: only records taken of the bytes the file holds now count."""
    folder = check_dir(docroot, key)
    records = []
    try:
        entries = list(os.scandir(folder))
    except OSError:
        entries = []
    for entry in entries:
        if entry.name.endswith(".json") and not entry.name.startswith(".") and entry.is_file(follow_symlinks=False):
            try:
                with open(entry.path, encoding="utf-8") as handle:
                    record = json.load(handle)
            except (OSError, ValueError):
                continue
            if isinstance(record, dict):
                records.append(record)
    fresh = [r for r in records if r.get("page_sha256") == digest]
    unique = {(f.get("check"), f.get("selector"), f.get("text"), f.get("detail"))
              for r in fresh for f in (r.get("findings") or []) if isinstance(f, dict)}
    return {
        "page": key,
        "dir": folder.relative_to(docroot).as_posix(),
        "checked": bool(fresh),
        "stale": bool(records) and not fresh,
        "findings": len(unique) + sum(r.get("dropped") or 0 for r in fresh if isinstance(r.get("dropped"), int)),
        "widths": sorted(r["width"] for r in fresh if isinstance(r.get("width"), int)),
    }


def lan_address():
    """This machine's address on its default route (a UDP connect sends nothing), else 127.0.0.1."""
    probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        probe.connect(("203.0.113.1", 9))
        return probe.getsockname()[0]
    except OSError:
        return "127.0.0.1"
    finally:
        probe.close()


class ServerState:
    """Shared mutable state between the request threads and the watcher."""

    def __init__(self, docroot, lan, key=""):
        self.docroot = docroot
        self.lan = lan
        self.key = key
        self.lock = threading.Lock()
        self.clients = []  # list[queue.Queue]
        self.last_activity = time.monotonic()

    def touch(self):
        with self.lock:
            self.last_activity = time.monotonic()

    def idle_for(self, now):
        """Seconds since the last completed request; 0 while any event stream is open."""
        with self.lock:
            return 0.0 if self.clients else now - self.last_activity

    def add_client(self):
        with self.lock:
            if len(self.clients) >= MAX_SSE_CLIENTS:
                return None
            client = queue.Queue(maxsize=64)
            self.clients.append(client)
            return client

    def drop_client(self, client):
        with self.lock:
            if client in self.clients:
                self.clients.remove(client)

    def broadcast(self, rel_path, event="change"):
        with self.lock:
            targets = list(self.clients)
        for client in targets:
            try:
                client.put_nowait((event, rel_path))
            except queue.Full:
                pass  # slow/idle client — drop the event, keep-alive still finds it dead

    def close_all(self):
        with self.lock:
            targets = list(self.clients)
        for client in targets:
            try:
                client.put_nowait(None)
            except queue.Full:
                pass


def _esc(text):
    """Minimal HTML escaper — stdlib-only, avoids importing the ``html`` module.

    Used solely by the synthesized landing/gallery pages.
    """
    return (
        str(text)
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
        .replace("'", "&#39;")
    )


def _urlenc(text):
    """Percent-encode one path segment — stdlib-only, no ``urllib`` import.

    Used solely for href/src path segments in the synthesized
    landing/gallery pages, so filenames with spaces/#/?/% still produce a
    working link. Keeps RFC 3986 unreserved characters; escapes everything
    else. Use ``_esc`` (not this) for visible text.
    """
    unreserved = (
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~"
    )
    out = []
    for byte in str(text).encode("utf-8"):
        ch = chr(byte)
        if ch in unreserved:
            out.append(ch)
        else:
            out.append("%{:02X}".format(byte))
    return "".join(out)


def build_handler(state):
    """Return a request-handler callable bound to ``state``'s docroot."""

    class Handler(http.server.SimpleHTTPRequestHandler):
        server_version = "MockupPreview/1.0"

        def handle(self):
            self.admitted = False
            try:
                super().handle()
            finally:
                if self.admitted:
                    state.touch()

        def lan_gate(self):
            """Apply the LAN key rule; False when the response (403, or the cookie-setting page) is already sent."""
            query = self.path.partition("?")[2]
            query_key = next((v for k, v in parse_qsl(query, keep_blank_values=True) if k == "key"), None)
            cookie_key = cookie_value(self.headers.get("Cookie", ""), KEY_COOKIE)
            access = lan_access(state.lan, self.client_address[0], query_key, cookie_key, state.key)
            self.admitted = access != "deny"
            if access == "open":
                return True
            if access == "deny":
                self.send_error(403, "Forbidden (LAN key required)")
                return False
            # A page with a meta refresh, not a 303: a browser withholds a SameSite=Strict cookie on the redirect of a link followed from another site.
            clean = html.escape(clean_location(self.path), quote=True)
            body = '<!doctype html><meta http-equiv="refresh" content="0;url={0}"><a href="{0}">Open the preview</a>'.format(clean).encode()
            self.send_response(200)
            self.send_header("Set-Cookie", "{}={}; Path=/; HttpOnly; SameSite=Strict".format(KEY_COOKIE, state.key))
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            if self.command != "HEAD":
                self.wfile.write(body)
            return False

        def do_HEAD(self):
            if self.lan_gate():
                super().do_HEAD()

        def do_GET(self):
            if not self.lan_gate():
                return
            path = self.path.split("?", 1)[0]
            if path == "/events":
                self.handle_sse()
                return
            # Synthesized session-map and gallery pages: STATIC snapshots (no SSE, no reload script); a user-authored index.html always wins.
            if path in ("/", ""):
                if (state.docroot / "index.html").exists():
                    super().do_GET()  # user's own index.html wins verbatim
                    return
                self.serve_landing()
                return
            if path == "/gallery/" and not (state.docroot / "gallery" / "index.html").exists():
                self.serve_gallery()
                return
            # Ledger lane: the dated passes on disk, as data, for an open preview's version picker.
            if path == "/_versions.json":
                self.serve_versions()
                return
            if path == "/_feedback":
                self.serve_feedback()
                return
            if path == "/_checks":
                self.serve_checks()
                return
            super().do_GET()

        def do_POST(self):
            if not self.lan_gate():
                return
            route = self.path.split("?", 1)[0]
            if route == "/_restore":
                self.handle_restore()
                return
            if route == "/_feedback":
                self.handle_feedback()
                return
            self.send_error(404, "Not Found")

        def is_loopback_local(self):
            """Loopback peer and a local Host/Origin, in LAN mode too: the rule for /_restore and /_feedback."""
            return peer_is_loopback(self.client_address[0]) and self.host_and_origin_local()

        def serve_feedback(self):
            """The feedback rows for ?page=, as data, for the shell's status list."""
            if not self.is_loopback_local():
                self.send_error(403, "Forbidden (feedback is loopback-only)")
                return
            query = self.path.partition("?")[2]
            page = page_key(next((v for k, v in parse_qsl(query, keep_blank_values=True) if k == "page"), ""))
            self._send_json({"rows": [r for r in read_feedback(state.docroot) if r.get("page") == page]})

        def handle_feedback(self):
            """Append one pick or note row to .feedback.jsonl; the guards are /_restore's, the header its own."""
            if not self.is_loopback_local():
                self.send_error(403, "Forbidden (feedback is loopback-only)")
                return
            if not self.headers.get(FEEDBACK_HEADER):
                self.send_error(403, "Forbidden (missing %s)" % FEEDBACK_HEADER)
                return
            try:
                length = int(self.headers.get("Content-Length", "0"))
            except ValueError:
                length = 0
            if length > MAX_FEEDBACK_BODY:
                self.send_error(413, "Body too large")
                return
            body = None
            if length > 0:
                try:
                    body = json.loads(self.rfile.read(length).decode("utf-8"))
                except (ValueError, UnicodeDecodeError, RecursionError):
                    body = None
            row = feedback_row(body) if isinstance(body, dict) else None
            if row is None:
                self._send_json({"recorded": False, "error": "body must be a JSON pick or note of 1..%d bytes" % MAX_FEEDBACK_BODY}, 400)
                return
            try:
                if not append_feedback(state.docroot, row):
                    self._send_json({"recorded": False, "error": "%s has reached its %d MiB cap; move it aside to record more"
                                     % (FEEDBACK_FILE, MAX_FEEDBACK_FILE // (1024 * 1024))}, 507)
                    return
            except OSError as exc:
                self._send_json({"recorded": False, "error": str(exc)}, 500)
                return
            self._send_json({"recorded": True, "id": row["id"]})

        def serve_checks(self):
            """Whether ?page= was checked as its bytes stand now, and the finding count, for the shell's badge."""
            if not self.is_loopback_local():
                self.send_error(403, "Forbidden (the render check is loopback-only)")
                return
            query = self.path.partition("?")[2]
            found = check_page(state.docroot, next((v for k, v in parse_qsl(query, keep_blank_values=True) if k == "page"), ""))
            try:
                digest = file_sha256(found[1]) if found else None
            except OSError:
                digest = None
            if digest is None:
                self._send_json({"error": "no such page in the docroot"}, 404)
                return
            self._send_json(read_checks(state.docroot, found[0], digest))

        def handle_sse(self):
            if not self.is_local_request():
                self.send_error(403, "Forbidden (non-local Origin/Host)")
                return
            client = state.add_client()
            if client is None:
                self.send_error(503, "Too many preview streams open")
                return
            try:
                self.send_response(200)
                self.send_header("Content-Type", "text/event-stream")
                self.send_header("Cache-Control", "no-cache")
                self.send_header("Connection", "close")
                self.end_headers()
                self.wfile.write(b": connected\n\n")
                self.wfile.flush()
                while True:
                    try:
                        item = client.get(timeout=KEEPALIVE_SECONDS)
                    except queue.Empty:
                        self.wfile.write(b": keep-alive\n\n")
                        self.wfile.flush()
                        continue
                    if item is None:
                        break
                    payload = "event: {}\ndata: {}\n\n".format(*item)
                    self.wfile.write(payload.encode("utf-8"))
                    self.wfile.flush()
            except (BrokenPipeError, ConnectionResetError, OSError):
                pass
            finally:
                state.drop_client(client)

        def is_local_request(self):
            return state.lan or self.host_and_origin_local()

        def host_and_origin_local(self):
            if hostname_from_netloc(self.headers.get("Host", "")) not in LOCAL_HOSTNAMES:
                return False
            origin = self.headers.get("Origin")
            if origin:
                origin_netloc = origin.split("://", 1)[-1]
                if hostname_from_netloc(origin_netloc) not in LOCAL_HOSTNAMES:
                    return False
            return True

        def send_head(self):
            if is_private(self.path):
                self.send_error(404, "Not Found")
                return None
            return super().send_head()

        def list_directory(self, path):
            self.send_error(404, "Not Found")
            return None

        def log_message(self, fmt, *args):
            sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

        def _send_html(self, body):
            """Send a hand-built HTML string with a 200. STATIC — no reload lane."""
            payload = body.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(payload)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(payload)

        def _send_json(self, obj, status=200):
            payload = json.dumps(obj).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(payload)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(payload)

        def _ledger_entry(self, name):
            """(name, mtime) for a top-level ledger .html, or None if excluded."""
            low = name.lower()
            if "/" in name or name.startswith(".") or not low.endswith(".html") or low in LEDGER_EXCLUDED:
                return None
            try:
                return (name, (state.docroot / name).stat().st_mtime)
            except OSError:
                return None

        def serve_versions(self):
            """JSON list of the dated ledger passes, newest first.

            Feeds the shell's version picker. Read-only and local-guarded like
            every other synthesized route.
            """
            if not self.is_local_request():
                self.send_error(403, "Forbidden (non-local Origin/Host)")
                return
            entries = []
            for rel, _stat in scan_mtimes(state.docroot):
                entry = self._ledger_entry(rel)
                if entry is not None:
                    entries.append(entry)
            entries.sort(key=lambda item: item[1], reverse=True)
            self._send_json({
                "current": "current.html",
                "versions": [{"name": n, "mtime": m} for n, m in entries],
            })

        def handle_restore(self):
            """Copy a chosen ledger pass over current.html (rollback).

            The ONLY route that writes. Four independent gates, because a
            localhost port is not a trust boundary: a loopback peer with a local
            Origin/Host (in LAN mode too, a valid key included), the
            preflight-forcing custom header, a bounded body, and a name that
            must be a bare basename resolving to an existing top-level ledger
            file inside the docroot. The destination is hardcoded — a request
            never names what it overwrites.
            """
            if not self.is_loopback_local():
                self.send_error(403, "Forbidden (restore is loopback-only)")
                return
            if not self.headers.get(RESTORE_HEADER):
                self.send_error(403, "Forbidden (missing %s)" % RESTORE_HEADER)
                return
            try:
                length = int(self.headers.get("Content-Length", "0"))
            except ValueError:
                length = -1
            if length < 0 or length > MAX_RESTORE_BODY:
                self.send_error(413, "Body too large")
                return
            try:
                body = json.loads(self.rfile.read(length).decode("utf-8") or "{}")
                name = body["name"]
            except (ValueError, KeyError, UnicodeDecodeError):
                self._send_json({"ok": False, "error": "bad request body"}, 400)
                return
            # A non-basename is rejected before the filesystem is touched: Path('a/../b').name would launder a traversal.
            if (not isinstance(name, str) or not name or name != Path(name).name
                    or name in (".", "..") or self._ledger_entry(name) is None):
                self._send_json({"ok": False, "error": "not a ledger file"}, 400)
                return
            source = (state.docroot / name).resolve()
            if source.parent != state.docroot or not source.is_file():
                self._send_json({"ok": False, "error": "not a ledger file"}, 400)
                return
            # Copy to a dot-named temp file, then one rename: a kill mid-copy leaves current.html whole.
            dest = state.docroot / "current.html"
            tmp = None
            try:
                fd, tmp = tempfile.mkstemp(dir=str(state.docroot), prefix=".restore-", suffix=".tmp")
                with os.fdopen(fd, "wb") as out, open(source, "rb") as src:
                    shutil.copyfileobj(src, out)
                if dest.exists():
                    os.chmod(tmp, stat.S_IMODE(dest.stat().st_mode))
                os.replace(tmp, str(dest))
            except OSError as exc:
                if tmp is not None and os.path.exists(tmp):
                    os.unlink(tmp)
                self._send_json({"ok": False, "error": str(exc)}, 500)
                return
            # No explicit broadcast: the watcher sees current.html's new mtime and pushes the reload.
            self._send_json({"ok": True, "restored": name})

        def serve_landing(self):
            """Synthesized session-map landing for '/' (no user index.html present).

            current.html is marked the LIVE decision; active per-purpose files
            (theme/walkthrough/diagram/api.html when present) and dated ledger
            files (newest first) follow, plus a link to /gallery/. Empty docroot
            yields an honest empty state. A STATIC snapshot — no reload injected.
            """
            if not self.is_local_request():
                self.send_error(403, "Forbidden (non-local Origin/Host)")
                return
            root = state.docroot
            top_html = []       # [(name, mtime)] for top-level *.html
            gallery_count = 0
            for rel, (mtime, _size) in scan_mtimes(root):  # reuse the shared os.walk scan
                low = rel.lower()
                if not low.endswith(".html"):
                    continue
                if "/" not in rel:
                    top_html.append((rel, mtime))
                elif rel.startswith("gallery/") and rel.count("/") == 1 and low != "gallery/index.html":
                    gallery_count += 1

            present = {name for name, _ in top_html}
            per_purpose = [n for n in PER_PURPOSE_FILES if n in present]
            special = {"current.html"} | set(per_purpose)
            ledger = sorted(
                ((n, m) for n, m in top_html if n not in special),
                key=lambda item: item[1], reverse=True,
            )

            css = (
                "body{font:15px/1.5 system-ui,-apple-system,sans-serif;max-width:52rem;"
                "margin:2rem auto;padding:0 1rem;color:#1a1a1a}"
                "h1{margin:0 0 .25rem}"
                "h2{margin:1.6rem 0 .4rem;font-size:.8rem;text-transform:uppercase;"
                "letter-spacing:.05em;color:#666}"
                "ul{list-style:none;padding:0;margin:0}li{margin:.2rem 0}"
                "a{color:#0b57d0;text-decoration:none}a:hover{text-decoration:underline}"
                ".live{font-size:1.15rem;font-weight:600}"
                ".badge{background:#0b8043;color:#fff;font-size:.62rem;font-weight:700;"
                "padding:.1rem .4rem;border-radius:.5rem;vertical-align:middle;margin-left:.4rem}"
                ".empty{color:#666}"
                "code{background:#f1f3f4;padding:.05rem .3rem;border-radius:.25rem}"
            )
            parts = [
                "<!DOCTYPE html>", '<html lang="en"><head><meta charset="utf-8">',
                '<meta name="viewport" content="width=device-width, initial-scale=1">',
                "<title>Mockup session map</title><style>", css, "</style></head><body>",
                "<h1>Mockup session</h1>",
            ]
            if not top_html and gallery_count == 0:
                parts.append(
                    '<p class="empty">No mockups yet &mdash; the pipeline writes '
                    "<code>current.html</code> on the first visual decision.</p>"
                )
            else:
                if "current.html" in present:
                    parts.append("<h2>Live decision</h2>")
                    parts.append(
                        '<a class="live" href="/current.html">current.html'
                        '<span class="badge">LIVE</span></a>'
                    )
                if per_purpose:
                    parts.append("<h2>Active views</h2><ul>")
                    for name in per_purpose:
                        parts.append(
                            '<li><a href="/{0}">{1}</a></li>'.format(_urlenc(name), _esc(name))
                        )
                    parts.append("</ul>")
                if ledger:
                    parts.append("<h2>Ledger <small>(newest first)</small></h2><ul>")
                    for name, _m in ledger:
                        parts.append(
                            '<li><a href="/{0}">{1}</a></li>'.format(_urlenc(name), _esc(name))
                        )
                    parts.append("</ul>")
                parts.append('<p><a href="/gallery/">Browse the gallery &rarr;</a></p>')
            parts.append("</body></html>")
            self._send_html("".join(parts))

        def serve_gallery(self):
            """Synthesized gallery index for '/gallery/' (no user index.html there).

            One card per gallery/*.html: a scaled same-origin <iframe> thumbnail
            plus a caption parsed from gallery/INDEX.md (filename fallback).
            Inline CSS only, no external assets. A STATIC snapshot — no reload.
            """
            if not self.is_local_request():
                self.send_error(403, "Forbidden (non-local Origin/Host)")
                return
            gdir = state.docroot / "gallery"
            files = []
            # Rooted at gallery/, not the docroot, to avoid O(whole-tree) I/O per hit.
            for name, (_mtime, _size) in scan_mtimes(gdir):
                if "/" in name:
                    continue
                low = name.lower()
                if low.endswith(".html") and low != "index.html":
                    files.append(name)
            files.sort()
            captions = self._gallery_captions(gdir)

            css = (
                "body{font:15px/1.5 system-ui,-apple-system,sans-serif;max-width:60rem;"
                "margin:2rem auto;padding:0 1rem;color:#1a1a1a}h1{margin:0 0 1rem}"
                "a{color:#0b57d0;text-decoration:none}a:hover{text-decoration:underline}"
                ".grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));"
                "gap:1.2rem}"
                ".card{border:1px solid #dadce0;border-radius:.5rem;overflow:hidden;background:#fff}"
                ".thumb{display:block;width:100%;height:200px;overflow:hidden;position:relative;"
                "border-bottom:1px solid #eee;background:#fafafa}"
                ".thumb iframe{width:1280px;height:800px;border:0;transform:scale(.25);"
                "transform-origin:top left;pointer-events:none}"
                ".cap{padding:.5rem .7rem;font-size:.9rem}.empty{color:#666}"
            )
            parts = [
                "<!DOCTYPE html>", '<html lang="en"><head><meta charset="utf-8">',
                '<meta name="viewport" content="width=device-width, initial-scale=1">',
                "<title>Gallery</title><style>", css, "</style></head><body>",
                "<h1>Gallery</h1>",
            ]
            if not files:
                parts.append('<p class="empty">No gallery pages yet.</p>')
            else:
                parts.append('<div class="grid">')
                for name in files:
                    caption = captions.get(name, name)
                    href = _urlenc(name)
                    parts.append('<div class="card">')
                    parts.append(
                        '<a class="thumb" href="/gallery/{0}"><iframe src="/gallery/{0}" '
                        'scrolling="no" tabindex="-1" aria-hidden="true" loading="lazy">'
                        "</iframe></a>".format(href)
                    )
                    parts.append(
                        '<div class="cap"><a href="/gallery/{0}">{1}</a></div>'.format(
                            href, _esc(caption)
                        )
                    )
                    parts.append("</div>")
                parts.append("</div>")
            parts.append('<p><a href="/">&larr; Session map</a></p>')
            parts.append("</body></html>")
            self._send_html("".join(parts))

        def _gallery_captions(self, gdir):
            """Parse gallery/INDEX.md into {filename: caption} (best-effort, no re)."""
            captions = {}
            try:
                text = (gdir / "INDEX.md").read_text(encoding="utf-8", errors="replace")
            except OSError:
                return captions
            for raw in text.splitlines():
                line = raw.strip()
                if not line or ".html" not in line.lower():
                    continue
                # Markdown link form: [caption](file.html)
                if "](" in line:
                    close = line.find("](")
                    open_b = line.rfind("[", 0, close)
                    end = line.find(")", close)
                    if open_b != -1 and end != -1:
                        target = line[close + 2:end].strip().split("/")[-1]
                        caption = line[open_b + 1:close].strip()
                        if target.lower().endswith(".html") and caption:
                            captions.setdefault(target, caption)
                            continue
                # Fallback: "file.html — caption" / "- file.html: caption" / table row.
                fname = None
                for tok in line.replace("|", " ").split():
                    cand = tok.strip("`*_-.,:;()[]").split("/")[-1]
                    if cand.lower().endswith(".html"):
                        fname = cand
                        break
                if fname:
                    idx = line.find(fname)
                    rest = line[idx + len(fname):].strip(" \t-—–:|`*")
                    if rest:
                        captions.setdefault(fname, rest)
            return captions

    return functools.partial(Handler, directory=str(state.docroot))


def scan_mtimes(docroot):
    """Yield (docroot-relative posix path, (mtime, size)) for every servable file under docroot."""
    for root, dirs, files in os.walk(docroot):
        dirs[:] = [d for d in dirs if not d.startswith(".")]
        for name in files:
            if name.startswith("."):
                continue
            full = Path(root) / name
            try:
                st = full.stat()
            except OSError:
                continue
            yield full.relative_to(docroot).as_posix(), (st.st_mtime, st.st_size)


def scan_stamps(docroot):
    """Yield (stamp path, (mtime, size)) for each page folder's run.json under .checks."""
    try:
        folders = list(os.scandir(docroot / CHECKS_DIR))
    except OSError:
        return
    for folder in folders:
        try:
            if folder.is_dir(follow_symlinks=False):
                st = os.stat(os.path.join(folder.path, CHECK_STAMP), follow_symlinks=False)
                yield os.path.join(folder.path, CHECK_STAMP), (st.st_mtime, st.st_size)
        except OSError:
            continue


def stamped_page(path):
    try:
        with open(path, encoding="utf-8") as handle:
            page = json.load(handle).get("page")
    except (OSError, ValueError, AttributeError):
        return None
    return page if isinstance(page, str) else None


def watch_loop(state, stop_event):
    """Poll file mtimes under docroot; broadcast each changed/new path, and "checked" for a page whose run.json changed."""
    mtimes = dict(scan_mtimes(state.docroot))
    stamps = dict(scan_stamps(state.docroot))
    while not stop_event.wait(POLL_INTERVAL_SECONDS):
        current = dict(scan_mtimes(state.docroot))
        for rel_path, mtime in current.items():
            if mtimes.get(rel_path) != mtime:
                state.broadcast(rel_path)
        mtimes = current
        now = dict(scan_stamps(state.docroot))
        for path, mtime in now.items():
            page = stamped_page(path) if stamps.get(path) != mtime else None
            if page:
                state.broadcast(page, event="checked")
        stamps = now


def minutes_from_env(name, default):
    """A minutes setting: unset or unreadable gives the default; 0 or less means off (0.0)."""
    raw = os.environ.get(name, "").strip()
    try:
        value = float(raw) if raw else float(default)
    except ValueError:
        value = float(default)
    return max(value, 0.0)


def describe_minutes(minutes, off_text):
    return "{:g} minutes".format(minutes) if minutes else off_text


def stop_reason(state, started, now, lan_seconds, idle_seconds):
    if lan_seconds and now - started >= lan_seconds:
        return "the LAN time limit passed (PREVIEW_LAN_MINUTES)"
    if idle_seconds and state.idle_for(now) >= idle_seconds:
        return "idle, no request and no open stream (PREVIEW_IDLE_MINUTES)"
    return None


def lifetime_loop(state, httpd, stop_event, lan_seconds, idle_seconds):
    """Shut the server down at the LAN time limit or after the idle limit."""
    started = time.monotonic()
    tick = min(5.0, max(0.1, min(s for s in (lan_seconds, idle_seconds) if s) / 4))
    while not stop_event.wait(tick):
        reason = stop_reason(state, started, time.monotonic(), lan_seconds, idle_seconds)
        if reason:
            print("Stopping: {}".format(reason), file=sys.stderr, flush=True)
            httpd.shutdown()
            return


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--port", type=int, default=int(os.environ.get("PREVIEW_PORT", 8123)),
        help="Port to bind (default: $PREVIEW_PORT or 8123).",
    )
    parser.add_argument(
        "--docroot", default="taskmaster-docs/mockups",
        help="Directory to serve; created if missing (default: taskmaster-docs/mockups).",
    )
    parser.add_argument(
        "--lan", action="store_true",
        help="Bind 0.0.0.0; a non-loopback peer needs the key printed in the URL; exits after $PREVIEW_LAN_MINUTES (default 60).",
    )
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    docroot = Path(args.docroot).resolve()
    docroot.mkdir(parents=True, exist_ok=True)

    state = ServerState(docroot=docroot, lan=args.lan)
    if args.lan:
        try:
            state.key = load_or_create_key(docroot)
        except OSError as e:
            print(f"cannot keep the LAN key in {docroot / LAN_KEY_FILE}: {e}", file=sys.stderr)
            sys.exit(1)
    host = "0.0.0.0" if args.lan else "127.0.0.1"
    try:
        httpd = http.server.ThreadingHTTPServer((host, args.port), build_handler(state))
    except OSError as e:
        print(f"port {args.port} unavailable: {e}", file=sys.stderr)
        sys.exit(1)
    httpd.daemon_threads = True
    if args.lan:
        url = "http://{}:{}/?key={}".format(lan_address(), args.port, state.key)
    else:
        url = "http://127.0.0.1:{}/".format(args.port)

    stop_event = threading.Event()
    watcher = threading.Thread(target=watch_loop, args=(state, stop_event), daemon=True)
    watcher.start()

    idle_minutes = minutes_from_env("PREVIEW_IDLE_MINUTES", IDLE_MINUTES_DEFAULT)
    lan_minutes = minutes_from_env("PREVIEW_LAN_MINUTES", LAN_MINUTES_DEFAULT) if args.lan else 0.0
    if idle_minutes or lan_minutes:
        threading.Thread(
            target=lifetime_loop, args=(state, httpd, stop_event, lan_minutes * 60, idle_minutes * 60), daemon=True,
        ).start()

    print("Serving {} at {}  (SSE: GET /events)".format(docroot, url), file=sys.stderr, flush=True)
    if args.lan:
        print(
            "On this machine: http://127.0.0.1:{}/ (open this one here; Restore refuses a page opened from the network"
            " address, even on this machine)".format(args.port),
            file=sys.stderr, flush=True,
        )
        print(
            "LAN mode: a device on this network needs the key in that URL (kept in {}); restore stays on this machine;"
            " it exits after {} (PREVIEW_LAN_MINUTES, 0 = no limit).".format(
                LAN_KEY_FILE, describe_minutes(lan_minutes, "no time limit")),
            file=sys.stderr, flush=True,
        )
    print(
        "Idle shutdown: after {} with no request and no open stream (PREVIEW_IDLE_MINUTES, 0 = off).".format(
            describe_minutes(idle_minutes, "never")),
        file=sys.stderr, flush=True,
    )
    try:
        httpd.serve_forever(poll_interval=0.5)
    except KeyboardInterrupt:
        pass
    finally:
        stop_event.set()
        state.close_all()
        httpd.shutdown()
        httpd.server_close()
        watcher.join(timeout=2)


if __name__ == "__main__":
    main()
