# Blender Python: what raises on 5.x

> Last verified: 2026-10-30 — https://developer.blender.org/docs/release_notes/5.2/python_api/

Only changes where the answer a model gives from 2023–2025 code now raises or silently does nothing. Not an
API tour. Sources re-read on 2026-10-30: the Python API release notes for 4.0, 4.1, 4.2, 4.4, 5.0, 5.1 and 5.2,
the 5.0 core and compatibility notes, and Blender's `blo_core_blend_header.cc`. Every "gone" below was also
probed in a Blender 5.2.3 LTS binary (`scripts/__tests__/test_rules_in_blender.py`, run with `BLENDER_EXE`).
`check_bpy_scripts.py` carries the rule id after each item.

## Animation (5.0)

- `Action.fcurves`, `Action.groups` and `Action.id_root` are gone (4.4 marked them legacy, 5.0 removed them).
  F-curves live in a channelbag per slot:

  ```python
  from bpy_extras import anim_utils
  ad = ob.animation_data
  cb = anim_utils.action_ensure_channelbag_for_slot(ad.action, ad.action_slot)   # or action_get_... to read
  fc = cb.fcurves.ensure("location", index=0, group_name="Object Transforms")      # action_group= is now group_name=
  ```

  `[action-fcurves]` `[action-id-root]`. The ID type an action animates is `action_slot.target_id_type`.
- Assigning `animation_data.action` may not pick a slot: a fresh `actions.new()` leaves `action_slot` `None` (probed). If it is `None`,
  assign one (`act.slots.new(id_type="OBJECT", name=ob.name)`). `ob.keyframe_insert(...)` still creates action,
  slot and channelbag for you.
- `context.space_data.action` is gone: `context.active_action` `[space-action]`.
- `Bone.select`, `select_head`, `select_tail` are gone: `pose_bone.select`, or `edit_bone.select*` in Edit Mode `[bone-select]`.

## Compositor and rendering (5.0)

- `scene.node_tree` is gone; `scene.use_nodes` is deprecated and always `True`. The tree is a node group:
  `scene.compositing_node_group = bpy.data.node_groups.new("Comp", "CompositorNodeTree")` `[scene-node-tree]`.
  There is no Composite node: the group's `NodeGroupOutput` is the image, so give the group an output socket with
  `tree.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")`.
- File Output node: `base_path`, `file_slots`, `layer_slots` are gone; use `directory`, `file_name`,
  `file_output_items` `[file-output-slots]`. Several compositor nodes became shader nodes (`CompositorNodeGamma` →
  `ShaderNodeGamma`), and the compositing Color output socket is `"Color"`, not `"RGBA"`.
- The EEVEE engine id is `BLENDER_EEVEE` again; `BLENDER_EEVEE_NEXT` raises `TypeError` `[eevee-next]`.
  4.2–4.5 accept only `BLENDER_EEVEE_NEXT` `[eevee-4x]`.
- Render passes were renamed (`Z` → `Depth`, `IndexMA` → `Material Index`); match by the new names.
- `image_settings.media_type` (`IMAGE`, `MULTI_LAYER_IMAGE`, `VIDEO`) must be set **before** `file_format`:
  with `media_type = "IMAGE"`, `file_format = "FFMPEG"` raises `TypeError`. Probed on 5.2.3.
- `scene.eevee.use_gtao`, `gtao_distance`, `gtao_quality` are gone: `view_layer.eevee.ambient_occlusion_distance` `[eevee-gtao]`.
- `material.use_nodes` and `world.use_nodes` are deprecated no-ops (removal planned for 6.0): a new material
  already has a Principled BSDF and a Material Output `[use-nodes-noop]`.

## Python, properties, drawing (5.0–5.2)

- Dict access to add-on property groups is gone: `scene["cycles"]` is a `KeyError`; use `scene.cycles`. Reset with
  `ob.property_unset("cycles")`, not `del ob["cycles"]` `[idprop-addon-settings]`.
- `bgl` is gone; so are `Image.bindcode` and shaders built from raw GLSL source. Draw with `gpu`,
  `gpu_extras.batch`, `gpu.texture.from_image(image)` `[bgl]` `[image-bindcode]`.
