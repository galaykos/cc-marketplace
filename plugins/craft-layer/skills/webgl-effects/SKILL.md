---
name: webgl-effects
description: Use when adding a postprocessing pass or custom shader to a Three.js/R3F scene — bloom, DOF, a scroll/pointer fragment effect, a bespoke material — or when a craft review flags a WebGL effect with no GPU budget, capability fallback, or reduced-motion path. Sits on motion-tiers Tier 3: decides if the effect earns its GPU cost, drives shader uniforms from scroll/pointer, sets a pass budget, mandates a static/reduced-motion fallback; references threejs-best-practices and webgl-3d.md by path.
---

## What this decides

This skill decides WHETHER a postprocessing pass or custom shader earns the GPU cost and
WHICH effect layer to add — then pins the pipeline and budget. It does NOT re-teach
Three.js: the renderer (WebGPU-default), TSL shader authoring (`three/tsl`), disposal,
and the render loop live in `plugins/threejs/skills/threejs-best-practices/SKILL.md`; the
lazy-load contract, the two-render static fallback, and capability gating live in
`plugins/craft-layer/skills/motion-tiers/references/webgl-3d.md` — reference both by
path, never copy.

**Reconciliation with motion-tiers Tier 3:** Tier 3
(`plugins/craft-layer/skills/motion-tiers/SKILL.md`) decides whether to be 3D at all and
owns lazy-load + static fallback + the KB budget. This skill is the EFFECT LAYER *once
you are already in a 3D scene* — the shader/post pipeline on top. It is not a fifth tier
and does not restate the lazy/fallback rules; it defers them to webgl-3d.md.

## Decide: does the effect earn the GPU cost?

Answer before adding anything; take the first that fits the surface:

1. The look is reachable with DOM / CSS / a Tier 1–2 motion → **no WebGL effect.** A
   CSS blur or gradient is free; a fragment shader is not.
2. One built-in pass carries the whole look (bloom on emissive, subtle DOF, vignette) →
   a **single postprocessing pass**, nothing bespoke.
3. The effect is bespoke and *driven* (a fragment distortion tied to scroll, a pointer
   ripple, a custom material) → a **custom TSL/GLSL shader** with uniforms.
4. Reduced-bundle, low-power, or reduced-motion → the **static fallback** from
   webgl-3d.md, no effect at all.

An effect costs GPU frame time (fill-rate × passes × pixel ratio) that does not show up
in the JS bundle. Budget it like paint, not like KB.

## The postprocessing pipeline

- Use Three's built-in postprocessing (`three/addons` / the TSL `PostProcessing` node) —
  **no third-party dependency.** One composer / post pipeline per renderer; reuse the
  single renderer webgl-3d.md already mandates.
- Order passes cheapest-first and cap the count (see budget); each full-screen pass
  re-reads the framebuffer. Downsample expensive passes (bloom) rather than running them
  at full DPR.
- Setup, the composer/render-graph wiring, and the GLSL→TSL port are in
  `references/effect-pipeline.md`.

## Shader uniforms from scroll + pointer

- Drive the effect through **uniforms**, not by rebuilding the material each frame: a
  `uProgress` from scroll (fed by scroll-orchestration, not re-derived here), a
  `uPointer` vec2, a `uTime`.
- ONE writer per uniform (see gotchas "one writer per property") and update on the render
  loop's cadence — do not write uniforms from a second rAF.
- Feed scroll progress from the existing scroll contract
  (`plugins/craft-layer/skills/scroll-orchestration/SKILL.md`); this skill consumes the
  progress, it does not own the scroll loop.

## WebGPU/TSL default, WebGL fallback

- Author effects in **TSL** (`three/tsl`) so they compile to WGSL on the WebGPU renderer
  (the threejs-best-practices default) and to GLSL on the WebGL fallback — one source,
  both backends. Detect and fall back per threejs-best-practices.
- Porting a raw GLSL `ShaderMaterial`: rewrite the node graph in TSL rather than shipping
  hand-written GLSL that only runs on WebGL. The port checklist is in
  `references/effect-pipeline.md`.

## prefers-reduced-motion (mandatory)

- Under `matchMedia('(prefers-reduced-motion: reduce)')`: freeze animated uniforms and
  render ONE static frame (the in-scene reduced-motion rule from webgl-3d.md) — the
  effect is visible but still.
- Gate any uniform-driving loop (scroll scrub, pointer, time) behind the media query
  before it starts; a `uTime` uniform ticking every frame with no gate is the classic
  miss.
- Combined with the static fallback (below), reduced-motion users never see motion they
  did not ask for.

## Perf budget

- Cap passes (≈2–3 full-screen passes as a ceiling); downsample bloom/blur; clamp
  `renderer.setPixelRatio` to ≤2 (webgl-3d.md). Measure GPU frame time, not KB.
- Never in the initial bundle: the whole 3D + effect layer lazy-loads on
  viewport/intent (webgl-3d.md), with the static poster shown first.
- Low-power / `Save-Data` / no-WebGPU-and-slow-WebGL → skip the effect, keep the static
  fallback. One renderer, disposed on unmount (threejs-best-practices).

## References

- `references/effect-pipeline.md` — the postprocessing pipeline wiring, driving uniforms
  from scroll/pointer, and the GLSL→TSL port checklist.
- Renderer, TSL authoring, disposal, render loop, R3F:
  `plugins/threejs/skills/threejs-best-practices/SKILL.md`.
- Lazy-load contract, two-render static fallback, capability gating, KB budget:
  `plugins/craft-layer/skills/motion-tiers/references/webgl-3d.md`.
- Scroll progress source: `plugins/craft-layer/skills/scroll-orchestration/SKILL.md`.
  One-writer-per-property: `plugins/craft-layer/skills/motion-tiers/references/gotchas.md`.

## Anti-patterns

- **Effect for a CSS look** — a fragment shader for a blur or gradient DOM+CSS does free.
- **Second renderer / composer** — a new renderer per effect instead of reusing the one
  Tier 3 renderer; doubles GPU cost and memory.
- **Uniform with no reduced-motion gate** — a `uTime` loop ticking under
  `prefers-reduced-motion: reduce`.
- **Effect in the entry bundle** — shipping the 3D + post layer eagerly instead of
  lazy-loading with a static poster (webgl-3d.md).
- **Hand-written GLSL only** — GLSL `ShaderMaterial` that never runs on the WebGPU
  renderer; author in TSL and port.
- **Re-teaching R3F / renderer setup** here instead of referencing threejs-best-practices.
