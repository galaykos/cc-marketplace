# blender: derivations, provenance and verification (2026-10-30)

The `blender` plugin was built on 2026-10-30 from four MIT repositories, each fetched as a tarball at a pinned
commit into a scratch directory and never executed: EL4CTEO/blender-skills @71d031d (the seed: 22 skills, ~2.1k
lines of skill text, ~5.4k lines of scripts), ra100/blender-claude-plugin @78e9151 (8 API-reference skills, ~10k
lines), MartinRapcan/blender-claude-skill @70f45e3 (~4k lines) and AiverReaver/blender-unreal-pipeline-skill
@b590525 (skill, scripts, a 1,296-line report and 11 research notes). The bar was `README.md`'s and
`rationale/measured-zero-shapes.md`'s: only inverted facts, non-obvious footguns, hard limits and mechanisms with
exit codes survive. Every kept fact was re-checked against a primary source or probed in a local Blender 5.2.3 LTS
binary (build e13b728c6880, 2026-10-22). Nothing here is measured against a control arm. Standing: `recorded` —
no gate reads this file.

## plugins/blender/scripts/check_bpy_scripts.py

### Why it exists

The confident 2023–2025 answer for animation, compositor, render-engine and Geometry Nodes code raises on 5.x
(`action.fcurves`, `scene.node_tree`, `BLENDER_EEVEE_NEXT`, `mod["Socket_2"]`). A model writes those from memory,
and a review reads past them. A lexical gate with an exit code is the one artifact here that measured-zero-shapes
does not predict to be zero.

### Design

- AST, not regex: comments and strings never match, and receivers are compared as unparsed source.
- Each rule carries a version window, so one table serves "removed in X" (error from X), deprecation (warning
  from X) and "too new for X" (error below X), and the 4.2–4.5 `BLENDER_EEVEE_NEXT` window.
- Ambiguous attribute names (`fcurves`, `groups`, `node_tree`, `select`, `use_nodes`, `inputs`) need a receiver
  spelled like the removed owner. The owner map came from Blender 5.2.3: every `bpy.types` struct still carrying
  each name was listed (`fcurves`: ActionChannelbag, NlaStrip; `node_tree`: 31 types, none Scene; `id_root`:
  none), and names with no surviving owner match bare.
- The target version comes from `--blender`, else the newest `.blend` header under the path. The header layout
  was read from Blender's `source/blender/blenloader_core/intern/blo_core_blend_header.cc` (legacy 12 bytes
  `BLENDER` + `_`/`-` + `v`/`V` + 3 digits; format 1, 17 bytes, `BLENDER17-01v` + 4 digits) and gzip/zstd
  detection from `blo_core_file_reader.cc` and `BLI_file_magic_is_zstd`.

### Measured on 2026-10-30

