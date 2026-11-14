# asset-forge

Game-asset creation in Blender. The model is weak at four things that a Blender MCP server alone does not fix:
judging its own work, organic shapes, hand-painted textures and retargeting animation. It also does not hold
studio conventions. This plugin adds a headless MCP server that renders, validates, bakes and exports
**snapshots** of the live scene (never the working `.blend`), a pure-bpy library the live session imports, and
pipeline skills with per-engine presets.

**Status: 0.7.0.** Library, server tools, skills, art-reviewer agent and review-after-change gate, exercised on three
stress tests (a wolf from a skin blockout, a rock cluster textured both ways, a Meshy humanoid's walk retargeted
and exported for Unity). Six eval cases, see Evals.

## Install

```bash
claude plugin install asset-forge@cc-plugins-marketplace
```

Needs `python3` on PATH (standard library only; tested on 3.14) and Blender (tested on 5.2.3 only). Nothing is downloaded
or installed: no uv, no pip, no Pillow. Live editing goes through a Blender MCP server you already run (this
plugin calls `execute_blender_code` and the screenshot tools; it ships none of them).

Works best beside **blender**: the retarget skill sends animated exports through its `anim_audit.py` and
`rig_check.py`, and its export rules back the presets. asset-forge runs without it. Nothing installs the pair for
you: no plugin here may declare `dependencies`.

```bash
claude plugin install blender@cc-plugins-marketplace
```

## Configure

| Option | Default | What it does |
|---|---|---|
| `cc_forge_review` (`CC_FORGE_REVIEW`) | on | The review-after-change gate below |
| `blender_path` | empty | Blender executable for headless jobs. Empty: `BLENDER_PATH`, then `blender` on PATH, then `~/Applications/blender-*`, `/opt/blender*`, the macOS app and `C:/Program Files/Blender Foundation` |

Per-project settings (engine, platform tiers, art style, game camera, budgets, folders) will live in the game
project's `asset-forge.json`, written by the `pipeline` skill on first use.

## What ships

