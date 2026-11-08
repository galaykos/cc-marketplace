---
name: animation-retarget
description: Use when putting a motion made for another skeleton onto a game rig in Blender (a Mixamo FBX the user downloaded, Meshy text-to-motion or animate, BVH mocap), with bone maps, rest-pose offsets, bake, loop cleanup, in-place vs root motion and clip naming per engine.
disable-model-invocation: true
---

# Retargeting motion onto the project's rig

Runs **live** (forge import snippet: `${CLAUDE_PLUGIN_ROOT}/skills/pipeline/SKILL.md` §3). Rigging, skinning and
clips that go missing on export stay with `blender:blender-rig-anim` and its `anim_audit.py`.

## Sources

| Source | How it arrives | Notes |
|---|---|---|
| Mixamo | The **user** downloads the FBX (FBX Binary, "Without Skin" for clips) — never automate their login | Imports at 0.01 object scale with `mixamorig:` names |
| Meshy | `…meshy_rig` (5 credits, includes a walk and a run) then `…meshy_animate` for more clips, through the Meshy MCP; confirm credits first | Meshy rigs only textured humanoids. Bone map `meshy_to_rigify` (names read from a real Meshy rig, 2026-11-08); its glTF imports at 0.01 object scale, which retarget handles in world space |
| BVH mocap | `bpy.ops.import_anim.bvh(filepath=…)` | Name maps vary by library; write a bone map |

## Steps

1. Import the source; note its armature object and action. Apply the target rig's object transforms first.
2. Bone map: `presets/bonemaps/mixamo_to_rigify.json`, `mixamo_to_ue5.json`, or a dict of the same shape
   (`{"source", "target", "root": {"source", "target"}, "bones": {src: tgt}}`). Check it with
   `retarget.load_bonemap(...)`; a doubled or missing target is refused.
3. `retarget.retarget(source_rig, target_rig, bonemap, action=None, frame_range=None)` → a baked action on the
   target. Rest-pose differences (T-pose source, A-pose target) and bone rolls are compensated. Read its
   `skipped`, `unmapped_*` and `warnings`.
4. Locomotion per engine:
   - in place: `retarget.make_in_place(action, root_bone)` (keeps vertical bob);
   - root motion: `retarget.extract_root_motion(rig, action, hips_bone, root_bone, create=True)`.
   Unity and Unreal take either (Animator "Apply Root Motion" / per-sequence Root Motion); Godot uses a root
   motion track in the AnimationTree. Ask which the game uses.
5. `retarget.loop_cleanup(action, blend_frames=2, travel_bones=(root_bone,) if root motion else ())` for cycles.
6. `retarget.trim(action, start, end)` → starts at frame 0 (glTF time is frame / fps; a clip starting late in an
   engine is this).
7. `retarget.push_to_nla(rig, action, engine=..., asset=..., clip=...)` names it per the preset (`{asset}@{clip}`
   for Unity, `A_{asset}_{clip}` for Unreal, Godot `-loop` suffix on cycled clips). The FBX presets export NLA strips
   only (`bake_anim_use_all_actions: False`): with Blender's defaults the stress test shipped its clip twice and
   leaked the source rig's action. Delete or unlink the imported source rig before export anyway.
8. Export with `export_asset(..., clips=["<asset>@<clip>", ...])`: the post-export audit then fails unless exactly
   those clips shipped.
9. Screenshot frames 0, ¼, ½ of the cycle from the side; `blender`'s `anim_audit.py` on a snapshot cross-checks
   FBX and glTF clip timing and loops.

## Rules

- Retarget onto bones that carry keys. Rigify's `DEF-` bones are driven by constraints from the `ORG`/`MCH`
  chain, so keys baked onto them are overridden at evaluation (`retarget` warns): target the control rig, or a
  separate deform skeleton exported on its own. Standing: recorded; `retarget` warns.
- Mechanical props: a simple armature with one bone per moving part, rigid-weighted; no retarget needed.
- Humanoids without a rig: Meshy auto-rig (textured humanoid only) or Rigify (`pose.rigify_generate` on a
  metarig), then weights (check them: automatic weights can fail silently, see `blender-rig-anim`).

## Limitations

- Hips travel is copied in metres, not scaled by hip height: a rig with different leg length slides its feet.
- Measured on the stress test: Meshy's walk retargeted onto a Rigify-named A-pose rig matched the source's thigh,
  shin, upper-arm and chest directions to 0.0° at four frames; Meshy's walk is already in place and loops.
- Mixamo bone names in the shipped maps are not yet checked against a real Mixamo download; `mixamo_to_ue5`'s
  `spine_04`, `spine_05` and `neck_02` are unverified. Missing pairs are skipped and listed, not errors.
- Quality depends on rest-pose match: fingers and toes with different counts or rolls need hand fixes.
- Armatures with object-level rotation or 0.01 scale (raw FBX imports) are untested: apply transforms first.
