# anime.js depth — v4 recipes the SKILL body has no room for

Read on demand from motion-best-practices. Everything here assumes anime.js v4
(npm `animejs`, ESM-only, tree-shakable). v4 was a full API rewrite — verify
current names at https://animejs.com/documentation/ before use.

## v4 core API

- `import { animate, createTimeline, stagger, onScroll, utils, engine } from 'animejs'` —
  named imports only; there is no default `anime()` export any more.
- `animate(target, { x: 100, rotate: '1turn', duration: 500, ease: 'outQuad' })` —
  v3's `anime({ targets: ... })` single-object call is gone; the target is the
  first argument.
- Renames from v3: `easing` → `ease` (names drop the `ease` prefix: `'outExpo'`),
  `direction: 'alternate'` → `alternate: true`, callbacks are `onComplete` /
  `onUpdate` / `onBegin`.
- Per-property parameters: `x: { to: 100, duration: 800, ease: 'out(3)' }`;
  keyframes are arrays of those objects.
- Springs: `ease: createSpring({ stiffness, damping })` — physics-based easing
  per property, no plugin.

## Timelines and stagger

- `const tl = createTimeline({ defaults: { duration: 400, ease: 'outQuad' } })`,
  then `tl.add(target, params, position)` — positions accept `'<'`, `'+=200'`,
  and `tl.label('name')` anchors; defaults live on the timeline, not per tween.
- `stagger(80, { from: 'center', grid: [rows, cols] })` works on values, delays,
  and timeline positions.
- Build a timeline once and control it thereafter
  (`tl.play()/pause()/reverse()/seek()`); do not rebuild per interaction.

## Scroll and scope

- Scroll-linked play: `animate(target, { ..., autoplay: onScroll({ sync: true }) })` —
  `sync: true` scrubs progress to scroll position; enter/leave thresholds take
  `'bottom top'`-style edge pairs.
- `createScope({ root })` sandboxes selectors; in React, create the scope in an
  effect and `return () => scope.revert()` — `revert()` is the leak-free
  cleanup, the same job as GSAP's context.

## Reduced motion

`createScope` accepts media queries and re-runs when a match changes:

```js
const scope = createScope({
  mediaQueries: { reduced: '(prefers-reduced-motion: reduce)' },
}).add((self) => {
  if (self.matches.reduced) utils.set('.card', { opacity: 1 }); // final state, no movement
  else animate('.card', { y: [40, 0], opacity: [0, 1], delay: stagger(80) });
});
```

Never ship an anime.js animation without this branch (or an equivalent
`matchMedia` gate) — the skill's reduced-motion rule applies to every library.

## Performance and variants

- `x` / `y` / `scale` / `rotate` shorthands compose into one `transform`;
  layout properties (`width`, `top`) thrash — the compositor rules from the
  SKILL body apply unchanged.
- Hardware-accelerated variant: `import { waapi } from 'animejs'` →
  `waapi.animate(target, params)` runs on the Web Animations API off the main
  thread; prefer it for simple tweens under main-thread load.
- `utils.remove(target)` stops running animations on a target;
  `engine.fps` / `engine.precision` tune the global loop.
- SVG helpers ship in the core package, no plugin registration:
  `svg.createDrawable()` (line drawing), `svg.morphTo()`, `svg.createMotionPath()`.
