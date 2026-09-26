# Hosted runtimes and shader presets — Spline, Unicorn Studio, Paper Shaders

> Last verified: 2026-09-26 — https://docs.spline.design/exporting-your-scene/how-to-optimize-your-scene — npm:@splinetool/runtime@2.0
>
> Versions read that day: `@splinetool/runtime` and `@splinetool/viewer` 2.0.58, `@splinetool/react-spline`
> 4.1.0, the Unicorn Studio SDK v2.3.0 (GitHub `hiunicornstudio/unicornstudio.js` via jsDelivr — not on npm),
> `unicornstudio-react` 2.2.13, `@paper-design/shaders-react` 0.0.81. The stamp tails one package because the
> staleness script reads one; re-read the others before quoting them.

A hosted runtime is still **Tier 3**. The two-render contract, the error boundary, capability
gating and the reduced-bundle path in `webgl-3d.md` apply unchanged, and a loop running past five
seconds still owes a visible pause control (`../SKILL.md`). This file adds only what changes when
the scene, the player, or both belong to a vendor.

| shape | example | you ship | the vendor serves |
|---|---|---|---|
| hosted scene + player | Spline | a React wrapper or `<spline-viewer>` | the runtime (npm or CDN), the scene file (`prod.spline.design`), WASM per scene feature |
| hosted composition SDK | Unicorn Studio | an embed element + the SDK | the SDK (jsDelivr), the scene JSON and its textures |
| shader preset library | Paper Shaders | an npm component | nothing — no remote host |

## When it beats hand-built three.js, and when it does not

- **Beats it:** an ambient hero, a product glow, a gradient or blob background — decoration with
  no data and no app state, authored by a designer in the vendor's editor. A preset draws a
  full-bleed shader plane for a small fraction of three.js's weight (Weight, below).
- **Loses:** 3D as data (a globe of thousands of points, a dependency graph, a 3D heatmap) — it
  needs instancing, picking and a table twin (`threejs-best-practices`); an interaction-heavy scene
  whose state lives in your app (configurator, drag-to-place); a canvas persisting across routes
  (`plugins/craft-layer/skills/threejs-best-practices/references/webgl-first-site.md`); anything
  that must own the renderer, disposal or the loop — the vendor owns those.
- For decoration, try them in this order: a preset (no remote host), then a hosted scene, then hand-built three.js.

Standing: recorded — nothing checks which runtime a surface picked; once one ships, the craft
reviewer detects it by import and grades it as the 3D/WebGL row.

## Arrival: lazy mount, then a real poster

The miss this section exists for, observed in a 10-run probe on 2026-09-26 (a Spline scene behind
a Next.js hero): every run deferred the runtime and skipped it under reduced motion, and nine of
ten put a CSS gradient where the poster belongs, leaving "export a still frame" as advice. One
argued the gradient "can't become the LCP element the way a poster image could".

- **Defer the import, not just the render.** `@splinetool/react-spline` 4.1.0 is a `"use client"`
  module with a static `import { Application } from '@splinetool/runtime'`, so importing the
  component — its `/next` entry too — puts the runtime in that route's client JS. Use
  `next/dynamic(() => import(…), { ssr: false })` inside a Client Component (Next rejects
  `ssr: false` in a Server Component), or a dynamic `import()` fired by an IntersectionObserver
  or on idle after `load`. Inject a script-tag SDK at that moment, not in `<head>`.
  `<spline-viewer>` defers its SCENE (`loading="auto"` waits for the viewport) — its script still
  downloads as soon as the tag is parsed.
- **Ship the poster; do not suggest it.** A still of the scene's first frame, compressed
  (AVIF/WebP), in the served HTML at the scene's box size (`width`/`height` or a reserved aspect
  box) so the swap causes no CLS. It is the whole hero for everyone who never gets the scene —
  reduced motion, Save-Data, no WebGL, a vendor host that failed — and a gradient shows them a
  hero nobody designed.
- **Treat the poster as the LCP element.** An `<img>` is an LCP candidate; a `<canvas>` is not
  (web.dev "What elements are considered?"). Load it eagerly at high priority — on Next 16
  `loading="eager"` or `fetchPriority="high"`, since `priority` is deprecated there — never lazy,
  never faded in from `opacity: 0`. Chrome skips an element covering the whole viewport and a
  low-entropy placeholder; then the headline is LCP, and the poster still ships.
- **Keep the poster under the canvas** once the scene mounts rather than unmounting it: a lost
  context or a failed scene then shows the poster, not an empty box.
