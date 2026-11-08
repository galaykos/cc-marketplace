# Changelog — asset-forge

Consumer-facing changes only. Newest first.

## 0.2.0 — 2026-11-08

- **The forge library**, `blender_lib/forge/`: 14 modules for review renders and a numpy contact sheet, validation (20 checks), UVs, LODs, collision, engine export, Cycles map baking, a procedural hand-painted albedo, multi-view projection, sculpt-like deforms, organic blockouts, retopology and AI-mesh cleanup, and animation retargeting. Every public function returns a summary dict and refuses bad input with a named stage. Presets for four engines, three platforms and two bone maps. The server's runner gains a `call` op that runs any public forge function on a snapshot. Standing: gate where run, `scripts/__tests__/forge-lib.test.sh` (105 cases in Blender 5.2.3; skipped where no Blender is installed, CI included).

## 0.1.0 — 2026-11-08

- **New plugin, skeleton.** A `forge` MCP server written against the Python standard library (no uv, pip or Pillow), run by `python3` from `.mcp.json`. One tool, `env_check`: the Blender executable and how it was found (`blender_path` option, `BLENDER_PATH`, PATH, install folders), version, settable render engines (read from Blender at run time, Workbench included), numpy in Blender's Python. Headless jobs run `blender -b --factory-startup --python-exit-code 1`, with a timeout, and return `{"ok": false, "stage", "error", "blender_log_tail"}` on failure. Six skill stubs that state their status, each with `disable-model-invocation: true` until its content ships. Standing: gate where run, `scripts/__tests__/forge-server.test.sh`.
