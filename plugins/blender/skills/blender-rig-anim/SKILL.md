---
name: blender-rig-anim
description: Use when rigging, skinning or animating in Blender for a game engine — armatures, Rigify, automatic weights, shape keys, actions, NLA, baking — or when a clip from an FBX/glTF export is missing, duplicated, on the wrong object or late in Unity, Unreal or Godot. Runs the export to see what shipped.
---

> Last verified: 2026-11-07 — https://docs.blender.org/api/5.2/bpy.ops.export_scene.html
<!-- version-tail-ok: Blender ships as a binary, not a package; every exporter fact here was probed in a local Blender 5.2.3 LTS on 2026-11-07 -->

Rig and clip faults reach the engine silently. Each exporter has rules about which bones,
weights, shape keys and actions it writes, and a from-memory answer gets them wrong. Read the
target Blender version first, as `blender-best-practices` says; the API removals for rigging
(bone layers, bone groups, `bake_action` keywords, `driver_add` modifiers) are in its checker.

## The rules, and who enforces each

| Rule | Standing |
|---|---|
| Every action that should ship does, once, on its own object, from frame 0 | **gate** where `anim_audit.py` runs (exit 1): it runs the real exporters and reads what they wrote |
| A looping clip's last frame matches its first | **gate** where `anim_audit.py --loop` runs |
| One root after FBX "Only Deform Bones", no B-Bones or dual-quaternion deform, every vertex weighted, no masked shape keys | **gate** where `rig_check.py` runs (exit 1) |
| A decimated or remeshed copy keeps its UV density | **gate** where `blender_qa.py --compare-uv SRC` runs |
| A headless bake keys visual transforms of every bone | **recorded** — `references/animation.md` |
| Engine-side import (Humanoid T-pose, retarget maps, root motion, import fps, compression) | **recorded**, owned by the engine plugins: `unity-traps`, `godot`, `unreal` |

Whether any script runs is **agent-graded**: nothing forces the call.

## Run the checks

```sh
blender -b char.blend --python-exit-code 2 --python "${CLAUDE_PLUGIN_ROOT}/scripts/anim_audit.py" -- \
  --expect Walk Run Idle --loop Walk Run [--format fbx|gltf|both] [--fbx bake_anim_use_all_actions=False] [--gltf export_anim_slide_to_zero=True] [--json]
blender -b char.blend --python-exit-code 2 --python "${CLAUDE_PLUGIN_ROOT}/scripts/rig_check.py" -- --armature Rig [--profile unity|unreal|roblox] [--limit 4]
blender -b asset.blend --python-exit-code 2 --python "${CLAUDE_PLUGIN_ROOT}/scripts/blender_qa.py" -- --objects SM_Rock_LOD1 --compare-uv SM_Rock
```

Pass the same `--fbx`/`--gltf` overrides the project exports with. `anim_audit.py` exports to a temp
dir (`--keep DIR` keeps the files) and judges what the files hold, not the settings: it reports
an action that did not ship, an FBX clip of one object's action written on another, a clip
shipped twice, a glTF clip that starts late, and a loop whose ends do not meet. Exit 0 pass,
1 findings, 2 could not run (an override the exporter refused, a missing armature).

## What a from-memory answer gets wrong

- **FBX "All Actions" is on by default** and writes every action whose paths resolve on an
  object onto that object: three actions on three empties became nine clips. Turning it off is
  not enough: with All Actions off, FBX writes NLA-track strips only, so an action that is
  merely active ships nowhere. Push each clip onto its object's NLA track, then export with
  `bake_anim_use_all_actions=False`. → `references/animation.md`
- **One stale F-curve drops the whole action from FBX** (a bone renamed after keying), with nothing logged.
- **glTF counts time from frame 0.** A clip keyed at 101–124 plays from 4.21 s. Use `export_anim_slide_to_zero=True`.
- **`bpy.ops.nla.bake` defaults to `only_selected=True, visual_keying=False`.** A headless bake of
  an IK rig keys only the selected bones and drops the constraint result.
- **Rigify with "Only Deform Bones" still exports two roots** (`root`, `MCH-torso.parent`) and every
  non-deform parent of a DEF bone: 278 bones from a human rig with 160 DEF. → `references/rigging.md`
- **Neither exporter writes B-Bones, Preserve Volume or Bone Envelopes**: engines skin with
  vertex groups and linear blending, so the export bends differently from Blender.
- **Automatic weights report FINISHED when they fail**, stop at the failing bone, and on a tiny
  mesh can fail with no warning at all. Check the weights, not the operator's return.
- **A shape key's vertex-group mask is dropped on export**: split L/R correctives ship as whole-face shapes.

## Anti-patterns

- **Trusting the export dialog.** The settings say what was asked; `anim_audit.py` says what shipped.
- **Fixing a cross-assigned clip in the engine.** Delete-on-import hides it until the next export; fix the NLA.
- **Exporting the Rigify control rig to a game.** Export a deform skeleton with one root.
- **Decimating an AI-generated mesh without `--compare-uv`.** Fragmented atlases collapse first.
