# Pointer patterns — the effects on one shared loop

Read on demand from the interaction-fx SKILL. The animation primitives (Framer/Motion
springs, `useSpring`, gestures, drag) are NOT re-taught here — they live in
`plugins/ui-ux/skills/motion-best-practices/SKILL.md` + `plugins/ui-ux/skills/motion-best-practices/references/motion.md`. This file
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

## Index hover preview

- One preview element for the whole list (fixed-position, transform only), not one per
  row. A delegated `pointerover` on the list swaps its image; the shared loop lerps it
  toward the pointer; `pointerleave` on the list hides it.
- Keyboard parity: on a row's `:focus-visible` (or `focusin`) show the same preview pinned
  beside the row, not at a stale pointer position.
- Preload a row's image on `pointerenter` / `focus`, and reserve its aspect ratio so the
  swap never flashes an empty box. The preview is `alt=""` — the row's link text carries
  the meaning.
- Off under `(pointer: coarse)` and `prefers-reduced-motion: reduce` (no follow; a
  focus-pinned thumbnail may stay).

## Scene steering

- Normalise the pointer to −1..1 in the shared loop and write ONE uniform or camera
  target per frame; lerp toward it so the scene eases rather than snaps.
- Bound the range (a few degrees of orbit, a capped distortion), return to rest on
  `pointerleave`, and stop writing while the canvas is off-screen.
- If steering reveals content or changes meaning, expose the same parameter as visible
  controls (buttons, a slider) that work by keyboard and touch.

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
