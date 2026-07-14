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


def build_handler(state):
    """Return a request-handler callable bound to ``state``'s docroot."""

    class Handler(http.server.SimpleHTTPRequestHandler):
        server_version = "MockupPreview/1.0"

        def do_GET(self):
            if self.path.split("?", 1)[0] == "/events":
                self.handle_sse()
                return
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
