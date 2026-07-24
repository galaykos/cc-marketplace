# Iconography — icons as a system, not a pack

An icon set is a SYSTEM decision, not a download. Award-grade sites read as coherent because their
icons share one grid, one weight, one metaphor. This file decides the SYSTEM; it names no specific
pack (kill-trigger).

## Choose the set as a system (consistency axes)

Judge and pick an icon system on:

- **Stroke width** — one weight across the set, related to your type/UI weight.
- **Grid + optical size** — a shared px grid (16 / 20 / 24); icons optically balanced at ship size.
- **Corner + terminal style** — rounded vs sharp, consistent joins.
- **Metaphor + coverage** — one visual language, with enough coverage that you never mix two sets.
- **Fill vs stroke** — pick one as the default; a mixed set reads as borrowed.

A single off-the-shelf set used untouched is a sameness-fingerprint default
(`plugins/craft-layer/skills/creative-direction/references/sameness-fingerprint.md`) — customise
weight/grid, or commission the brand-defining marks, so the iconography is a choice, not a default.

## Deliver: icon-font vs inline-SVG vs SVG-sprite

- **Inline SVG (default)** — themeable via `currentColor`, no extra request, per-icon tree-shake.
  Best for a curated handful.
- **SVG sprite** (`<use href>`) — one cached file for many icons; good for a large in-app set.
- **Icon font** — legacy / wide reuse; ships the whole set, has a11y traps (maps glyphs to text),
  and a font licence (often SIL-OFL — see `licence-discipline.md`). Prefer SVG unless a font is
  mandated.

## Colour: technique only (theming stays Part C)

Icons inherit text colour via `currentColor` — a colour-INHERITANCE technique, so an icon tints
with its context for free. Deriving the theme's token VALUES (which colour, which surface) is NOT
decided here — that is the theming system (Part C). This file only says "inherit, don't hardcode."

## Accessibility

A meaningful icon needs an accessible name (`aria-label` / `<title>`); a decorative icon is
`aria-hidden`; an icon-only control always needs a name. Full a11y → `/a11y:audit`.

## Licence

Every third-party icon set / icon font is under the licence gate (`licence-discipline.md`) — record
its class + source; an icon font's SIL-OFL obliges shipping the licence text + Reserved Font Name.
