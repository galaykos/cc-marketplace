# anime.js depth — v4 recipes the SKILL body has no room for

> Last verified: 2026-10-06 — https://animejs.com/documentation/ — npm:animejs@4.5

Read on demand from motion-best-practices. Everything here assumes anime.js v4
(npm `animejs`, ESM-only, tree-shakable; 4.5.0 current on 2026-10-06). v4 was a
full API rewrite, and its minors still break APIs (4.2, 4.4 below) — so the
stamp carries the minor. Verify current names at
https://animejs.com/documentation/ before use.

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
- Springs: `import { spring } from 'animejs'`, then
  `ease: spring({ bounce: .5, duration: 350 })` (perceived params) or physics
  params `{ mass, stiffness, damping, velocity }` — per property, no plugin;
  the spring's settling time overrides the tween's `duration`.
- Easing helpers are imported functions since 4.2: `import
  { cubicBezier, steps } from 'animejs'`, then `ease: cubicBezier(.7, .1, .5, .9)`
  or `ease: steps(5)` (`linear()` and `irregular()` likewise). The string forms
  `'cubicBezier(…)'` / `'steps(…)'` log a warning and fall back to linear in
  `animate()`; only `waapi.animate()` still takes them as strings.

## 4.4.0 breaking changes (2026-04-29)

- Function-based values get `(target, index, targets)`: the third argument is
  now the targets array, not the total count — write `targets.length` where
  v4.0–4.3 code used `total`. A `stagger(…, { use })` callback still gets a
  number there (4.4.0 and 4.5.0 source; the 4.4.0 release notes say otherwise).
- Transforms render in a fixed order — perspective, translate, rotate, scale,
  skew — whatever order the params list them in, so
  `{ scale: 2, translateX: 100 }` no longer scales first. `matrix` and
  `matrix3d` can no longer be animated directly.

## Timelines and stagger

- `const tl = createTimeline({ defaults: { duration: 400, ease: 'outQuad' } })`,
  then `tl.add(target, params, position)` — positions accept `'<'`, `'+=200'`,
  and `tl.label('name')` anchors; defaults live on the timeline, not per tween.
- `stagger(80, { from: 'center', grid: [cols, rows] })` works on values, delays,
  and timeline positions.
- Build a timeline once and control it thereafter
  (`tl.play()/pause()/reverse()/seek()`); do not rebuild per interaction.

## Scroll and scope

- Scroll-linked play: `animate(target, { ..., autoplay: onScroll({ sync: true }) })` —
  `sync: true` scrubs progress to scroll position; `enter`/`leave` thresholds
  take `'bottom top'`-style edge pairs (container edge first, target second).
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
- SVG helpers ship in the core package (`import { svg } from 'animejs'`), no plugin
  registration: `svg.createDrawable()` (line drawing), `svg.morphTo()`, `svg.createMotionPath()`.

## Text: free, in core

- `splitText(target, { lines, words, chars })` returns a `TextSplitter`;
  animate its `.lines`, `.words` or `.chars` arrays, not the splitter itself
  (added in 4.1 as `text.split()`, renamed in 4.2; the old name warns). Its `accessible` option, on by default, keeps a visually hidden copy
  of the original text and sets `aria-hidden` on every split node (read from
  the 4.5.0 source, not screen-reader tested); `split.revert()` restores the
  markup.
- `scrambleText()` (4.4+) is a function-based value:
  `animate(el, { innerHTML: scrambleText() })` — `innerHTML`, not
  `textContent`.
- Neither needs a paid plugin. Under reduced motion skip both and leave the
  original text in place. Standing: recorded.
