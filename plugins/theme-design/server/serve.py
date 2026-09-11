#!/usr/bin/env python3
"""theme-design session server: a loopback bridge between a browser canvas and
the Claude Code session that started it.

Two lanes ride one port.

  Browser -> Claude   POST /__td/event   chat messages and gestures (select,
                      move, resize, text, style, annotate, end), appended to
                      <root>/events.jsonl with a monotonic `seq`.
  Claude  -> Browser  POST /__td/reply   an assistant line (+ optional reload),
                      pushed over GET /__td/events (Server-Sent Events).
  Claude waits        GET  /__td/next    long-poll: blocks until an event with
                      seq > <root>/cursor exists, returns the batch, advances
                      the cursor. The UserPromptSubmit hook advances the same
                      file when it injects pending events into a terminal turn,
                      so an event is delivered on one surface, not both.

Two canvas modes, chosen at start.

  --mode html   serve <root>/ as static files (pages/*.html + tokens.css);
                a watcher pushes `reload` when any .html/.css under it changes.
  --mode proxy  forward every other request to --proxy <url> (the project's
                own dev server) and inject the editor into text/html replies.
                Reload is explicit (POST /__td/reply {"reload": true}); dev-server
                websockets (Vite HMR) do NOT survive the proxy, by design of
                http.server, and the skill says so.

Stdlib only; binds 127.0.0.1 only; every state-changing route demands the
X-Theme-Design header, which forces a CORS preflight this server never answers,
so a page on another localhost port cannot drive the session.

Skins: <root>/skin.css is the look the prototype vocabulary (.card, .btn,
.input, .badge, table …) renders in. server/skins/<name>.css are lookalikes of
a library's defaults on that vocabulary — never the library. GET /__td/skins
lists them, POST /__td/skin {"name"} copies one over <root>/skin.css (the
watcher reloads) and records a `skin` event so the session knows.

    python3 serve.py --root .theme-design --mode html [--port 8140] [--open] [--skin wireframe]
    python3 serve.py --root .theme-design --mode proxy --proxy http://localhost:5173
    python3 serve.py --root .theme-design --status | --stop
"""

import argparse
import html
import json
import mimetypes
import shutil
import os
import queue
import signal
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import webbrowser
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

HERE = Path(__file__).resolve().parent
SKINS_DIR = HERE / "skins"
DEFAULT_SKIN = "wireframe"
LOCAL_HOSTNAMES = {"localhost", "127.0.0.1", "::1"}
CSRF_HEADER = "X-Theme-Design"
MAX_BODY = 64 * 1024
MAX_SSE_CLIENTS = 8
KEEPALIVE_SECONDS = 15
WATCH_INTERVAL_SECONDS = 0.5
DEFAULT_PORT = int(os.environ.get("THEME_DESIGN_PORT", "8140"))
INJECT = (
    '\n<link rel="stylesheet" href="/__td/editor.css">'
    '<script src="/__td/editor.js" defer></script>\n'
)
HOP_BY_HOP = {
    "connection", "keep-alive", "proxy-authenticate", "proxy-authorization",
    "te", "trailers", "transfer-encoding", "upgrade", "content-encoding",
    "content-length",
}


def now_iso():
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def hostname_from_netloc(netloc):
    if not netloc:
        return ""
    if netloc.startswith("["):
        end = netloc.find("]")
        return netloc[1:end] if end != -1 else netloc
    return netloc.split(":", 1)[0]


def inject_editor(body):
    """Insert the editor tags before </body> (or </html>, or at the end)."""
    lower = body.lower()
    for marker in (b"</body>", b"</html>"):
        i = lower.rfind(marker)
        if i != -1:
            return body[:i] + INJECT.encode("utf-8") + body[i:]
    return body + INJECT.encode("utf-8")


