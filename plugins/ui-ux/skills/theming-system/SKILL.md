---
name: theming-system
description: Use when a concept must become a coherent token SYSTEM — surface/ink/accent tiers, the three-role accent split, a reserved status palette, a theme-derived chart palette, light/dark duality — as ROLES and derivation rules for /ui-ux:theme. Never ships a colour, hex, or token value.
---

## What this decides

This skill owns HOW a concept becomes a coherent token SYSTEM — the surface/ink/accent
tiers, the three-role accent split (display · fill · text/mark), a reserved status palette, a chart palette
tied to the theme, and a light/dark duality — derived as ROLES and rules that are correct
by construction. It does NOT generate the values, re-teach a ramp, or ship a theme. Those

- `/ui-ux:theme` — generates the token VALUES and the live preview from the theme brief
  this skill fills; it owns value generation, this skill owns the coherent direction.
- `plugins/ui-ux/skills/design-tokens/SKILL.md` — the token SCALES (spacing, radius, type,
  the numeric ramps a value is stepped along); this skill sets ROLES on top, not scales.
- `plugins/ui-ux/skills/shadcn-theming/SKILL.md` — the palette + dark-mode GENERATION
  mechanics (accent lightening, the elevation shadow↔border flip, card-above-background).
- `dataviz` (an external host skill, cited by NAME only — it is not in this repo) — the
  categorical/sequential chart-colour rules and the runnable palette validator.
- `plugins/craft-layer/skills/design-research/SKILL.md` — mines the mood into a theme
  brief; theming-system derives the coherent SYSTEM that brief carries into generation.

The net-new value here is the derivation: turning a concept + its mood into a token SYSTEM
of roles and contrast rules, so a build passes the existing accent-contrast gate and the
`dataviz` validator BY CONSTRUCTION rather than in an audit. This skill adds no checker.

Where it applies: the derivation lands in the theme brief `design-research` emits at the
craft flow's research step, so the token-system direction is CARRIED into `/ui-ux:theme`
with no new command step — the vehicle is a token-system-direction slot in that brief, not
dead docs. Reach for this whenever a concept needs to become a coherent, contrast-correct
token system rather than a recoloured default.

## Derive the system, in order

Take each step in turn; each routes to the reference that owns its derivation:

1. **Name the tiers** — surfaces (base/raised/sunken/line), ink (primary/secondary/
   tertiary), accent (display + fill + text/mark), each a TIER with a ROLE, and map the
   concept's mood to their RELATIONSHIPS (chroma, contrast step, warmth). → `references/token-tiers.md`.
2. **Reserve status, derive chart** — a reserved status palette (good/warn/serious/critical,
   never reused for a data series) plus a chart palette DERIVED from the theme ramps, not
   bolted on; defer categorical/validator rules to `dataviz`. → `references/status-and-chart-palette.md`.
   **This runs BEFORE the accent** because status is a fixed semantic ladder the product
   inherits and the accent is free — the free thing is constrained by the fixed one. Deriving
   the accent first and reserving status after is how an accent ends up sitting between two
   status roles, which no amount of lightness work later can fix.
3. **Derive the accent** — first constrain the HUE (separation from every reserved status
   role, a viable step for all three accent tiers, forced-colours survival, not a category
   default), then derive the STEPS: on a light ground a darker step for small text and marks
   and a darker fill for text set on it; on a dark ground the relationship inverts. This is
   the single home of the accent split. → `references/accent-system.md`.
4. **Require the duality** — design BOTH modes stepped from the ramps (never `invert()` an
   auto-flip); state when both are derived and how the duality enters the direction, and
   cite `shadcn-theming` for the generation mechanics. → `references/light-dark-duality.md`.
5. **Hand off the concept** — pack the token-system direction (metaphor · voice · mood →
   role relationships) into the slot the theme brief carries into `/ui-ux:theme`, so the
   generated system EXPRESSES the concept, not a recoloured default. → `references/concept-to-tokens.md`.
6. **Name the interchange format** — say in the direction whether the generated system is
   serialized to the W3C DTCG token format, and if so which roles map to which token
   groups, so the system survives leaving this codebase. → `references/token-interchange.md`.

## Where this sits in ui-ux

Moved here from `craft-layer` on 2026-07-27: three skills in this plugin touched the
same concern from different plugins, so a reader asking "how do I theme this" got a
different answer depending on what was installed. They are one pipeline:

