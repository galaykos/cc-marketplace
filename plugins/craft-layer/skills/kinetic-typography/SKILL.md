---
name: kinetic-typography
description: Use when animating type on a web surface — kinetic or variable-font headlines, weight/width axis animation on scroll or hover, rotating phrase cross-fades, or a split-text reveal — or when a craft review flags type that moves without earning it or a missing reduced-motion path. Decides when animated type helps vs distracts, animates font-variation-settings axes, and mandates a reduced-motion fallback; references split-text mechanics and the gradient-clip / aria traps by path.
---

## What this decides

This skill decides WHEN type should move and animates the two net-new kinetic
patterns — variable-font axes and rotating phrases. It does NOT re-teach how to
split text into lines/words/chars, and it does NOT re-bake the invisibility and
screen-reader traps; both live elsewhere and are referenced by path:

- Split-text mechanics (SplitText per-line/word/char, mask reveals, revert):
  `plugins/ui-ux/skills/motion-best-practices/references/gsap.md`. The non-GSAP
  option is the `split-type` package + your own CSS / tween. Do not re-implement.
- Two traps, referenced not copied, in
  `plugins/craft-layer/skills/motion-tiers/references/gotchas.md`: gotcha A
  (gradient-clip on split letters → invisible) and gotcha C (aria-label the
  phrase, aria-hidden the spans).

The net-new value here is the decision, variable-font axis animation, phrase
cross-fade, and the mandatory reduced-motion path on every one of them.

## The kinetic-type decision — does the motion earn its cost?

Animate type only on the ONE focal element of a surface: the hero headline, a
single accent word, or one rotating slot. Never body copy, never two competing
type animations on one screen.

Kinetic type has to serve reading, not fight it. It earns its cost when it:

- sequences the eye INTO the headline (a reveal that lands word by word), or
- adds emphasis a static weight cannot (an axis shift on the accent word), or
- carries real alternative meaning (a rotating slot cycling true synonyms).

It costs: split-text multiplies DOM nodes and can break screen readers; a
variable font adds font payload; `font-variation-settings` triggers layout, not
just the compositor. If the words read identically when frozen, do not animate
them — spend the budget on a motion tier (`motion-tiers`) that moves layout.

## Variable-font axes on scroll + hover

Ship one variable file via `@fontsource-variable/<family>` — continuous axes
(`wght` 100–900, `wdth`, `opsz`, `slnt`, custom `GRAD`) in a single download —
then animate the axis, not a swap between static weights.

- Drive axes through registered custom properties so they interpolate smoothly:
  `@property --wght { syntax:'<number>'; inherits:false; initial-value:400 }`,
  then `font-variation-settings: "wght" var(--wght), "wdth" var(--wdth)`.
  Animating the raw declaration string does NOT tween; animating the number
  behind `@property` does.
- Scroll: bind `--wght` / `--wdth` to scroll progress — CSS scroll-driven
  `animation-timeline: scroll()`, or GSAP ScrollTrigger `scrub` (see `gsap.md`)
  — so the headline thickens or widens as it enters. Scroll ORCHESTRATION
  itself is `motion-tiers` / card 01, not this skill.
- Hover / focus: transition `--wght` on `:hover` and `:focus-visible` for a
  weight/width lift on interactive words; keep it short and single-axis.
- Cost: axis changes reflow the glyph, so restrict them to the focal element and
  a short duration. Payload + flash-of-wrong-weight caveats and the preload /
  subset rules are in `references/variable-fonts.md`.

## Phrase cross-fade — rotating headline words

A fixed lead-in with one rotating slot ("We build ___" cycling real synonyms):

- Cross-fade, do not hard-cut: overlap the outgoing word (opacity 1→0, small
  `y`) with the incoming one so the eye never sees an empty slot.
- Reserve the slot's box — stack the words in one grid cell or measure the
  widest — so rotation never reflows the line around it.
- The first word must be real, static, meaningful text in the DOM (not an empty
  animated slot) so no-JS and first paint show a complete headline.
- Full pattern, timing, and the aria-live handling: `references/text-reveals.md`.

## Split reveals — reference, do not re-implement

Per-line / word / char reveals are a mechanics problem already solved:

- Recipes: SplitText (`type`, `mask`, `autoSplit`, `revert`) in
  `plugins/ui-ux/skills/motion-best-practices/references/gsap.md`; the
  dependency-light alternative is the `split-type` package driving your own CSS
  or tween. Pick one owner per element; revert on resize / unmount.
- Two traps you MUST honour, held in
  `plugins/craft-layer/skills/motion-tiers/references/gotchas.md` — reference,
  never re-bake: gotcha A — a `background-clip:text` gradient word split into
  transparent child spans paints nothing; keep the accent word ONE gradient
  unit. Gotcha C — split spans make screen readers spell the word out; put the
  phrase on the container `aria-label` and mark the spans `aria-hidden`.

## prefers-reduced-motion — mandatory on every pattern

No pattern above ships without a reduced-motion path; this is accessibility, not
polish.

- Under `prefers-reduced-motion: reduce`: no letter flight, no scroll- or
  hover-driven axis animation, no auto-rotating phrase.
- Allowed instead: the headline at its static final weight/width shown at once;
  the split phrase revealed with a single opacity fade or no motion; the
  rotating slot frozen on its first real word (or at most an opacity crossfade,
  never translation).
- Gate BOTH layers: JS with `matchMedia("(prefers-reduced-motion: reduce)")`
  before starting any scroll/hover axis tween or the rotation interval; CSS
  inside `@media (prefers-reduced-motion: reduce)`. A rotation running on a
  `setInterval` with no matchMedia guard is the most-missed violation.

## References

- `references/variable-fonts.md` — `@fontsource-variable` setup,
  `font-variation-settings` with registered `@property` axes, animating axes on
  scroll + hover, and the flash-of-unstyled / wrong-weight payload caveat.
- `references/text-reveals.md` — split-reveal and phrase cross-fade patterns;
  defers split mechanics to `gsap.md` / `split-type` and the invisibility + aria
  traps to `motion-tiers/references/gotchas.md`.

## Anti-patterns

- **Motion with no meaning** — animating a headline that reads the same frozen;
  the reveal is decoration competing with the words.
- **Animating everything** — kinetic body copy or several type animations per
  screen; reserve it for one focal element.
- **Weight swap, not axis tween** — cross-fading two static weights instead of
  animating one variable axis through a registered `@property`.
- **Reflowing rotator** — a rotating slot with no reserved box, so every word
  change jumps the line; or an empty first slot that renders blank with no JS.
- **Re-baking references** — copying SplitText recipes from `gsap.md` or the
  gradient / aria traps from `gotchas.md` into this skill instead of pointing.
- **Unguarded rotation** — a phrase interval or scroll axis tween with no
  `prefers-reduced-motion` gate.