class Session:
    """Everything shared between request threads, the watcher and disk."""

    def __init__(self, root, mode, proxy, port):
        self.root = root
        self.mode = mode
        self.proxy = proxy.rstrip("/") if proxy else None
        self.port = port
        self.lock = threading.Lock()
        self.cond = threading.Condition(self.lock)
        self.clients = []
        self.events_path = root / "events.jsonl"
        self.cursor_path = root / "cursor"
        self.transcript_path = root / "transcript.md"
        self.state_path = root / "state.json"
        self.seq = self._last_seq()

    # --- events ------------------------------------------------------------
    def _last_seq(self):
        last = 0
        if self.events_path.exists():
            for line in self.events_path.read_text("utf-8", errors="replace").splitlines():
                try:
                    last = max(last, int(json.loads(line).get("seq", 0)))
                except (ValueError, AttributeError):
                    continue
        return last

    def append_event(self, event):
        with self.cond:
            self.seq += 1
            event["seq"] = self.seq
            event["ts"] = now_iso()
            with self.events_path.open("a", encoding="utf-8") as fh:
                fh.write(json.dumps(event, ensure_ascii=False) + "\n")
            self.cond.notify_all()
        if event.get("type") == "message":
            self.append_transcript("user", event.get("text", ""))
        return event["seq"]

    def read_cursor(self):
        try:
            return int(self.cursor_path.read_text("utf-8").strip() or 0)
        except (OSError, ValueError):
            return 0

    def write_cursor(self, value):
        self.cursor_path.write_text(str(value), "utf-8")

    def pending(self):
        cursor = self.read_cursor()
        out = []
        if not self.events_path.exists():
            return out
        for line in self.events_path.read_text("utf-8", errors="replace").splitlines():
            try:
                ev = json.loads(line)
            except ValueError:
                continue
            if int(ev.get("seq", 0)) > cursor:
                out.append(ev)
        return out

    def wait_next(self, timeout):
        deadline = time.monotonic() + timeout
        with self.cond:
            while True:
                batch = self.pending()
                if batch:
                    self.write_cursor(batch[-1]["seq"])
                    return batch
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    return []
                self.cond.wait(min(remaining, 1.0))

    # --- transcript --------------------------------------------------------
    def append_transcript(self, role, text):
        if not text:
            return
        with self.lock:
            with self.transcript_path.open("a", encoding="utf-8") as fh:
                fh.write("- **%s** (%s): %s\n" % (role, now_iso(), text.replace("\n", " ")))

    # --- SSE ---------------------------------------------------------------
    def add_client(self):
        with self.lock:
            if len(self.clients) >= MAX_SSE_CLIENTS:
                return None
            q = queue.Queue()
            self.clients.append(q)
            return q

    def drop_client(self, q):
        with self.lock:
            if q in self.clients:
                self.clients.remove(q)

    def broadcast(self, payload):
        with self.lock:
            targets = list(self.clients)
        for q in targets:
            try:
                q.put_nowait(payload)
            except queue.Full:
                pass

    # --- skins -------------------------------------------------------------
    def skins(self):
        return sorted(p.stem for p in SKINS_DIR.glob("*.css"))

    def active_skin(self):
        try:
            return (self.root / "skin").read_text("utf-8").strip() or None
        except OSError:
            return None

    def apply_skin(self, name):
        """Copy a shipped skin over <root>/skin.css; the watcher pushes the reload."""
        if name not in self.skins():
            return False
        shutil.copyfile(SKINS_DIR / ("%s.css" % name), self.root / "skin.css")
        (self.root / "skin").write_text(name + "\n", "utf-8")
        return True

    # --- state file --------------------------------------------------------
    def write_state(self):
        self.state_path.write_text(json.dumps({
            "pid": os.getpid(),
            "port": self.port,
            "mode": self.mode,
            "proxy": self.proxy,
            "root": str(self.root),
            "url": "http://localhost:%d/" % self.port,
            "started": now_iso(),
        }, indent=2) + "\n", "utf-8")

    def snapshot(self):
        pages = sorted(p.name for p in (self.root / "pages").glob("*.html")) if (self.root / "pages").is_dir() else []
        return {
            "mode": self.mode,
            "proxy": self.proxy,
            "port": self.port,
            "cursor": self.read_cursor(),
            "last_seq": self.seq,
            "pending": len(self.pending()),
            "pages": pages,
            "clients": len(self.clients),
            "skin": self.active_skin(),
            "skins": self.skins(),
        }


def watch_files(session, stop):
    """Push `reload` whenever an .html/.css file under the root changes (html mode)."""
    def scan():
        seen = {}
        for p in session.root.rglob("*"):
            if p.suffix in (".html", ".css", ".js", ".svg") and p.is_file():
                try:
                    seen[str(p.relative_to(session.root))] = p.stat().st_mtime_ns
                except OSError:
                    continue
        return seen

    before = scan()
    while not stop.is_set():
        time.sleep(WATCH_INTERVAL_SECONDS)
        after = scan()
        changed = [k for k, v in after.items() if before.get(k) != v] + [k for k in before if k not in after]
        if changed:
            session.broadcast({"type": "reload", "paths": sorted(changed)})
        before = after