- `design-tokens` — the numeric SCALES a value is stepped along (spacing, radius, type,
  the ramps). Vocabulary; no colour decisions.
- **This skill** — the ROLES derived from a concept: surface/ink/accent tiers, the
  three-role accent split, status and chart palettes, light/dark duality. Rules and
  ratios, never values.
- `shadcn-theming` — the VALUES and the stack wiring: the actual ramps, the dark-mode
  second design, the CSS-variable or Sass format for the installed stack, the preview.

Concept → roles → values → stack. The craft flow still drives this skill through
`/craft-layer:research` and `/craft-layer:craft`; the move changed its address, not its
place in that flow.

## The two seam rules

Both bind every card and every reference; they keep the files from stripping rules or
duplicating an owner:

- **Ratio-is-a-rule, not a value.** A contrast RATIO (`≥4.5:1` for small text, `≥3:1` for
  marks and large text) is a REQUIRED rule and MUST survive in the derivation — it is what
  makes the split reviewable. A colour VALUE — a hex code, an `oklch`/`hsl`/`rgb` scalar, or
  a named colour used as a value — is forbidden. The kill-trigger forbids VALUES, never
  ratios. A fresh session must neither strip the ratios (toothless) nor keep other numbers.
- **Tiers name, accent-system derives.** `references/token-tiers.md` NAMES the accent roles
  (display + fill + text/mark, as tiers with roles). `references/accent-system.md` DERIVES the
  contrast STEPS between them (hue constraints first, then the split). Tiers name; accent-system derives —
  so the two files never duplicate or contradict the same accent.

## The kill-trigger

If this skill emits a specific colour, a hex, an `oklch`/`hsl`/`rgb` scalar, or a named
theme, it has become a shipped theme — stop and re-scope to token TIERS + derivation RULES
(roles + relationships, not values). Contrast ratios are rules and stay; a starter palette,
an example hex, or a proper-noun theme name is the trigger. The mechanism ships a
theme-BUILDER and its rules, never a built theme.

## References

- `references/token-tiers.md` — the token-system SHAPE: surface/ink/accent tiers as ROLES,
  and how the concept's mood maps to the tier relationships. NAMES the accent roles.
- `references/accent-system.md` — the accent HUE constraints (status separation) + the three-role DERIVATION,
  the single owner of the darker-text-step / accent-fill split and its contrast steps.
- `references/light-dark-duality.md` — the DUALITY requirement: both modes stepped from the
  ramps (never auto-flip), when to derive them, how it enters the direction; cites shadcn.
- `references/status-and-chart-palette.md` — the reserved status palette (net-new) plus the
  theme-derived chart palette; cites `dataviz` for categorical rules + the validator.
- `references/concept-to-tokens.md` — the handoff CONTRACT: the token-system-direction
  payload the theme brief carries into `/ui-ux:theme` so the system expresses the concept.
- `references/token-interchange.md` — the W3C DTCG serialization decision: what the format
  requires, how the tiers/split/duality/status map onto it, and the component-tier cost.

## Anti-patterns

- **Shipping a value** — a hex, an `oklch`/`hsl`/`rgb` scalar, a named colour, or a whole
  named theme in any file. That is the kill-trigger, not a token system — re-scope to roles.
- **Stripping the ratios** — deleting `≥4.5:1`/`≥3:1` to "remove all numbers"; the ratios
  are RULES and must survive (ratio-is-a-rule). Only colour VALUES are forbidden.
- **Two accent owners** — deriving the split in `token-tiers.md` AND `accent-system.md`;
  tiers NAME the roles, accent-system DERIVES the steps — one home, no contradiction.
- **Auto-flip duality** — generating dark mode by inverting light instead of stepping both
  modes from the ramps; an `invert()` dual is not a designed duality.
- **A bolted-on chart palette** — chart colours picked independent of the theme rather than
  derived from its ramps; the chart palette is part of the system, not an afterthought.
- **Re-teaching a neighbour** — restating `/ui-ux:theme` generation, `design-tokens` scales,
  `shadcn-theming` dark-mode mechanics, or `dataviz` colour rules instead of citing them.
- **A new coherence gate** — adding an audit checker for what this derives; the existing
  accent-contrast gate and the `dataviz` validator already verify it. This skill has no gate.
- **Folding this into design-research** — re-owning the coherent derivation inside the
  mining skill; design-research MINES and briefs, theming-system DERIVES the system it carries.
