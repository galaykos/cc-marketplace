"""asset-forge MCP server: JSON-RPC 2.0 over stdio, one JSON message per line, Python standard library only.
stdout carries protocol messages and nothing else; diagnostics go to stderr."""
import json
import sys
import traceback

import tools

SERVER_INFO = {"name": "asset-forge-forge", "version": "0.4.0"}
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
    method = message.get("method")
    msg_id = message.get("id")
    is_request = "id" in message
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
    if not is_request:
        return None
    return _error(msg_id, -32601, f"method not found: {method}")


def main():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            message = json.loads(line)
        except ValueError:
            response = _error(None, -32700, "parse error")
        else:
            if not isinstance(message, dict):
                response = _error(None, -32600, "batch requests are not supported")
            else:
                try:
                    response = handle(message)
                except Exception as exc:  # one malformed request must not end the server
                    traceback.print_exc(file=sys.stderr)
                    response = _error(message.get("id"), -32603, f"internal error: {type(exc).__name__}: {exc}") if "id" in message else None
        if response is not None:
            sys.stdout.write(json.dumps(response) + "\n")
            sys.stdout.flush()


if __name__ == "__main__":
    main()
