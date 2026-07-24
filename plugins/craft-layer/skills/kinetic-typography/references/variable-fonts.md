# Variable fonts — setup, axis animation, payload caveats

> Verify axis names and ranges against the specific family (Fontsource / the
> foundry's spec) before quoting a literal — `wght` range, whether `wdth` /
> `opsz` / `slnt` exist, and any custom axes differ per family.

Read on demand from the kinetic-typography SKILL. This is the how-to for
animating font axes; WHEN to animate type at all is the SKILL's decision.

## Ship one variable file

- Install `@fontsource-variable/<family>` and import the axis CSS you use, e.g.
  `import '@fontsource-variable/inter'` (full axes) or a single-axis subset
  entry when the package exposes one. One file carries the whole continuous
  range — you never ship `-Regular` + `-Bold` + `-Black` separately.
- Declare the family once; set a default axis state on the base selector so the
  static render (and no-JS) is already correct:
  `font-family:'Inter Variable'; font-variation-settings:"wght" 400;`.
- Registered CSS shorthands (`font-weight`, `font-stretch`, `font-optical-sizing`)
  map to `wght` / `wdth` / `opsz`; for custom axes (`GRAD`, `slnt`, foundry
  axes) you must use `font-variation-settings`.

## Animate axes, not weight swaps

- `font-variation-settings` takes a whole declaration string, so it does not
  interpolate cleanly on its own. Drive each axis through a REGISTERED custom
  property and animate the number:

      @property --wght { syntax:'<number>'; inherits:false; initial-value:400 }
      @property --wdth { syntax:'<number>'; inherits:false; initial-value:100 }
      .kt { font-variation-settings:"wght" var(--wght), "wdth" var(--wdth); }

  Now `--wght` / `--wdth` tween smoothly via CSS transition, CSS scroll-driven
  animation, or a JS engine writing the custom property.
- Scroll-linked: `.kt { animation: thicken linear both; animation-timeline:
  scroll(); }` with `@keyframes thicken { to { --wght:800 } }`, or a GSAP
  ScrollTrigger `scrub` tween on `--wght` (ScrollTrigger detail lives in
  `plugins/ui-ux/skills/motion-best-practices/references/gsap.md`).
- Hover / focus: `.kt:hover, .kt:focus-visible { --wght:700; --wdth:90 }` with a
  `transition:--wght .25s, --wdth .25s`. Keep it short and to one or two axes.
- Cost: an axis change reflows the glyph outline (layout + paint), unlike
  `transform` / `opacity`. Restrict axis animation to the ONE focal element and
  a short duration; do not axis-animate paragraphs or lists.

## reduced-motion

- Under `@media (prefers-reduced-motion: reduce)` set the axis to its final
  static value and drop the `animation` / `transition`:
  `.kt { --wght:800; animation:none; transition:none; }`.
- Guard JS axis tweens (scroll scrub, hover interpolation) behind
  `matchMedia("(prefers-reduced-motion: reduce)")` before they start.

## Payload + flash caveats

- A variable file is larger than a single static weight. Preload it
  (`<link rel="preload" as="font" type="font/woff2" crossorigin>`) and self-host
  via Fontsource so it is not a third-party round-trip.
- Flash of wrong weight: with `font-display:swap` the fallback renders first,
  then the variable font swaps in and the weight jumps. Tune the fallback metrics
  (`size-adjust`, `ascent-override`) or accept a brief `optional` block; either
  way the SWAP, not just the timing, is what shifts axis state — verify the
  focal headline does not lurch weight on load.
- Subset to the glyphs and axes actually used; an unsubsetted multi-axis file can
  be hundreds of KB and undoes the one-file win.