- Blender 5.2.3's 601 bundled scripts at `--blender 5.2`: 0 findings (after the two fixes below).
- Blender's own scripts fetched at tags v3.6.0, v4.0.0, v4.4.0, v4.5.0: 0 findings at their own version; at 5.2,
  real breaks (`action.fcurves` in 4.4's `anim_utils.py` and `anim.py`, `scene.node_tree` in 4.4's `anim.py`,
  `use_auto_smooth` and `sculpt_tool` in 4.0's UI scripts, `BLENDER_EEVEE_NEXT` strings), each spot-checked.
- The four upstream repos' scripts at 5.2: 0 findings after the fixes.
- Two false positives found on real code and fixed before shipping: `settings.use_automasking_*` is valid in 5.2
  (the names live on in `MeshAutomaskingSettings`), so the automasking rule now needs a brush/sculpt/paint
  receiver; a plain dict keyed `"cycles"` (EL4CTEO `render_batch.py:80`) matched the idprop rule, which now needs
  an ID-like receiver.
- Three seeded mutations (a rule disabled, the header decoder off by one byte, the pose-bone exclusion removed)
  each failed the suite.
- `test_rules_in_blender.py` with `BLENDER_EXE` set: for all 29 rules, the reported API is absent from 5.2.3 where
  the rule applies, and the replacement its message names exists.
- Suite run under Python 3.14 (zstd read) and Blender's bundled Python 3.13 (zstd reported unreadable).

### Limits

A renamed variable, an aliased import (`from bpy import ops`) or `getattr` hides a break; an unrelated object
with a matching attribute and receiver spelling is reported. Removals outside the table (bone layers,
`BMLoopUV.select`, render-pass names, Principled socket names) are not checked.

## plugins/blender/scripts/blender_qa.py

### Upstream docstring (EL4CTEO/blender-skills@71d031d skills/blender-asset-qa/scripts/qa_check.py), verbatim

```text
Mesh/asset QA: z-fighting, detached parts, normals, topology, transforms, UVs, weights.

Pass the objects of ONE asset (they are checked together: islands far from all others = floating).
Usage:
  blender -b f.blend -P qa_check.py -- [--objects A B] [--profile game|render|print|roblox]
      [--eps 0.001] [--tol 0.002] [--no-modifiers] [--max-tris 300000]
  MCP: import qa_check; print(qa_check.run(objects=["Chair"], profile="game"))
Returns {"pass": bool, "errors": [...], "warnings": [...], "objects": {name: metrics}}.
```

### What changed on import

- Upstream's `_bpyx.cli` exited 1 only on an exception; a failed check printed `{"pass": false}` and exited 0, so
  a CI step read every failing asset as success. It now exits 1 on errors (or warnings with `--strict`) and 2 when
  it cannot run (missing object, bad flag, run outside Blender). Measured in 5.2.3 on fixtures: clean cube 0,
  coplanar planes 1, detached island 1, missing object 2, unknown profile 2.
- Helpers inlined from `shared/_bpyx.py`; island grouping takes index pairs so it is testable without Blender;
  bpy imports are guarded so CI can load the module.
- The `roblox` profile's 20,000-triangle cap was re-read on Roblox's General specifications page
  (<https://create.roblox.com/docs/art/modeling/specifications>, "Individual meshes can not exceed 20,000 triangles").

### Limits

CI runs only the pure parts. The geometry checks are upstream's, exercised here on three fixtures in 5.2.3; they
were not re-derived. No check judges silhouette, deformation, shading or material intent.

## Provenance

| Upstream path | Verdict | Landed | Reason |
|---|---|---|---|
| EL4CTEO `blender-core/SKILL.md` | merged | SKILL.md (headless command, node lookup by type) | routing table and data-API doctrine are restatement |
| EL4CTEO `blender-core/references/api-changes-5x.md` | merged | `references/api-5x.md`, checker rules | every row re-read against the release notes and probed; only rows that raise or no-op kept |
| EL4CTEO `blender-core/references/bpy-patterns.md` | cut | — | API tour; the channelbag snippet was rewritten and probed |
| EL4CTEO `blender-core/scripts/run_in_blender.py`, `env_report.py` | cut | — | wrappers; its one fact (flag before `-P`) re-measured and kept in SKILL.md |
| EL4CTEO `shared/_bpyx.py` (+20 identical copies, md5-checked) | merged | `scripts/blender_qa.py` helpers | copied and modified, see NOTICE |
| EL4CTEO `blender-asset-qa/SKILL.md` | merged | SKILL.md § Mesh QA | the catch/miss list; fix table cut as doctrine |
| EL4CTEO `blender-asset-qa/scripts/qa_check.py` | kept | `scripts/blender_qa.py` | a mechanism; exit-code defect fixed |
| EL4CTEO `blender-asset-qa/scripts/review_shots.py` | cut | — | renders a contact sheet, returns no verdict |
| EL4CTEO `blender-export-pipelines/SKILL.md` | merged | `references/export.md` | `use_tspace`, `bake_space_transform` (re-read from the exporter's RNA); checklist cut |
| EL4CTEO `export-pipelines/references/unreal.md` | merged | export.md § Unreal, unit table | collision naming re-read on Epic's page; its Unit 1.0 + `FBX_SCALE_UNITS` advice is confirmed at file level (factor in the header, no node scale) but engine-side contested, so the measured table replaces it |
| EL4CTEO `export-pipelines/references/unity.md` | merged | export.md § Unity | URP and HDRP packing re-read on Unity's pages; Humanoid and clip doctrine cut |
| EL4CTEO `export-pipelines/references/godot-web.md` | merged | export.md § glTF, Godot | suffix list re-read on Godot 4.7 (upstream's was incomplete); web budgets cut |
| EL4CTEO `export-pipelines/references/roblox.md` | cut | — | avatar and cage specs not re-read; only the 20k cap survives, via the QA profile |
| EL4CTEO `export-pipelines/scripts/export_asset.py` | cut | — | an exporter wrapper encoding the contested unit choice; no verdict |
| EL4CTEO `blender-animation/SKILL.md`, `scripts/bake_action.py` | merged / cut | api-5x.md § Animation | 5.0 data model kept and probed; workflow and baking tool cut |
| EL4CTEO `blender-addon-development` (SKILL.md + template) | merged | api-5x.md (private modules, manifest row) | template is framework restatement |
| EL4CTEO `blender-geometry-nodes` (SKILL.md, recipes, `gn_builder.py`) | merged | api-5x.md, rule `gn-socket-key` | 5.2 modifier API probed (`TypeError`); builder cut |
| EL4CTEO `blender-rendering` (SKILL.md, `render_batch.py`) | merged | api-5x.md § Compositor and rendering | `media_type` order probed; presets cut |
| EL4CTEO `blender-sculpting` (SKILL.md, `sculpt_ops.py`) | merged | api-5x.md § Brushes | brush renames probed; "Sculpt Mode crashes under -b" kept as unverified |
| EL4CTEO `blender-pbr-materials` (SKILL.md, `pbr-values.md`, `build_pbr_material.py`) | merged | export.md packing | value tables cut as catalogue |
| EL4CTEO `blender-pipeline-automation` (SKILL.md, `batch_process.py`) | merged | SKILL.md § Headless runs | flag semantics re-measured; batch tool cut |
| EL4CTEO `blender-weather-fx` (SKILL.md, 2 refs, 3 scripts) | merged | api-5x.md (instances absent from `to_mesh`) | probed; weather catalogue cut |
| EL4CTEO `character-rigging`, `facial-shapekeys`, `game-optimization`, `hardsurface-modeling`, `lighting-lookdev`, `retopology-uv`, `scene-setup`, `simulation`, `texture-baking`, `time-of-day`, `workflow-recipes` (+ their scripts and references) | cut | — | doctrine, budgets and value catalogues; their version facts (`bone.select`, Boolean `FAST`) went to checker rules |
| EL4CTEO `tools/*`, `tests/*`, README, AGENTS, CHANGELOG, `install/*`, `docs/*` | cut | — | repo tooling; the comparison page is not a control-arm eval |
| ra100 `blender-*/SKILL.md` and `references/*` (8 skills) | cut | — | node, modifier and settings catalogues; several claims wrong for 5.x (compositor via `scene.node_tree`, `action.fcurves` as the working accessor, `bone.layers`) |
| ra100 `docs/blender-mcp-setup.md` | replaced | README § MCP servers | re-read from the Lab project itself (release v1.0.3, Setup wiki); ra100's v1.0.0 links and `settings.json` wiring dropped |
| MartinRapcan `blender/references/gotchas.md`, SKILL.md | merged | api-5x.md, SKILL.md | EEVEE id, `action.fcurves`, compositor, `use_nodes`, Python 3.13 re-verified |
| MartinRapcan `references/*` (rest), `scripts/*`, `tests/*` | cut | — | lighting and detailing catalogues, helper kits |
| AiverReaver `skills/blender-unreal-pipeline/SKILL.md`, `references/*` | merged | export.md | unit table and shape-key rule re-measured at file level on 5.2.3 (both match); exporter defaults re-read from RNA; armature naming and smoothing warning kept as unverified |
| AiverReaver `scripts/fbx_inspect.py` | cut (not copied) | — | a real FBX gate; out of scope for 0.1.0, named as a follow-up |
| AiverReaver `scripts/validate_blender.py`, `export_fbx_template.py`, `ue_import.py`, `commands/*`, `tests/*` | cut | — | MCP-driven workflow; `validate_blender.py`'s headless line puts `--python-exit-code` after `--python` |
| AiverReaver `reports/…guide.md`, `research_notes/*` | read, routed | export.md | experiment results used only where re-measured or labelled |

Read by delegated readers rather than in this thread, each told to read in full and list gaps (none reported):
EL4CTEO's 24 non-core scripts and 17 tests; all of ra100; all of MartinRapcan; AiverReaver's report and research
notes. AiverReaver's `references/sources.md` registry rows after R79 were read truncated (a URL list).

## Verified against primary sources (2026-10-30)

| Fact | Source |
|---|---|
| 5.0 removals and renames (Action legacy API, `scene.node_tree`, EEVEE id, bgl, bindcode, bpy.props dict access, `media_type`, passes, File Output, Boolean `FLOAT`, bone select, `space_data.action`, brush, GP, private modules, `use_nodes` deprecations) | https://developer.blender.org/docs/release_notes/5.0/python_api/ |
| Python 3.13, `stroke_method`, VSE property deprecations | https://developer.blender.org/docs/release_notes/5.1/python_api/ |
| GN modifier RNA properties, Compare/Random Value identifiers, automasking struct, `active_asset_library`, `template_palette` | https://developer.blender.org/docs/release_notes/5.2/python_api/ |
| New file format, 4.5 LTS reads it, compression on by default | https://developer.blender.org/docs/release_notes/5.0/core/ · https://developer.blender.org/docs/release_notes/compatibility/ |
| `.blend` header layouts; gzip/zstd detection | Blender source, `blenloader_core/intern/blo_core_blend_header.cc`, `blo_core_file_reader.cc`, `blenlib/intern/fileops_c.cc` (main @191de40e) |
| `--python-exit-code` semantics and default 0; argument order | https://docs.blender.org/manual/en/latest/advanced/command_line/arguments.html · `source/creator/creator_args.cc`, `creator.cc:186` |
| `sys.exit(n)` exits Blender with n | `source/blender/python/intern/bpy_interface_run.cc`, `generic/py_capi_utils.cc` |
| ops context-dict removal, `NodeTree.interface`, Principled renames | https://developer.blender.org/docs/release_notes/4.0/python_api/ |
| auto smooth and split-normal removals | https://developer.blender.org/docs/release_notes/4.1/python_api/ |
| `BLENDER_EEVEE_NEXT` in 4.2, `blend_method` → `surface_render_method`, manifest vs `bl_info` | https://developer.blender.org/docs/release_notes/4.2/python_api/ |
| slotted actions, `action_get_channelbag_for_slot`, legacy API removal planned for 5.0 | https://developer.blender.org/docs/release_notes/4.4/python_api/ |
| Collision prefixes, single-mesh collision, pivot at origin, sockets | https://dev.epicgames.com/documentation/en-us/unreal-engine/fbx-static-mesh-pipeline-in-unreal-engine |
| URP channel packing, smoothness source | https://docs.unity.com/en-us/engine/6000.3/manual/materials-and-shaders/built-in/shaders-in-universalrp/channel-packed-texture · https://docs.unity.com/en-us/engine/6000.0/manual/materials-and-shaders/built-in/shaders-in-universalrp/reference/lit-shader |
| HDRP mask map | https://docs.unity3d.com/Packages/com.unity.render-pipelines.high-definition@17.0/manual/Mask-Map-and-Detail-Map.html |
| glTF metallicRoughness and occlusion channels | https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html (5.22.5, 5.19.6) |
| Godot import suffixes | https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/node_type_customization.html (4.7) |
| Blender Lab MCP: GPL-3.0, add-on 5.1+, v1.0.3, Setup wiki commands | https://projects.blender.org/lab/blender_mcp (LICENSE, readme.md, wiki Setup via API, @dbbf836) · https://www.blender.org/lab/mcp-server/ |
| MCP for Blender: install lines, telemetry, safe mode | https://github.com/ahujasid/mcp-for-blender @992233b (README.md, TERMS_AND_CONDITIONS.md) |

Probed in Blender 5.2.3 (scripts in a scratch directory, not shipped): exit codes for raise, compile error,
flag order, `sys.exit`, missing `.blend`; every rule's absent/replacement pair; the default save being zstd and
the uncompressed header `BLENDER17-01v0502`; localized node names (French UI: `BSDF guidée`, English sockets);
`FFMPEG` rejected under `media_type = "IMAGE"`; a fresh action has no slot; GN instances absent from `to_mesh()`;
FBX `UnitScaleFactor` and `Lcl Scaling` for three scale options at Unit Scale 1.0 and 0.01; shape keys kept with an
Armature-only stack and dropped by a Subdivision modifier; FBX and glTF exporter defaults and descriptions.

## Dropped or kept as unverified

| Claim (upstream) | Disposition | Why |
|---|---|---|
| `gpu.init()` is required in background mode (EL4CTEO) | dropped | 5.2 notes say it initializes the GPU backend, not that it is required |
| User site-packages no longer loaded from 5.1 (EL4CTEO) | dropped | not on the 5.1 Python API page |
| IDProperty nesting capped at 1024 (EL4CTEO) | dropped | verified, but not a trap anyone hits |
| Sculpt Mode operators crash under `-b` (EL4CTEO) | kept, labelled unverified | not re-run |
| Unreal drops only an armature object named `Armature`; `root` + `root` → `root1` (AiverReaver) | kept, labelled unverified | upstream measurement on UE 5.8.3 legacy import; no Unreal here |
| `mesh_smooth_type='OFF'` makes Unreal log "No smoothing group information" (AiverReaver) | kept, labelled unverified | same |
| Unreal's legacy MCP import ignores `UnitScaleFactor` (AiverReaver) | kept, labelled unverified | same; the file-level half was re-measured |
| Unity Bake Axis Conversion, Humanoid minimum bones, glTFast (EL4CTEO) | dropped | not re-read; not inverted |
| Roblox avatar budgets, cages, attachments (EL4CTEO) | dropped | not re-read |
| Godot auto LOD, `.blend` direct import, extras as metadata (EL4CTEO) | dropped | not re-read |
| Lab MCP default port 9876 (ra100) | dropped | not on the Lab's own pages |
| `SunLight.use_nodes` deprecated (EL4CTEO) | dropped | not on the 5.0 page that lists the material and world deprecations |

## What is not done

- No control-arm eval: each KEEP is a falsifiable prediction.
- No hook runs either script; the skill tells the model when to.
- CI cannot run Blender: the rule-truth test and the QA geometry tests run only where `BLENDER_EXE` is set.
- AiverReaver's `fbx_inspect.py` (a stdlib FBX gate for `UnitScaleFactor` and node scale) was not imported.
