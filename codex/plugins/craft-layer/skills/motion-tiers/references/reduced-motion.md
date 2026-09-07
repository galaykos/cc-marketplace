# The reduced-motion gate — stated once FOR CRAFT-LAYER

Scope, because the earlier title said plainly "stated once" and that was false:
`ui-ux:motion-best-practices` also states the rule, and owns the WHY (vestibular
harm), the CSS kill-switch, and the runtime subscription mechanism —
`motion-tiers/SKILL.md` itself assigns that mechanism to it. This file is the
single statement of the gate **across craft-layer's motion skills**, not across
the marketplace. A file whose job is preventing restatement claiming a uniqueness
it does not have was the sharpest version of the problem it exists to solve.

Every craft-layer motion skill answers `prefers-reduced-motion` or it does not
ship. What each skill owns is its **path**: which of its effects stop, and what
the surface looks like when they do. That part is domain-specific and lives in
each skill.

What every one of them shares is the **mechanism**, and it is this:

> Gate **both layers**. In JS, check
> `matchMedia('(prefers-reduced-motion: reduce)')` **before** starting the
> animation — not inside its loop, and not after instantiating the engine. In
> CSS, wrap the moving rules in `@media (prefers-reduced-motion: reduce)` (or
> put the motion behind `no-preference`). Then land the user on the **static
> final state** — the layout they would have ended at — never a blank or
> half-built one.

Skills cite this file rather than re-explaining `matchMedia` and `@media`.

## The three ways it is actually missed

1. **A loop that starts, then checks.** A `requestAnimationFrame` or
   `setInterval` already running when the query is read. The check belongs
   before the first frame.
2. **One layer only.** JS gated, CSS not (or the reverse). A CSS keyframe
   animation keeps running with the JS disabled, and a JS tween keeps writing
   `transform` with the media query satisfied.
3. **Landing on the start state.** Reveal animations that gate the animation but
   leave `opacity: 0` — reduced-motion users get an invisible page. Land on the
   END state, which is also why a fallback-safe reveal starts visible.

## What this file does NOT cover

Per-tier fallback choices (which tier degrades to a crossfade, which to a poster
frame) are in `tier-budgets.md`. The reduced-**bundle** path — shipping less
JavaScript, as opposed to less motion — is a separate mandate with its own
column in that table; satisfying one does not satisfy the other.
