# GSAP depth — recipes the SKILL body has no room for

> Last verified: 2026-09-26 — https://gsap.com/docs — npm:gsap@3.15

Read on demand from motion-best-practices. Everything here assumes GSAP 3.13+
(all plugins free on npm since 3.13, single `gsap` package, React hook in
`@gsap/react`; current line 3.15). Verify current APIs at gsap.com/docs —
v3.13.0 rewrote SplitText (half the size, 14 new features).

Licence: the "Standard no-charge" licence (https://gsap.com/standard-license/),
not MIT. Commercial use and every plugin are free; the headline prohibited use
is a no-code visual animation builder that competes with Webflow's.

## Timeline architecture

- One timeline per logical sequence, built once, controlled thereafter
  (`play/pause/reverse/seek`) — do not rebuild timelines on every interaction.
- Use labels (`tl.add("reveal")`) and position parameters (`"<"`, `"-=0.2"`)
  instead of hand-summed absolute offsets; offsets rot the moment a duration
  changes.
- Nest child timelines for composable scenes: build each section's timeline in
  its own function returning the timeline, then `master.add(section())`.
- Defaults belong on the timeline (`gsap.timeline({ defaults: { ease: "power2.out",
  duration: 0.4 } })`), not repeated per tween.

## ScrollTrigger

- One `ScrollTrigger` per scene; for N similar items use `gsap.utils.toArray()` +
  a loop, never one mega-trigger with manual progress math.
- `scrub: true` binds animation progress to scroll position (use a number,
  e.g. `scrub: 0.5`, for smoothing); `toggleActions` is for play-on-enter
  patterns — do not combine both mental models in one trigger.
- Pinning: `pin: true` reparents/spacers the element — set
  `pinSpacing: false` deliberately, and never pin an element whose ancestor has
  a transform (breaks fixed positioning).
- Always `ScrollTrigger.refresh()` after content that changes layout loads
  (images, fonts, async lists); stale measurements are the #1 ScrollTrigger bug.
- Kill triggers on unmount: `useGSAP()` (React) or `gsap.context()` scoping
  handles this; a manually-created trigger needs `st.kill()`.
- Many similar reveals (cards, list rows, a Webflow-style "fade in on scroll"
  attribute): `ScrollTrigger.batch(".card", { onEnter: (els) => gsap.to(els,
  { opacity: 1, y: 0, stagger: 0.1 }) })` — one trigger per element, callbacks
  grouped per `interval`, so rows entering together stagger as one group
  (`batchMax` caps it). A per-element loop fires N separate tweens instead.
  Build it inside the SKILL's `gsap.matchMedia()` gate. Standing: recorded.
- Mobile address bar: on a touch-only device ScrollTrigger already skips the
  refresh when only the height changes, by under 25% (`ignoreMobileResize`, on
  by default there). Do not set it `false`, and do not add your own `resize` →
  `refresh()` listener — either brings back the pin jump as the bar shows and
  hides. If pins still jump, `ScrollTrigger.normalizeScroll(true)` stops the
  bar from toggling on most mobile browsers. Standing: recorded.

## SplitText (v3.13 rewrite)

- Split only what you animate (`type: "lines"` beats `"lines,words,chars"` for
  a line reveal — chars multiply DOM nodes fast).
- Revert when done: `split.revert()` restores original markup — critical for
  screen readers and for re-splitting after a resize; the `autoSplit` option
  (3.13+) re-splits for you when text reflows after fonts finish loading.
- Mask reveals: `mask: "lines"` (3.13+, also `"words"`/`"chars"`) wraps each
  line in an extra clipping element — no hand-built wrapper divs.
- Accessibility: SplitText sets `aria-label` on the container and
  `aria-hidden` on split nodes by default (3.13+) — do not disable that
  without a replacement.

## React integration

- `useGSAP(() => { ... }, { scope: containerRef })` — scoping doubles as
  selector sandbox (`gsap.from(".card", ...)` matches only inside the ref) and
  auto-cleanup on unmount.
- Event-driven tweens go in `contextSafe(...)` so they join the same cleanup
  context.
- Never mix GSAP and Motion on the same property of the same element — two
  writers on `transform` fight; pick one owner per element.

## Performance

- Animate `transform`/`opacity`; use `xPercent/yPercent` for responsive
  translations instead of recomputing pixel values on resize.
- `will-change` is managed by GSAP when needed — hand-setting it everywhere
  defeats the browser's own heuristics.
- Batch DOM reads before writes; inside a tween use `onUpdate` sparingly — a
  per-frame callback touching layout properties forces layout thrash.
