# Motion-tier budgets — the full per-tier table

> The KB figures are gzipped order-of-magnitude planning budgets, not guarantees —
> measure the real number from your bundle analyzer per surface and record it. Verify
> current package sizes at bundlephobia.com / the library's docs before quoting a literal.

Library idioms are NOT repeated here. This is the DECISION table only:

- Motion / GSAP / anime.js API: `plugins/ui-ux/skills/motion-best-practices/SKILL.md`
  (+ `plugins/ui-ux/skills/motion-best-practices/references/animejs.md`).
- Three.js / R3F correctness: `plugins/threejs/skills/threejs-best-practices/SKILL.md`.
- Sprite-sheet authoring: the `sprite-motion` skill.

## The table

| Tier | When to use | Bundle-KB (gzip) | Runtime cost | prefers-reduced-motion fallback | reduced-bundle fallback |
| --- | --- | --- | --- | --- | --- |
| **1 — Framer Motion** (`motion`, `motion/react`) | React / Next UI state, layout animation, gestures, exit / enter transitions, micro-interactions | ≈ 34KB full; ≈ 2.6KB `motion/mini` `animate()` | Compositor-only (transform + opacity); layout via FLIP; no per-frame React state | `<MotionConfig reducedMotion="user">` tree-wide, or `useReducedMotion()` → opacity crossfade / final state | `animate()` from `motion/mini`, or plain CSS transitions for two-state tweens |
| **2 — anime.js v4** (`animejs`, ESM) | Imperative multi-step timelines, SVG draw / morph / motion-path, staggered hero choreography; framework-neutral | ≈ 10–15KB tree-shaken (named imports only) | Main-thread JS tween loop; `waapi.animate` runs off the main thread on WAAPI | `createScope({ mediaQueries: { reduced: '(prefers-reduced-motion: reduce)' } })` → `utils.set(target, finalState)` | Import only used named exports; `waapi` variant or CSS `@keyframes` for simple loops |
| **3 — Three.js / R3F** (`three`, `@react-three/fiber`, `drei`) | Real 3D, WebGL background, product / model viewer, shader hero | ≈ 150KB+ core, more with R3F + drei — NEVER in the initial bundle; lazy-load only | GPU-bound; render-on-demand (no idle rAF), `setPixelRatio(min(dpr,2))`, dispose on unmount | Freeze `setAnimationLoop`, render one static frame (or swap to the poster image) | Static hero image / `<video poster>` as initial render; load the 3D chunk on viewport / interaction only. See `webgl-3d.md` |
| **4 — Sprites / sprite-sheets** | Looping frame-by-frame character / mascot / pixel-art motion | ≈ one packed WebP/AVIF sheet ≤ 150KB (budget per sheet, not per frame) | Compositor-cheap: CSS `steps()` on `background-position`, or a throttled `requestAnimationFrame` frame advance | Pause the loop on a single poster frame (`animation-play-state: paused` / stop rAF) | Ship the static poster frame; defer the full sheet until idle / visible. Authoring: `sprite-motion` |
| **5 — Vector** (Lottie / Rive) | Designer-authored illustrative motion — icons, mascots, empty states, onboarding loops — shipped as data rather than code | Runtime ≈ 35–60KB gz (`lottie-web` full ≈ 60KB, `dotlottie`/`@rive-app/canvas` lighter) PLUS the animation file: budget **≤ 100KB per animation**, and lazy-load the runtime | Main-thread SVG/canvas playback; canvas renderer over SVG for anything with many shapes; one player per surface | Stop the player and render the first/rest frame as a static poster | Export a static SVG/PNG of the rest frame and skip the runtime entirely below the fold. Detail: `vector.md` |

## Reading the budget

- **Bundle-KB** is the gate for tier CHOICE: if the surface cannot afford the tier's KB
  on its target network, the reduced-bundle column IS the shipping default and the tier
  is a progressive upgrade — this is the rule for tiers 3 and 4 always.
- **Runtime cost** is the gate for tier CORRECTNESS: staying on the compositor (tiers
  1, 2, 4) or on-demand + disposed on the GPU (tier 3) is what keeps the tier within
  frame budget. The owning skills hold the how.
- **Both fallback columns are mandatory** — a surface that fills only one has not met
  the tier contract. reduced-motion is an accessibility requirement; reduced-bundle is a
  performance requirement. They are different axes and neither substitutes for the other.

## The cumulative budget (combined motion JS)

Per-tier KB is necessary but not sufficient — real surfaces combine tiers AND the sibling
engines (scroll-orchestration's Lenis + ScrollTrigger, physics-motion, motion-sequencing,
webgl-effects). Budget the COMBINED initial motion JS, not each piece alone:

- **Baseline** for a motion-rich page: Lenis + ScrollTrigger + ONE tier. That is the
  affordable default.
- **Every additional EAGER engine** — a second tier, physics (matter.js), sequencing
  (`@theatre/core`), WebGL (three) — must justify its weight or **lazy-load off the
  critical path** (on viewport / interaction, as tier 3 always does).
- If the hero does not need an engine, do not ship it eagerly for a below-the-fold
  surface — split it out and load on approach.
- No fixed ceiling: measure the combined initial motion JS per build against the target
  network. The rule is "one heavy engine eager, the rest lazy" — not a magic number.

## Not a tier

GSAP is deliberately absent: it is a powerful alternative for complex imperative
timelines and ScrollTrigger scenes, but it lives as an option inside
`motion-best-practices`, not as one of these craft decision tiers. Do not add a row
for it.
