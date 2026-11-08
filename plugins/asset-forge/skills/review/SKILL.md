---
name: review
description: Use when a game asset in Blender needs judging (after a blockout, after texturing, before export, or when asked whether it reads well), with turntable, silhouette, game-distance, wireframe and UV-checker renders of a snapshot plus validation, critiqued by an independent art reviewer.
disable-model-invocation: true
---

# Review an asset

`/asset-forge:review [object]`. Also read by `new-asset` and `pipeline` at their review steps.

## Steps

1. **Snapshot** the live scene (`${CLAUDE_PLUGIN_ROOT}/skills/pipeline/SKILL.md` §4).
2. **Render**: `render_review_set` tool with `{blend_path, object, game_camera}` (`game_camera` from
   `asset-forge.json`; without it the game-distance tile is skipped and the result says so). After a blockout,
   `include: ["silhouette", "game_distance", "beauty"]` is enough.
3. **Validate**: `validate_asset` tool with the project's engine, each platform tier, the asset class, and
   `budget_overrides[tier]` as `overrides`. Skip at blockout stage (UVs and names are not done yet).
4. **Critique**: dispatch the `asset-forge:art-reviewer` agent with: the contact-sheet path and the per-view image
   paths with the layout, the reference image paths, the brief, `style.description`, the budget numbers, and the
   validator JSON — or, at blockout stage, the triangle count and the measured size in metres (the reviewer
   cannot read either from the images and asks for them). Give it nothing about how the asset was built. If that agent is not available, critique with
   the same output format yourself and say that the review was not independent.
5. **Present** the verdict, scores and issues to the user, each issue mapped to a concrete fix — a forge call
   (`deform.inflate(obj, center=…, radius=…, amount=…)`), a modelling instruction, or a texture parameter.
6. **Apply** fixes only after the user agrees, or all of them when the user said "fix everything". Then re-run
   from step 1 and compare the new contact sheet with the old one, issue by issue.

## The reviewer's format (strict)

```
VERDICT: ship | revise | rework
SCORES (1–5): silhouette, proportions, readability at game distance, style match, surface detail, technical
ISSUES (ordered by impact):
  - [severity] what's wrong → where (view/region) → concrete fix
KEEP: what works and must not be lost in revisions
```

Order of judgement: silhouette first (from the silhouette tiles), then game-distance readability, then proportions
against the references, then surfaces. Spatial and specific ("left horn reads thin from 3/4 view"), never generic
("add more detail"). Compare against the references and the style description, not taste.

## Reading the contact sheet

`layout` in the tool result lists `[kind, view]` per tile, row-major, `columns` wide. Tiles: beauty turntable
(azimuth per tile), silhouettes (front, side, three-quarter), game distance (rendered at the true on-screen pixel
height and upscaled with nearest-neighbour, so lost detail shows as blocks), wireframe, UV checker (stretched or
mis-sized squares show texel problems), matcap (surface flow without colour).

## Limitations

- A render is not the engine: lighting, tone mapping and shaders differ. Read colour as relative, not absolute.
- The wireframe tile shows Blender's faces, not the engine's triangulation.
- Only the named object (and its armature parent) is rendered: LODs, collision and separate parts of a
  multi-object asset are not in the tiles. Join parts for the review, or review each object.