- **`@splinetool/react-spline/next` is a placeholder, not a poster.** It is an async Server
  Component that fetches `https://<host>.spline.design/<id>/hash` at render time and draws a
  blurhash through `next/image`: a low-entropy blur, a server-side dependency on the vendor, and
  no deferral of the runtime. Ship your own poster and dynamic-import the plain component.

Standing: agent-graded — the craft reviewer checks every 3D/WebGL surface for lazy load, a static
fallback and an error boundary; whether the fallback is a real frame is its read.

## Reduced motion — no vendor documents it

Keep the poster and never start the scene. If a user opts into it anyway, stop it. Subscribe to
the media query rather than reading `.matches` once (`reduced-motion.md`).

- **Spline** — do not mount; once mounted, `app.stop()` ("Stop/Pause all rendering controls and
  events" in the runtime's types) and `app.play()` to resume.
- **Unicorn Studio** — do not call `addScene`/`init`; once running, `scene.paused = true`.
- **Paper Shaders** — `speed={0}` with a chosen `frame` is the preset's own still ("speed=0 stops
  the animation loop"; "frame fully defines the state of static shader").

Spline's optimisation page, Unicorn's performance and embed guides, and Paper's shader pages say
nothing about `prefers-reduced-motion`, and the string appears in none of the five builds read
(Spline runtime and viewer 2.0.58, Unicorn SDK 2.3.0, `unicornstudio-react` 2.2.13, Paper 0.0.81).
Unicorn's agent reference uses reduced motion only to lower a glow variable — dimming is not
stopping.

Standing: gate when the craft-gates suite runs — "canvas: no <canvas> keeps animating" in
`plugins/craft-layer/template/craft-gates/gates.spec.ts` samples up to four visible canvases
(open shadow roots included, so `<spline-viewer>` counts) 400ms apart under reduced motion. A
fifth canvas, or motion under 0.1% of its pixels, passes unseen.

## Pause off-screen and in a hidden tab

- **Unicorn and Paper already do it — do not add a second controller.** Unicorn "pauses rendering
  when scenes are outside the viewport", and "Page visibility changes cancel and restart the SDK
  animation loop, so do not add a separate document-hidden render controller" (unicornstudio-llms.txt).
  Paper pauses a shader outside the viewport since 0.0.78, and its 0.0.81 mount also listens for
  `visibilitychange`.
- **Spline's React wrapper does not.** Drive `app.stop()`/`app.play()` from an
  IntersectionObserver on the scene box and from `visibilitychange`; resume only when both say
  visible, and never under reduced motion. `<spline-viewer>` emits `viewport-intersection` and
  takes `unloadable` (unload when it leaves the viewport; the next entry reloads the scene).
- `requestAnimationFrame` already pauses in most browsers' background tabs (MDN), so the hidden-tab
  handler is for the runtime's events and timers, and for not waking an off-screen scene when the
  tab returns.

Standing: recorded.

## The WebGL context ceiling — count across embeds

Each embed holds its own context: one per Spline scene (on its WebGL fallback — Spline prefers
WebGPU where the browser grants an adapter), one per Unicorn scene, one WebGL2 context per Paper
shader component (`getContext("webgl2")` per mount in 0.0.81), plus every three.js/R3F, Rive or
Pixi canvas on the page. Past the page's cap Chromium force-loses the OLDEST context (Blink
`ForciblyLoseOldestContext`: "Too many active WebGL contexts. Oldest context will be lost").
Vendor guidance: Unicorn — "Stay under 10 — WebGL allows a maximum of 16 contexts"; Spline —
"only use one or two embeds per page", "Avoid using more than 3 embeds per page". The cap is set
per browser and platform, not by a spec. A grid with a shader per card is how pages hit it: use
one shared background, not N.

Standing: recorded.

## A third party hosts the scene

- **Availability.** The scene file, and often the runtime, come from the vendor's origin; when it
  is slow, down, or the account lapses, the scene fails. `react-spline` 4.1.0 rethrows a failed
  load during render, so the error boundary from `webgl-3d.md` is what keeps the poster. Spline's
  runtime README says to "download the .splinecode file and self-host it" (point `wasmPath` at
  self-hosted WASM too — the default is `https://cdn.spline.design/@splinetool/runtime@<version>/build`),
  and its pricing page lists "Code & Self-hosted exports" among Enterprise features — check the
  plan before promising it. Unicorn loads a self-hosted JSON via `data-us-project-src`/`filePath`;
  "JSON export" is listed on its paid Legend plan, not Free.
