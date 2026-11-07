# Actions, NLA, baking and clip export

> Last verified: 2026-11-07 — https://docs.blender.org/api/5.2/bpy.ops.export_scene.html and probes in Blender 5.2.3 LTS
<!-- version-tail-ok: Blender ships as a binary; facts marked "probed" were run headless with --factory-startup -->

`anim_audit.py` catches the rows marked **(anim_audit)** by exporting and reading the files.

## FBX clips

- **All Actions writes actions onto objects that never use them (anim_audit).** `bake_anim_use_all_actions`
  (default on) writes every action whose F-curve paths all resolve on an object as a take named `Object|Action`.
  Three empties with one location action each exported nine takes: `Hero|CrateSlide`, `Crate|Walk` and the rest
  (probed). Engines import them as extra clips.
- **Turning All Actions off drops active-only actions (anim_audit).** With it off and `bake_anim_use_nla_strips` on
  (the default), FBX writes NLA-track strips only, named by the strip; an action that is only the object's active
  action is not written. With both off, FBX writes one take named after the scene, covering the whole timeline
  (probed). The working setup: each clip a strip on its own object's NLA track, `bake_anim_use_all_actions=False`.
- **Both on duplicates NLA clips (anim_audit).** A strip ships as `Walk` and again as `Hero|Walk` (probed).
- **One stale path drops the action (anim_audit).** All Actions skips an action unless every F-curve path resolves
  ("*all* paths in the action must be valid", `io_scene_fbx/export_fbx_bin.py`); a bone renamed after keying is
  enough, and nothing is logged (research probe).

## glTF clips

- **Time counts from frame 0 (anim_audit).** glTF time is frame / fps: a clip keyed at 101–124 at 24 fps exported
  at 4.21–5.17 s (probed). `export_anim_slide_to_zero=True` starts each clip at 0; FBX All Actions slides to zero itself.
- **Fake-user actions do not ship (anim_audit).** The default `export_animation_mode='ACTIONS'` exports active and
  NLA-track actions; one kept only by a fake user is skipped.
- **NLA tracks merge by action since 4.4.** "Before Blender 4.4, tracks were merged regarding their name … Now,
  tracks are merged by the action they are using" (https://docs.blender.org/manual/en/5.2/addons/scene_gltf2.html);
  `export_merge_animation` defaults to `'ACTION'`. Old advice to give tracks the same name needs `'NLA_TRACK'`.
- **Frame rate.** Scenes default to 24 fps (probed); a clip authored "at 30" in a 24 fps scene plays 25% slower in
  the engine. `anim_audit.py` prints the scene fps.

## Baking

- **`bpy.ops.nla.bake` defaults to `only_selected=True` and `visual_keying=False`** (probed, RNA defaults in 5.2.3;
  https://docs.blender.org/api/5.2/bpy.ops.nla.html). A headless bake of an IK or constraint rig with the defaults
  keys only the selected bones and drops the constraint result, and it bakes frames 1–250 (`frame_start`,
  `frame_end` defaults), not the action's range. Pass `only_selected=False, visual_keying=True, bake_types={'POSE'}`
  and the clip's frame range.
- **`anim_utils.bake_action` takes `bake_options` since 4.1.** The signature is
  `bake_action(obj, *, action, frames, bake_options)` with a `BakeOptions` of 12 required fields; the 4.0 keywords
  (`only_selected=…`) raise `TypeError` (probed; `check_bpy_scripts.py` rule `bake-action-kwargs`).
- **`driver_add()` adds no F-modifier since 5.0** (probed; it adds two keyframes), so the old
  `fc.modifiers.remove(fc.modifiers[0])` raises `IndexError` (checker rule `driver-fmodifier`).
- **An NLA strip picks the first compatible slot (4.4).** Assigning `strip.action` auto-assigns the first slot whose
  `target_id_type` fits; a multi-slot action (the glTF importer makes one for transforms and one for shape keys) can
  animate with the wrong slot. Set `strip.action_slot`
  (https://developer.blender.org/docs/release_notes/4.4/python_api/).

## Loops

A looping clip whose last frame differs from its first pops on every cycle. `anim_audit.py --loop NAME` compares
the evaluated pose at the action's first and last frame (location in metres, rotation in radians, `--tol`). It
checks only an action that is some object's active action. Whether an engine drops a duplicated last frame on
import is not verified here.
