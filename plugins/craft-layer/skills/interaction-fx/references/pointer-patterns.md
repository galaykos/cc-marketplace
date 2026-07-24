# Pointer patterns — the four effects on one shared loop

Read on demand from the interaction-fx SKILL. The animation primitives (Framer/Motion
springs, `useSpring`, gestures, drag) are NOT re-taught here — they live in
`plugins/ui-ux/skills/motion-best-practices/SKILL.md` + `references/motion.md`. This file
is the pointer-effect mechanics + the single loop.

## One shared pointer loop

- Track the pointer once, page-wide: a single passive `pointermove` writes the latest
  `{x, y}` to a ref/store; a single `requestAnimationFrame` loop reads it and updates
  every active effect. Never one rAF per effect.
- Smooth by lerping the rendered value toward the target each frame (or a Framer
  `useSpring`), so motion trails the pointer naturally instead of snapping.
- Gate the whole loop: start it only when `matchMedia('(prefers-reduced-motion: reduce)')`
  is false AND `matchMedia('(hover: hover) and (pointer: fine)')` matches. Tear it down on
  unmount.

## Custom cursor

- A fixed-position element translated to the smoothed pointer position (transform only).
- Grow / change on interactive targets via a shared hover state (delegate a
  `pointerover` on `a, button, [data-cursor]`), not a listener per element.
- Keep the system cursor visible unless it conveys nothing extra AND a keyboard path
  exists; prefer augmenting the real cursor over replacing it.

## Magnetic button

- Within a small radius, translate the control toward the pointer by a fraction of the
  offset (≈0.2–0.4); spring back to origin on leave. The inner label may lead the
  container slightly for depth.
- One writer on the transform — Framer `useSpring` OR a manual write, never both.

## Hover tilt

- Map the pointer's offset within the element to bounded `rotateX`/`rotateY` (≈±6–10°);
  reset on leave. `transform-style: preserve-3d` on the parent, `perspective` on the
  container. Transform only.

## Drag affordance

- Use Framer `drag` with `dragConstraints` and inertia for grabbable carousels/handles;
  expose a visible affordance (cursor/handle) and keyboard/scroll equivalents.

## Verify

- One rAF loop total; transforms only; no `top`/`left` writes.
- Effects off under `pointer: coarse` and `prefers-reduced-motion: reduce`.
- Every hover-revealed state has a `:focus-visible` equivalent.
- The real cursor is never lost without a keyboard-navigable equivalent.
