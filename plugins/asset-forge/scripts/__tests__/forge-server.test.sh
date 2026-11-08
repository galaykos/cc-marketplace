#!/usr/bin/env bash
# Harness for server/forge_server: the MCP stdio protocol, Blender discovery order and the headless launcher's error
# contract, driven with fake blender executables; plus one real env_check when a Blender is found (skipped otherwise).
set -u
here=$(cd "$(dirname "$0")" && pwd)
SRV="$here/../../server/forge_server"
pass=0; fail=0; skip=0
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
ok()   { printf 'PASS: %s\n' "$1"; pass=$((pass+1)); }
bad()  { printf 'FAIL: %s\n' "$1"; fail=$((fail+1)); }
skp()  { printf 'SKIP: %s\n' "$1"; skip=$((skip+1)); }

rpc() { printf '%s\n' "$@" | python3 "$SRV/main.py"; }
INIT='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"t","version":"0"}}}'
CALL='{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"env_check","arguments":{}}}'
tool_text() { jq -r 'select(.id==3) | .result.content[0].text'; }

out=$(rpc "$INIT")
[ "$(printf '%s' "$out" | jq -r '.result.protocolVersion')" = 2025-06-18 ] && ok "initialize echoes a known protocol version" || bad "initialize ($out)"
out=$(rpc '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"1999-01-01"}}')
[ "$(printf '%s' "$out" | jq -r '.result.protocolVersion')" = 2025-11-25 ] && ok "an unknown protocol version gets the newest known" || bad "unknown version ($out)"
out=$(rpc "$INIT" '{"jsonrpc":"2.0","method":"notifications/initialized"}' '{"jsonrpc":"2.0","id":2,"method":"tools/list"}')
[ "$(printf '%s\n' "$out" | wc -l)" = 2 ] && ok "a notification gets no response line" || bad "notification answered ($out)"
printf '%s' "$out" | jq -e 'select(.id==2) | .result.tools | map(.name) | index("env_check")' >/dev/null && ok "tools/list names env_check" || bad "tools/list ($out)"
out=$(rpc '{"jsonrpc":"2.0","id":4,"method":"resources/list"}' '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"nope"}}' 'not json')
[ "$(printf '%s\n' "$out" | jq -sc 'map(.error.code)')" = '[-32601,-32602,-32700]' ] && ok "unknown method, unknown tool and bad JSON get their JSON-RPC errors" || bad "errors ($out)"

out=$(rpc '{"jsonrpc":"2.0","id":6,"method":"tools/call","params":["not","an","object"]}' '{"jsonrpc":"2.0","id":7,"method":"ping"}' 2>/dev/null)
[ "$(printf '%s\n' "$out" | jq -sc 'map(.error.code // "ok")')" = '[-32603,"ok"]' ] && ok "a malformed request gets an internal error and the server keeps answering" || bad "malformed params ($out)"

out=$(FORGE_BLENDER_PATH=/nonexistent/blender rpc "$CALL")
printf '%s' "$out" | jq -e 'select(.id==3) | .result.isError == true' >/dev/null \
  && printf '%s' "$out" | tool_text | jq -e '.stage == "locate-blender" and (.error | contains("/nonexistent/blender"))' >/dev/null \
  && ok "a configured path that is not executable is an error naming it, not a silent fallback" || bad "bad configured path ($out)"

FAKE="$T/fake-blender"
cat > "$FAKE" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "${FAKE_ARGS:-/dev/null}"
req=""; seen=""; for a in "$@"; do [ -n "$seen" ] && req=$a; [ "$a" = -- ] && seen=1; done
case "${FAKE_MODE:-ok}" in
  ok) python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); json.dump({"ok": True, "op": r["op"]}, open(r["result_path"], "w"))' "$req" ;;
  silent) echo "Error: Python: Traceback (most recent call last)" >&2; exit 3 ;;
  sleep) sleep 5 ;;
esac
EOF
chmod +x "$FAKE"

out=$(FORGE_BLENDER_PATH="" BLENDER_PATH="$FAKE" FAKE_ARGS="$T/args" rpc "$CALL" | tool_text)
printf '%s' "$out" | jq -e '.ok and .op == "env" and .blender.found_by == "BLENDER_PATH"' >/dev/null && ok "BLENDER_PATH is used when the userConfig value is empty" || bad "BLENDER_PATH fallback ($out)"
args=$(tr '\n' ' ' < "$T/args")
case "$args" in
  "-b --factory-startup --python-exit-code 1 --python "*runner.py" -- "*) ok "the launcher passes -b, --factory-startup and --python-exit-code before --python" ;;
  *) bad "launcher argv: $args" ;;
esac

out=$(FORGE_BLENDER_PATH="$FAKE" FAKE_MODE=silent rpc "$CALL" | tool_text)
printf '%s' "$out" | jq -e '.stage == "blender" and (.error | contains("exited 3")) and (.blender_log_tail | contains("Traceback"))' >/dev/null \
  && ok "Blender exiting without a result reports the exit code and the log tail" || bad "silent exit ($out)"

out=$(cd "$SRV" && FORGE_BLENDER_PATH="$FAKE" FAKE_MODE=sleep python3 -c 'import json, headless; print(json.dumps(headless.run_job("env", timeout=1)))')
printf '%s' "$out" | jq -e '.stage == "timeout"' >/dev/null && ok "a job past its timeout is stopped and reported" || bad "timeout ($out)"
out=$(cd "$SRV" && FORGE_BLENDER_PATH="$FAKE" python3 -c 'import json, headless; print(json.dumps(headless.run_job("env", blend_path="/nonexistent/x.blend")))')
printf '%s' "$out" | jq -e '.stage == "input"' >/dev/null && ok "a missing blend_path is refused before Blender starts" || bad "missing blend ($out)"

real=$(cd "$SRV" && FORGE_BLENDER_PATH="" python3 -c 'import headless; p, _ = headless.find_blender(); print(p or "")')
if [ -n "$real" ]; then
  out=$(FORGE_BLENDER_PATH="" rpc "$CALL" | tool_text)
  printf '%s' "$out" | jq -e '.ok and (.version | length) == 3 and (.render_engines | length) >= 1 and .file == null' >/dev/null \
    && ok "env_check on the real Blender ($(printf '%s' "$out" | jq -r '.version_string'), engines $(printf '%s' "$out" | jq -c '.render_engines'))" \
    || bad "real env_check ($out)"
else
  skp "no Blender found: real env_check not run"
fi

printf '\n%d passed, %d failed, %d skipped\n' "$pass" "$fail" "$skip"
[ "$fail" = 0 ]
