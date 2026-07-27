# Token tiers — the shape of the system

This reference owns the SHAPE of the token system: which tiers exist, what ROLE each
plays, and how the concept's mood maps to the RELATIONSHIPS between them. It emits no
colour value — no hex, no functional-colour scalar, no named colour used as a value.
Every entry below is a ROLE or a RELATIONSHIP, never a number and never a colour. Value
GENERATION is `/ui-ux:theme`; the numeric SCALES are `design-tokens`; this file only names
and relates.

## The three tier families

A coherent system has three families. Each token is a tier with a role, positioned by its
relationship to its neighbours — not by an absolute value.

### Surfaces — where content sits

- **base** — the resting ground the app lives on; every other surface is stepped relative
  to it.
- **raised** — a surface that reads as ABOVE the base (a card, a popover, a menu); it is
  separated from base by an elevation STEP, expressed as either an elevation cue or a tone
  step, never a fixed tone.
- **sunken** — a surface that reads as BELOW the base (a well, an inset field, a track);
  the inverse relationship to raised.
- **line** — the divider/border role that separates surfaces when no elevation step is
  used; it is the quietest structural tier, a hair of separation, not a content tone.

The surfaces form an elevation ORDER (sunken → base → raised); a build must keep that order
legible in both modes. The mechanics of expressing an order as tone-vs-shadow belong to
`light-dark-duality.md` and `shadcn-theming`, not here.

### Ink — what is read on a surface

Ink is the text/foreground family, ranked by SIGNAL, each paired against the surface it
sits on so the contrast rule holds:

- **ink-primary** — the loudest foreground: headings, key values, the thing read first.
- **ink-secondary** — supporting copy, labels, the second-glance layer; a clear step
  quieter than primary but still comfortably legible.
- **ink-tertiary** — the quietest legible role: metadata, placeholders, disabled hints;
  the floor of legibility, never below the small-text contrast rule.

The three inks are a HIERARCHY of signal, not three arbitrary tones — each step down is a
deliberate reduction in prominence while every step stays a legible pairing on its surface.
The required contrast rule (`≥4.5:1` for small text) is a RULE the pairing must satisfy; it
is not a value this file emits.

### Accent — the theme's voice

The accent family carries the concept's identity. It splits into three named roles (the
derivation of the STEPS between them is `accent-system.md`'s job, per the tiers-name /
accent-system-derives seam rule). Three, not two, because a fill that carries text answers
to a different rule than a mark that sits on a surface — collapsing them is the most common
way an accent passes review at hero size and fails on its own primary button:

- **accent-fill** — the role for a filled area that CARRIES TEXT ON IT: a solid button, a
  badge, a selected row. Its obligation runs inward — the label on it must clear small-text
  contrast against the fill — which is a different constraint from every other accent role
  and the reason this is its own tier rather than a use of accent-display.
- **accent-display** — the expressive role for large, low-density moments: a hero, a
  display heading, a large mark, a decorative flourish where the accent can be at full
  strength because it is not carrying small text.
- **accent-text/mark** — the restrained role for small text on the accent and for small UI
  marks (icons, indicators, focus rings) that must satisfy the contrast rules (`≥4.5:1` for
  small text, `≥3:1` for marks).

This file NAMES those three accent roles and states that steps between them exist. It does NOT
derive the steps, their direction, or how the ratios resolve — `accent-system.md` owns the
accent derivation. Naming here, deriving there, keeps one owner for the split.

## Mapping mood to tier relationships

The concept's mood (mined by `design-research`, shaped by `creative-direction`) does not
pick colours here — it sets the RELATIONSHIPS between the tiers. Three levers, each stated
as a relationship, never a value:

- **Chroma** — how saturated the accent and tinted surfaces read relative to neutral. A
  calm/clinical mood pulls chroma toward neutral surfaces with a focused accent; an
  energetic/expressive mood widens chroma and lets tint reach the surfaces. This is a
  relative position on the ramp, resolved to a value downstream, not fixed here.
- **Contrast step** — how large the jumps are between surface tiers and between ink ranks.
  A crisp, high-contrast mood widens the steps (sharper elevation, punchier ink hierarchy);
  a soft, ambient mood narrows them (gentler elevation, closer inks) while still honouring
  the legibility rules — a narrow step never collapses below the contrast RULE.
- **Warmth** — the temperature bias shared across the neutral ramp and the accent so the
  system reads as one coherent family. A warm mood biases neutrals and accent one way, a
  cool mood the other; the point is that surfaces, ink, and accent share ONE temperature
  direction rather than clashing. The bias is a direction, not a hue value.

These levers describe the SYSTEM's internal relationships. `/ui-ux:theme` resolves them to
actual values along the `design-tokens` ramps; this file only says how the tiers should
relate so that whatever values are generated stay a coherent, contrast-correct family.

## What this file does not do

- It does not emit a colour, a hex, a functional-colour scalar, or a named colour — that is
  the kill-trigger; this file ships roles and relationships only.
- It does not derive the accent split or its contrast steps — `accent-system.md` owns that.
- It does not step the light/dark modes or express elevation as tone-vs-shadow —
  `light-dark-duality.md` and `shadcn-theming` own the mode mechanics.
- It does not define the status or chart tiers — `status-and-chart-palette.md` owns those.
