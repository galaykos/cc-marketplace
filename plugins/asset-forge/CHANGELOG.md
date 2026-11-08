# Changelog — asset-forge

Consumer-facing changes only. Newest first.

## 0.4.0 — 2026-11-08

- **The six skills.** `pipeline` is the one skill Claude can trigger by itself: config, order, live vs headless, snapshot and import snippets. In 3 of 3 fresh `claude -p` sessions, "make a low-poly stylized treasure chest in Blender for my Unity game" loaded it first, and the session then read the project config. `new-asset` and `review` are commands; `organic-modeling` (recipes, proportions), `stylized-texturing` (Tier 1 vs Tier 2, seam checklist) and `animation-retarget` are read by path from `pipeline`. Standing: recorded for the procedures; gate for the recipe code (`test_recipes.py`) and for the generated API reference (`gen_forge_api.py --check`).
- **Measured on an end-to-end treasure chest built in a live Blender 5.2.3.** Edits made through the Blender MCP do not mark the file as unsaved until `bpy.ops.ed.undo_push`, so the skill now requires one after every mutating step. `uv.pack` undoes texel density, so `set_texel_density` goes last. Over three revisions the independent reviewer's silhouette score went from 2 to 4, readability from 3 to 4 and style match from 2 to 4. The final asset passes all 22 validator checks for Unity on PC; the validator counts LOD0–3 at 336/140/74/46 tris, and the FBX re-imports with all four LODs, one material slot each and the box collider.
- `lod.make_lod_chain(protect=…)`: choose which edges lock vertices. A level that would not reduce the previous one is skipped and listed, not built as a copy.
- `stylize.apply_albedo` merges the mesh to one slot (one draw call); the validator accepts a collider named from the exact LOD0 mesh name, which Unreal requires.
- `scripts/trigger-corpus.sh` (repo) skips `disable-model-invocation` skills, which never reach the model's listing.

## 0.3.0 — 2026-11-08

- **Server tools.** `render_review_set`, `validate_asset`, `bake_maps`, `stylize_texture`, `export_asset`, `texture_views`, `project_texture` and `batch_run` join `env_check`. Each runs one headless job on a `.blend` the caller names. The review contact sheet, the stylized albedo and the projected texture come back as inline images. Errors return `{"ok": false, "stage", "error"}`, and missing arguments and unknown objects are named. `batch_run` runs files in parallel and writes copies to a folder that holds no source file. The tools' always-on context cost is 1,201 tokens. Standing: gate where run, `scripts/__tests__/forge-server.test.sh` (27 cases); every tool was also called once from a `claude -p` session on the fixtures.
- **A headless job never writes the file it opened.** The runner refuses to save a copy over its source, and the server fails a job whose source file changed size or modification time (`stage: source-modified`). Standing: gate where run.
- The `generate_texture` tool from the design is split into `texture_views` and `project_texture`, because the generation step runs through the Meshy MCP server, which this server cannot call.

## 0.2.0 — 2026-11-08

- **The forge library**, `blender_lib/forge/`: 14 modules for review renders and a numpy contact sheet, validation (20 checks), UVs, LODs, collision, engine export, Cycles map baking, a procedural hand-painted albedo, multi-view projection, sculpt-like deforms, organic blockouts, retopology and AI-mesh cleanup, and animation retargeting. Every public function returns a summary dict and refuses bad input with a named stage. Presets for four engines, three platforms and two bone maps. The server's runner gains a `call` op that runs any public forge function on a snapshot. Standing: gate where run, `scripts/__tests__/forge-lib.test.sh` (105 cases in Blender 5.2.3; skipped where no Blender is installed, CI included).

## 0.1.0 — 2026-11-08

- **New plugin, skeleton.** A `forge` MCP server written against the Python standard library (no uv, pip or Pillow), run by `python3` from `.mcp.json`. One tool, `env_check`: the Blender executable and how it was found (`blender_path` option, `BLENDER_PATH`, PATH, install folders), version, settable render engines (read from Blender at run time, Workbench included), numpy in Blender's Python. Headless jobs run `blender -b --factory-startup --python-exit-code 1`, with a timeout, and return `{"ok": false, "stage", "error", "blender_log_tail"}` on failure. Six skill stubs that state their status, each with `disable-model-invocation: true` until its content ships. Standing: gate where run, `scripts/__tests__/forge-server.test.sh`.
