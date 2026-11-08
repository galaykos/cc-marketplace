---
name: pipeline
description: Use when making or changing a game asset in Blender (prop, character, creature, rock, modular piece) for Unity, Unreal, Godot or glTF. Covers the project's asset-forge.json, the order from brief to export, which steps run live and which headless on a snapshot, and how to import forge live.
---

# Game-asset pipeline in Blender

Two execution paths, never mixed:

| Path | Tool | Does |
|---|---|---|
| **Live** | Blender MCP `execute_blender_code` in the user's open Blender | Every **mutating** step, so the user sees it and nothing drifts |
| **Headless** | forge MCP tools `mcp__plugin_asset-forge_forge__*` | Read-only or output-producing jobs on a **snapshot**: review renders, validation, bakes, stylized albedo, AI-texture guides and projection, export, batch |

## 1. Project config first

Read `${CLAUDE_PROJECT_DIR}/asset-forge.json`. Missing → ask the user in ONE batched question before any
modelling: engine (never guess it), platform tiers, art style, game camera, folders. Write the file; schema and
defaults: `${CLAUDE_PLUGIN_ROOT}/skills/pipeline/references/config.md`. **Platform tiers are asked per project
and may be several** (author for the highest tier, scale down; validate every tier). Standing: recorded.

## 2. The order

| # | Step | Path | How |
|---|---|---|---|
| 1 | Brief | — | Asset class (`prop_small` … `character`), real-world size in metres, references from `folders.references` |
| 2 | Blockout | live | Hard surface: primitives + bmesh. Organic: read `${CLAUDE_PLUGIN_ROOT}/skills/organic-modeling/SKILL.md` |
| 3 | **Review** | headless | `/asset-forge:review` flow (read `${CLAUDE_PLUGIN_ROOT}/skills/review/SKILL.md`) — silhouette and proportions only |
| 4 | Refine | live | forge `deform`, bevels, detail |
| 5 | Retopo / cleanup | live | `retopo.decimate_to_budget`, `retopo.clean_ai_mesh` for generated meshes |
| 6 | UV | live | `uv.seams_from_sharp` → `uv.unwrap` (or `uv.smart_project`) → `uv.pack(texture_px=)` → `uv.set_texel_density` **last**: `pack` rescales islands to fill the square and undoes the density. If the packed density is under the target, the texture is too small for the asset class (measured: a 0.8 m chest reaches 344 px/m at 1,024 px, 718 at 2,048) |
| 7 | Bake | headless | `bake_maps` (normal from a high-poly when there is one) |
| 8 | Texture | headless, then live | read `${CLAUDE_PLUGIN_ROOT}/skills/stylized-texturing/SKILL.md`; assign the PNG live with `stylize.apply_albedo` (merges to one slot, one draw call) |
| 9 | **Review** | headless | full set, surfaces this time |
| 10 | LODs | live | `lod.make_lod_chain(obj, engine=, platform=)` — renames the source to LOD0. Hard-surface meshes whose every edge is a UV seam lock every vertex: read `skipped`, then pass `protect=("boundary",)` |
| 11 | Collision | live | `collision.make_collision(obj, kind=, engine=)` on LOD0 — named from the exact render-mesh name (`UCX_SM_X_LOD0_01`), which Unreal requires |
| 12 | Validate | headless | `validate_asset` per platform tier; fix every `fail`, explain every `warn` |
| 13 | Export | headless | `export_asset` to `folders.export_dir` |

Animated assets add rig and clips between 11 and 12: `${CLAUDE_PLUGIN_ROOT}/skills/animation-retarget/SKILL.md`.

## 3. Live: import forge

Run once per session through `execute_blender_code` (it also drops a stale copy after a plugin update):

```python
import sys
LIB = "${CLAUDE_PLUGIN_ROOT}/blender_lib"
sys.path[:] = [p for p in sys.path if p == LIB or not ("/asset-forge/" in p and p.endswith("/blender_lib"))]
if LIB not in sys.path:
    sys.path.insert(0, LIB)
for name in [m for m in sys.modules if m == "forge" or m.startswith("forge.")]:
    del sys.modules[name]
from forge import blockout, deform, retopo, uv, lod, collision, retarget, util
result = {"forge": LIB}
```

Every forge function returns a dict with `ok`; assign it to `result` to see it. A refusal raises `ForgeError`
with a `stage` and a message saying what to change. Signatures: `references/forge-api.md`.

**End every mutating call with `bpy.ops.ed.undo_push(message="asset-forge: <step>")`.** Python data writes do not
mark the file as unsaved: measured on 5.2.3 through the Blender MCP, `bpy.data.is_dirty` stayed False after an
edit and turned True only after an undo push. Without it, closing Blender loses the work with no prompt, and the
user has no Ctrl+Z step to go back to. Standing: recorded.

## 4. Headless: snapshot first

Before every headless tool call on the live scene, save a **copy** from the live session:

```python
import bpy, os, time
snap = os.path.join("/tmp/asset-forge/snapshots", f"{bpy.path.clean_name(bpy.context.scene.name)}_{int(time.time())}.blend")
os.makedirs(os.path.dirname(snap), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=snap, copy=True)
result = {"snapshot": snap}
```

`copy=True` leaves the user's file path and unsaved state alone. Pass `snap` as `blend_path`. Images generated
or painted in this session and never saved are NOT in the snapshot: pack them first (`image.pack()`).
Standing: gate for the other half — the server fails any job whose source file changed
(`stage: source-modified`); recorded for "the user's working file is never opened headless", which the server
cannot see.

## 5. Look before you claim

After every significant live change, take `get_screenshot_of_window_as_image` (or
`get_objects_summary` for structure) and actually check it: the shape, the scale against a 1.8 m reference,
nothing left selected in Edit Mode. A forge dict saying `ok` means the code ran, not that the asset looks right.
Standing: recorded.

## 6. Conventions

- Metres, real-world scale (door ≈ 2.0 m, crate 0.5–1 m, character 1.6–1.9 m). Z up in Blender; the exporter
  converts per engine.
- Names, LOD suffixes, collision names, texture packing and pivot rule come from
  `${CLAUDE_PLUGIN_ROOT}/presets/engines/<engine>.json`; budgets from `presets/budgets/<tier>.json`, overridden by
  `asset-forge.json`. Summary table: `references/config.md`.
- Apply rotation and scale before UVs and export (`util.apply_transforms`).
- Never run `execute_blender_code` for read-only inspection when a summary tool exists.

## 7. Neighbours

`blender:blender-best-practices` for bpy API breaks and exporter facts; `blender`'s `rig_check.py` and
`anim_audit.py` for skinned and animated exports; `gamedev:asset-pipeline` for a concept image through Meshy to an
engine; `meshy:meshy-generation` before spending Meshy credits.

## Limitations

- Nothing here was checked inside Unity, Unreal or Godot; exports are verified by re-importing into Blender.
- The server cannot see which file the live session has open: the snapshot rule is yours to keep.
- Budgets are starting defaults, not engine limits; the user's numbers in `asset-forge.json` win.