- **Plan terms** (pricing pages, 2026-09-26). Spline Free: "Web exports with watermark"; paid
  tiers: "No watermark on web exports". Unicorn Free: "Up to 8 publishes with Unicorn branding"
  and "Personal and non-commercial use"; Legend: "Unlimited publishes without logo watermark",
  "Commercial license". A company site on Unicorn's free plan is outside its use terms, not merely
  branded. Record host, plan and watermark status on the provenance record
  (`plugins/craft-layer/skills/asset-sourcing/references/licence-discipline.md`).
- **Licences.** The Unicorn SDK is proprietary: "Permission is granted to use this software only
  for integration with legitimate Unicorn Studio projects." The `@splinetool/*` packages publish
  no licence field on npm. Paper Shaders is Apache-2.0 and allows commercial use "without visible
  attribution".
- **CSP.** Allow each host in the directive that governs its request: `script-src` for a runtime
  loaded from a CDN (`cdn.spline.design` for `<spline-viewer>`, `cdn.jsdelivr.net` for the Unicorn
  SDK tag); `connect-src` for the scene file and WASM fetches (`prod.spline.design`,
  `cdn.spline.design`); `'wasm-unsafe-eval'` in `script-src` when the runtime loads WASM, or
  "WebAssembly is blocked from loading and executing" (MDN). The Unicorn build references
  `assets.unicorn.studio` and `storage.googleapis.com/unicornstudio-production` for scene
  assets — allow whichever directive the console's CSP report names. `react-spline/next` also
  needs server egress to `*.spline.design`. A preset library needs none of this.

Standing: agent-graded for the provenance record (the craft reviewer's licence gate); recorded
for availability and CSP.

## Versions: pin exactly

- **Paper Shaders is 0.0.x and says so:** "Please pin your dependency – we will ship breaking
  changes under 0.0.x versioning". 0.0.81 renamed and removed Paper Texture parameters. Install
  with `--save-exact`; a `~0.0.x` range admits breaking releases.
- **`@splinetool/runtime` shipped 57 releases in 36 days** (2.0.1 on 2026-08-20 to 2.0.58 on
  2026-09-25), and `@splinetool/react-spline` accepts any runtime (`"*"` peer). Pin the runtime
  exactly and upgrade on purpose.
- **CDN URLs carry the version.** Unicorn's embed guide pins `unicornstudio.js@v2.3.0`.
  `<spline-viewer>`'s quickstart URL is unpinned; its README says "pin a version with
  `@splinetool/viewer@<version>`". An unpinned URL changes under the page with no deploy.

Standing: recorded.

## Official vs community React wrappers

| runtime | wrapper | publisher |
|---|---|---|
| Spline | `@splinetool/react-spline` 4.1.0 | Spline's npm maintainers; last release 2025-07-15, while the runtime releases almost daily |
| Unicorn Studio | `unicornstudio-react` 2.2.13 | a community author — Unicorn's embed guide calls it "unofficial". MIT, but it bundles the proprietary SDK, whose licence still applies |
| Paper Shaders | `@paper-design/shaders-react` 0.0.81 | the vendor, from the same monorepo as vanilla `@paper-design/shaders` |

A community wrapper can lag the SDK it wraps: `unicornstudio-react` 2.2.13 embeds SDK 2.2.13 while
the official tag is at 2.3.0. Unicorn's official path is the SDK itself (`UnicornStudio.addScene`).
Record which one shipped. Standing: recorded.

## Weight — measure yours; these are one measurement

Measured 2026-09-26 with `gzip -9`, over the npm tarballs and an esbuild 0.28.2 minified bundle
with React external. The scene file is extra and differs per scene — read it in the network panel.

| what | gzip |
|---|---|
| `@splinetool/react-spline` 4.1.0 + `@splinetool/runtime` 2.0.58, static import closure | 281 KB in 42 chunks; 1,095 KB over all 110 emitted chunks, fetched as a scene's features need them |
| Spline feature WASM, e.g. `physics.wasm` (only when the scene uses physics) | 570 KB |
| `<spline-viewer>` 2.0.58, `spline-viewer.js` (WebGPU + WebGL) | 961 KB; `.webgl.js` 641 KB, `.webgpu.js` 773 KB |
| Unicorn SDK `unicornStudio.umd.js` v2.3.0 | 53 KB |
| `unicornstudio-react` 2.2.13, `dist/index.mjs` (bundles the SDK) | 227 KB |
| `@paper-design/shaders-react` 0.0.81, one `MeshGradient` | 8 KB |

Record the measured KB on the build task's `Motion:` line like any tier-3 surface; the budget is
`tier-budgets.md`'s. Standing: agent-graded — the craft audit injects measured chunk weight and the
reviewer judges it against the tier budget; nothing re-measures the rows above.
