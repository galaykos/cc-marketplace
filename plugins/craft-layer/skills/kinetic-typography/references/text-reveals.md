# Text reveals — split reveal + phrase cross-fade patterns

Read on demand from the kinetic-typography SKILL. These are the two reveal
patterns; the SKILL owns the decision (animate the focal element only) and the
reduced-motion mandate.

Mechanics and traps are NOT duplicated here — they are referenced:

- Split-text mechanics (SplitText `type` / `mask` / `autoSplit` / `revert`,
  ScrollTrigger, stagger): `plugins/ui-ux/skills/motion-best-practices/references/gsap.md`.
  The dependency-light, non-GSAP option is the `split-type` package driving your
  own CSS or tween.
- Invisibility + screen-reader traps:
  `plugins/craft-layer/skills/motion-tiers/references/gotchas.md` — gotcha A
  (gradient-clip on split letters → invisible) and gotcha C (aria-label the
  phrase, aria-hidden the spans).

## Split reveal

A headline that resolves as the eye lands on it — per line for a calm reveal,
per word for punch, per char only for a short accent (chars multiply DOM nodes).

- Get the spans from SplitText or `split-type`; do not hand-wrap. Animate
  `transform` + `opacity` (compositor-cheap), stagger by line/word, and drive it
  from an on-enter trigger (`toggleActions`) or a scrub — see `gsap.md`.
- Revert the split on resize and on unmount so the DOM returns to the real
  markup; re-split after fonts load (`autoSplit`) so line breaks are correct.
- Trap A (do NOT re-solve here, honour it): if the accent word uses
  `background-clip:text` + `color:transparent`, keep it as ONE element — split
  children inherit `transparent` and paint nothing. Detail in `gotchas.md`.
- Trap C: split spans make assistive tech spell the word; put the phrase on the
  container `aria-label`, mark spans `aria-hidden="true"`. Detail in `gotchas.md`.
- No-JS / crawler safety: the real text must be present and readable before the
  split runs; reveal from a visible state or add a JS-ready gate so a failed
  observer never leaves the headline blank (see `gotchas.md` whileInView trap).

## Phrase cross-fade — rotating slot

`We build ___` with the slot cycling real synonyms (products / brands / teams):

- Stack the candidate words in ONE grid cell (`display:grid`, every word in
  `grid-area:1/1`) so the slot's box is fixed and the surrounding line never
  reflows as words swap. Alternative: measure the widest word and pin a
  min-width.
- Cross-fade, never hard-cut: the outgoing word `opacity:1→0` with a small `y`,
  the incoming `0→1` overlapping, so the slot is never empty mid-swap.
- The first word is real static text in the DOM — a meaningful complete headline
  at first paint and with no JS, not an empty animated slot.
- Interval: rotate on a comfortable dwell (~2–3s), pause on hover / focus, and
  keep the full phrase reachable to assistive tech. Do not wrap the slot in an
  `aria-live` region that announces every rotation — expose the canonical phrase
  once and let the rotation be decorative.

## reduced-motion

- Split reveal: show the full headline at once (single opacity fade at most), no
  per-line/word/char flight. Gate the split-and-animate step behind
  `matchMedia("(prefers-reduced-motion: reduce)")`.
- Phrase cross-fade: stop the interval and show only the first real word (static)
  — or, at most, an opacity crossfade with no translation. The `setInterval`
  rotation with no matchMedia guard is the classic miss.
