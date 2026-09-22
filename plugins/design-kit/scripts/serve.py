#!/usr/bin/env python3
"""design-kit preview server — one localhost URL for every design-kit surface.

WHAT IT DOES. Serves a docroot (default ./.design-kit) on 127.0.0.1:8124 with:
  GET /              a gallery: every deck, board, artifact and preview under the
                     docroot, newest first, grouped by top-level folder, with an
                     iframe thumbnail per page
  GET /_events       Server-Sent Events; a tick each time any file under the
                     docroot changes mtime (0.75 s poll), so every served page that
                     includes the reload snippet refreshes itself
  GET /_index.json   the same listing the gallery renders, for scripts; each page
                     carries `tokens`: the design-kit-tokens stamp it was built
                     with and whether it still equals sha12(design-system/tokens.json)
  GET /<path>        static files; .html pages get the reload snippet injected
                     before </body> — except for a headless browser (User-Agent)
                     or a `?static=1` query, because an open event stream keeps a
                     screenshot or print from ever settling
  POST /_decision    the ONE write route: a board's pick / knob / text-edit state,
                     appended as one JSON line to <docroot>/decisions.jsonl with
                     consumed:false. Accepted only from a loopback client, only
                     with the X-Design-Kit-Decision header, only ≤ 8 KiB, only
                     valid JSON — else 403 / 413 / 400. `dk decision` reads it.
The gallery also shows a FLOW STRIP read from <docroot>/workshop.json (written by
dk.sh) and a per-card token badge: green when the page's stamp equals the current
tokens.json hash, amber "tokens moved since build" otherwise.
--lan binds 0.0.0.0 so a phone on the same network can open it. That is the only
path here that lets a page leave the machine, and the launcher says so. /_decision
stays loopback-only under --lan: a pick made on a phone is NOT recorded.

WHAT IT DOES NOT DO. Export, restore and publish are scripts, not HTTP; the one
write route above is append-only and never touches a served file. No auth: the LAN
mode is for a phone on your own network. Port 8123 is the taskmaster/ui-ux mockup
server and is never the default here.

Standing: scripts/__tests__/serve.test.sh drives start, static serving, the
reload injection, /_index.json, the /_decision accept and reject paths, both badge
states, and stop. Nothing proves a browser rendered a page.
"""
import argparse
import hashlib
import html
import json
import os
import posixpath
import re
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
IGNORED = {".preview.pid", ".preview.url", "_index.json", "workshop.json", "decisions.jsonl", "usage.jsonl"}
DECISION_MAX = 8 * 1024
LOOPBACK = ("127.0.0.1", "::1", "::ffff:127.0.0.1")
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
                f"<a class=\"card\" href=\"{href}\"><iframe loading=\"lazy\" src=\"{href}\" title=\"{html.escape(p['title'])}\"></iframe>"
                f"<div class=\"t\">{html.escape(p['title'])}{badge}</div><div class=\"p\">{html.escape(p['path'])} · {when}</div></a>"
            )
        parts.append("</div>")
    parts.append((RELOAD_SNIPPET if live else "") + "</body></html>")
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
        if path in ("/", "/index.html"):
            if not os.path.exists(os.path.join(self.root, "index.html")):
                return self._html(_gallery_html(_walk_pages(self.root), live=self._wants_live(), root=self.root))
            path = "/index.html"
        full = self.translate_path(path)
        if os.path.isfile(full) and full.lower().endswith(PAGE_EXT):
            try:
                with open(full, "rb") as fh:
                    body = fh.read()
            except OSError:
                return self.send_error(HTTPStatus.NOT_FOUND)
            low = body.lower()
            i = low.rfind(b"</body>")
            if i >= 0 and b"data-design-kit-reload" not in body and self._wants_live():
                body = body[:i] + RELOAD_SNIPPET.encode() + body[i:]
            return self._bytes(body, "text/html; charset=utf-8")
        return super().do_GET()

    def do_POST(self):
        path = urlsplit(self.path).path
        if path != "/_decision":
            return self.send_error(HTTPStatus.NOT_IMPLEMENTED)
        if self.client_address[0] not in LOOPBACK:
            return self._reject(HTTPStatus.FORBIDDEN, "decisions are recorded from this machine only")
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
        budget never expires and the capture hangs (measured with Chrome 2026-09-22).
        `?static=1` opts any client out."""
        if "static=1" in (urlsplit(self.path).query or ""):
            return False
        return "headless" not in (self.headers.get("User-Agent") or "").lower()

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
