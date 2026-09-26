---
name: webgl-effects
description: Use when adding a postprocessing pass or custom shader to a Three.js/R3F scene — bloom, DOF, a scroll/pointer fragment effect, a bespoke material — or when a review flags a WebGL effect with no GPU budget, capability fallback, or reduced-motion path. Sits on motion-tiers Tier 3.
---

> Last verified: 2026-09-26 — https://threejs.org/docs/pages/RenderPipeline.html — npm:three@0.186

## What this decides

This skill decides WHETHER a postprocessing pass or custom shader earns the GPU cost and
WHICH effect layer to add — then pins the pipeline and budget. It does not re-teach
Three.js: the renderer choice, TSL shader authoring (`three/tsl`), disposal,
and the render loop live in `plugins/craft-layer/skills/threejs-best-practices/SKILL.md`; the
lazy-load contract, the two-render static fallback, and capability gating live in
`plugins/craft-layer/skills/motion-tiers/references/webgl-3d.md` — reference both by path.

**Reconciliation with motion-tiers Tier 3:** Tier 3
(`plugins/craft-layer/skills/motion-tiers/SKILL.md`) decides whether to be 3D at all and
owns lazy-load + static fallback + the KB budget. This skill is the EFFECT LAYER *once
you are already in a 3D scene* — the shader/post pipeline on top. It is not a fifth tier
and does not restate the lazy/fallback rules; it defers them to webgl-3d.md.

## Decide: does the effect earn the GPU cost?

Answer before adding anything; take the first that fits the surface:

1. The look is reachable with DOM / CSS / a Tier 1–2 motion → **no WebGL effect.** A
   CSS blur or gradient is free; a fragment shader is not.
   A lone full-bleed shader plane with no scene (mesh gradient, grain, blob) → a **shader
   preset library**, not a custom pass, unless no preset carries the look or it must live
   inside an existing scene's renderer (`../motion-tiers/references/hosted-runtimes.md`).
2. One built-in pass carries the whole look (bloom on emissive, subtle DOF, vignette) →
   a **single postprocessing pass**, nothing bespoke.
3. The effect is bespoke and *driven* (a fragment distortion tied to scroll, a pointer
   ripple, a custom material) → a **custom TSL/GLSL shader** with uniforms.
4. Reduced-bundle, low-power, or reduced-motion → the **static fallback** from
   webgl-3d.md, no effect at all.

An effect costs GPU frame time (fill-rate × passes × pixel ratio) that does not show up
in the JS bundle. Budget it like paint, not like KB.

## The postprocessing pipeline

Pick the pipeline by renderer — they do not mix:

- **WebGPURenderer** → the TSL `RenderPipeline` (r183 renamed it from `PostProcessing`;
  the old name is a deprecated wrapper). No third-party dependency.
- **Plain three on WebGLRenderer** → `three/addons` `EffectComposer` + passes
  (WebGLRenderer only). No third-party dependency.
- **R3F on WebGL** → `@react-three/postprocessing` over pmndrs `postprocessing`, which
  merges effects into one `EffectPass` — fewer full-screen passes than chained addons
  passes. WebGL only (threejs-best-practices § R3F on WebGPU).

Standing: recorded — no gate reads which pipeline a scene uses.

- One pipeline per renderer; reuse the single renderer webgl-3d.md already mandates.
- Order passes cheapest-first and cap the count (see budget); each full-screen pass
  re-reads the framebuffer. Downsample expensive passes (bloom) rather than running them
  at full DPR.
- Setup, the render-graph wiring, and the GLSL→TSL port are in
  `references/effect-pipeline.md`.
- Bundle-critical page needing only ONE shader plane? The three.js-vs-OGL lightweight
  lever (OGL has no postprocessing) is in `references/effect-pipeline.md`.

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
- Exception: an R3F stack that stays on WebGL for drei GLSL materials or
  `@react-three/postprocessing` writes its effects as pmndrs GLSL `Effect`s. That is
  correct when the renderer choice is recorded; a GLSL-only effect on a WebGPU renderer
  is still a finding. Standing: agent-graded — the craft reviewer reads this section.
- Porting a raw GLSL `ShaderMaterial`: rewrite the node graph in TSL rather than shipping
  hand-written GLSL that only runs on WebGL. The port checklist is in
  `references/effect-pipeline.md`.

## prefers-reduced-motion (mandatory)

- When reduced, freeze animated uniforms and render ONE static frame (the in-scene rule
  from webgl-3d.md) — the effect is visible but still.
- Gate both layers and land on the static final state — mechanism and the three ways
  it is missed: `../motion-tiers/references/reduced-motion.md`.
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
- Pause the loop off-screen: an animated post/shader pipeline must stop rendering once the
  surface leaves the viewport (`frameloop→never` / unmount), or it burns GPU on unseen
  pixels — the full off-screen-pause rule is in `webgl-3d.md`.

## References

- `references/effect-pipeline.md` — the postprocessing pipeline wiring, driving uniforms
  from scroll/pointer, and the GLSL→TSL port checklist.
- Renderer, TSL authoring, disposal, render loop, R3F:
  `plugins/craft-layer/skills/threejs-best-practices/SKILL.md`.
- Lazy-load contract, two-render static fallback, capability gating, KB budget:
  `plugins/craft-layer/skills/motion-tiers/references/webgl-3d.md`.
- Scroll progress source: `plugins/craft-layer/skills/scroll-orchestration/SKILL.md`.
- One fixed canvas with planes tracking DOM rects, scroll velocity as a uniform:
  `plugins/craft-layer/skills/threejs-best-practices/references/webgl-first-site.md`.
  One-writer-per-property: `plugins/craft-layer/skills/motion-tiers/references/gotchas.md`.

## Anti-patterns

- **Effect for a CSS look** — a fragment shader for a blur or gradient DOM+CSS does free.
- **Second renderer / composer** — a new renderer per effect instead of reusing the one
  Tier 3 renderer; doubles GPU cost and memory.
- **Uniform with no reduced-motion gate** — a `uTime` loop ticking under
  `prefers-reduced-motion: reduce`.
- **Effect in the entry bundle** — shipping the 3D + post layer eagerly instead of
  lazy-loading with a static poster (webgl-3d.md).
- **Loop never paused off-screen** — an animated bloom/shader pass still rendering at full
  DPR after the surface scrolls out of view; gate it off (webgl-3d.md).
- **Hand-written GLSL on WebGPU** — a GLSL `ShaderMaterial` on the WebGPU renderer, where
  it never runs; author in TSL and port.
- **Mixed pipeline** — `EffectComposer` on WebGPURenderer or `RenderPipeline` on
  WebGLRenderer; each runs on one renderer only.
- **Re-teaching R3F / renderer setup** here instead of referencing threejs-best-practices.
