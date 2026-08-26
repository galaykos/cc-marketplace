---
name: motion-tiers
description: Use when deciding HOW to animate a web-app surface — Framer Motion vs anime.js vs Three.js/R3F vs sprite-sheets — or when a motion review flags a missing perf budget, prefers-reduced-motion path, or reduced-bundle fallback.
---

## What this decides

This skill picks the animation TIER for a surface and pins its budget; it does not
re-teach any library's API. Idioms live elsewhere — reference them by path:

- Motion / GSAP / anime.js idioms: `plugins/ui-ux/skills/motion-best-practices/SKILL.md`
  (+ `plugins/ui-ux/skills/motion-best-practices/references/animejs.md`).
- Three.js / R3F correctness: `plugins/threejs/skills/threejs-best-practices/SKILL.md`.
- Sprite-sheet authoring detail: `references/sprite.md`.

The net-new value here is the taxonomy, the per-tier budgets, the framework bindings,
and the two mandatory fallbacks. Every tier ships BOTH a `prefers-reduced-motion` path
AND a reduced-bundle fallback — no exceptions. Record the chosen tier and its measured
bundle-KB per surface so the craft audit can check the choice against its budget.

## Pick a tier

Answer in order; take the first that fits the surface:

1. Looping frame-by-frame character / mascot / pixel motion? → **Sprites** (tier 4).
2. Real 3D, a WebGL background, or a product viewer? → **3D / WebGL** (tier 3) —
   budget-gated, lazy-loaded, static fallback (see `references/webgl-3d.md`).
3. Have (or want) a designer-authored `.lottie` / `.riv` asset, or an interactive
   state-machine vector? → **Vector** (tier 5) — a shipped Lottie/Rive beats
   hand-coding the same motion (see `references/vector.md`).
4. Multi-step timeline, SVG draw/morph, or a choreographed hero sequence? →
   **Timeline / SVG** (tier 2).
5. React / Vue UI state, layout shift, gesture, exit, or micro-interaction? →
   **UI state / layout** (tier 1).
6. Two-state fade/slide with no orchestration? → no tier — CSS transitions
   (`motion-best-practices`), the cheapest path.

Cheapest-that-fits is right for ordinary surfaces, wrong for the ONE carrying the concept's
SIGNATURE interaction — that surface is picked by what the MOVE needs, not by what is cheapest.
One writer per property per element: never point two tiers at the same `transform`.
Full table: `references/tier-budgets.md` — SOURCE OF TRUTH for every KB figure below and
the `Last verified:` date; fix drift there, then mirror here. Standing: KB figures
are **gate** (`pc_source_of_truth`); prose agreement is **recorded** — nothing reads meaning.

## The five tiers (one line each)

- **Tier 1 — UI state / layout** (Framer Motion, `motion/react`): React / Next UI
  state, layout, gestures, exit. Budget ≈ 34KB gzip full or ~2.6KB `motion/mini`;
  compositor-only (transform + opacity), FLIP for layout. reduced-motion:
  `<MotionConfig reducedMotion="user">` or `useReducedMotion()` crossfade.
  reduced-bundle: `LazyMotion`+`m.*` in React; `motion/mini` is for vanilla tweens.
- **Tier 2 — Timeline / SVG** (anime.js v4, `animejs` ESM): imperative timelines, SVG
  draw/morph, staggered hero sequences; framework-neutral. Budget ≈ 10–15KB gzip
  tree-shaken; main-thread JS (use `waapi.animate` for off-thread). reduced-motion:
  `createScope` media-query branch to `utils.set(finalState)`. reduced-bundle: import
  only the named exports you use, or the `waapi` variant / CSS keyframes for loops.
- **Tier 3 — 3D / WebGL** (Three.js / R3F, `three`, `@react-three/fiber`): 3D hero,
  WebGL background, product viewer. Budget ≈ 150KB+ gzip — NEVER in the initial bundle;
  lazy-load on viewport / interaction; GPU cost gated by render-on-demand, DPR ≤ 2,
  disposal, and a loop paused off-screen. reduced-motion: freeze the loop, one static frame.
  reduced-bundle: a static hero image or `<video poster>`; the 3D chunk loads only
  when visible.
- **Tier 4 — Sprites / sprite-sheets**: looping character / mascot motion. Budget ≈
  one packed WebP/AVIF sheet ≤ 150KB; CSS `steps()` or a `requestAnimationFrame` loop
  — compositor-cheap. reduced-motion: pause on a single poster frame. reduced-bundle:
  ship the static poster frame and defer the sheet. Authoring detail: `references/sprite.md`.
- **Tier 5 — Vector** (Lottie / Rive): designer-authored vector motion. Lottie
  (`@lottiefiles/dotlottie-react`) = timeline playback; Rive (`@rive-app/react-canvas`)
  = interactive state-machine. Budget ≈ the `.lottie`/`.riv` asset size + player
  runtime; lazy-load the asset and player. reduced-motion: render a static poster
  frame. reduced-bundle: ship a poster image and lazy-load the asset. Lottie-vs-Rive,
  budget, and both fallbacks: `references/vector.md`.

