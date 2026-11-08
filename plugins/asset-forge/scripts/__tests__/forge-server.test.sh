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
tool() { # <name> <arguments-json> -> the tools/call result object
  jq -cn --arg n "$1" --argjson a "$2" '{jsonrpc:"2.0",id:9,method:"tools/call",params:{name:$n,arguments:$a}}' \
    | FORGE_BLENDER_PATH="" python3 "$SRV/main.py" | jq -c '.result'
}
payload() { jq -r '.content[0].text'; }
has_image() { jq -e '[.content[] | select(.type == "image" and (.data | length) > 100)] | length >= 1' >/dev/null; }
png() { # <path> <r> <g> <b>: a 64x64 solid PNG with the standard library
  python3 -c 'import sys, zlib, struct
p, r, g, b = sys.argv[1], *map(int, sys.argv[2:])
raw = b"".join(b"\x00" + bytes([r, g, b, 255]) * 64 for _ in range(64))
chunk = lambda t, d: struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
open(p, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 64, 64, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))' "$@"
}
if [ -n "$real" ]; then
  out=$(FORGE_BLENDER_PATH="" rpc "$CALL" | tool_text)
  printf '%s' "$out" | jq -e '.ok and (.version | length) == 3 and (.render_engines | length) >= 1 and .file == null' >/dev/null \
    && ok "env_check on the real Blender ($(printf '%s' "$out" | jq -r '.version_string'), engines $(printf '%s' "$out" | jq -c '.render_engines'))" \
    || bad "real env_check ($out)"

  F="$T/fixtures"; WAYLAND_DISPLAY= "$real" -b --factory-startup --python "$here/blender/fixtures.py" -- "$F" >/dev/null 2>&1
  crate_sum=$(sha256sum "$F/crate.blend" | cut -d' ' -f1)

  r=$(tool render_review_set "$(jq -cn --arg b "$F/crate.blend" --arg o "$T/review" '{blend_path:$b, object:"SM_Crate", out_dir:$o, angles:4, tile_px:192, game_camera:{type:"perspective",distance_m:6,fov_deg:60,screen_height_px:1080}}')")
  printf '%s' "$r" | jq -e '.isError == false' >/dev/null && printf '%s' "$r" | has_image && [ -s "$T/review/contact_sheet.png" ] \
    && ok "render_review_set returns the contact sheet inline and on disk" || bad "render_review_set ($(printf '%s' "$r" | payload | head -c 400))"

  r=$(tool validate_asset "$(jq -cn --arg b "$F/bad_asset.blend" '{blend_path:$b, object:"crate final", engine:"unity", platform:"pc", asset_class:"prop_small"}')")
  printf '%s' "$r" | payload | jq -e '.ok and (.passed | not) and ([.checks[] | select(.status=="fail") | .id] | index("ngons"))' >/dev/null \
    && ok "validate_asset fails the bad-asset fixture with named checks" || bad "validate bad ($(printf '%s' "$r" | payload | head -c 300))"
  r=$(tool validate_asset "$(jq -cn --arg b "$F/crate.blend" '{blend_path:$b, object:"SM_Crate", engine:"unity", platform:"pc", asset_class:"prop_small"}')")
  printf '%s' "$r" | payload | jq -e '.passed' >/dev/null && ok "validate_asset passes the crate" || bad "validate crate"

  r=$(tool export_asset "$(jq -cn --arg b "$F/crate.blend" --arg o "$T/export" '{blend_path:$b, objects:["SM_Crate"], engine:"unity", out_dir:$o}')")
  printf '%s' "$r" | payload | jq -e '.ok' >/dev/null && ls "$T/export"/*.fbx >/dev/null 2>&1 && ok "export_asset writes an FBX for unity" || bad "export ($(printf '%s' "$r" | payload | head -c 300))"

  r=$(tool bake_maps "$(jq -cn --arg b "$F/crate.blend" --arg o "$T/bake" '{blend_path:$b, low:"SM_Crate", out_dir:$o, maps:["ao"], resolution:128, samples:4}')")
  printf '%s' "$r" | payload | jq -e '.ok' >/dev/null && [ -s "$T/bake/SM_Crate_ao.png" ] && ok "bake_maps writes the AO map" || bad "bake ($(printf '%s' "$r" | payload | head -c 300))"

  r=$(tool stylize_texture "$(jq -cn --arg b "$F/crate.blend" --arg o "$T/style" '{blend_path:$b, object:"SM_Crate", out_dir:$o, recipe:"wood", resolution:128}')")
  printf '%s' "$r" | jq -e '.isError == false' >/dev/null && printf '%s' "$r" | has_image && ok "stylize_texture returns the albedo inline" || bad "stylize ($(printf '%s' "$r" | payload | head -c 300))"

  r=$(tool texture_views "$(jq -cn --arg b "$F/crate.blend" --arg o "$T/views" '{blend_path:$b, object:"SM_Crate", out_dir:$o, views:["front","back"], resolution:128}')")
  vb=$(printf '%s' "$r" | payload | jq -r '.views_blend // empty')
  if [ -n "$vb" ] && [ -s "$vb" ]; then
    ok "texture_views writes guides and a copy that keeps the cameras"
    imgs='{}'
    for cam in $(printf '%s' "$r" | payload | jq -r '.cameras[]'); do
      case $cam in *front) png "$T/$cam.png" 255 0 0 ;; *) png "$T/$cam.png" 0 0 255 ;; esac
      imgs=$(printf '%s' "$imgs" | jq -c --arg c "$cam" --arg p "$T/$cam.png" '. + {($c): $p}')
    done
    r=$(tool project_texture "$(jq -cn --arg b "$vb" --arg o "$T/proj" --argjson v "$imgs" '{blend_path:$b, object:"SM_Crate", out_dir:$o, view_images:$v, resolution:128}')")
    printf '%s' "$r" | jq -e '.isError == false' >/dev/null && printf '%s' "$r" | has_image && ok "project_texture bakes the view images into the UVs" || bad "project ($(printf '%s' "$r" | payload | head -c 300))"
  else
    bad "texture_views ($(printf '%s' "$r" | payload | head -c 300))"
  fi

  r=$(tool batch_run "$(jq -cn --arg a "$F/crate.blend" --arg b "$F/rock.blend" --arg o "$T/batch" '{files:[$a,$b], module:"validate", function:"validate_asset", kwargs:{obj:"SM_Crate"}, out_dir:$o, save_copies:false}')")
  printf '%s' "$r" | payload | jq -e '(.results | length) == 2 and .results[0].ok and (.results[1].ok | not) and (.results[1].error | contains("SM_Crate"))' >/dev/null \
    && ok "batch_run runs per file and reports each file's own failure" || bad "batch ($(printf '%s' "$r" | payload | head -c 400))"
  r=$(tool batch_run "$(jq -cn --arg a "$F/crate.blend" --arg o "$F" '{files:[$a], module:"validate", function:"validate_asset", out_dir:$o}')")
  printf '%s' "$r" | payload | jq -e '.stage == "input"' >/dev/null && ok "batch_run refuses an out_dir that holds a source file" || bad "batch out_dir guard"

  r=$(tool render_review_set "$(jq -cn --arg b "$F/crate.blend" '{blend_path:$b, object:"Nope"}')")
  printf '%s' "$r" | jq -e '.isError' >/dev/null && printf '%s' "$r" | payload | jq -e '.stage == "input" and (.error | contains("Nope"))' >/dev/null \
    && ok "an unknown object is a readable input error" || bad "unknown object ($(printf '%s' "$r" | payload | head -c 300))"
  r=$(tool export_asset "$(jq -cn --arg b "$F/crate.blend" '{blend_path:$b, objects:["SM_Crate"]}')")
  printf '%s' "$r" | payload | jq -e '.stage == "input" and (.error | contains("engine"))' >/dev/null && ok "a missing required argument names itself" || bad "required arg"
  out=$(cd "$SRV" && FORGE_BLENDER_PATH="" python3 -c 'import json, sys, headless; print(json.dumps(headless.run_job("call", {"module": "util", "function": "get_object", "kwargs": {"name_or_obj": "SM_Crate"}, "save_copy_to": sys.argv[1]}, blend_path=sys.argv[1])))' "$F/crate.blend")
  printf '%s' "$out" | jq -e '(.ok | not) and (.error | contains("never saves over"))' >/dev/null && ok "the runner refuses to save over the file it opened" || bad "save-over guard ($out)"
  [ "$(sha256sum "$F/crate.blend" | cut -d' ' -f1)" = "$crate_sum" ] && ok "after every tool the source .blend is byte-identical" || bad "crate.blend changed"
else
  skp "no Blender found: real env_check and the Blender-backed tool cases not run"
fi

printf '\n%d passed, %d failed, %d skipped\n' "$pass" "$fail" "$skip"
[ "$fail" = 0 ]