def build_handler(session):
    class Handler(BaseHTTPRequestHandler):
        server_version = "ThemeDesign/0.1"
        protocol_version = "HTTP/1.0"

        # --- plumbing ------------------------------------------------------
        def log_message(self, fmt, *args):
            if os.environ.get("THEME_DESIGN_QUIET"):
                return
            sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

        def is_local(self):
            if hostname_from_netloc(self.headers.get("Host", "")) not in LOCAL_HOSTNAMES:
                return False
            origin = self.headers.get("Origin")
            if origin and hostname_from_netloc(origin.split("://", 1)[-1]) not in LOCAL_HOSTNAMES:
                return False
            return True

        def send_bytes(self, data, ctype, status=200, extra=None):
            self.send_response(status)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Cache-Control", "no-store")
            for k, v in (extra or {}).items():
                self.send_header(k, v)
            self.end_headers()
            if self.command != "HEAD":
                self.wfile.write(data)

        def send_json(self, obj, status=200):
            self.send_bytes(json.dumps(obj, ensure_ascii=False).encode("utf-8"),
                            "application/json; charset=utf-8", status)

        def send_html(self, text, status=200):
            self.send_bytes(inject_editor(text.encode("utf-8")), "text/html; charset=utf-8", status)

        def read_body(self):
            length = int(self.headers.get("Content-Length") or 0)
            if length > MAX_BODY:
                self.send_json({"error": "body too large"}, 413)
                return None
            raw = self.rfile.read(length) if length else b""
            try:
                return json.loads(raw.decode("utf-8") or "{}")
            except ValueError:
                self.send_json({"error": "invalid json"}, 400)
                return None

        def guard_mutation(self):
            if not self.is_local():
                self.send_json({"error": "non-local origin"}, 403)
                return False
            if not self.headers.get(CSRF_HEADER):
                self.send_json({"error": "missing %s header" % CSRF_HEADER}, 403)
                return False
            return True

        # --- routing -------------------------------------------------------
        def do_GET(self):
            path = urllib.parse.urlsplit(self.path).path
            if path.startswith("/__td/"):
                return self.control_get(path)
            if session.mode == "proxy":
                return self.proxy_request()
            return self.static_get(path)

        do_HEAD = do_GET

        def do_POST(self):
            path = urllib.parse.urlsplit(self.path).path
            if path.startswith("/__td/"):
                return self.control_post(path)
            if session.mode == "proxy":
                return self.proxy_request()
            self.send_json({"error": "not found"}, 404)

        do_PUT = do_PATCH = do_DELETE = do_OPTIONS = do_POST

        # --- control lane --------------------------------------------------
        def control_get(self, path):
            query = urllib.parse.parse_qs(urllib.parse.urlsplit(self.path).query)
            if path == "/__td/editor.js":
                return self.send_bytes((HERE / "editor.js").read_bytes(), "application/javascript; charset=utf-8")
            if path == "/__td/editor.css":
                return self.send_bytes((HERE / "editor.css").read_bytes(), "text/css; charset=utf-8")
            if path == "/__td/events":
                return self.handle_sse()
            if path == "/__td/state":
                return self.send_json(session.snapshot())
            if path == "/__td/skins":
                return self.send_json({"skins": session.skins(), "active": session.active_skin()})
            if path == "/__td/transcript":
                text = session.transcript_path.read_text("utf-8") if session.transcript_path.exists() else ""
                return self.send_bytes(text.encode("utf-8"), "text/markdown; charset=utf-8")
            if path == "/__td/next":
                if not self.is_local():
                    return self.send_json({"error": "non-local origin"}, 403)
                try:
                    timeout = min(float(query.get("timeout", ["280"])[0]), 590.0)
                except ValueError:
                    timeout = 280.0
                return self.send_json(session.wait_next(timeout))
            self.send_json({"error": "not found"}, 404)

        def control_post(self, path):
            if not self.guard_mutation():
                return
            body = self.read_body()
            if body is None:
                return
            if path == "/__td/event":
                if not isinstance(body, dict) or not isinstance(body.get("type"), str):
                    return self.send_json({"error": "event needs a string `type`"}, 400)
                seq = session.append_event(body)
                return self.send_json({"ok": True, "seq": seq})
            if path == "/__td/skin":
                name = body.get("name") if isinstance(body, dict) else None
                if not isinstance(name, str) or not session.apply_skin(name):
                    return self.send_json({"error": "unknown skin", "skins": session.skins()}, 400)
                seq = session.append_event({"type": "skin", "name": name, "page": body.get("page", "")})
                return self.send_json({"ok": True, "skin": name, "seq": seq})
            if path == "/__td/reply":
                text = body.get("text", "") if isinstance(body, dict) else ""
                session.append_transcript("assistant", text)
                if text:
                    session.broadcast({"type": "assistant", "text": text, "ts": now_iso()})
                if body.get("reload"):
                    session.broadcast({"type": "reload", "paths": ["reply"]})
                return self.send_json({"ok": True})
            self.send_json({"error": "not found"}, 404)

        def handle_sse(self):
            if not self.is_local():
                return self.send_json({"error": "non-local origin"}, 403)
            client = session.add_client()
            if client is None:
                return self.send_json({"error": "too many streams"}, 503)
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
                        payload = client.get(timeout=KEEPALIVE_SECONDS)
                    except queue.Empty:
                        self.wfile.write(b": keep-alive\n\n")
                        self.wfile.flush()
                        continue
                    self.wfile.write(("data: %s\n\n" % json.dumps(payload, ensure_ascii=False)).encode("utf-8"))
                    self.wfile.flush()
            except (BrokenPipeError, ConnectionResetError, OSError):
                pass
            finally:
                session.drop_client(client)

        # --- html mode: static files ---------------------------------------
        def static_get(self, path):
            rel = urllib.parse.unquote(path).lstrip("/")
            if path == "/favicon.ico" and not (session.root / "favicon.ico").is_file():
                return self.send_bytes(b"", "image/x-icon", 204)
            if path == "/skin.css" and not (session.root / "skin.css").is_file():
                return self.send_bytes((SKINS_DIR / (DEFAULT_SKIN + ".css")).read_bytes(), "text/css; charset=utf-8")
            if path in ("", "/"):
                index = session.root / "pages" / "index.html"
                if index.is_file():
                    return self.send_html(index.read_text("utf-8", errors="replace"))
                return self.send_html(self.landing())
            target = (session.root / rel).resolve()
            try:
                target.relative_to(session.root.resolve())
            except ValueError:
                return self.send_json({"error": "forbidden"}, 403)
            if target.is_dir():
                target = target / "index.html"
            if not target.is_file():
                return self.send_html(self.not_found_page(rel), 404)
            ctype = mimetypes.guess_type(str(target))[0] or "application/octet-stream"
            data = target.read_bytes()
            if ctype == "text/html":
                return self.send_bytes(inject_editor(data), "text/html; charset=utf-8")
            self.send_bytes(data, ctype)

        def landing(self):
            pages = session.snapshot()["pages"]
            items = "".join('<li><a href="/pages/%s">%s</a></li>' % (html.escape(p), html.escape(p)) for p in pages)
            body = "<ul>%s</ul>" % items if pages else \
                "<p>No pages yet. Describe the first screen in the chat panel and Claude will create <code>pages/index.html</code>.</p>"
            return ("<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><title>theme-design</title>"
                    "<link rel=\"stylesheet\" href=\"/tokens.css\">"
                    "<style>body{font:16px/1.5 system-ui,sans-serif;max-width:40rem;margin:4rem auto;padding:0 1rem;"
                    "background:var(--background,#fff);color:var(--foreground,#111)}</style></head>"
                    "<body><h1>theme-design session</h1>%s</body></html>" % body)

        def not_found_page(self, rel):
            return ("<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><title>404</title></head>"
                    "<body><h1>Not found</h1><p><code>%s</code> is not under the session root. "
                    "<a href=\"/\">Back to the session</a>.</p></body></html>" % html.escape(rel))

        # --- proxy mode ----------------------------------------------------
        def proxy_request(self):
            if not self.is_local():
                return self.send_json({"error": "non-local origin"}, 403)
            url = session.proxy + self.path
            length = int(self.headers.get("Content-Length") or 0)
            body = self.rfile.read(length) if length else None
            headers = {k: v for k, v in self.headers.items()
                       if k.lower() not in ("host", "accept-encoding", "connection")}
            headers["Accept-Encoding"] = "identity"
            headers["Host"] = urllib.parse.urlsplit(session.proxy).netloc
            req = urllib.request.Request(url, data=body, headers=headers, method=self.command)
            opener = urllib.request.build_opener(NoRedirect)
            try:
                resp = opener.open(req, timeout=30)
            except urllib.error.HTTPError as err:
                resp = err
            except (urllib.error.URLError, OSError) as err:
                return self.send_html(
                    "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><title>502</title></head><body>"
                    "<h1>Dev server unreachable</h1><p>Proxying <code>%s</code> failed: %s.</p>"
                    "<p>Start the project's dev server, then reload.</p></body></html>"
                    % (html.escape(session.proxy), html.escape(str(err))), 502)
            with resp:
                data = resp.read()
                status = resp.status if hasattr(resp, "status") else resp.code
                ctype = resp.headers.get("Content-Type", "")
                if ctype.startswith("text/html"):
                    data = inject_editor(data)
                self.send_response(status)
                for k, v in resp.headers.items():
                    kl = k.lower()
                    if kl in HOP_BY_HOP:
                        continue
                    if kl == "location" and v.startswith(session.proxy):
                        v = "http://localhost:%d" % session.port + v[len(session.proxy):]
                    self.send_header(k, v)
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                if self.command != "HEAD":
                    self.wfile.write(data)

    return Handler


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def load_state(root):
    path = root / "state.json"
    if not path.is_file():
        return None
    try:
        return json.loads(path.read_text("utf-8"))
    except ValueError:
        return None


