---
name: motion-tiers
description: Use when deciding HOW to animate a web-app surface — choosing between Framer Motion, anime.js, Three.js/R3F, or sprite-sheets, or when a motion review flags a missing perf budget, prefers-reduced-motion path, or reduced-bundle fallback. Picks a tier per surface + framework, sets a bundle-KB and runtime budget, and mandates reduced-motion and reduced-bundle fallbacks; reuses motion-best-practices and threejs-best-practices idioms.
---

## What this decides

This skill picks the animation TIER for a surface and pins its budget; it does not
re-teach any library's API. Idioms live elsewhere — reference them by path:

- Motion / GSAP / anime.js idioms: `plugins/ui-ux/skills/motion-best-practices/SKILL.md`
  (+ `plugins/ui-ux/skills/motion-best-practices/references/animejs.md`).
- Three.js / R3F correctness: `plugins/threejs/skills/threejs-best-practices/SKILL.md`.
- Sprite-sheet authoring detail: the `sprite-motion` skill.

The net-new value here is the taxonomy, the per-tier budgets, the framework bindings,
and the two mandatory fallbacks. Every tier ships BOTH a `prefers-reduced-motion` path
AND a reduced-bundle fallback — no exceptions. Record the chosen tier and its measured
bundle-KB per surface so the craft audit can check the choice against its budget.

## Pick a tier

Answer in order; take the first that fits the surface:

1. Looping frame-by-frame character / mascot / pixel motion? → **Sprites** (tier 4).
2. Real 3D, a WebGL background, or a product viewer? → **Three.js / R3F** (tier 3) —
   budget-gated, lazy-loaded, static fallback (see `references/webgl-3d.md`).
3. Have (or want) a designer-authored `.lottie` / `.riv` asset, or an interactive
   state-machine vector? → **Vector** (tier 5) — a shipped Lottie/Rive beats
   hand-coding the same motion (see `references/vector.md`).
4. Multi-step timeline, SVG draw/morph, or a choreographed hero sequence? →
   **anime.js** (tier 2).
5. React / Vue UI state, layout shift, gesture, exit, or micro-interaction? →
   **Framer Motion** (tier 1).
6. Two-state fade/slide with no orchestration? → no tier — CSS transitions
   (`motion-best-practices`), the cheapest path.

One writer per property per element: never point two tiers at the same `transform`.
Full decision table with budgets: `references/tier-budgets.md`.

## The five tiers (one line each)

- **Tier 1 — Framer Motion** (Motion, `motion/react`): React / Next UI state, layout,
  gestures, exit. Budget ≈ 34KB gzip full or ~2.6KB `motion/mini`; compositor-only
  (transform + opacity), FLIP for layout. reduced-motion: `<MotionConfig
  reducedMotion="user">` or `useReducedMotion()` crossfade. reduced-bundle:
  `animate()` from `motion/mini`, or plain CSS for simple tweens.
- **Tier 2 — anime.js v4** (`animejs`, ESM): imperative timelines, SVG draw/morph,
  staggered hero sequences; framework-neutral. Budget ≈ 10–15KB gzip tree-shaken;
  main-thread JS (use `waapi.animate` for off-thread). reduced-motion: `createScope`
  media-query branch to `utils.set(finalState)`. reduced-bundle: import only the named
  exports you use, or the `waapi` variant / CSS keyframes for simple loops.
- **Tier 3 — Three.js / R3F** (`three`, `@react-three/fiber`): 3D hero, WebGL
  background, product viewer. Budget ≈ 150KB+ gzip — NEVER in the initial bundle;
  lazy-load on viewport / interaction; GPU cost gated by render-on-demand, DPR ≤ 2,
  and disposal. reduced-motion: freeze the loop, render one static frame.
  reduced-bundle: a static hero image or `<video poster>`; the 3D chunk loads only
  when visible.
- **Tier 4 — Sprites / sprite-sheets**: looping character / mascot motion. Budget ≈
  one packed WebP/AVIF sheet ≤ 150KB; CSS `steps()` or a `requestAnimationFrame` loop
  — compositor-cheap. reduced-motion: pause on a single poster frame. reduced-bundle:
  ship the static poster frame and defer the sheet. Authoring detail: `sprite-motion`.
- **Tier 5 — Vector (Lottie / Rive)**: designer-authored vector motion. Lottie
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
  autoplay); keep at most an opacity crossfade or a static final frame. Gate in JS with
  `matchMedia("(prefers-reduced-motion: reduce)")` before animating. This is an
  accessibility requirement, not polish — `motion-best-practices` owns the CSS
  kill-switch.
- **reduced-bundle** — a lighter path when the tier's KB is not affordable (slow
  network, low-end device, or a surface below the fold): drop to CSS, to `motion/mini`,
  or to a static image. Tiers 3 and 4 make this the DEFAULT initial render and upgrade
  progressively once the heavy chunk is affordable. Measure the fallback path too — a
  fallback that still ships the full tier bundle is not a reduced-bundle path.

## GSAP and sibling skills

GSAP is not a motion tier: its element animation is one alternative inside
`motion-best-practices`, and its ScrollTrigger is the engine owned by the sibling
`scroll-orchestration` skill — scroll-driven sequencing is a different job from
picking a per-surface tier. Two sibling craft skills layer on top of a chosen tier:

- `scroll-orchestration` — scroll-linked reveals, pinning, and ScrollTrigger / Lenis
  choreography across a page.
- `kinetic-typography` — text-as-motion (split-text, variable-font, letter staggers).

## References

- `references/vector.md` — Lottie (timeline) vs Rive (state-machine), the Tier-5
  budget, the `prefers-reduced-motion` poster path, and the reduced-bundle lazy path.
- `references/tier-budgets.md` — the full per-tier table: when / bundle-KB / runtime /
  reduced-motion fallback / reduced-bundle fallback.
- `references/framework-bindings.md` — the tool→framework binding matrix for every named
  stack (React, Next, Vue, Nuxt, Laravel via Inertia, Laravel via Livewire).
- `references/webgl-3d.md` — the 3D lazy-load + static-fallback rules; cites
  `plugins/threejs/skills/threejs-best-practices/SKILL.md` for R3F correctness.
- `references/gotchas.md` — tool-usage traps that break real builds: gradient-clip on
  split text (invisible), whileInView reveals with no fallback, split-text aria,
  one-writer-per-property, scroll-link contract.

## Anti-patterns

- **No budget** — shipping a tier without a named bundle-KB + runtime ceiling; the
  budget is what makes the choice reviewable and is what the audit checks.
- **Three.js in the initial bundle** — 150KB+ of WebGL blocking first paint with no
  lazy-load and no static fallback.
- **A tier with one fallback** — a reduced-motion path but no reduced-bundle path (or
  the reverse). Both are mandatory on every surface.
- **Two tiers on one element** — Framer Motion and anime.js both writing `transform`;
  choose one writer per property.
- **Re-teaching the library** — copying Motion / anime / R3F API recipes into this skill
  instead of referencing `motion-best-practices` / `threejs-best-practices` by path.
- **GSAP as a tier** — GSAP is an alternative inside `motion-best-practices`, not one of
  these five decision tiers; its ScrollTrigger belongs to `scroll-orchestration`.
