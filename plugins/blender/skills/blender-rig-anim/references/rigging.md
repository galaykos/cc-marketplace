# Rigging and skinning for a game export

> Last verified: 2026-11-07 — https://docs.blender.org/api/5.2/bpy.ops.export_scene.html and probes in Blender 5.2.3 LTS
<!-- version-tail-ok: Blender ships as a binary; facts marked "probed" were run headless with --factory-startup -->

Each row says what breaks, how it was established, and the fix. `rig_check.py` catches the rows marked **(rig_check)**.

## Bones

- **"Only Deform Bones" keeps non-deform parents (rig_check).** The FBX option keeps "non-deforming ones when they
  have deforming children". A Rigify human rig (full human metarig, `pose.rigify_generate`) exported with
  `use_armature_deform_only=True, add_leaf_bones=False` writes 278 bones for 160 DEF bones, under two roots,
  `root` and `MCH-torso.parent` (probed; `rig_check.py`'s model of the filter matched the exporter's bone set
  exactly). Engines expect one root, and Unity Humanoid and Unreal's retargeter map the wrong hierarchy. Fix: export
  a separate deform skeleton with one root that follows the DEF bones (Copy Transforms), and bake onto it.
- **B-Bones are not exported (rig_check).** 22 of Rigify's 35 DEF bones in the basic human use B-Bone segments
  (research probe). Neither `io_scene_fbx` nor the glTF exporter references B-Bone data (source read, 5.2 branch), so
  engines deform those bones as straight segments. Fix: set `bbone_segments = 1` on deform bones, or add real
  twist bones.
- **glTF `export_def_bones` re-parents; FBX does not.** glTF reparents each kept bone to its nearest kept ancestor
  (`io_scene_gltf2/blender/exp/tree.py`), FBX keeps the non-deform parents, so one scene gives two skeletons.
- **Bone collections, not layers (4.0).** `bone.layers`, `armature.layers`, `pose.bone_groups` and
  `pose_bone.bone_group` are gone ("Layers and bone groups have been removed",
  https://developer.blender.org/docs/release_notes/4.0/python_api/). `armature.collections` iterates and indexes
  **root** collections only since 4.1; a nested one is `armature.collections_all["Name"]`
  (https://developer.blender.org/docs/release_notes/4.1/animation_rigging/).
- **`bones[n].hide` is edit-bone visibility since 5.0.** Object and Pose mode read `ob.pose.bones[n].hide`;
  old code runs without error and hides nothing (probed).
- **Constraints and IK on deform bones do not export as constraints.** FBX bakes the evaluated pose when it bakes
  animation; glTF samples pose bones by default (`export_force_sampling=True`), but an object animated only by a
  constraint, with no action of its own, needs `export_bake_animation=True`.

## Weights

- **Automatic weights fail silently (rig_check).** `parent_set(type='ARMATURE_AUTO')` returns `{'FINISHED'}` after
  "Bone Heat Weighting: failed to find solution for one or more bones", and stops at the failing bone: a mesh with
  one loose far piece kept 904 of 904 verts unweighted. On a tiny-scale mesh 2 of 3 bones got no weights and no
  warning was printed (research probes, 5.2.3; source `editors/armature/meshlaplacian.cc`). Fix: check weights, scale
  the mesh to real size, join or remove loose parts, then weight again.
- **Unweighted verts add a joint in glTF.** The exporter adds a `neutral_bone` to the skin for them
  (`io_scene_gltf2/blender/exp/tree.py`).
- **Four influences.** glTF keeps the 4 highest weights (`export_influence_nb=4`) and renormalises with only a log
  line; Unity's default rig quality is 4 bones. `rig_check.py --limit` and `blender_qa.py` report verts over it.
- **Preserve Volume and Bone Envelopes do not export (rig_check).** glTF defines linear blend skinning; the FBX
  exporter binds through vertex groups only ("We only support vertex groups binding method, not bone envelopes
  one!", `io_scene_fbx/export_fbx_bin.py`).

## Shape keys

- **A vertex-group mask is dropped (rig_check).** Both exporters read the raw key positions: with a mask, Blender
  moved 10 of 25 verts; the glTF morph target and an FBX round trip moved 25 of 25 (research probe, 5.2.3). Fix: bake
  each masked key into a new key (New Shape from Mix with only that key on) and export that.
- **Relative keys differ by format (rig_check, warning).** glTF writes every morph against the Basis and skips
  muted keys; FBX writes each key against its own `relative_key`.

Route engine-side setup elsewhere: Unity Humanoid avatar and T-pose → `unity-traps`; Godot BoneMap and
`SkeletonProfileHumanoid` → `godot`; Unreal IK Retargeter and root motion → `unreal`.
