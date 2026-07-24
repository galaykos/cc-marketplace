# Physics patterns — matter.js world, sync, and constraints

Read on demand from the physics-motion SKILL. The spring/tween alternative (when NOT to
use physics) lives in `plugins/ui-ux/skills/motion-best-practices/SKILL.md`; the
one-writer-per-property trap lives in
`plugins/craft-layer/skills/motion-tiers/references/gotchas.md`. This file is the
engine how-to.

## One world, one loop

- Create a single `Engine` (`Matter.Engine.create()`) and its `world`. Step it from ONE
  driver — the built-in `Runner`, or your own rAF calling `Engine.update(engine, delta)`.
  Never run two loops (double-stepping = doubled gravity + jitter).
- Enable sleeping (`engine.enableSleeping = true` / per-body `sleepThreshold`) so settled
  bodies stop consuming CPU. Pause the runner when the surface leaves the viewport
  (IntersectionObserver) and on unmount dispose: `Runner.stop`, `Engine.clear`, `World.clear`.

## Static bounds

- Add static walls/floor (`Bodies.rectangle(..., { isStatic: true })`) around the
  viewport so bodies never escape. Recompute wall positions on resize and call the
  engine's update so bounds stay honest.

## Body ↔ DOM sync (transform only)

- Each frame, read `body.position.{x,y}` and `body.angle` and write
  `el.style.transform = translate(x,y) rotate(angle)` on the matching element — transform
  only, ONE writer (no other tween on that transform, per gotchas). Position elements
  absolutely so layout never fights the simulation.
- Prefer a `data-body-id` map from element → body to avoid per-frame lookups.

## Canvas rendering (many bodies)

- For hundreds of bodies, render to a `<canvas>` (matter's `Render`, or your own draw)
  instead of hundreds of DOM nodes — far cheaper. Choose by count: tens → DOM, hundreds →
  canvas. The canvas is decorative (`aria-hidden`) with the real content in the fallback.

## Mouse / drag constraint

- Use `MouseConstraint` for grab-and-throw with real inertia. Constrain stiffness so
  drags feel weighted, and clamp velocities so a hard throw cannot launch a body through a
  wall (or enable CCD-style substeps by raising the step rate).
- On touch, ensure the constraint does not block scrolling; scope it to the surface.

## reduced-motion + fallback (defer, don't restate)

- Under `prefers-reduced-motion: reduce`, do NOT create the runner — render bodies in
  their settled rest layout (static). The SKILL owns this mandate; this file only notes
  the settled arrangement is the fallback content.

## rapier — the wasm alternative

- `@dimforge/rapier2d` (wasm) is faster and more stable for large/complex simulations, at
  the cost of a wasm load and a heavier setup. Use it when matter.js becomes the
  bottleneck; for typical landing/craft surfaces matter.js is enough. planck.js is a third
  option (Box2D port) — not the default here.

## Verify

- One engine, one step loop; sleeping on; runner paused off-screen; disposed on unmount.
- DOM sync is transform-only with one writer; walls contain every body.
- Reduced-motion renders the settled static layout with no runner.