- Several bundled modules became private in 5.0 (`rna_info`, `bl_ui_utils`, `bpy_restrict_state`, …); do not import them.
- 5.1 bundles Python 3.13. A wheel or compiled module built for the 3.11 of 4.x does not load.
- 5.2: a Geometry Nodes modifier no longer takes ID properties. `mod["Socket_2"] = 1.0` raises `TypeError`
  (probed). Use the RNA proxy, and look the identifier up instead of assuming its number:

  ```python
  ident = next(i.identifier for i in ng.interface.items_tree if i.item_type == "SOCKET" and i.in_out == "INPUT" and i.name == "Scale")
  getattr(mod.properties.inputs, ident).value = 2.0          # .type = "ATTRIBUTE"; .attribute_name = "mask"
  ```

  `[gn-socket-key]` `[too-new-gn-properties]`. 5.2 also changed the socket identifiers of the Compare and Random
  Value nodes: link those by socket name.
- 5.2: `PreferencesFilePaths.active_asset_library` no longer indexes `asset_libraries` — "All Libraries" and
  "Essentials" take the first two indices. `UILayout.template_palette` lost `color` `[template-palette-color]`.

## Brushes and sculpt settings

- 5.0: `brush.sculpt_tool` → `brush.sculpt_brush_type` `[sculpt-tool]`.
- 5.1: `use_airbrush`, `use_anchor`, `use_space`, `use_line`, `use_curve`, `use_restore_mesh` are one enum,
  `brush.stroke_method` (`AIRBRUSH`, `ANCHORED`, `SPACE`, `LINE`, `CURVE`, `DRAG_DOT`) `[brush-stroke-flags]`.
- 5.2: brush and paint automasking moved to `.mesh_automasking_settings`; factor names lose the prefix
  (`automasking_cavity_factor` → `mesh_automasking_settings.cavity_factor`) `[automasking]`.
- Sculpt Mode operators need a 3D View; under `-b` use modifiers (Remesh, Multires, Displace) on the data instead.
  Upstream reports they crash headless; not re-run here.

## Still emitted from memory: the 4.x removals

Old enough that most models know them, short enough to keep: the checker reports each.

| Removed | Use | Since |
|---|---|---|
| `bpy.ops.x.y(override_dict, ...)` | `with bpy.context.temp_override(object=ob, ...): bpy.ops.x.y(...)` `[ops-context-dict]` | 4.0 |
| `node_group.inputs.new(...)` | `node_group.interface.new_socket(name, in_out="INPUT", socket_type="NodeSocketFloat")` `[node-group-sockets]` | 4.0 |
| Principled `Subsurface`, `Specular`, `Transmission`, `Coat`, `Sheen`, `Emission` | `… Weight`, `Specular IOR Level`, `Emission Color` | 4.0 |
| `mesh.use_auto_smooth`, `auto_smooth_angle` | Smooth by Angle: `bpy.ops.object.shade_auto_smooth(angle=…)` adds the modifier; the `sharp_edge` attribute `[auto-smooth]` | 4.1 |
| `calc_normals_split()` | `mesh.corner_normals` `[normals-split]` | 4.1 |
| `material.blend_method` | `material.surface_render_method` = `DITHERED` or `BLENDED`; `blend_method` still exists in 5.2.3, which the 4.2 notes call "deprecated or aliased" `[blend-method]` | 4.2 |
| `bl_info` in an add-on | `blender_manifest.toml` extension; `bl_info` add-ons still load as legacy | 4.2 |

## Footguns that are not version changes

- **Node names are translated.** With a non-English UI, new data gets translated names (`use_translate_new_dataname`
  defaults on). Probed on 5.2.3 in French: the default Principled node is named `BSDF guidée`, and
  `nodes["Principled BSDF"]` is a `KeyError`. Find nodes by `n.type == "BSDF_PRINCIPLED"`; socket names are not
  translated.
- **Freed references.** Applying or removing a modifier, object or data-block frees it; a Python reference held from
  before points at freed memory. Collect names first and look items up again.
- **Evaluated data.** Read modifier results through `ob.evaluated_get(depsgraph)` and call `to_mesh_clear()` after
  `to_mesh()`. Geometry Nodes instances are not in that mesh: probed on 5.2.3, ten instanced cubes gave
  `to_mesh()` 0 vertices and 10 entries in `depsgraph.object_instances`. Realize them, or iterate the instances.
