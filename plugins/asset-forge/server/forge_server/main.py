"""asset-forge MCP server: JSON-RPC 2.0 over stdio, one JSON message per line, Python standard library only.
stdout carries protocol messages and nothing else; diagnostics go to stderr."""
import json
import sys
import threading
import traceback
from pathlib import Path

import headless
import tools

PLUGIN_JSON = Path(__file__).resolve().parents[2] / ".claude-plugin" / "plugin.json"
SERVER_INFO = {"name": "asset-forge-forge", "version": json.loads(PLUGIN_JSON.read_text(encoding="utf-8"))["version"]}
KNOWN_PROTOCOLS = ("2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05")


def _result(msg_id, result):
    return {"jsonrpc": "2.0", "id": msg_id, "result": result}


def _error(msg_id, code, message):
    return {"jsonrpc": "2.0", "id": msg_id, "error": {"code": code, "message": message}}


def _tool_content(payload):
    """A tool returns a dict; an optional "_images" list of {"data": base64, "mimeType"} becomes image content."""
    images = payload.pop("_images", [])
    content = [{"type": "text", "text": json.dumps(payload, indent=1)}]
    content += [{"type": "image", "data": img["data"], "mimeType": img.get("mimeType", "image/png")} for img in images]
    return content


def handle(message):
    """Return the response dict, or None for a notification."""
    if "id" not in message:
        return None
    method = message.get("method")
    msg_id = message.get("id")
    params = message.get("params") or {}
    if method == "initialize":
        asked = params.get("protocolVersion")
        version = asked if asked in KNOWN_PROTOCOLS else KNOWN_PROTOCOLS[0]
        return _result(msg_id, {"protocolVersion": version, "capabilities": {"tools": {"listChanged": False}},
                                "serverInfo": SERVER_INFO})
    if method == "ping":
        return _result(msg_id, {})
    if method == "tools/list":
        listed = [{"name": name, "description": desc, "inputSchema": schema,
                   **({"annotations": tools.ANNOTATIONS[name]} if name in tools.ANNOTATIONS else {})}
                  for name, (_handler, desc, schema) in tools.TOOLS.items()]
        return _result(msg_id, {"tools": listed})
    if method == "tools/call":
        name = params.get("name")
        if name not in tools.TOOLS:
            return _error(msg_id, -32602, f"unknown tool: {name}")
        try:
            payload = tools.call(name, params.get("arguments") or {})
        except Exception as exc:
            traceback.print_exc(file=sys.stderr)
            payload = {"ok": False, "stage": f"server:{name}", "error": f"{type(exc).__name__}: {exc}"}
        return _result(msg_id, {"content": _tool_content(payload), "isError": not payload.get("ok", False)})
    return _error(msg_id, -32601, f"method not found: {method}")


_write_lock = threading.Lock()
_inflight_lock = threading.Lock()
_inflight = {}
_calls = []


def _send(response):
    if response is None:
        return
    with _write_lock:
        sys.stdout.write(json.dumps(response) + "\n")
        sys.stdout.flush()


def _respond(message):
    try:
        return handle(message)
    except Exception as exc:  # one malformed request must not end the server
        traceback.print_exc(file=sys.stderr)
        return _error(message.get("id"), -32603, f"internal error: {type(exc).__name__}: {exc}") if "id" in message else None


def _serve_call(message, key, scope):
    headless.SCOPE.set(scope)
    try:
        response = _respond(message)
    finally:
        with _inflight_lock:
            _inflight.pop(key, None)
    if not scope.cancelled:  # MCP: a cancelled request gets no response
        _send(response)


def _dispatch(message):
    """tools/call runs on its own thread, so the loop keeps reading and notifications/cancelled can kill its Blender."""
    method, params = message.get("method"), message.get("params")
    if method == "notifications/cancelled" and isinstance(params, dict):
        with _inflight_lock:
            scope = _inflight.get(json.dumps(params.get("requestId")))
        if scope:
            scope.cancel()
    elif method == "tools/call" and "id" in message and isinstance(params, dict) and params.get("name") in tools.TOOLS:
        key, scope = json.dumps(message["id"]), headless.JobScope()
        with _inflight_lock:
            _inflight[key] = scope
        call = threading.Thread(target=_serve_call, args=(message, key, scope))
        _calls[:] = [t for t in _calls if t.is_alive()] + [call]
        call.start()
    else:
        _send(_respond(message))


def main():
    sys.stdin.reconfigure(encoding="utf-8")
    sys.stdout.reconfigure(encoding="utf-8")
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            message = json.loads(line)
        except ValueError:
            _send(_error(None, -32700, "parse error"))
            continue
        if not isinstance(message, dict):
            _send(_error(None, -32600, "batch requests are not supported"))
            continue
        _dispatch(message)
    for call in _calls:  # past this point the interpreter shuts down and a thread pool refuses new work
        call.join()


if __name__ == "__main__":
    main()
