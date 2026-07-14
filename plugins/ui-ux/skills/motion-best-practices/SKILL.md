---
name: motion-best-practices
description: Use when writing or reviewing UI animation and motion — CSS transitions/@keyframes, @starting-style entry effects, scroll-driven animations, the View Transitions API, Motion (ex-Framer Motion), GSAP, microinteractions, easing/duration, prefers-reduced-motion accessibility, compositor-only performance.
---

## `prefers-reduced-motion` is a hard rule, not a nice-to-have

Vestibular disorders make large or unexpected motion physically harmful, so every animation
ships with a reduced-motion path — this is an accessibility requirement, not polish. "Reduce"
means removing movement (translation, scale, parallax, spin, autoplay), not necessarily all
feedback: an opacity crossfade is usually a safe substitute for a slide or zoom.

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

The global kill-switch above is the minimum baseline; per-component crossfade fallbacks are
better. In JS, gate with `matchMedia("(prefers-reduced-motion: reduce)")` before animating.

## CSS transitions and entry/exit effects

Use transitions for two-state changes and `@keyframes` for multi-step sequences. To animate
an element entering from `display: none` (dialogs, popovers, toasts), pair `@starting-style`
with `transition-behavior: allow-discrete` — Baseline since late 2024 and safe as progressive
enhancement: unsupported browsers just show the element instantly.

```css
dialog[open] {
  opacity: 1;
  transition: opacity 200ms ease-out, display 200ms allow-discrete, overlay 200ms allow-discrete;
  @starting-style { opacity: 0; }
}
```

Reduced-motion fallback: entry/exit effects collapse to instant appearance or a short fade —
never a slide or scale — under the media query above.

## Scroll-driven animations (CSS, no JS)

`animation-timeline: scroll()` / `view()` replaces JS scroll listeners for progress bars,
reveal-on-scroll, and parallax. Support (mid-2026): Chrome/Edge 115+, Safari 26+; Firefox
stable still gates it behind a flag — treat it as a progressive enhancement wrapped in
`@supports (animation-timeline: view())`, with the element resting in its final state otherwise.

Reduced-motion fallback: scroll-linked movement and parallax are among the strongest vestibular
triggers. Under `prefers-reduced-motion: reduce`, set `animation: none` and show content in its
final state; keep at most an opacity-only reveal.

## View Transitions API

Same-document (`document.startViewTransition(cb)`) is Baseline: Chrome 111+, Safari 18+,
Firefox 144+ (Level 1 only — no transition types yet, which some framework wrappers need).
Cross-document, opt in on both pages with `@view-transition { navigation: auto; }` — Chrome
126+ and Safari 18.2+, not yet Firefox. Always feature-detect and fall back to an instant
DOM update or plain navigation; the transition is decoration, never a dependency.

Reduced-motion fallback:

```css
@media (prefers-reduced-motion: reduce) {
  ::view-transition-group(*), ::view-transition-old(*), ::view-transition-new(*) {
    animation: none !important;
  }
}
```

## Motion (the library formerly Framer Motion)

The npm package is `motion` (v12 line); React code imports from `motion/react`. The
`framer-motion` package still mirrors releases but is a legacy alias — new code uses `motion`.
Prefer the mini `animate()` from `motion/mini` for simple vanilla tweens (smallest bundle);
reserve full `motion` components for gestures, layout animation, and exit transitions.

Reduced-motion fallback: wrap the tree in `<MotionConfig reducedMotion="user">` so transform
animations are disabled system-wide automatically, or branch on `useReducedMotion()` for
per-component crossfade substitutes.

## GSAP

GSAP 3.13+ (April 2025, post-Webflow acquisition) is 100% free for commercial use including
every formerly-paid Club plugin — SplitText, MorphSVG, ScrollSmoother, DrawSVG, ScrollTrigger —
all shipped in the standard `gsap` npm package. Do not avoid plugins or bundle nulled copies
over stale licensing assumptions. Register plugins once (`gsap.registerPlugin(ScrollTrigger)`)
and kill tweens on component unmount (`gsap.context()` / `useGSAP()`) to avoid leaks.

Reduced-motion fallback: `gsap.matchMedia()` is the idiomatic gate —

```js
const mm = gsap.matchMedia();
mm.add("(prefers-reduced-motion: no-preference)", () => {
  gsap.from(".card", { y: 40, opacity: 0, stagger: 0.1 });
});
mm.add("(prefers-reduced-motion: reduce)", () => {
  gsap.set(".card", { opacity: 1 }); // final state, no movement
});
```

## Animate on the compositor

- Animate `transform` and `opacity` only; `width`, `height`, `top`, `left`, and `margin`
  trigger layout on every frame, and `box-shadow`/`filter` can be paint-heavy.
- `will-change` is a scalpel: apply it just before an animation starts, remove it after.
  Leaving it on permanently or sprinkling it across many elements wastes GPU memory and
  can degrade rendering.
- Avoid layout thrash in JS: batch DOM reads before writes, drive frames with
  `requestAnimationFrame`, and use the FLIP technique (measure First/Last, Invert with a
  transform, Play) instead of animating layout properties directly.
- Microinteraction timing: 150–300ms for most UI feedback, `ease-out` for entrances,
  `ease-in` for exits; durations over 500ms on frequent interactions feel sluggish.

## Common mistakes

- Shipping any motion with no `prefers-reduced-motion` path — an accessibility failure,
  not a style choice.
- Animating layout properties (`width`, `top`, `margin`) instead of `transform`.
- Permanent `will-change` on many elements "for performance".
- JS scroll listeners recalculating styles per scroll event where `animation-timeline`
  or an `IntersectionObserver` toggle would do.
- Assuming GSAP plugins still require a paid Club license (free since 3.13).
- Importing `framer-motion` in new code instead of `motion` / `motion/react`.
- Treating View Transitions as required: no feature detection, broken flow when
  `startViewTransition` is missing.
- Infinite or autoplaying decorative loops with no pause affordance.

## Verify Against Current Docs

Browser support moves fast here — Firefox's scroll-driven-animations flag and cross-document
View Transitions status were the open gaps as of mid-2026. Check https://caniuse.com and MDN
before asserting support, https://motion.dev/docs for Motion, and https://gsap.com/docs for
GSAP APIs and plugin names.
