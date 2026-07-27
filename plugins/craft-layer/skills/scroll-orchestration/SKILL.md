---
name: scroll-orchestration
description: Use when adding smooth scroll, scroll-linked reveals, scrub, pin, or parallax to a web surface, or when a motion review flags scroll drift/jitter, a missing smooth-scroll contract, or a scroll effect with no reduced-motion path. Decides whether scroll motion earns its cost and which engine — a Lenis substrate feeding GSAP ScrollTrigger, or a native CSS scroll-driven reduced-bundle path — sets a KB budget, and mandates one scroll contract plus a prefers-reduced-motion path.
---

## What this decides

This skill decides WHETHER a surface needs orchestrated scroll motion and WHICH
ScrollTrigger API: scrub, pin, parallax, one-trigger-per-scene, `.refresh()`,
cleanup, and `gsap.matchMedia()` already live in
`plugins/ui-ux/skills/motion-best-practices/references/gsap.md` — reference by path,

**GSAP reconciliation:** GSAP is NOT a motion tier. Element and UI animation is a
tier choice in `plugins/craft-layer/skills/motion-tiers/SKILL.md`. GSAP — via
ScrollTrigger — IS the scroll-orchestration engine. Different jobs: pick a tier for
the element, pick a scroll engine for the page. Do not list GSAP as a fifth tier.

## Decide: does scroll motion earn its cost?

Answer before adding anything; take the first that fits the surface:

1. Content is read top-to-bottom with no choreography? → **no orchestration.** Native
   scroll. Do not add a smooth-scroll lib to "feel premium" — it taxes every device
   for nothing. The evidence runs against it: NN/g's scrolljacking study found most
   participants at least mildly disoriented, worse on mobile and worse the longer the
   hijacked run — risky even when well executed. Smoothed scroll is earned by
   choreography that needs it, kept off touch (`syncTouch` OFF) and off long runs.
2. A few reveal-on-enter sections, no scrubbing? → **no engine.** Native scroll + CSS
   scroll-driven reveals (`references/css-scroll-driven.md`) or an
   IntersectionObserver reveal — the cheapest path, zero runtime.
3. Scrubbed timelines, pinned scenes, or parallax bound to scroll progress? →
   **Lenis substrate feeding GSAP ScrollTrigger** — one contract, one engine.
4. A reduced-bundle build, or the scrub is a single transform? → stay on **native CSS
   scroll-driven** (`animation-timeline: scroll()` / `view()`) and skip the JS.

`animation-timeline` is **not Baseline** (MDN: limited availability; absent from a major
engine). Options 2 and 4 still stand — the `@supports` + visible-base-rule authoring in
`references/css-scroll-driven.md` degrades to the static end state — but treat CSS
scroll-driven as a PROGRESSIVE ENHANCEMENT, never a universal engine: no meaning may
live in motion the static state loses.

Full decision: `references/orchestration-decision.md`. What a scrubbed or pinned scene can
BE — pinned act, frame sequence, revealed panel — plus their budgets: `references/scroll-acts.md`.

## The single scroll contract (one source of truth)

Native scroll, a smooth-scroll lib, and scroll-driven animation each reading a
different scroll position drift and jitter. Choose ONE contract and never mix:

- **Native scroll + CSS scroll-driven animations** — no JS scroll loop; the browser
  is the single source of truth. This is the reduced-bundle default.
- **One smooth-scroll lib (Lenis) feeding one animation engine (ScrollTrigger)** —
  Lenis owns the scroll position and ScrollTrigger reads it, so both agree.

Never run Lenis AND native-driven CSS scroll timelines on the same axis. The full
failure mode (scroll-linked motion without a smooth-scroll contract) lives in
`plugins/craft-layer/skills/motion-tiers/references/gotchas.md` — apply it, do not
re-bake it here.

## Lenis — the smooth-scroll substrate

Lenis (`lenis`, ≈ 3KB gzip) is the net-new substrate: it lerps native scroll into a
smoothed position the animation engine reads, without hijacking the scrollbar or
breaking anchor links and keyboard scroll.

- Instantiate once per app and drive its `raf(time)` from a single loop (or GSAP's
  `ticker`) — never two loops.
- Tune feel with `lerp` (≈ 0.1) OR `duration`, not both; higher lerp = snappier.
- Feed ScrollTrigger from the same loop so both read one position — this IS the
  contract above.
