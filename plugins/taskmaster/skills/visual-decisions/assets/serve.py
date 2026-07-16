#!/usr/bin/env python3
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
import functools
import http.server
import os
import queue
import sys
import threading
from pathlib import Path

MAX_SSE_CLIENTS = 8
POLL_INTERVAL_SECONDS = 0.75
KEEPALIVE_SECONDS = 15
LOCAL_HOSTNAMES = {"localhost", "127.0.0.1", "::1"}


def hostname_from_netloc(netloc):
    """Strip a port from a Host/Origin authority, IPv6-literal aware."""
    if not netloc:
        return ""
    if netloc.startswith("["):
        end = netloc.find("]")
        return netloc[1:end] if end != -1 else netloc
    return netloc.split(":", 1)[0]


class ServerState:
    """Shared mutable state between the request threads and the watcher."""

    def __init__(self, docroot, lan):
        self.docroot = docroot
        self.lan = lan
        self.lock = threading.Lock()
        self.clients = []  # list[queue.Queue]

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

    def broadcast(self, rel_path):
        with self.lock:
            targets = list(self.clients)
        for client in targets:
            try:
                client.put_nowait(rel_path)
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

    ADDITIVE helper: used solely by the synthesized landing/gallery pages.
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

    ADDITIVE helper: used solely for href/src path segments in the synthesized
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

        def do_GET(self):
            path = self.path.split("?", 1)[0]
            if path == "/events":
                self.handle_sse()
                return
            # --- ADDITIVE landing/gallery branches ------------------------------
            # Synthesized session-map and gallery pages. Both are STATIC snapshots:
            # no SSE and no auto-reload script is injected, and the /events lane
            # plus the per-purpose-file model (basename filter) stay untouched. A
            # user-authored index.html always wins. Delete these two branches (and
            # the serve_landing / serve_gallery / _gallery_captions helpers) to
            # revert '/' and '/gallery/' to today's stock autoindex.
            if path in ("/", ""):
                if (state.docroot / "index.html").exists():
                    super().do_GET()  # user's own index.html wins verbatim
                    return
                self.serve_landing()
                return
            if path == "/gallery/" and not (state.docroot / "gallery" / "index.html").exists():
                self.serve_gallery()
                return
            # --- end ADDITIVE ---------------------------------------------------
            super().do_GET()

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
                        rel_path = client.get(timeout=KEEPALIVE_SECONDS)
                    except queue.Empty:
                        self.wfile.write(b": keep-alive\n\n")
                        self.wfile.flush()
                        continue
                    if rel_path is None:
                        break
                    payload = "event: change\ndata: {}\n\n".format(rel_path)
                    self.wfile.write(payload.encode("utf-8"))
                    self.wfile.flush()
            except (BrokenPipeError, ConnectionResetError, OSError):
                pass
            finally:
                state.drop_client(client)

        def is_local_request(self):
            if state.lan:
                return True
            if hostname_from_netloc(self.headers.get("Host", "")) not in LOCAL_HOSTNAMES:
                return False
            origin = self.headers.get("Origin")
            if origin:
                origin_netloc = origin.split("://", 1)[-1]
                if hostname_from_netloc(origin_netloc) not in LOCAL_HOSTNAMES:
                    return False
            return True

        def log_message(self, fmt, *args):
            sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

        # --- ADDITIVE helpers: synthesized static pages (no SSE/reload) ---------
        def _send_html(self, body):
            """Send a hand-built HTML string with a 200. STATIC — no reload lane."""
            payload = body.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(payload)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(payload)

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
            per_purpose_order = ["theme.html", "walkthrough.html", "diagram.html", "api.html"]
            per_purpose = [n for n in per_purpose_order if n in present]
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
            # Scoped to gallery/ only (not the whole docroot) — same scan_mtimes
            # helper, just rooted one level down to avoid O(whole-tree) I/O per hit.
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
        # --- end ADDITIVE helpers ----------------------------------------------

    return functools.partial(Handler, directory=str(state.docroot))


def scan_mtimes(docroot):
    """Yield (docroot-relative posix path, (mtime, size)) for every file under docroot."""
    for root, _dirs, files in os.walk(docroot):
        for name in files:
            full = Path(root) / name
            try:
                st = full.stat()
            except OSError:
                continue
            yield full.relative_to(docroot).as_posix(), (st.st_mtime, st.st_size)


def watch_loop(state, stop_event):
    """Poll file mtimes under docroot; broadcast each changed/new path."""
    mtimes = dict(scan_mtimes(state.docroot))
    while not stop_event.wait(POLL_INTERVAL_SECONDS):
        current = dict(scan_mtimes(state.docroot))
        for rel_path, mtime in current.items():
            if mtimes.get(rel_path) != mtime:
                state.broadcast(rel_path)
        mtimes = current


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
        help="Bind 0.0.0.0 and accept /events from non-localhost Origin/Host.",
    )
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    docroot = Path(args.docroot).resolve()
    docroot.mkdir(parents=True, exist_ok=True)

    state = ServerState(docroot=docroot, lan=args.lan)
    host = "0.0.0.0" if args.lan else "127.0.0.1"
    try:
        httpd = http.server.ThreadingHTTPServer((host, args.port), build_handler(state))
    except OSError as e:
        print(f"port {args.port} unavailable: {e}", file=sys.stderr)
        sys.exit(1)
    httpd.daemon_threads = True

    stop_event = threading.Event()
    watcher = threading.Thread(target=watch_loop, args=(state, stop_event), daemon=True)
    watcher.start()

    print(
        "Serving {} at http://{}:{}/  (SSE: GET /events)".format(docroot, host, args.port),
        file=sys.stderr,
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
