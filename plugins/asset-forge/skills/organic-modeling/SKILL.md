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
2. `blockout.skin_from_skeleton(spec, name="SK_Wolf", subdivisions=1)` → manifold mesh. Ends stop about 13% of the
   end radius short of their end joints: extend end joints slightly.
3. Shape with `deform` (world-space centres and radii; `symmetry="X"` for bilateral creatures):
   - mass: `grab`, `inflate`, `flatten` (cheeks, belly, chest plate)
   - lines: `crease_along_curve` (muscle separations, wrinkles, cracks), `bulge_along_curve` (muscles, veins, roots)
   - breakup: `noise_displace` (bark, rock), then `smooth(iterations=2)` to settle
   - paths: `stroke(obj, path_points, "inflate", radius_profile, strength_profile)` for brush-like passes
4. Check every few ops: screenshot from front, side and 3/4. Undo by rerunning from a duplicate kept hidden.
5. Retopo for the budget: `retopo.quadriflow(obj, target_faces)` (manifold input only; it returns CANCELLED
   on a non-manifold mesh) or `retopo.decimate_to_budget(obj, target_tris)`.
6. Details that did not survive retopo come back as a normal map: keep the dense version as `high`, bake with
   the `bake_maps` tool (`low`=the retopo, `high`=the dense mesh).

Spec shape (quadruped, metres, Z up, facing -Y):

```python
spec = {"joints": {
    "hips": {"co": [0, 0.35, 0.75], "radius": 0.2}, "chest": {"co": [0, -0.35, 0.8], "radius": 0.24},
    "neck": {"co": [0, -0.6, 1.0], "radius": 0.13}, "head": {"co": [0, -0.8, 1.05], "radius": 0.15},
    "snout": {"co": [0, -1.02, 0.98], "radius": 0.07},
    "fl_knee": {"co": [0.15, -0.38, 0.4], "radius": 0.07}, "fl_paw": {"co": [0.15, -0.4, 0.04], "radius": 0.06},
    "bl_knee": {"co": [0.15, 0.4, 0.42], "radius": 0.08}, "bl_paw": {"co": [0.15, 0.45, 0.04], "radius": 0.06},
    "fr_knee": {"co": [-0.15, -0.38, 0.4], "radius": 0.07}, "fr_paw": {"co": [-0.15, -0.4, 0.04], "radius": 0.06},
    "br_knee": {"co": [-0.15, 0.4, 0.42], "radius": 0.08}, "br_paw": {"co": [-0.15, 0.45, 0.04], "radius": 0.06},
    "tail": {"co": [0, 0.75, 0.85], "radius": 0.05}},
  "bones": [["hips", "chest"], ["chest", "neck"], ["neck", "head"], ["head", "snout"], ["hips", "tail"],
            ["chest", "fl_knee"], ["fl_knee", "fl_paw"], ["hips", "bl_knee"], ["bl_knee", "bl_paw"],
            ["chest", "fr_knee"], ["fr_knee", "fr_paw"], ["hips", "br_knee"], ["br_knee", "br_paw"]]}
```

The spec lists both sides: the Skin modifier's own X symmetry does not add missing joints. Biped, tree and
rock-cluster specs: `references/recipes.md`.

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
