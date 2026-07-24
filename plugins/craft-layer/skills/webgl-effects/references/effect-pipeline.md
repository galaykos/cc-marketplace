# Effect pipeline — postprocessing, uniforms, and the GLSL→TSL port

Read on demand from the webgl-effects SKILL. Renderer/scene/R3F setup is NOT re-taught
here — it lives in `plugins/threejs/skills/threejs-best-practices/SKILL.md`; lazy-load
and static-fallback rules live in
`plugins/craft-layer/skills/motion-tiers/references/webgl-3d.md`. This file is only the
effect-layer how-to.

## Postprocessing pipeline (no third-party dep)

- Use Three's built-in postprocessing. On the WebGPU renderer that is the TSL
  `PostProcessing` node graph; on the WebGL fallback it is the `three/addons`
  `EffectComposer` + passes. One pipeline instance per renderer, created after the scene,
  disposed with it.
- Compose passes cheapest-first; every full-screen pass re-reads the framebuffer, so each
  one is real fill-rate. Cap the count (≈2–3 as a ceiling).
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

## Verify the effect

- The pass count is ≤ the budget and expensive passes are downsampled.
- Uniforms are driven from ONE loop; no second rAF; `uTime` is gated by reduced-motion.
- The effect renders on both WebGPU and WebGL, or falls back to the static poster.
- The renderer + pipeline are disposed on unmount (threejs-best-practices).
