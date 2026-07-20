# GSAP depth — recipes the SKILL body has no room for

Read on demand from motion-best-practices. Everything here assumes GSAP 3.13+
(all plugins free, single `gsap` npm package). Verify current APIs at
gsap.com/docs — 3.15 rewrote SplitText (~50% smaller) with changed option names.

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

## SplitText (3.15 rewrite)

- Split only what you animate (`type: "lines"` beats `"lines,words,chars"` for
  a line reveal — chars multiply DOM nodes fast).
- Revert when done: `split.revert()` restores original markup — critical for
  screen readers and for re-splitting after a resize; the 3.15 `autoSplit`
  option re-splits on font load/resize for you.
- Mask reveals: 3.15's `mask: "lines"` wraps each line in an overflow clip —
  no hand-built wrapper divs.
- Accessibility: SplitText sets `aria-label` on the container and hides split
  nodes from the tree by default in 3.15 — do not disable that without a
  replacement.

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
