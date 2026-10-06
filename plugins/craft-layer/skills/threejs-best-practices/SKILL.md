---
name: threejs-best-practices
description: Use when building or reviewing Three.js or R3F code — scenes, renderers, TSL/GLSL shaders, react-three-fiber and drei, WebGPU vs WebGL choice, glTF/GLB asset loading, disposal and GPU leaks, render-loop performance.
---

> Last verified: 2026-10-06 — https://developer.mozilla.org/en-US/docs/Web/API/WebGPU_API — npm:three@0.186

# Three.js best practices

Three.js releases on a ~6–10-week `rXXX` cadence with real API movement between
revisions. Resolve the installed revision from the lockfile (`three` — e.g.
r186 in September 2026) and check the migration guide for anything you touch:
threejs.org/docs + the per-release migration notes. Never advise from a
remembered API level.

Versions read that day (2026-10-06) for the version traps below: three 0.186.1,
@react-three/fiber 9.8.1, @react-three/drei 10.7.9. Standing: recorded — no gate reads
this file, and the next three or fiber release can move any of them.

## Renderer choice (2026 floor)

- **WebGPURenderer is the default for new plain-three work** —
  `import { WebGPURenderer } from 'three/webgpu'`, with a WebGL 2 backend it falls back
  to automatically. WebGPU itself is **not Baseline**: MDN lists it as limited
  availability, secure contexts only — a dev server on `http://<LAN-IP>` silently gets
  the WebGL 2 backend. Test both (`forceWebGL: true`).
- WebGPURenderer does not run `ShaderMaterial`, `RawShaderMaterial`, `onBeforeCompile`
  or `EffectComposer`, on either backend. Write shaders in **TSL** (`three/tsl`, compiles
  to WGSL or GLSL) and post in the TSL pipeline (`webgl-effects`); port a raw GLSL
  material to TSL rather than pinning the renderer to WebGL for one material.
- Keep `WebGLRenderer` for legacy code pinned below the WebGPU line, and for the R3F
  stacks named in the next section.
- One renderer, one canvas, reused — creating renderers per view or per
  route change leaks GPU contexts (browsers cap them).

## R3F on WebGPU

R3F's `<Canvas>` creates a `WebGLRenderer` by default. WebGPU needs the `gl` prop to return a
promise (`new WebGPURenderer(props)`, then `await renderer.init()`), and R3F's docs call
that renderer "still a work in progress". R3F 10, the WebGPU-first line, is alpha (September 2026).

- drei materials built on `ShaderMaterial` (`MeshTransmissionMaterial`, the
  `shaderMaterial` helper) and `@react-three/postprocessing` (on pmndrs `postprocessing`,
  WebGLRenderer only) do NOT run on WebGPU. A stack using any of them stays on R3F's
  default WebGL renderer — the correct choice, not legacy.
- Want WebGPU in R3F → TSL node materials and `RenderPipeline` for post; check every drei
  import against its docs first. Decide once per canvas, record why. Standing: recorded.

## Scene and render-loop discipline

- Render on demand when nothing animates: drive frames from interaction/
  controls `change` events instead of an unconditional `requestAnimationFrame`
  loop — an idle spinning loop burns battery for a static scene.
- Use `renderer.setAnimationLoop(fn)` (required for WebXR, correct everywhere)
  instead of hand-rolled rAF recursion.
- Time-step animation with the loop's delta, never per-frame constants —
  frame-rate-independent motion is the difference between 60 and 120 Hz
  displays behaving the same.
- Take that delta from `THREE.Timer`, not `THREE.Clock` (deprecated since r183; it warns
  when constructed): `timer.update()` once per frame, then `getDelta()`, and
  `timer.connect(document)` so a tab coming back from hidden does not return one huge
  delta. R3F 9.8.1 still builds a Clock itself — that warning in an R3F app is the
  library's, not yours to fix.
- Cap `renderer.setPixelRatio(Math.min(devicePixelRatio, 2))` — full 3x DPR
  quadruples fragment work for imperceptible gain.

## Disposal — the leak discipline

Three.js does NOT garbage-collect GPU resources. Removing a mesh from the
scene keeps its geometry, material, and textures alive on the GPU:

- Every `Geometry`, `Material`, `Texture`, and render target you stop using
  gets `.dispose()`; traverse the removed subtree and dispose per node.
- Share geometries/materials across meshes deliberately; dispose only when
  the LAST user goes away — an ownership question, decide it explicitly.
- On SPA route unmount: dispose the whole scene graph AND
  `renderer.dispose()`; in R3F this is handled for tree-managed objects, but
  anything created imperatively (in `useEffect`, loaders) is yours to dispose.
- Symptom to look for in review: a `new THREE.*Geometry/Material/Texture` in
  a hot path (render loop, resize handler, React render body) — allocation
  per frame is both a leak and a stutter source.

## Assets

- Models: glTF/GLB only (`GLTFLoader`); compress geometry with Draco or
  Meshopt, textures with KTX2/Basis (`KTX2Loader`) — raw PNG textures are the
  most common bundle-size and VRAM offender.
- The loader decodes only what it was handed a decoder for — Meshopt needs
  `setMeshoptDecoder`, Draco `setDRACOLoader`, KTX2 `setKTX2Loader`, else GLTFLoader
  throws. `gltf-transform optimize` emits Meshopt by default, and drei's `useGLTF` fetches
  the Draco decoder from Google's gstatic host unless given a local path. Decoder wiring and
  hosting, KTX2 under WebGPU, encoding: `references/compressed-gltf.md`.
