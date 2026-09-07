# Lenis — the smooth-scroll substrate

> Last verified: 2026-07-24 — https://lenis.darkroom.engineering — npm:lenis@1

Read on demand from scroll-orchestration. Lenis is the ONLY smooth-scroll library
this skill blesses: ≈ 3KB gzip, no scroll hijack, no transformed wrapper. It lerps
the browser's native scroll into a smoothed value the animation engine reads — it
does not replace the scrollbar or reparent the page.

## Setup (once per app)

- Instantiate one `Lenis` instance for the whole document, high in the tree.
- Drive it from a SINGLE `requestAnimationFrame` loop, or hand the tick to GSAP's
  ticker so Lenis and ScrollTrigger share one clock:

      const lenis = new Lenis({ lerp: 0.1 })
      gsap.ticker.add((t) => lenis.raf(t * 1000))
      gsap.ticker.lagSmoothing(0)

- Never run two rAF loops. A second loop is the classic drift bug (Lenis reads one
  frame, ScrollTrigger another).

## Options that matter

- `lerp` (≈ 0.08–0.12) OR `duration` (≈ 1.0–1.2) — pick one feel model, not both.
  Higher `lerp` = snappier; lower = floatier. Do not set below 0.05 (mushy) or the
  page feels detached from input.
- `smoothWheel: true` is the point; leave `syncTouch`/`smoothTouch` OFF by default —
  smoothing touch scroll fights the OS and feels laggy on mobile.
- `wheelMultiplier` / `touchMultiplier` — tune only if input feels wrong; defaults
  are correct for most surfaces.
- `orientation` / `gestureOrientation` — set for horizontal galleries; the contract
  (one engine per axis) still holds.

## Feed the animation engine (the contract)

Lenis owns scroll position; ScrollTrigger must read Lenis, not `window.scrollY`:

    lenis.on('scroll', ScrollTrigger.update)

This is the single-scroll-contract in `SKILL.md`. With it, scrub/pin/parallax stay
locked to the smoothed position. Without it, ScrollTrigger reads native scroll and
the two positions diverge — the drift/jitter gotcha in
`plugins/craft-layer/skills/motion-tiers/references/gotchas.md`.

## Sticky-safe by design

- Lenis translates the scroll VALUE, not a DOM container, so `position: sticky` and
  `position: fixed` keep working. Do not add the legacy `transform: translate3d`
  wrapper some old smooth-scroll libs required — it breaks `sticky` and any pinned
  ScrollTrigger (a transformed ancestor kills `position: fixed`).
- After async content changes layout (images, fonts, lists), call
  `lenis.resize()` and `ScrollTrigger.refresh()` so measurements stay honest.
- Anchor links: use `lenis.scrollTo('#id')` (or let Lenis intercept native anchor
  clicks) so in-page navigation respects the smoothed scroll.

## Disable on reduced-motion (mandatory)

Do not instantiate Lenis at all when the user asked for less motion:

    const reduce = matchMedia('(prefers-reduced-motion: reduce)')
    let lenis
    if (!reduce.matches) {
      lenis = new Lenis({ lerp: 0.1 })
      gsap.ticker.add((t) => lenis.raf(t * 1000))
    }

- Reduced-motion users get plain native scroll — the accessible default.
- Also drop the scrub/pin/parallax scenes that depended on Lenis (gate them with
  `gsap.matchMedia()`), and honor a runtime change to the media query by tearing the
  instance down (`lenis.destroy()`).
- Clean up on unmount / route change: `lenis.destroy()` and remove the ticker
  callback, or the loop leaks across pages.
