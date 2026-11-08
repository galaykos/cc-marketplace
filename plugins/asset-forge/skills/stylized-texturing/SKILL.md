---
name: stylized-texturing
description: Use when texturing a game asset in Blender in a stylized or hand-painted look (wood, stone, metal, cloth, foliage), choosing a procedural bake that needs no AI service, or Meshy-generated images projected and rebaked onto the asset's own UVs.
disable-model-invocation: true
---

# Stylized texturing

Needs a clean UV map first (pipeline step 6). Baking and projection run **headless** on a snapshot through the
forge tools; assigning the result runs **live**. Snapshot and import snippets:
`${CLAUDE_PLUGIN_ROOT}/skills/pipeline/SKILL.md` §3–4.

## Pick a tier

| | Tier 1: procedural | Tier 2: AI images projected |
|---|---|---|
| Needs | Nothing external | The Meshy MCP server and credits (confirm the cost first) |
| Good for | Props, rocks, architecture, anything whose read comes from form | Painted detail the form does not carry: faces, emblems, cloth patterns, signage |
| Consistency | Deterministic, matches across a set | View-to-view drift; seams where views meet |
| Default | **yes** | only when the user asks or Tier 1 cannot carry the design |

## Tier 1: procedural hand-painted albedo

1. Snapshot. Pick a recipe: `wood`, `stone`, `metal`, `cloth`, `foliage`. Palette from `asset-forge.json`
   `style.palette` (sRGB 0–1, `base` colours cycle over material slots, so give each part its own slot first).
2. `stylize_texture` tool: `{blend_path, object, recipe, palette, resolution}`. It bakes AO and curvature itself,
   or reuses `maps` from an earlier `bake_maps`. Look at the albedo it returns inline.
3. Live: `from forge import stylize; result = stylize.apply_albedo("SM_Chest", "<albedo path>")`.
4. Screenshot in Material Preview, then the full review.

What the albedo contains, so the critique can name the knob: top light from world +Z (`top_light`), AO shading
that shifts hue toward `shadow` instead of greying (`ao_strength`), edge highlights from convex curvature
(`edge_strength`), cavity tint (`cavity_strength`), brush-stroke noise stretched along the longest axis
(`noise_strength`, `noise_scale`, `stroke_stretch`). Tune by passing a different `palette`, or a different recipe.

| Recipe | Base | Shadow | Edges |
|---|---|---|---|
| wood | warm browns | violet | soft |
| stone | grey, cool and warm | blue-violet | medium, strong cavities |
| metal | blue-grey | deep blue | strongest |
| cloth | muted red, teal, tan | violet | weak, long strokes |
| foliage | greens | blue-green | weak |

## Tier 2: Meshy images projected onto your UVs

1. Snapshot. `texture_views` tool: `{blend_path, object, views: ["front","back","left","right","top"], resolution}`.
   It returns per-camera normal, depth and AO guides and `views_blend` (a copy that keeps the cameras).
2. For each camera, generate one image with the same framing: the Meshy MCP's `…meshy_image_to_image` with the
   camera's **normal** guide as the reference (`reference_file_paths`, `remove_background: true`) and the style
   prompt from `asset-forge.json`, asking for the same silhouettes and framing, flat unlit colour. The AO guide is
   near-white on transparent and makes a poor reference. Download each to a local PNG (`save_to`) and look at it:
   the generator can add or drop shapes (the rock test's front view gained a rock that is not in the mesh).
3. `project_texture` tool: `{blend_path: views_blend, object, view_images: {camera: png}, resolution, seam_blend}`.
   `seam_blend` 0 takes only the best-facing view per texel; 0.2 cross-fades views within about 0.2 facing ratio.
4. Live: `stylize.apply_albedo(obj, "<projected path>", material_name="M_<name>")`.

Meshy's own retexture (`…meshy_retexture`) is an alternative for a whole model, but its UVs are its own: bake its
result onto your UVs (import it as `high`, `bake_maps` with an emission setup) instead of shipping its layout.

## Seam checklist (review every Tier 2 result)

- Edges where two views meet: colour or pattern jumps → raise `seam_blend`, or regenerate the weaker view.
- Undersides and deep cavities no view saw: filled from the nearest seen texel, possibly from another island →
  add a `bottom` view or paint those regions flat.
- Lighting painted into the generated images: baked in for good; ask the generator for flat, unlit colour.
- The same feature drawn differently in two views (an emblem twice) → regenerate one with the other as reference.

## Limitations

- Normal maps from `bake_maps` are OpenGL (+Y); Unreal expects DirectX: flip green on import.
- The first GPU (OptiX) bake on a machine can stall about a minute compiling kernels; later bakes take under a second.
- Projection blends in the images' sRGB encoding, not linear light; slight darkening at cross-fades.
- Tier 1 is one albedo: no roughness, metal or emission maps are painted; the material gets one roughness value.
- On the rock stress test, Tier 1 `stone` rendered almost flat grey at review distance; pass a palette with more
  value spread between `base` colours, or raise `top_light`, for stone.
- Two Tier-2 views saw 41% of the rock cluster's texels; the other 59% were filled from the nearest seen texel and
  show as smeared patches on the back. Use at least front, back, left, right and top for an asset seen all round.
- Tier 1 paints light, shade and edges, not motifs. On the treasure-chest test the independent reviewer scored
  surface detail 2/5: no plank seams, grain strokes, rivets or keyhole. Model those as geometry (a plank seam is a
  cut edge, a rivet a small box), or paint them with Tier 2. A material split per part (wood, iron, brass, each its
  own slot before stylizing) is what separates the values.