def alive(pid):
    try:
        os.kill(pid, 0)
    except (OSError, TypeError):
        return False
    return True


def cmd_status(root):
    state = load_state(root)
    if not state or not alive(state.get("pid")):
        print("no running theme-design session under %s" % root)
        return 1
    print(json.dumps(state, indent=2))
    return 0


def cmd_stop(root):
    state = load_state(root)
    if not state:
        print("no state file under %s" % root)
        return 1
    pid = state.get("pid")
    if alive(pid):
        os.kill(pid, signal.SIGTERM)
        for _ in range(40):
            if not alive(pid):
                break
            time.sleep(0.05)
    (root / "state.json").unlink(missing_ok=True)
    print("stopped theme-design session (pid %s)" % pid)
    return 0


def serve(args):
    root = Path(args.root).resolve()
    (root / "pages").mkdir(parents=True, exist_ok=True)
    if args.mode == "proxy" and not args.proxy:
        sys.exit("--mode proxy needs --proxy <url>")
    previous = load_state(root)
    if previous and alive(previous.get("pid")) and previous.get("pid") != os.getpid():
        sys.exit("a session is already running on port %s (pid %s); use --stop first"
                 % (previous.get("port"), previous.get("pid")))
    session = Session(root, args.mode, args.proxy, args.port)
    if args.skin:
        if not session.apply_skin(args.skin):
            sys.exit("unknown skin %r; shipped: %s" % (args.skin, ", ".join(session.skins())))
    elif args.mode == "html" and not (root / "skin.css").is_file():
        session.apply_skin(DEFAULT_SKIN)
    if not session.cursor_path.exists():
        session.write_cursor(session.seq)
    httpd = ThreadingHTTPServer(("127.0.0.1", args.port), build_handler(session))
    httpd.daemon_threads = True
    session.port = httpd.server_address[1]
    session.write_state()
    stop = threading.Event()
    if args.mode == "html":
        threading.Thread(target=watch_files, args=(session, stop), daemon=True).start()

    def shutdown(*_):
        stop.set()
        threading.Thread(target=httpd.shutdown, daemon=True).start()

    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)
    url = "http://localhost:%d/" % session.port
    print("theme-design %s session on %s (root %s)" % (args.mode, url, root), flush=True)
    if args.open:
        webbrowser.open(url)
    try:
        httpd.serve_forever()
    finally:
        httpd.server_close()
        session.state_path.unlink(missing_ok=True)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", default=".theme-design")
    parser.add_argument("--mode", choices=("html", "proxy"), default="html")
    parser.add_argument("--proxy", help="dev server origin for --mode proxy, e.g. http://localhost:5173")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help="0 picks a free port")
    parser.add_argument("--open", action="store_true", help="open the URL in the default browser")
    parser.add_argument("--skin", help="html mode: the look to start in (%s); default %s when the root has none"
                        % (", ".join(sorted(p.stem for p in SKINS_DIR.glob("*.css"))), DEFAULT_SKIN))
    parser.add_argument("--status", action="store_true")
    parser.add_argument("--stop", action="store_true")
    args = parser.parse_args(argv)
    root = Path(args.root).resolve()
    if args.status:
        return cmd_status(root)
    if args.stop:
        return cmd_stop(root)
    serve(args)
    return 0


if __name__ == "__main__":
    sys.exit(main())
