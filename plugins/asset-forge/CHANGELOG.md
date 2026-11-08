# Changelog — asset-forge

Consumer-facing changes only. Newest first.

## 0.1.0 — 2026-11-08

- **New plugin, skeleton.** A `forge` MCP server written against the Python standard library (no uv, pip or Pillow), run by `python3` from `.mcp.json`. One tool, `env_check`: the Blender executable and how it was found (`blender_path` option, `BLENDER_PATH`, PATH, install folders), version, settable render engines (read from Blender at run time, Workbench included), numpy in Blender's Python. Headless jobs run `blender -b --factory-startup --python-exit-code 1`, with a timeout, and return `{"ok": false, "stage", "error", "blender_log_tail"}` on failure. Six skill stubs that state their status, each with `disable-model-invocation: true` until its content ships. Standing: gate where run, `scripts/__tests__/forge-server.test.sh`.
