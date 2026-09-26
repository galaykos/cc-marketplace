# WebGL-first site — when the canvas is the page

> Last verified: 2026-09-26 — https://r3f.docs.pmnd.rs/api/canvas — npm:@react-three/fiber@9

Read on demand from the threejs-best-practices SKILL,
`plugins/craft-layer/skills/motion-tiers/references/webgl-3d.md` and
`plugins/craft-layer/skills/page-transitions/SKILL.md`. The default stays what webgl-3d.md
says: a 3D island on a DOM page, poster first. This file is the other architecture — one
canvas behind the whole site, DOM on top, the scene carrying on across routes. Take it
only when the concept needs it, record why (the escalation mark in
`plugins/craft-layer/skills/creative-direction/references/ambition-tiers.md`), and keep
every text, poster and reduced-motion rule.

## 1. One canvas that survives navigation

- Mount the canvas ONCE, in the layer the router never unmounts: Next's root layout
  (layouts persist across navigations), Nuxt's `app.vue` outside `<NuxtPage>`, Astro's
  `<ClientRouter />` with `transition:persist`, Livewire's `@persist`. A route changes
  scene state; it never creates a renderer (browsers cap contexts, and re-init stalls).
- A route change is a scene transition inside the GL world — tween the camera or
  uniforms — started from the same navigation event as the DOM transition
  (`page-transitions`), so the two never race.
- Dispose each route's geometries and textures when it leaves; keep the renderer.

## 2. DOM↔GL rect sync

- A plane standing in for a DOM image tracks that element's `getBoundingClientRect()`.
  Measure on resize and layout change (`ResizeObserver`), not every frame; per frame,
  apply only the scroll offset from the scroll contract.
- R3F: drei's `<View>` cuts one canvas into viewports that follow DOM elements (scissor);
  set the canvas `eventSource` to a parent holding both canvas and HTML.
- The DOM element stays in the document with its real `<img alt>` or text — the no-JS,
  crawler, screen-reader and poster path. The plane is the enhancement.
- Scroll velocity reaches shaders as a uniform written from the ONE scroll loop, never a
  second rAF (`plugins/craft-layer/skills/webgl-effects/references/effect-pipeline.md`).
- Labels anchored to scene points are projected DOM text: `data-3d.md` § Labels.

## 3. Scroll drives the camera, the page keeps its scroll

- Map the page's own scroll to camera or scene progress through the scroll-orchestration
  contract (Lenis → ScrollTrigger progress → a camera path or uniform).
- Do not give the canvas its own scroll container on a page whose content is DOM — drei's
  `ScrollControls` creates an HTML scroll container in front of the canvas — and never
  hide the page overflow and hijack the wheel. Both split the page into two scroll
  positions (`plugins/craft-layer/skills/scroll-orchestration/SKILL.md` § Anti-patterns).
- Reduced motion: no scrubbed camera — a fixed camera per section.

## 4. The loader

- Follow the arrival contract in `motion-tiers/references/webgl-3d.md`: progress from real
  loading (`THREE.LoadingManager`, or drei's `useProgress`, which wraps
  `THREE.DefaultLoadingManager`), a time cap after which content shows, text in the served
  HTML, no animated loader under reduced motion or on a repeat visit.
- The counterweighted preloader (an Arrival move in
  `creative-direction/references/moves-taxonomy.md`) lives here: its motion may be the
  brand's first beat, but its number is honest and the page behind it is readable.

## 5. GPU quality ladder

- Rungs, top down: full (post, shadows, DPR up to 2) → reduced (no post, lower DPR, fewer
  particles) → minimal (static scene, render on demand) → the poster.
- Start from a cheap guess — `Save-Data`, `(pointer: coarse)` — then move on measured
  frame time: drei's `<PerformanceMonitor>` (`onIncline` / `onDecline`, and `onFallback`
  once `flipflops` is reached) driving DPR and the rung. `onFallback` lands on minimal or
  the poster and stays there for the session; flip-flopping quality is visible.

## 6. Context loss and device loss

- Causes: a GPU reset, too many contexts across tabs, a GPU switch, a driver update (MDN).
- WebGL: `WebGLRenderer` already calls `preventDefault()` on `webglcontextlost` and
  re-initialises on `webglcontextrestored`. Stop your loop while lost; re-upload anything
  you created outside three.
- WebGPU: `WebGPURenderer`'s default `onDeviceLost` logs and stops rendering. Override it
  — show the poster, then recreate the renderer or stay on the poster.
- Either way the page stays usable because its text is DOM and the poster sits behind the
  canvas.

## 7. What still binds

The three chunk stays out of the entry bundle; the served HTML carries every word; a
scene looping past five seconds gets a visible pause control
(`plugins/craft-layer/skills/motion-tiers/SKILL.md`); the loop pauses off-screen and in a
hidden tab.

Standing: recorded — no gate reads this file. `/craft-layer:audit`'s served-HTML step
fails a loader painted over an empty document; nothing measures frame time or the ladder.