- Sticky-safe: Lenis transforms scroll, not layout, so `position: sticky` and
  `position: fixed` keep working. Never wrap the page in a transformed container to
  fake smoothing — that breaks `sticky` and every pinned ScrollTrigger.
- Resync on SPA route change: a client-side navigation can desync Lenis from native
  scroll (a collapsing pin-spacer is the usual cause), so reset BOTH in a rAF and call
  `ScrollTrigger.refresh()`. This is the seam with `page-transitions`; the full rule is
  the SPA-route-change gotcha in
  `plugins/craft-layer/skills/motion-tiers/references/gotchas.md` — apply it, do not
  re-bake it.

## Choose the engine

- **Lenis + ScrollTrigger** — scrub, pin, parallax, choreographed scroll scenes.
  Budget: Lenis ≈ 3KB + GSAP/ScrollTrigger (sized in gsap.md); a JS scroll loop on
- **Native CSS scroll-driven** — `animation-timeline: scroll()` / `view()` runs the
  animation off the main thread with zero JS. The reduced-bundle path; degrades to a
  static final state where unsupported. Detail: `references/css-scroll-driven.md`.


Any scroll reveal MUST stay readable with the animation stripped out — no-JS,
prerender, print, a full-page screenshot, or an observer that never fires. The
reveal-with-fallback pattern (start visible, hide only once JS is confirmed; pair a
once-fired reveal with a safety timeout) lives in
`plugins/craft-layer/skills/motion-tiers/references/gotchas.md` — apply it, do not
copy it here.

## RTL / BiDi

Scroll-linked motion carries reading direction: on a `dir="rtl"` target, MIRROR the
pinned horizontal-scroll direction, the scrub progress mapping, and the parallax x-offset
side — drive them from the resolved `direction`, never a hard-coded pixel sign. A data
chart pinned in a scrubbed scene stays an **LTR-island** (it reads left→right regardless).
The full decision + reuse of the i18n base rules:
`plugins/craft-layer/skills/motion-tiers/references/rtl-bidi.md`.

## prefers-reduced-motion (mandatory)

Every scroll surface answers this or it does not ship:

- When reduced, DO NOT start Lenis — leave native scroll intact.
- Drop scrub, pin, and parallax; keep at most an opacity crossfade. Gate ScrollTrigger
  scenes with `gsap.matchMedia()` (see gsap.md); CSS scroll-driven rules go behind
  `@media (prefers-reduced-motion: no-preference)`.
- Gate both layers and land on the static final state — mechanism and the three ways
  it is missed: `../motion-tiers/references/reduced-motion.md`.

## Perf budget

- Lenis ≈ 3KB gzip; ScrollTrigger ships inside GSAP — count both against `motion-tiers`.
- Native CSS scroll-driven ≈ 0KB JS — the reduced-bundle alternative, default below fold.
- One scroll loop, one engine. A second `requestAnimationFrame` scroll loop is both a
  budget violation and a contract violation.

## References

- `references/lenis-substrate.md` — Lenis setup, `lerp`/`duration`, sticky-safety,
  the ScrollTrigger feed, and the reduced-motion disable path.
- `references/css-scroll-driven.md` — native `animation-timeline: scroll()` / `view()`
  as the no-JS reduced-bundle path, support/fallback, and reduced-motion gating.
- `references/orchestration-decision.md` — scrub vs trigger vs parallax: the three
  mental models, when each applies, and why never to blend them on one scene.

- `references/scroll-acts.md` — the pinned act, the scrubbed frame sequence and the
  scroll-revealed panel: budgets, reduced-motion, no-JS and failure states, the no-dialog rule.
- ScrollTrigger API: `plugins/ui-ux/skills/motion-best-practices/references/gsap.md`.

## Anti-patterns

- **Smooth scroll by default** — adding Lenis to a surface with no scrubbed or pinned
  motion; it taxes every device for no craft gain.
- **Two scroll positions** — native scroll + Lenis + CSS scroll-driven all live at
  once; drift and jitter. One contract only.
- **Transformed page wrapper** — faking smoothing by translating a container; breaks
  `position: sticky` and every pinned ScrollTrigger.
- **Reveal with no fallback** — `opacity: 0` gated only on an observer; invisible with
  JS off (see gotchas.md).
- **No reduced-motion path** — scrub or parallax with no `prefers-reduced-motion`
  branch. Mandatory, not polish.
- **GSAP as a tier** — treating GSAP as a motion tier instead of the scroll engine, or
  copying ScrollTrigger recipes here instead of referencing gsap.md.