| Artifact | Reach for it when |
|---|---|
| `forge` MCP server (`mcp__plugin_asset-forge_forge__*`) | Headless jobs on a snapshot `.blend`. `env_check` (which Blender, its version and engines); `render_review_set` (contact sheet returned inline); `validate_asset`; `bake_maps`; `stylize_texture` (albedo returned inline); `export_asset`; `texture_views` and `project_texture` (the two halves of AI texturing: guides out, generated per-view images back onto the UVs); `batch_run` (any public forge function over many files, copies only) |
| `blender_lib/forge/` library | 14 modules, pure bpy/bmesh/numpy, importable live (`sys.path.insert(0, "${CLAUDE_PLUGIN_ROOT}/blender_lib"); import forge`) and headless. `review_renders` (turntable, silhouette, game-distance, wireframe, UV-checker and matcap tiles plus one contact sheet, in a temporary scene), `validate` (20 checks against budget and engine preset), `uv`, `lod`, `collision`, `export` (FBX/glTF per engine preset, kwargs filtered against the exporter's live RNA), `bake` (normal, AO, curvature, thickness, ID in Cycles), `stylize` (procedural hand-painted albedo, no AI), `project_paint` (project per-view images back onto UVs), `deform` (grab, inflate, pinch, crease, bulge, smooth, flatten, noise, stroke), `blockout` (skin skeleton, metaballs, rocks, lathe, loft), `retopo` (voxel, QuadriFlow, decimate to budget, `clean_ai_mesh`), `retarget` (bone maps, bake, in-place, root motion, loop cleanup, NLA naming) |
| `presets/` | Engine presets (unity, unreal, godot, generic: exporter settings, naming, collision and LOD conventions, texture packing), platform budgets (pc, console, mobile: tris per asset class, texture sizes, texel density, LOD ratios), bone maps (mixamo→rigify, mixamo→ue5, meshy→rigify) |
| `pipeline` skill | Fires on game-asset work in Blender: the project's `asset-forge.json` (asked once, engine never guessed, several platform tiers allowed), the order from brief to export, live vs headless per step, the snapshot and forge-import snippets, the undo-push rule |
| `/asset-forge:new-asset <brief>` | One asset end to end, pausing after the blockout review and after the texture review, ending in validation per tier, export and a report |
| `/asset-forge:review [object]` | Snapshot → review renders → validation → independent critique (verdict, six scores, spatial issues with concrete fixes) |
| `art-reviewer` agent | Dispatched by the review flow: reads the contact sheet, references and validator JSON cold, never how the asset was built, and returns a verdict (ship, revise, rework), six 1–5 scores, spatial issues each with a concrete fix, and what to keep |
| `hooks/review-state.sh` | After `execute_blender_code` the scene counts as changed; a successful `render_review_set` clears it. At Stop, a context that used asset-forge and changed the scene since its last review is sent back once per change cycle to run the review or say why not |
| `organic-modeling`, `stylized-texturing`, `animation-retarget` | Read by path from `pipeline` (also typeable as `/asset-forge:<name>`): skeleton blockout + deform recipes and a proportions sheet; procedural vs Meshy-projected texturing; retargeting Mixamo/Meshy/BVH with in-place or root motion per engine. Only `pipeline` is in Claude's skill listing, which keeps the plugin's always-on cost at one description |

## What has teeth

| Rule | Standing |
|---|---|
| Every python block in the organic-modeling skill and its recipes runs as written and yields a manifold mesh of the stated size | gate where run: `scripts/__tests__/blender/test_recipes.py` |
| `skills/pipeline/references/forge-api.md` matches the library's signatures | gate: `scripts/gen_forge_api.py --check`, run by `forge-server.test.sh` (no Blender needed) |
| The server speaks MCP over stdio and every tool works on the fixtures | gate where run: `scripts/__tests__/forge-server.test.sh`, 45 cases (the 22 Blender cases skip when no Blender is found, the bind-mount case when `unshare -r -m` is refused) |
| Each forge function does what its docstring says (verts outside a deform radius never move, retargeted limbs within 5° of the source, exports re-import with the expected names and triangle counts, the bad-asset fixture fails validation) | gate where run: `scripts/__tests__/forge-lib.test.sh`, 136 cases inside Blender 5.2.3. CI has no Blender, so it prints SKIP there: the cases run on a developer machine only |
| An asset that changed since its last review is not called done silently | gate: `hooks/review-state.sh` at Stop, once per change cycle; `scripts/__tests__/review-state.test.sh`, 16 cases with the host's payloads. Misses: edits made by hand in Blender, and reviews done without `render_review_set` |
| An export reports what failed | gate: `export_asset` runs `validate_asset` on the first mesh among `objects` and re-imports what it wrote (`post_export_audit`: expected objects, no extras, faces, n-gons, UVs, materials, clips in the main file); a failure in either, or a validation that could not run, returns an error naming the checks, with the written files listed |
| A headless job never writes the `.blend` it opened | gate: the runner refuses a `save_copy_to` that is the opened file (by file identity, path recorded before the function runs), `batch_run` refuses an `out_dir` that is a source folder (by identity), and the server compares the file's size and modification time before and after every job, failing with `stage: source-modified`; harness cases "a job that changes its .blend fails with source-modified" and "after every tool the source .blend is byte-identical" |
| Headless jobs open a snapshot, not the user's working file | recorded: the server cannot see which file the live session has open; the snapshot step is the skills' job |

## Evals

Six cases under `evals/`, run with `claude plugin eval plugins/asset-forge --scaffold` (`--scaffold` is needed by
`review-structured-verdict`, which copies a contact sheet into the workspace; without it that case runs on an empty
folder). Measured 2026-11-08, 3 runs per arm, haiku judge, $5.67 in total:

| Case | With plugin | Without | Reading |
|---|---|---|---|
| `pipeline-asks-engine` | 3/3 | 1/3 | the plugin's one clear lift: asks the engine, plans a visual review and a budget check |
| `review-structured-verdict` | 0.5, 0.5, 1 (agent dispatched 2/3) | 0.5 ×3 | the art-reviewer runs, but the main thread paraphrases its verdict instead of quoting it |
| `export-preset-unity-clips`, `organic-skeleton-branches`, `snapshot-not-working-file`, `validator-catches-bad-asset` | 3/3 | 3/3 | the control arm passes, so these are regression guards and cannot show the plugin helping |

Three runs cannot separate a small delta from noise. The delta comes from behaviour the base model skips
unprompted (asking before guessing, planning review and validation), not from facts it lacks when the prompt names
the problem.

## Limitations

- The skills' pauses, snapshot rule and "look before you claim" are prose; only "review after a change" has a gate.
- The art-reviewer judges renders, so it cannot see engine lighting, shaders or the in-game view.
- Skin-blockout creatures stay blocky: on the wolf stress test the independent reviewer still asked for a level
  topline and shoulder and haunch masses after two revisions (silhouette 2 → 3).
- Tier-2 texturing with fewer views than sides leaves nearest-filled smears on what no camera saw.
- Tier-1 texturing paints light, shade and edges, not motifs: plank seams, grain, rivets and keyholes need geometry
  or Tier 2 (the treasure-chest test's reviewer scored surface detail 2/5 for this).

- Nothing was imported into Unity, Unreal or Godot: export round-trips go through Blender's own importers. The
  255-vertex hull cap is PhysX's and unverified for Unreal's Chaos; Mixamo bone names in the bone maps are not yet
  checked against a real Mixamo download; the Meshy bone map was read from one Meshy auto-rig (CHANGELOG 0.6.0).
- Rigify DEF bones are driven by constraints, so keys retargeted onto them are overridden; `retarget` warns.
- Normal maps are OpenGL (+Y); Unreal expects DirectX (−Y) and no flip is applied yet.
- The first GPU (OptiX) bake on a machine can stall about a minute while kernels compile.

- The server runs Blender with `--factory-startup`, so the user's add-ons and preferences are not loaded headless.
- `env_check` finds render engines by trying to set each one; a third-party engine that registers only in the
  user's preferences is not listed.
