# Native CSS scroll-driven animations — the reduced-bundle path

> Last verified: 2026-07-24 — https://developer.mozilla.org/en-US/docs/Web/CSS/animation-timeline

Read on demand from scroll-orchestration. This is the ≈ 0KB-JS alternative to
Lenis + ScrollTrigger: the browser drives the animation off the main thread from
the scroll position itself. It is the reduced-bundle default and the below-the-fold
default. It cannot do smoothed scroll or complex pin choreography — for that, use
the JS engine (see `SKILL.md`).

## Two timeline sources

- `animation-timeline: scroll(<scroller> <axis>)` — progress = how far a scroll
  container has scrolled. Use for progress bars, a sticky header shrink, a page-wide
  parallax layer.
- `animation-timeline: view()` — progress = an element's travel through the viewport.
  Use for reveal-on-enter and per-element scrub. Pair with `animation-range`
  (e.g. `entry 0% cover 40%`) to bound when it plays.

Example — a per-element reveal, no JS:

    @keyframes reveal { from { opacity: 0; translate: 0 2rem } to { opacity: 1; translate: 0 } }
    .card {
      animation: reveal linear both;
      animation-timeline: view();
      animation-range: entry 0% cover 30%;
    }

## Support and fallback (this IS the fallback, so it must degrade)

- `animation-timeline` is not universal. Feature-detect and only opt in where
  supported so unsupported browsers get the STATIC final state, never a stuck
  `opacity: 0`:

      @supports (animation-timeline: scroll()) {
        .card { animation: reveal linear both; animation-timeline: view(); }
      }

- Author the base rule at the VISIBLE end state (`opacity: 1`); the `@supports`
  block layers motion on top. This is the reveal-with-fallback rule from
  `plugins/craft-layer/skills/motion-tiers/references/gotchas.md` expressed in pure
  CSS — no observer, so no no-JS blank.
- A named timeline (`scroll-timeline-name` / `timeline-scope`) links a timeline
  declared on one element to an animation on another when they are not
  ancestor/descendant.

## Reduced-motion gating (mandatory)

Wrap the motion in a no-preference query so reduced-motion users get the static
layout:

    @media (prefers-reduced-motion: no-preference) {
      @supports (animation-timeline: scroll()) {
        .card { animation: reveal linear both; animation-timeline: view(); }
      }
    }

- Never put the reveal in the base rule and try to cancel it under
  `reduce` — start static, add motion only when both no-preference AND supported.

## When to pick this over Lenis + ScrollTrigger

- Reveals, progress indicators, single-transform scrub, anything below the fold, and
  every reduced-bundle build → CSS scroll-driven.
- Smoothed scroll feel, multi-step pinned scenes, horizontal scroll sections, tight
  cross-element choreography → Lenis + ScrollTrigger (`gsap.md`).
- Never both on the same axis — that is the two-scroll-positions contract violation
  in `SKILL.md`.
