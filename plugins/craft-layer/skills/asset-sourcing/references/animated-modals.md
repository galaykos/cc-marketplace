# Animated modals / overlays — sourcing the animated content

A modal is CODED — its mechanics are motion, not a sourced asset. What this file owns is the
SOURCING decision for a modal's animated CONTENT (a celebratory Lottie, an animated SVG, a short
video): the build-vs-source-vs-commission call for that content. The modal MECHANICS are cited,
never taught here.

## The sourcing decision (what this owns)

When a modal / overlay carries an animation, decide via `sourcing-decision.md`'s six axes:

- **Build-in-code** — a CSS / SVG / spring micro-animation (a checkmark draw, a confetti burst) is
  usually cheaper and more themeable coded than sourced.
- **Source / commission** — a rich celebratory illustration-animation is a Lottie (`.lottie`) or
  Rive (`.riv`) asset; pick playback via the Vector tier
  (`plugins/craft-layer/skills/motion-tiers/references/vector.md`) and record its licence
  (`licence-discipline.md`).
- **Video** — a short overlay video defers sourcing / encoding to
  `plugins/craft-layer/skills/motion-tiers/references/sprite.md` and is under the licence gate.

## Mechanics — cited, not taught

The modal's open/close + interaction craft is owned elsewhere; cite by path, never restate:

- enter/exit choreography + reduced-motion → `plugins/craft-layer/skills/motion-tiers/SKILL.md` /
  `plugins/craft-layer/skills/page-transitions/SKILL.md`;
- focus-trap, dismiss affordances, restore-focus, `Esc`, backdrop click, `dialog` semantics →
  `plugins/craft-layer/skills/interaction-fx/SKILL.md` for pointer craft and **`/ui-ux:audit`** for
  the dialog / focus a11y contract.

## Reduced-motion + fallback

The sourced animation honours `prefers-reduced-motion` (a static poster frame) and ships a
reduced-bundle fallback — the same rules the Vector tier already sets; cite, do not re-budget.
