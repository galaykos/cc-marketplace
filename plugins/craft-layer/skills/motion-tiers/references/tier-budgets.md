# Motion-tier budgets — the full per-tier table

> **Last verified: 2026-07-25.** Every KB figure and package name below has a shelf
> life — runtimes are rewritten, players are replaced, and a stale number here is worse
> than no number because it is quoted with confidence. This table once claimed the Rive
> runtime was lighter than lottie-web when it is roughly three times heavier. Re-verify
> against the library's own docs/changelog before quoting a literal, and move this date
> when you do.
>
> The KB figures are gzipped order-of-magnitude planning budgets, not guarantees —
> measure the real number from your bundle analyzer per surface and record it.

Library idioms are NOT repeated here. This is the DECISION table only:

- Motion / GSAP / anime.js API: `plugins/ui-ux/skills/motion-best-practices/SKILL.md`
  (+ `plugins/ui-ux/skills/motion-best-practices/references/animejs.md`).
- Three.js / R3F correctness: `plugins/threejs/skills/threejs-best-practices/SKILL.md`.
- Sprite-sheet authoring: the `sprite-motion` skill.

## A tier is named for the job, not the package that currently does it

Tiers 1–3 used to be called *Framer Motion*, *anime.js*, and *Three.js / R3F* — the
occupant WAS the name. That is a catalog wearing a taxonomy's clothes, and it fails in a
specific way: when a package is superseded, a library name is a fact you re-verify and
re-date, but a library name that IS the taxonomy slot invalidates the vocabulary every
other file speaks. Nine files across this plugin refer to these tiers.

The durable axis is what a tier is FOR — declarative UI state, imperative timeline, real
3D, raster frame sequence, authored vector data. Those five hold whatever ships next. So
the row reads `capability (occupant)`: the capability picks the tier, the occupant is the
current best answer inside it and is subject to the `Last verified` date above. Tiers 4
and 5 were already written this way, which is what made the inconsistency visible.

Replacing an occupant is a normal re-verification. Adding or removing a TIER is a change
to the decision itself and needs the argument that a sixth job exists.

## The table

| Tier | When to use | Bundle-KB (gzip) | Runtime cost | prefers-reduced-motion fallback | reduced-bundle fallback |
| --- | --- | --- | --- | --- | --- |
| **1 — UI state / layout** (Framer Motion — `motion`, `motion/react`) | React / Next UI state, layout animation, gestures, exit / enter transitions, micro-interactions | ≈ 34KB full; ≈ 2.6KB `motion/mini` `animate()` | Compositor-only (transform + opacity); layout via FLIP; no per-frame React state | `<MotionConfig reducedMotion="user">` tree-wide, or `useReducedMotion()` → opacity crossfade / final state | `animate()` from `motion/mini`, or plain CSS transitions for two-state tweens |
| **2 — Timeline / SVG** (anime.js v4 — `animejs`, ESM) | Imperative multi-step timelines, SVG draw / morph / motion-path, staggered hero choreography; framework-neutral | ≈ 10–15KB tree-shaken (named imports only) | Main-thread JS tween loop; `waapi.animate` runs off the main thread on WAAPI | `createScope({ mediaQueries: { reduced: '(prefers-reduced-motion: reduce)' } })` → `utils.set(target, finalState)` | Import only used named exports; `waapi` variant or CSS `@keyframes` for simple loops |
| **3 — 3D / WebGL** (Three.js / R3F — `three`, `@react-three/fiber`, `drei`) | Real 3D, WebGL background, product / model viewer, shader hero | ≈ 150KB+ core, more with R3F + drei — NEVER in the initial bundle; lazy-load only | GPU-bound; render-on-demand (no idle rAF), `setPixelRatio(min(dpr,2))`, dispose on unmount | Freeze `setAnimationLoop`, render one static frame (or swap to the poster image) | Static hero image / `<video poster>` as initial render; load the 3D chunk on viewport / interaction only. See `webgl-3d.md` |
| **4 — Sprites / sprite-sheets** | Looping frame-by-frame character / mascot / pixel-art motion | ≈ one packed WebP/AVIF sheet ≤ 150KB (budget per sheet, not per frame) | Compositor-cheap: CSS `steps()` on `background-position`, or a throttled `requestAnimationFrame` frame advance | Pause the loop on a single poster frame (`animation-play-state: paused` / stop rAF) | Ship the static poster frame; defer the full sheet until idle / visible. Authoring: `sprite-motion` |
| **5 — Vector** (Lottie / Rive) | Designer-authored illustrative motion — icons, mascots, empty states, onboarding loops — shipped as data rather than code | Runtime varies by player and is NOT interchangeable: `@lottiefiles/dotlottie-web` ≈ 50KB gz, `lottie-web` ≈ 60KB gz, `@rive-app/canvas` ≈ 200KB gz (it bundles a WASM renderer — the heaviest, not the lightest). PLUS the animation file: budget **≤ 100KB per animation**, and lazy-load the runtime | Main-thread SVG/canvas playback; canvas renderer over SVG for anything with many shapes; one player per surface | Stop the player and render the first/rest frame as a static poster | Export a static SVG/PNG of the rest frame and skip the runtime entirely below the fold. Detail: `vector.md` |

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

## The frame-sequence budget (a scroll act's images, not its JS)

A scroll-scrubbed frame sequence is not tier 4. Tier 4 is a fixed-fps LOOP that ships as one
packed sheet; a scrubbed sequence is a run of separately decoded frames indexed by scroll
progress, and it is charged in a different currency. **These caps are POLICY, not measured
library facts** — the `Last verified` date above governs KB figures and package names, and does
not move for a decision. Both budgets bind independently: the cumulative budget above meters
motion JS, this one meters images, and neither buys the other.

| What | Cap |
| --- | --- |
| Total transferred, whole sequence | ≤ 1.5 MB |
| Frame count | ≤ 90 frames |
| Format | AVIF primary, WebP fallback |
| Longest edge | ≤ 1600 px |
| Decode-ahead window | ≤ 8 frames held as `ImageBitmap` |
| Fetch start | not before the act is within one viewport of entry |

Over cap, the remedy is **fewer frames across the same scroll range** — never a longer
download. The mechanism, the `save-data` opt-out, the mid-sequence failure behaviour, the
`ImageBitmap` release rule and the two distinct static states live in
`plugins/craft-layer/skills/scroll-orchestration/references/scroll-acts.md`. This file owns the
numbers only.

## Not a tier

GSAP is deliberately absent: it is a powerful alternative for complex imperative
timelines and ScrollTrigger scenes, but it lives as an option inside
`motion-best-practices`, not as one of these craft decision tiers. Do not add a row
for it.

**Licensing note (it changed).** GSAP is now free for commercial and non-commercial use,
including the plugins that were formerly paid — SplitText, MorphSVG, and the rest of the
old Club GreenSock set — under a licence effective 2025-04-30. Two consequences: do not
plan around a paid tier or avoid SplitText on cost grounds (`kinetic-typography` may
assume it), and note the one carve-out — the licence excludes using GSAP to build a
no-code visual animation tool competing with its owner's. Re-check the current licence
text before relying on this; it is a snapshot.