- Load through a shared `LoadingManager` for progress and error routing;
  never fire-and-forget loader promises without an error path.
- Reuse loaded assets via a cache keyed by URL; loading the same GLB per
  component instance duplicates VRAM silently.
- `texture.colorSpace = THREE.SRGBColorSpace` for color maps — leaving data
  maps (normal, roughness) linear; wrong colorSpace is the "everything looks
  washed out" bug.

## Performance checklist

- Draw calls dominate: merge static geometry (`BufferGeometryUtils`), use
  `InstancedMesh` for repeated objects (grass, particles, crowds) — thousands
  of individual meshes is the classic scene-graph mistake. Picking and labelling
  thousands of data marks: `references/data-3d.md`.
- Frustum culling is on by default — do not disable it globally to fix a
  skinned-mesh popping bug; fix the bounding sphere instead.
- Lights are per-fragment cost: prefer environment maps / baked lighting for
  static scenes; every added dynamic light multiplies shader work.
- Shadows: one shadow-casting light where possible, tight shadow-camera
  bounds, `mapSize` no larger than visibly needed; static scenes can freeze
  shadow maps (`autoUpdate = false`, update once).
- `PCFSoftShadowMap` is deprecated — r182 removed WebGLRenderer's soft filter and r186
  WebGPURenderer's; on r186 both swap in `PCFShadowMap` with a warning. R3F's boolean
  `<Canvas shadows>` still asks for it; write `shadows="percentage"` to get PCF shadows
  without the warning.
- Profile with the browser GPU profiler and `renderer.info` (draw calls,
  triangles, GPU memory) before optimizing — guesses about the bottleneck are
  usually wrong.

## react-three-fiber (R3F)

- R3F is the React reconciler for three — scene objects as JSX, hooks
  (`useFrame`, `useLoader`, `useThree`) for the loop and context; drei is the
  helper library (controls, loaders, staging). Since 9.5, R3F caps React's MINOR, not only
  the major — 9.8.1 peers `react >=19 <19.4` — so read fiber's peer range before a React
  minor bump. drei 10 and `@react-three/postprocessing` 3 need React 19; a React 18 app stays on
  fiber 8 + drei 9.
- Per-frame state does NOT go through React state — mutate refs in
  `useFrame`; a `setState` per frame re-renders the React tree at 60fps.
- `frameloop="demand"` renders only when a frame is requested. A prop changed through React
  requests one, and so does `@react-spring/three`'s `animated.*` (it invalidates itself). A
  GSAP tween, a spring outside `animated`, or a store subscription that mutates three objects
  outside `useFrame` does not — call `invalidate()` on every update, or the canvas stops
  repainting until something else asks.
- Extrusion depth is named differently per layer (read from source — drei 10.7.9,
  three-stdlib 2.36.1, three r172/r173 — not rendered): drei's `<Text3D>` takes `height`
  and passes it to three-stdlib's `TextGeometry` as depth, so a `depth` prop falls through
  to the mesh and changes nothing; three's own `TextGeometry` reads only `depth` since r173,
  so a `height` option there is ignored and the text extrudes 50 units.
- `useLoader` caches by URL and suspends — wrap scenes in `<Suspense>`; do
  not hand-roll loading state around it.
- Objects created in JSX are auto-disposed on unmount; objects created in
  effects/loaders follow the manual disposal rules above.

## When the scene is data, or the page

- `references/data-3d.md` — 3D as a data view inside an app: instanced picking with a
  BVH, labels, controls vs render-on-demand, and the DOM list/table twin it owes.
- `references/webgl-first-site.md` — the canvas IS the page: persistent across routes,
  DOM↔GL rect sync, scroll-to-camera, loader, GPU quality ladder, context loss.

## Defer rule

- Bundler mechanics (code-splitting the three chunk, import.meta.glob asset
  handling) → web-dev's `vite-best-practices` skill.
- Server state feeding R3F components (query libs, cache keys) and general
  React correctness are baseline — handle them inline.
- DOM/CSS animation (Motion, GSAP) → ui-ux motion-best-practices; three owns
  the canvas, not the page.
- WCAG/a11y of the page hosting the canvas → ui-ux's `/ui-ux:audit`.

## Anti-patterns

- **Remembered-API advice** — rXXX moved it; check the migration guide for
  the locked revision.
- **New plain-three scenes on WebGLRenderer** — starting 2026 work on the legacy path.
- **WebGPU under drei GLSL materials or `@react-three/postprocessing`** — they only run
  on WebGL; the scene breaks or silently drops the effect.
- **Remove-without-dispose** — GPU leaks that profile as "memory grows per
  route visit".
- **Allocation in the render loop** — `new Vector3()` per frame; hoist and
  reuse scratch objects.
- **React state per frame** — `setState` inside `useFrame`.
- **Raw PNG texture pipelines** — no KTX2/Draco, VRAM and bundle both bloat.

## Scope by model tier

**All models** — every rule above: the revision gate, the WebGPU/WebGL choice, disposal.
**Compensation (worker-tier)** — the resolve-revision → verify order in
`/code-review:review`'s Three.js pass, followed literally; a Fable-class session may compress it once
the lockfile is read. **Skip** — a diff touching no scene, renderer, shader, loader or
R3F component earns a one-line verdict.
