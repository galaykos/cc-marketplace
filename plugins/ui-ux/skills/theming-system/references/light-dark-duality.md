# Light/dark duality — both modes designed, stepped from the ramps

This reference owns ONE requirement: a theme ships TWO modes and BOTH are DESIGNED, each
stepped from the same token ramps the system is built on — neither mode is an automatic
flip of the other. It emits no colour value; it states a rule, a WHEN, and a seam.

The generation MECHANICS of dark mode — accent lightening, the elevation shadow↔border
flip, `card` sitting a step above `background` — are already owned by
`plugins/ui-ux/skills/shadcn-theming/SKILL.md` (lines 74–82). This file CITES them; it does
NOT restate them. Its job is to REQUIRE that both modes are derived, to say WHEN, and to say
HOW that requirement enters the token-system direction.

## The duality requirement

- **Both modes are first-class.** Light and dark are two designs of the SAME system — each
  stepped from the ramps `token-tiers.md` names — not one master mode plus an inversion of
  it.
- **No auto-flip.** Dark mode is never produced by an `invert()` filter or by copying the
  light values verbatim; `shadcn-theming` names that inversion as an anti-pattern and it is
  forbidden here too. A flipped light theme is not a designed dark theme.
- **Stepped from the ramps, not bolted on.** Each mode positions every tier — surface, ink,
  accent, status, chart — along the ramps FOR THAT MODE, keeping the tier RELATIONSHIPS
  legible in both modes: the elevation order, the ink hierarchy, and the accent split all
  survive the mode change.

## When both modes are derived

Both modes are derived TOGETHER, up front, as part of the token-system direction — not one
mode now and the other retrofitted later. Deriving both at design time is what surfaces a
mode-specific gap — an accent that reads in one mode but not the other, or an elevation that
separates on one ground and flattens on the other — at DESIGN time rather than in audit,
where `shadcn-theming`'s mechanics resolve it. The duality is decided when the tiers are
decided, so every tier carries its light-mode AND dark-mode intent from the start.

## How the duality enters the token-system direction

The token-system direction the theme brief carries (see `concept-to-tokens.md`) speaks in
the PLURAL: for every tier it states the RELATIONSHIP each mode must hold — the elevation
order, the paired contrast, the accent-step direction on that ground — WITHOUT resolving a
value. `/ui-ux:theme` then generates the two value sets, and `shadcn-theming` supplies the
dark-set mechanics it owns. Because the direction describes BOTH modes tier by tier, the
generator is never left to invent the second mode from the first — which is precisely what
the no-auto-flip rule forbids.

## What this file does not do

- It does not restate the dark-mode generation mechanics (accent lightening, the elevation
  shadow↔border flip, `card`-above-`background`) — `shadcn-theming` (`:74-82`) owns those;
  this file cites them.
- It does not emit a colour value — no hex, no functional-colour scalar, no named colour used
  as a value.
- It does not name the tiers or derive the accent step — `token-tiers.md` names,
  `accent-system.md` derives.
- It does not generate the values or run the live preview — `/ui-ux:theme` does.
