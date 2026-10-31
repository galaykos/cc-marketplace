# Export from Blender to a game engine

> Last verified: 2026-10-30 — https://dev.epicgames.com/documentation/en-us/unreal-engine/fbx-static-mesh-pipeline-in-unreal-engine

Only settings whose default or textbook answer breaks an engine import. Sources re-read on 2026-10-30: the
option descriptions and defaults of Blender 5.2.3's own FBX exporter (`io_scene_fbx` 5.15.0) and glTF exporter,
read from their RNA; FBX files exported from 5.2.3 and parsed; Epic's FBX Static Mesh Pipeline page; Unity 6's URP
Lit, URP channel-packing and HDRP mask-map pages; the glTF 2.0 specification; Godot 4.7's import-hint page.
Anything carried from an upstream without a re-read here is marked **unverified**.

## FBX: the exporter's defaults are not game settings

| Option (Python) | Default in 5.2.3 | For a game engine |
|---|---|---|
| `add_leaf_bones` | `True` | `False` — otherwise every bone chain gains an `_end` bone in the engine's skeleton |
| `mesh_smooth_type` | `'OFF'` (normals only) | `'FACE'` — upstream measured Unreal 5.8.3 logging "No smoothing group information" with `OFF` (**unverified** here) |
| `use_armature_deform_only` | `False` | `True` for rigs with control or mechanism bones |
| `bake_anim`, `bake_anim_use_all_actions`, `bake_anim_use_nla_strips` | all `True` | `bake_anim=False` for a mesh-only file; for clips, decide all-actions vs NLA on purpose |
| `use_selection` | `False` (whole scene) | `True`, and know that it means "selected **and visible**": hidden objects are skipped |
| `apply_scale_options` | `'FBX_SCALE_NONE'` | see the factor-100 table below |
| `use_tspace` | `False` | "will only work correctly with tris/quads only meshes!" — triangulate (or quad) first, or the tangents are wrong |
| `bake_space_transform` (Apply Transform) | `False` | "experimental option, use at own risk, known to be broken with armatures/animations" — static meshes only |
| `use_triangles` | `False` | triangulate once, the same way for the normal-map bake and the export |

### Where the factor 100 goes at Unit Scale 1.0

Measured on 2026-10-30: a cube parented to an armature named `Armature`, exported from Blender 5.2.3 and the
FBX read back.

| Scene Unit Scale | `apply_scale_options` | FBX `UnitScaleFactor` | `Lcl Scaling` on the armature and mesh nodes |
|---|---|---|---|
| 1.0 (metres, the default) | `FBX_SCALE_NONE` (default) | 1 | **100** |
| 1.0 | `FBX_SCALE_UNITS` or `FBX_SCALE_ALL` | **100** | none |
| 0.01 (centimetres) | any of the three | 1 | none |

At Unit Scale 1.0 the factor 100 is always somewhere. The default hides it in the armature node, so sizes can
look right while the root bone carries scale 100 and sockets sit 100× out. Authoring at Unit Scale 0.01 is the
only setting that writes neither. How an engine applies `UnitScaleFactor` depends on its importer: upstream
measured Unreal 5.8.3's legacy importer, as driven by an MCP tool, ignoring it (meshes 100× small) and the editor
dialog honouring it — **unverified** here. Measure one test import before trusting either.

### Shape keys and Apply Modifiers

The `use_mesh_modifiers` tooltip says it "prevents exporting shape keys". Measured on 5.2.3, the rule is narrower:
a mesh whose only modifier is an Armature keeps its shape keys with the option on; one other modifier
(a Subdivision Surface in the test) drops **all** of them; with the option off they survive. Apply the
non-Armature modifiers before authoring shape keys, or export with `use_mesh_modifiers=False`. The glTF option
`export_apply` carries the same warning and defaults to `False` — the opposite default to FBX, so a glTF export
from the same scene ships the unmodified mesh unless you turn it on.

## Unreal (Epic's FBX Static Mesh Pipeline page)

- Collision meshes go in the same FBX as the render mesh, named `UBX_` (an undeformed box), `UCP_` (a capsule),
  `USP_` (a sphere) or `UCX_` (any closed convex shape), then `<RenderMeshName>_##`. "RenderMeshName must be
  identical to the name of the render mesh" — a typo imports the hull as visible geometry.
- "When importing multiple meshes with custom collision in a single file, only the first mesh's collision will be
  imported": one render mesh with custom collision per FBX.
- "The pivot point is always located at the origin (0,0,0)": the asset pivot is Blender's world origin, not the
  object origin. Move the asset to the origin before export.
- Sockets are empties named `SOCKET_<RenderMeshName>_##`; include `'EMPTY'` in `object_types`.
- Upstream measured on Unreal 5.8.3's legacy importer, **unverified** here: an armature object named exactly
  `Armature` is dropped and its first bone becomes the root; any other object name becomes an extra root bone, and
  an object `root` over a bone `root` imports as `root` + `root1`. Interchange was not tested.

## Unity: the packed map is not the glTF/Unreal ORM

- URP Lit reads one RGBA texture as **R = metallic, G = occlusion, B = unused, A = smoothness** (Smoothness Source
  "Metallic Alpha", the default), with sRGB off. An ORM texture packed for glTF or Unreal (R = occlusion,
  G = roughness, B = metallic) shows wrong metal, wrong gloss and no occlusion.
- HDRP's mask map is **R = metallic, G = ambient occlusion, B = detail mask, A = smoothness**.
- Unity's smoothness runs the other way to Blender's roughness (1 = a sharp highlight like glass); pack
  `1 − roughness` into alpha.

## glTF (Godot, three.js, Unity with glTFast)

- glTF reads metalness from **B** and roughness from **G** of `metallicRoughnessTexture`, occlusion from **R** of
  its texture — so one R = AO, G = roughness, B = metallic image serves both.
- `export_animation_mode='ACTIONS'` (the default) exports actions that are active or on NLA tracks. An action kept
  only by a fake user is not exported: push it onto an NLA track.
- Defaults that differ from the FBX exporter: `export_apply=False` (modifiers not applied), `export_leaf_bone=False`,
  `export_def_bones=False`, `export_extras=False` (custom properties are dropped unless you turn it on).

### Godot import hints (Godot 4.7 docs)

Suffixes on Blender object names change what Godot builds: `-col`, `-convcol`, `-colonly`, `-convcolonly`
(collision), `-rigid`, `-vehicle`, `-wheel`, `-navmesh`, `-occ`, `-occonly`, `-noimp` (skip), `-alpha`, `-vcol`,
and `loop`/`cycle` at the start or end of an animation name. "All the suffixes … can be used with `-`, `$`, and
`_` and are case-insensitive", so `Crate_col` and `crate-COL` both trigger — rename an object whose name merely
ends in one. `-noimp` is honoured even with `nodes/use_node_type_suffixes` off.
