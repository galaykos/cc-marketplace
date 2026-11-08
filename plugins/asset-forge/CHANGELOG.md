# Changelog — asset-forge

Consumer-facing changes only. Newest first.

## 0.7.0 — 2026-11-08

- **Evals.** Six cases under `evals/` (run with `--scaffold`). Three runs per arm: `pipeline-asks-engine` 3/3 with the plugin against 1/3 without. `review-structured-verdict` scores 0.67 with against 0.5 without; the art-reviewer was dispatched in 2 of 3 runs once its description named review renders. The other four cases pass without the plugin too, so they are regression guards. Standing: recorded (nothing runs evals in CI).
- **Full review, 59 findings fixed.** Highlights:
  - `batch_run` and the runner compare files by identity, so a case-insensitive disk can no longer overwrite a source.
  - `apply_transforms` bakes shape keys and leaves Edit Mode first.
  - Symmetric deforms no longer double an edit on the mirror plane.
  - `apply_albedo` writes to its own named node and creates a BSDF when the material has none.
  - The validator accepts only the colliders that export will collect.
  - `audit_export` checks collider naming and refuses to run outside `blender -b`.
  - LOD `silhouette_ok` measures surface distance. It caught a caved-in LOD3 that the old bounding-box test passed.
  - `export_asset` fails when its source validation cannot run, and skips validation (with a note) when the export has no mesh.
  - The server runs each call on its own thread and kills Blender when a call is cancelled.
  - Other fixes: stdin and stdout are UTF-8; parallel Blender processes are capped; the inline image limit is 3.7 MB.
  - Preset naming lives in one module, `forge/naming.py`, and the bake helpers are public in `forge/bakekit.py`.
  - Standing: the library suite (136), the server harness (45) and the review-state harness (16).
- `apply_albedo`'s default material name is now `M_<object>_Stylized`, the same as `stylize`.

## 0.6.0 — 2026-11-08

- **Stress tests: a wolf, a rock cluster, an animated Meshy humanoid.** Fixes and skill changes from what they exposed:
  - **New bone map `meshy_to_rigify`.** The names were read from a real Meshy auto-rig: Spine02 sits next to the hips; neck is lower-case. Meshy's walk retargeted onto a Rigify-named A-pose rig matched the source's bone directions to 0.0° (4 bones, 4 frames). Its 0.01-scale glTF armature needed nothing extra.
  - **FBX presets export NLA strips only.** Blender's defaults shipped the retargeted clip twice and leaked the source rig's action, as `anim_audit.py` showed. Unity and Unreal now set `bake_anim_use_all_actions: False`.
  - **`export_asset(clips=[…])`.** The post-export audit now lists the clips that shipped and fails unless they are exactly the ones named. It also accepts armatures among the expected objects; before, it wrongly failed any rigged export.
  - **`validate_asset` pivot for skinned meshes.** Their origin must sit on the ground inside the footprint, not at the bounding-box centre, which feet and tails skew.
  - **`organic-modeling`.** Silhouette features such as ears, tail, elbows, hocks and paws are skeleton branches: a deform-made ear moved 4 vertices and never showed. Never add a joint between two torso joints, because the Skin hull folds there. Fuse with `voxel_remesh(0.015)` and smooth. The quadruped spec is replaced by the wolf's round-3 spec, and the independent reviewer's verdict on it went from rework to revise.
  - **`stylized-texturing`.** For Meshy image-to-image, send the normal guide, not the AO guide. Inspect generated views, since the generator can add shapes. Two views saw 41% of a rock cluster's texels. Tier-1 stone needs more value spread.
  - Credits spent on Meshy: 26.

## 0.5.0 — 2026-11-08

- **`art-reviewer` agent.** An independent critique from the contact sheet, references and validator alone. It returns a verdict, six 1–5 scores and spatial issues, each with a concrete fix. On a deliberately wrong blockout (a 1.44 m column briefed as a 0.8 m chest), dispatched from a fresh `claude -p` session, it returned `rework` with silhouette, proportions and readability at 1. It named the size miss in numbers (31% of the target width, 240% of the height) and gave target dimensions. Standing: agent-graded.
- **Review-after-change gate** (`hooks/review-state.sh`, option `cc_forge_review` / `CC_FORGE_REVIEW`, default on). An `execute_blender_code` call marks the scene changed; a successful `render_review_set` clears it. At Stop, a context that used asset-forge and changed the scene since its last review is sent back once per change cycle. Plain Blender work in a session that never touched asset-forge is never blocked. Standing: gate, `scripts/__tests__/review-state.test.sh` (14 cases).
- **`export_asset` validates the source and audits what it wrote.** `source_validation` runs `validate_asset` (new optional `asset_class`). `post_export_audit` re-imports the files into an empty scene and checks the expected objects arrived with nothing extra, with faces, no n-gons, UVs and materials. Either failure returns an error naming the checks; the files written are still listed. The design's separate post-export hook and SessionStart setup hook were folded away: `rationale/derivations/plugin-asset-forge.md`.

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