## Framework binding (one line)

Bind each tier to the stack's idiomatic tool: Framer Motion → React / Next; `motion-v`
or `@vueuse/motion` → Vue / Nuxt; anime.js, Three.js, and sprites are framework-neutral
(any stack); Laravel drives motion through Inertia-React (Framer Motion) or
Livewire + Alpine (CSS / anime.js). Full matrix: `references/framework-bindings.md`.

## The two mandatory fallbacks

Every surface answers both, or it does not ship:

- **prefers-reduced-motion** — remove movement (translation, scale, parallax, spin,
  autoplay); keep at most an opacity crossfade or a static final frame. Accessibility
  requirement, not polish. In JS this is a SUBSCRIPTION, never a one-time `.matches`
  read at mount — `motion-best-practices` owns that mechanism and the CSS kill-switch;
  what this skill requires is that every tier on the page honors it the same way.
- **reduced-bundle** — a lighter path when the tier's KB is not affordable (slow
  network, low-end device, or a surface below the fold): drop to CSS, to `motion/mini`,
  or to a static image. Tiers 3 and 4 make this the DEFAULT initial render and upgrade
  progressively once the heavy chunk is affordable. Measure the fallback path too — a
  fallback that still ships the full tier bundle is not a reduced-bundle path.

## Cross-cutting decisions

These apply on top of the chosen tier, on every surface:

- **RTL / BiDi** — on a right-to-left target, mirror direction-bearing motion (scroll,
  marquee, entrance, parallax, horizontal-scroll), but keep charts, numerals, and code as
  LTR-islands (`dir="ltr"`). Full decision + reuse of the i18n base rules:
  `references/rtl-bidi.md`.
- **Cumulative motion budget** — budget the COMBINED initial motion JS, not each tier
  alone; baseline is Lenis + ScrollTrigger + one tier, and every extra eager engine
  (a second tier, physics, WebGL) justifies its weight or lazy-loads. Rule:
  `references/tier-budgets.md`.
- **Reveal default = fallback-safe** — a scroll/enter reveal starts VISIBLE and hides only
  once JS confirms it can reveal (then observe); never ship a bare observer-gated
  `opacity:0`. See `references/gotchas.md`.

## GSAP and sibling skills

GSAP is not a motion tier: its element animation is one alternative inside
`motion-best-practices`, and its ScrollTrigger is the engine owned by the sibling
`scroll-orchestration` skill — scroll-driven sequencing is a different job from
picking a per-surface tier. Two sibling craft skills layer on top of a chosen tier:

- `scroll-orchestration` — scroll-linked reveals, pinning, and ScrollTrigger / Lenis
  choreography across a page.
- `kinetic-typography` — text-as-motion (split-text, variable-font, letter staggers).

## References

- `references/reduced-motion.md` — the gate MECHANISM stated once (gate both layers; check `matchMedia` before starting, not inside the loop). Six sibling skills cite it for their own paths.
- `references/vector.md` — Lottie (timeline) vs Rive (state-machine), the Tier-5
  budget, the `prefers-reduced-motion` poster path, and the reduced-bundle lazy path.
- `references/tier-budgets.md` — the full per-tier table: when / bundle-KB / runtime /
  both fallbacks.
- `references/sprite.md` — Tier-4 authoring: sheet layout, `steps()` and rAF loops, poster fallback, size budget.
- `references/framework-bindings.md` — the tool→framework binding matrix for every
  named stack (React, Next, Vue, Nuxt, Laravel via Inertia or Livewire).
- `references/webgl-3d.md` — the 3D lazy-load + static-fallback rules; cites
  `plugins/threejs/skills/threejs-best-practices/SKILL.md` for R3F correctness.
- `references/gotchas.md` — tool-usage traps that break real builds: gradient-clip on
  split text, whileInView with no fallback, split-text aria, one-writer, scroll-link.
- `references/rtl-bidi.md` — the RTL/BiDi decision: which effects mirror vs the
  LTR-islands (charts, numerals, code); states the four-rule base floor itself.

## Anti-patterns

- **No budget** — shipping a tier without a named bundle-KB + runtime ceiling; the
  budget is what makes the choice reviewable and is what the audit checks.
- **Three.js in the initial bundle** — 150KB+ of WebGL blocking first paint with no
  lazy-load and no static fallback.
- **A tier with one fallback** — reduced-motion but no reduced-bundle path, or the
  reverse. Both are mandatory on every surface.
- **Two tiers on one element** — two engines writing `transform`; one writer per property.
- **Re-teaching the library** — copying Motion / anime / R3F recipes here instead of
  referencing `motion-best-practices` / `threejs-best-practices` by path.
- **GSAP as a tier** — an alternative inside `motion-best-practices`, not one of these
  five tiers; its ScrollTrigger belongs to `scroll-orchestration`.
- **Bare whileInView reveal** — `opacity:0` gated only on an observer; invisible with
  JS off, in a prerender, or a screenshot. Default fallback-safe — `references/gotchas.md`.
