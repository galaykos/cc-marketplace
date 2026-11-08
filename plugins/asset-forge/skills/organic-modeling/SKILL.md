---
name: organic-modeling
description: Use when modeling an organic shape in Blender for a game (creature, character body, head, tree, roots, rock or cliff), picking a skin or metaball blockout refined with forge deforms, a Meshy model cleaned and rebaked onto clean low-poly, or both.
disable-model-invocation: true
---

# Organic modelling with forge

All of this runs **live** through `execute_blender_code`, after the forge import snippet in
`${CLAUDE_PLUGIN_ROOT}/skills/pipeline/SKILL.md` §3. Review after the blockout (silhouette first) before any detail.

## Pick the route

| Situation | Route |
|---|---|
| Stylized creature or character, the user wants control of proportions | **A**: skeleton blockout + deform strokes |
| Rocks, cliffs, roots, tree trunks | **A** with `blockout.rock` / `bulge_along_curve` + `noise_displace` |
| Realistic or very detailed creature, the user accepts credit spend | **B**: Meshy generate → clean → retopo → rebake |
| A Meshy base whose proportions or silhouette need correcting | **C**: B, then deform strokes on the clean mesh before the bake |

## A. Skeleton blockout, then sculpt by vertex math

1. Proportions from `references/proportions.md`, in metres. Write the skeleton spec: joints with radii, bones as pairs.
2. Every feature that must read in silhouette is a **skeleton branch**, not a deform: ears, tail, muzzle, elbows,
   hocks, paws. Measured on the wolf stress test: a `grab` for an ear on the coarse skin moved 4 vertices and
   nothing showed; the same ear as a branch read in every view.
3. `blockout.skin_from_skeleton(spec, name="SK_Wolf", subdivisions=2)`, then fuse:
   `retopo.voxel_remesh(obj, voxel_size=0.015)` and `deform.smooth(obj, iterations=2)`. Ends stop about 13% of
   the end radius short of their end joints: extend end joints slightly. Never put an extra joint between two torso
   joints (a "hump" between hips and chest): the Skin hull folds there and the fold survives remeshing as a
   visible plate. Make humps with `deform.grab` after fusing.
4. Shape with `deform` (world-space centres and radii; `symmetry="X"` for bilateral creatures):
   - mass: `grab`, `inflate`, `flatten` (cheeks, belly, chest plate, shoulder hump)
   - lines: `crease_along_curve` (muscle separations, wrinkles, cracks), `bulge_along_curve` (muscles, veins, roots)
   - breakup: `noise_displace` (bark, rock), then `smooth(iterations=2)` to settle
   - paths: `stroke(obj, path_points, "inflate", radius_profile, strength_profile)` for brush-like passes
5. Review (silhouette first) before any detail; screenshot front, side and 3/4 between passes.
6. Retopo for the budget: `retopo.decimate_to_budget(obj, target_tris)`, or `retopo.quadriflow(obj, target_faces)`
   (manifold input only; it returns CANCELLED on a non-manifold mesh).
7. Details that did not survive retopo come back as a normal map: keep the dense version as `high`, bake with
   the `bake_maps` tool (`low`=the retopo, `high`=the dense mesh).

Spec (stylized wolf, about 1.2 m to the ear tips and 1.65 m nose to tail; metres, Z up, facing -Y). This is the
second-round spec of the stress test; its review still asked for a level topline and thicker legs, so treat it as a
start, not a finished design:

```python
J = {"hips": ((0, 0.28, 0.82), 0.16), "chest": ((0, -0.26, 0.86), 0.21), "neck": ((0, -0.46, 0.98), 0.12),
     "skull": ((0, -0.6, 1.04), 0.13), "brow": ((0, -0.7, 1.04), 0.09), "muzzle": ((0, -0.84, 0.99), 0.055),
     "ear_l": ((0.07, -0.58, 1.27), 0.015), "ear_r": ((-0.07, -0.58, 1.27), 0.015),
     "tail_base": ((0, 0.46, 0.84), 0.06), "tail_mid": ((0, 0.64, 0.74), 0.09), "tail_tip": ((0, 0.8, 0.6), 0.03)}
for s, x in (("l", 0.13), ("r", -0.13)):
    J.update({f"f{s}_elbow": ((x, -0.3, 0.52), 0.075), f"f{s}_wrist": ((x, -0.32, 0.13), 0.045),
              f"f{s}_paw": ((x, -0.4, 0.045), 0.06), f"b{s}_knee": ((x, 0.24, 0.55), 0.1),
              f"b{s}_hock": ((x, 0.42, 0.25), 0.05), f"b{s}_paw": ((x, 0.36, 0.045), 0.06)})
bones = [["hips", "chest"], ["chest", "neck"], ["neck", "skull"], ["skull", "brow"], ["brow", "muzzle"],
         ["skull", "ear_l"], ["skull", "ear_r"], ["hips", "tail_base"], ["tail_base", "tail_mid"], ["tail_mid", "tail_tip"]]
for s in "lr":
    bones += [["chest", f"f{s}_elbow"], [f"f{s}_elbow", f"f{s}_wrist"], [f"f{s}_wrist", f"f{s}_paw"],
              ["hips", f"b{s}_knee"], [f"b{s}_knee", f"b{s}_hock"], [f"b{s}_hock", f"b{s}_paw"]]
spec = {"joints": {k: {"co": list(c), "radius": r} for k, (c, r) in J.items()}, "bones": bones}
```

Biped, tree and rock-cluster specs: `references/recipes.md`.

## B. Meshy generate → clean → retopo → rebake

Read `meshy:meshy-generation` (installed with the `meshy` plugin) before any call: credits are spent per task, a
timed-out create may already be charged, files expire after 3 days. Then:

1. Generate with the Meshy MCP (`…meshy_text_to_3d` or `…meshy_image_to_3d`; for a game asset choose smart
   topology — `meshy-t2.5` with `target_polycount` — over a dense model remeshed down). Confirm the cost first.
2. Download GLB; import live with `bpy.ops.import_scene.gltf(filepath=…)`.
3. `retopo.clean_ai_mesh(obj)`: merges doubles, drops specks and loose geometry, fills small holes, fixes normals,
   applies transforms, re-origins to the bottom centre. Read its before/after counts.
4. Dense result → keep it as `high`; make the game mesh with `decimate_to_budget` or `quadriflow`, UV it, and bake
   normal (+ AO) from `high` with the `bake_maps` tool. Meshy's own UVs are not reused.

## C. Hybrid

B steps 1–3, then route A step 3 on the cleaned mesh (mass and silhouette fixes only), then B step 4.

## Rules

- Sizes in real metres; check against a 1.8 m human for every creature. Standing: recorded.
- Branch limbs from torso joints: a hip or shoulder joint inside the torso's radius makes a non-manifold skin.
  `skin_from_skeleton` reports `manifold`; a False there must be fixed before retopo. Standing: recorded.
- Silhouette before surface: no crease or noise until the review's silhouette tiles read correctly.
- Deform refuses meshes with shape keys and shared meshes: add shape keys after sculpting; make single-user first.

## Limitations

- Deform ops are vertex math with a falloff, not ZBrush: no dynamic topology, no clay build-up. Fine detail
  needs a dense mesh (subdivide first) and a bake.
- `experimental_brush_stroke` needs a UI and is refused headless; in a live session it uses whichever sculpt brush
  is active.
- QuadriFlow edge flow is automatic; deforming joints (shoulders, hips) may need manual loops for good bends.
- Skin-modifier blockouts are tubular: hands, ears and faces need deform passes or separate parts.
