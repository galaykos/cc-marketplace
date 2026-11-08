# asset-forge

Game-asset creation in Blender. The model is weak at four things that a Blender MCP server alone does not fix:
judging its own work, organic shapes, hand-painted textures and retargeting animation. It also does not hold
studio conventions. This plugin adds a headless MCP server that renders, validates, bakes and exports
**snapshots** of the live scene (never the working `.blend`), a pure-bpy library the live session imports, and
pipeline skills with per-engine presets.

**Status: 0.3.0 ships the forge library and the headless server tools.** The skills' content, the hooks and the
art-reviewer agent are not built yet. Each skill says so when it loads.

## Install

```bash
claude plugin install asset-forge@cc-plugins-marketplace
```

Needs `python3` on PATH (standard library only; tested on 3.14) and Blender (tested on 5.2.3 only). Nothing is downloaded
or installed: no uv, no pip, no Pillow. Live editing goes through a Blender MCP server you already run (this
plugin calls `execute_blender_code` and the screenshot tools; it ships none of them).

Companion: install **blender** alongside it. Its checkers (`blender_qa.py`, `rig_check.py`, `anim_audit.py`)
and its export rules are what asset-forge calls rather than duplicating. Nothing installs the pair for you: no
plugin here may declare `dependencies`.

```bash
claude plugin install blender@cc-plugins-marketplace
```

## Configure

| Option | Default | What it does |
|---|---|---|
| `blender_path` | empty | Blender executable for headless jobs. Empty: `BLENDER_PATH`, then `blender` on PATH, then `~/Applications/blender-*`, `/opt/blender*`, the macOS app and `C:/Program Files/Blender Foundation` |

Per-project settings (engine, platform tiers, art style, game camera, budgets, folders) will live in the game
project's `asset-forge.json`, written by the `pipeline` skill on first use.

## What ships

| Artifact | Reach for it when |
|---|---|
| `forge` MCP server (`mcp__plugin_asset-forge_forge__*`) | Headless jobs on a snapshot `.blend`. `env_check` (which Blender, its version and engines); `render_review_set` (contact sheet returned inline); `validate_asset`; `bake_maps`; `stylize_texture` (albedo returned inline); `export_asset`; `texture_views` and `project_texture` (the two halves of AI texturing: guides out, generated per-view images back onto the UVs); `batch_run` (any public forge function over many files, copies only) |
| `blender_lib/forge/` library | 14 modules, pure bpy/bmesh/numpy, importable live (`sys.path.insert(0, "${CLAUDE_PLUGIN_ROOT}/blender_lib"); import forge`) and headless. `review_renders` (turntable, silhouette, game-distance, wireframe, UV-checker and matcap tiles plus one contact sheet, in a temporary scene), `validate` (20 checks against budget and engine preset), `uv`, `lod`, `collision`, `export` (FBX/glTF per engine preset, kwargs filtered against the exporter's live RNA), `bake` (normal, AO, curvature, thickness, ID in Cycles), `stylize` (procedural hand-painted albedo, no AI), `project_paint` (project per-view images back onto UVs), `deform` (grab, inflate, pinch, crease, bulge, smooth, flatten, noise, stroke), `blockout` (skin skeleton, metaballs, rocks, lathe, loft), `retopo` (voxel, QuadriFlow, decimate to budget, `clean_ai_mesh`), `retarget` (bone maps, bake, in-place, root motion, loop cleanup, NLA naming) |
| `presets/` | Engine presets (unity, unreal, godot, generic: exporter settings, naming, collision and LOD conventions, texture packing), platform budgets (pc, console, mobile: tris per asset class, texture sizes, texel density, LOD ratios), bone maps (mixamo→rigify, mixamo→ue5) |
| skills `pipeline`, `new-asset`, `organic-modeling`, `stylized-texturing`, `animation-retarget`, `review` | Stubs that state their status. All six carry `disable-model-invocation: true`, so they cost no listing context and never fire on their own until their content ships; `/asset-forge:<name>` still opens one |

## What has teeth

| Rule | Standing |
|---|---|
| The server speaks MCP over stdio and every tool works on the fixtures | gate where run: `scripts/__tests__/forge-server.test.sh`, 27 cases (the 15 Blender cases skip when no Blender is found) |
| Each forge function does what its docstring says (verts outside a deform radius never move, retargeted limbs within 5° of the source, exports re-import with the expected names and triangle counts, the bad-asset fixture fails validation) | gate where run: `scripts/__tests__/forge-lib.test.sh`, 105 cases inside Blender 5.2.3. CI has no Blender, so it prints SKIP there: the cases run on a developer machine only |
| A headless job never writes the `.blend` it opened | gate: the runner refuses `save_copy_to` equal to the opened file, and the server compares the file's size and modification time before and after every job, failing with `stage: source-modified`; harness case "after every tool the source .blend is byte-identical" |
| Headless jobs open a snapshot, not the user's working file | recorded: the server cannot see which file the live session has open; the snapshot step is the skills' job |

## Limitations

- Nothing was imported into Unity, Unreal or Godot: export round-trips go through Blender's own importers. The
  255-vertex hull cap is PhysX's and unverified for Unreal's Chaos; Mixamo bone names in the bone maps are not yet
  checked against a real Mixamo download; there is no Meshy bone map (no source names Meshy's rig bones).
- Rigify DEF bones are driven by constraints, so keys retargeted onto them are overridden; `retarget` warns.
- Normal maps are OpenGL (+Y); Unreal expects DirectX (−Y) and no flip is applied yet.
- The first GPU (OptiX) bake on a machine can stall about a minute while kernels compile.

- The server runs Blender with `--factory-startup`, so the user's add-ons and preferences are not loaded headless.
- `env_check` finds render engines by trying to set each one; a third-party engine that registers only in the
  user's preferences is not listed.
