# 3D as a data view — picking, labels, and the DOM twin

> Last verified: 2026-09-26 — https://threejs.org/docs/pages/Raycaster.html — npm:three@0.186

Read on demand from the threejs-best-practices SKILL when a scene SHOWS DATA inside an
app — a globe of regions, a 3D dependency graph, a bin heatmap, a model with issue
markers — rather than decorating a marketing page. Renderer, loop and disposal rules stay
in the SKILL; the lazy-load and poster contract stays in
`plugins/craft-layer/skills/motion-tiers/references/webgl-3d.md`.

## First: does the data need a third dimension?

Occlusion and perspective distort comparison; a 2D map, heatmap or table reads values
more accurately. Use 3D when the third dimension IS the data (a physical layout, a
building model, a network whose shape is the point). Otherwise the chart-vs-table call
belongs to `plugins/craft-layer/skills/information-design/SKILL.md`.

## One draw call per mark type

- Thousands of markers are ONE `InstancedMesh` per marker shape: `setMatrixAt` /
  `setColorAt`, then flag `instanceMatrix.needsUpdate` / `instanceColor.needsUpdate`.
  One `Mesh` per datum is the frame-rate killer.
- After moving instances, recompute bounds (`computeBoundingSphere()`,
  `computeBoundingBox()`) — raycasting and frustum culling read them, and three does not
  refresh them for you.
- Very large clouds of identical marks: `THREE.Points`.

## Picking

- Raycast against the `InstancedMesh`; the hit's `instanceId` is the datum's index. Keep
  one array mapping `instanceId → record id`, and never key selection on the mesh.
- Raycast on pointer events, not every frame. Tell a click from an orbit drag with a small
  movement threshold between `pointerdown` and `pointerup`; throttle hover to the frame.
- Dense geometry: `three-mesh-bvh` (`computeBoundsTree`, `acceleratedRaycast`,
  `raycaster.firstHitOnly = true`); `PointsBVH` for point clouds and
  `computeBatchedBoundsTree` for `BatchedMesh`. Rebuild the tree only when geometry
  changes. Profile first: if the per-instance loop is the cost, pick against an index of
  instance positions and map back to `instanceId`.

## Labels stay DOM text

- Project the anchor point to the screen (`vector.project(camera)`), or use drei's
  `<Html>` in R3F (`occlude` hides it behind geometry; `transform` mode can render blurry
  on some devices). Never bake meaningful text into a texture.
- Cap live labels — hovered, selected, nearest N. Dozens of labels repositioned every
  frame is layout work on the main thread.
- A label's text is also the datum's accessible name: reuse it in the DOM twin.

## Controls vs render-on-demand

- A data view is idle most of the time: render on demand. With `enableDamping`, call
  `controls.update()` inside the render function and request a frame on the controls'
  `change` event — `update()` keeps emitting `change` while the camera settles, so the
  scene renders until it stops (three.js manual, "Rendering on Demand"). Guard with a
  render-requested flag so one frame is queued at a time. R3F: `frameloop="demand"` plus
  `invalidate()`.
- Never switch the whole session to an always-on loop to make damping work.

## The DOM twin (mandatory when the 3D carries data)

The static poster is NOT the accessible equivalent when the 3D carries data — a picture
shows no values and cannot be searched, sorted or selected.

- Every datum in the scene is also a row in a DOM list or table next to the canvas (or
  one toggle away), with the same names and values.
- Selection is ONE piece of state both views read: choosing a row highlights its
  instance (`setColorAt`, a camera move); picking an instance selects and scrolls to its
  row.
- Keyboard lives in the twin: arrows or Tab move through rows, Enter opens detail,
  Escape clears. Announce a selection change once in a polite live region, never per
  hover.
- Reduced motion: the camera jumps to the selection instead of flying there.
- On a narrow screen the twin may be the default view, with the 3D one tap away.

Standing: recorded — no gate reads this file. `/ui-ux:audit` can find a missing
keyboard route through the twin; nothing checks that the twin and the scene agree.
