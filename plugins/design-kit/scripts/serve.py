#!/usr/bin/env python3
"""design-kit preview server — one localhost URL for every design-kit surface.

WHAT IT DOES. Serves a docroot (default ./.design-kit) on 127.0.0.1:8124 with:
  GET /              a gallery: every deck, board, artifact and preview under the
                     docroot, newest first, grouped by top-level folder, with an
                     iframe thumbnail per page
  GET /_events       Server-Sent Events; a tick each time any file under the
                     docroot changes mtime (0.75 s poll), so every served page that
                     includes the reload snippet refreshes itself
  GET /_index.json   the same listing the gallery renders, for scripts
  GET /<path>        static files; .html pages get the reload snippet injected
                     before </body>
--lan binds 0.0.0.0 so a phone on the same network can open it. That is the only
path here that lets a page leave the machine, and the launcher says so.

WHAT IT DOES NOT DO. No write route of any kind — export, restore and publish are
scripts, not HTTP. No auth: the LAN mode is for a phone on your own network. Port
8123 is the taskmaster/ui-ux mockup server and is never the default here.

Standing: scripts/__tests__/serve.test.sh drives start, static serving, the
reload injection, /_index.json and stop. Nothing proves a browser rendered a page.
"""
import argparse
import html
import json
import os
import posixpath
import sys
import threading
import time
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import unquote, urlsplit

RELOAD_SNIPPET = (
    '<script data-design-kit-reload>'
    '(function(){try{var s=new EventSource("/_events");'
    's.onmessage=function(e){if(e.data==="reload")location.reload()};}catch(e){}})();'
    '</script>'
)
PAGE_EXT = (".html", ".htm")
IGNORED = {".preview.pid", "_index.json"}


def _walk_pages(root):
    pages = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if not d.startswith(".")]
        for fn in filenames:
            if fn.startswith(".") or fn in IGNORED or not fn.lower().endswith(PAGE_EXT):
                continue
            full = os.path.join(dirpath, fn)
            rel = os.path.relpath(full, root).replace(os.sep, "/")
            group = rel.split("/")[0] if "/" in rel else "(root)"
            pages.append({
                "path": rel,
                "group": group,
                "mtime": int(os.stat(full).st_mtime),
                "title": _title_of(full) or fn,
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


def _gallery_html(pages):
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
        ".empty{color:#77756e}</style></head><body>",
        "<h1>design-kit gallery</h1>",
    ]
    if not pages:
        parts.append("<p class=\"empty\">Nothing here yet. A deck, board, artifact or preview appears the moment a command writes one.</p>")
    for group, items in groups.items():
        parts.append(f"<h2>{html.escape(group)}</h2><div class=\"grid\">")
        for p in items:
            href = "/" + "/".join(html.escape(seg) for seg in p["path"].split("/"))
            when = time.strftime("%Y-%m-%d %H:%M", time.localtime(p["mtime"]))
            parts.append(
                f"<a class=\"card\" href=\"{href}\"><iframe loading=\"lazy\" src=\"{href}\" title=\"{html.escape(p['title'])}\"></iframe>"
                f"<div class=\"t\">{html.escape(p['title'])}</div><div class=\"p\">{html.escape(p['path'])} · {when}</div></a>"
            )
        parts.append("</div>")
    parts.append(RELOAD_SNIPPET + "</body></html>")
    return "".join(parts)


class Handler(SimpleHTTPRequestHandler):
    root = "."
    state = None  # shared: {"version": int}

    def log_message(self, *_):
        pass

    def translate_path(self, path):
        path = urlsplit(path).path
        path = posixpath.normpath(unquote(path))
        parts = [p for p in path.split("/") if p and p not in (".", "..")]
        return os.path.join(self.root, *parts)

    def do_GET(self):
        path = urlsplit(self.path).path
        if path == "/_events":
            return self._events()
        if path == "/_index.json":
            return self._json(_walk_pages(self.root))
        if path in ("/", "/index.html") and not os.path.exists(os.path.join(self.root, "index.html")):
            return self._html(_gallery_html(_walk_pages(self.root)))
        full = self.translate_path(path)
        if os.path.isfile(full) and full.lower().endswith(PAGE_EXT):
            try:
                with open(full, "rb") as fh:
                    body = fh.read()
            except OSError:
                return self.send_error(HTTPStatus.NOT_FOUND)
            low = body.lower()
            i = low.rfind(b"</body>")
            if i >= 0 and b"data-design-kit-reload" not in body:
                body = body[:i] + RELOAD_SNIPPET.encode() + body[i:]
            return self._bytes(body, "text/html; charset=utf-8")
        return super().do_GET()

    def _events(self):
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "keep-alive")
        self.end_headers()
        seen = self.state["version"]
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

    def _json(self, obj):
        self._bytes(json.dumps(obj, indent=1).encode(), "application/json")

    def _html(self, text):
        self._bytes(text.encode(), "text/html; charset=utf-8")

    def _bytes(self, body, ctype):
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)


def _watch(root, state, stop):
    last = _newest_mtime(root)
    while not stop.is_set():
        time.sleep(0.75)
        now = _newest_mtime(root)
        if now != last:
            last = now
            state["version"] += 1


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--docroot", default=".design-kit")
    ap.add_argument("--port", type=int, default=int(os.environ.get("DESIGN_KIT_PORT", "8124")))
    ap.add_argument("--lan", action="store_true", help="bind 0.0.0.0 so devices on your network can open it")
    args = ap.parse_args(argv)
    root = os.path.abspath(args.docroot)
    os.makedirs(root, exist_ok=True)
    state = {"version": 0}
    Handler.root = root
    Handler.state = state
    bind = "0.0.0.0" if args.lan else "127.0.0.1"
    try:
        srv = ThreadingHTTPServer((bind, args.port), Handler)
    except OSError as exc:
        print(f"serve.py: cannot bind {bind}:{args.port} — {exc}", file=sys.stderr)
        return 4
    srv.daemon_threads = True
    stop = threading.Event()
    threading.Thread(target=_watch, args=(root, state, stop), daemon=True).start()
    print(f"design-kit: serving {root} on http://{bind}:{args.port}/", flush=True)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        stop.set()
        srv.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
