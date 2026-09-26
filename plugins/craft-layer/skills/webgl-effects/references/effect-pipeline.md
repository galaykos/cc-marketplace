# Effect pipeline — postprocessing, uniforms, and the GLSL→TSL port

> Last verified: 2026-09-26 — https://threejs.org/docs/pages/RenderPipeline.html — npm:three@0.186

Read on demand from the webgl-effects SKILL. Renderer/scene/R3F setup is NOT re-taught
here — it lives in `plugins/craft-layer/skills/threejs-best-practices/SKILL.md`; lazy-load
and static-fallback rules live in
`plugins/craft-layer/skills/motion-tiers/references/webgl-3d.md`. This file is only the
effect-layer how-to.

## Postprocessing pipeline — one per renderer

| Renderer | Pipeline | Dependency |
| --- | --- | --- |
| `WebGPURenderer` (WebGPU or its WebGL 2 backend) | TSL `RenderPipeline` from `three/webgpu`: `new RenderPipeline(renderer)`, `outputNode = pass(scene, camera)` plus effect nodes, `renderPipeline.render()` in the loop. Named `PostProcessing` before r183; that name is a deprecated wrapper. | none |
| Plain three on `WebGLRenderer` | `EffectComposer` from `three/addons/postprocessing/EffectComposer.js` + passes | none |
| R3F on `WebGLRenderer` | `@react-three/postprocessing` `<EffectComposer>` over pmndrs `postprocessing`; its effects merge into one `EffectPass` | pmndrs, WebGL only |

- Each row runs on its own renderer only: `EffectComposer` "can only be used with
  WebGLRenderer", `RenderPipeline` "can only be used with WebGPURenderer" (three.js docs).
  pmndrs `postprocessing` names no WebGPU support.
- One pipeline instance per renderer, created after the scene, disposed with it.
- Compose passes cheapest-first; every full-screen pass re-reads the framebuffer, so each
  one is real fill-rate. Cap the count (≈2–3 as a ceiling). pmndrs merging counts as one
  pass for this cap; chained addons passes each count.
- Downsample the expensive passes: run bloom/blur at half resolution and upsample, rather
  than at full device pixel ratio. Clamp pixel ratio ≤2 (webgl-3d.md).

## Driving uniforms from scroll + pointer

- Declare uniforms once (`uProgress`, `uPointer`, `uTime`) and WRITE them on the render
  loop — never rebuild the material or the pipeline per frame.
- Scroll progress comes from the existing scroll contract
  (`plugins/craft-layer/skills/scroll-orchestration/SKILL.md`) — read the smoothed
  progress it already produces; do not start a second scroll/rAF loop for the shader
  (one-writer-per-property, `motion-tiers/references/gotchas.md`).
- Pointer: normalise to −1..1 in a single pointermove handler, lerp toward the target in
  the render loop for smoothing, and disable it on `pointer:coarse` where a hover pointer
  is absent.
- `uTime`: only advance it when not reduced-motion; gate the increment behind
  `matchMedia('(prefers-reduced-motion: reduce)')`.
- `uVelocity` (scroll speed for smear or distortion): read from the same scroll loop as
  `uProgress`. DOM-synced planes on one fixed canvas — measure, sync, scroll — are in
  `plugins/craft-layer/skills/threejs-best-practices/references/webgl-first-site.md`.

## GLSL → TSL port checklist

Porting a raw GLSL `ShaderMaterial` so it runs on the WebGPU renderer too:

- Rewrite the fragment/vertex logic as a TSL node graph (`three/tsl`) instead of a GLSL
  string; TSL compiles to WGSL (WebGPU) and GLSL (WebGL) from one source.
- Map `uniform`s to TSL `uniform()` nodes; map `varying`s to the node equivalents;
  replace built-ins (`gl_FragCoord`, texture sampling) with their TSL nodes.
- Verify parity on BOTH backends: render once on WebGPU, once on the WebGL fallback, and
  confirm the effect matches. Keep the GLSL only as a reference, not as the shipped path.

## Reduced-motion + fallback (defer, don't restate)

- In-scene reduced-motion = freeze uniforms, render one static frame (webgl-3d.md).
- No WebGPU and slow WebGL, or `Save-Data` → skip the effect entirely and keep the static
  poster (webgl-3d.md). This file adds nothing to those rules; it only consumes them.

## three.js vs OGL — the lightweight lever

When the ENTIRE need is one shader plane or a single small effect and bundle size is
critical (a marketing/landing page that must stay light), **OGL** (~a few KB) is a lighter
alternative to three.js — a thin WebGL wrapper with no scene-graph overhead.

- Reach for OGL when: one full-screen shader quad, a single mesh with a custom material,
  and no need for a scene graph, loaders, or a postprocessing chain.
- Stay on three.js when: more than one object, a scene graph, GLTF/loaders, TSL, or a
  **postprocessing pipeline** — OGL has NO built-in postprocessing/EffectComposer, so the
  moment you need passes (bloom, DOF, composed effects) it is three.js.
- Either way the lazy-load + static-fallback + reduced-motion rules are unchanged
  (`plugins/craft-layer/skills/motion-tiers/references/webgl-3d.md`): OGL is a bundle
  lever, not a lower bar for the fallback contract.

## Verify the effect

- The pass count is ≤ the budget and expensive passes are downsampled.
- Uniforms are driven from ONE loop; no second rAF; `uTime` is gated by reduced-motion.
- The effect renders on both WebGPU and WebGL, or falls back to the static poster.
- The renderer + pipeline are disposed on unmount (threejs-best-practices).
