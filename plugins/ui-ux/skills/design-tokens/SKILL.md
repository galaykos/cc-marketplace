---
name: design-tokens
description: Use when building or reviewing design-system foundations — spacing/type scales, radius, elevation, motion tokens, semantic color tiering: named scales over magic numbers. Palette generation is shadcn-theming.
---

# Design tokens

A design token is a named decision — `space-4`, `text-lg`, `radius-md` — used instead
of a raw value. The point is not naming for its own sake; it is that **every spacing,
size, and radius in the UI comes from a small shared scale**, so the interface reads as
one system instead of forty arbitrary pixel values that almost line up. Magic numbers
are the tell of a design with no system.

## The scales

### Spacing — one scale, everywhere
A single spacing scale drives margin, padding, and gap. Use a consistent ratio, not
ad-hoc values: a 4px base with `4, 8, 12, 16, 24, 32, 48, 64` covers almost everything.
Every gap in the UI is a step on this scale; `margin: 13px` is a bug, not a choice. This
is what makes rhythm feel intentional.

### Type — a modular scale
Font sizes come from a scale (e.g. 1.25 ratio: `12, 14, 16, 20, 24, 32, 40`), each paired
with a deliberate line-height (tighter for headings, ~1.5 for body) and a small set of
weights. Do not pick font sizes per component; assign a step. Line-length matters too —
cap body measure at roughly 45–75 characters. This skill is the single source for that
bound; `ui-ux-engineer`'s checklist cites it rather than carrying its own number.

The DISPLAY tier above these heading steps, the display-to-body CONTRAST that makes
hierarchy visible, and the static type contract are `theming-system`'s.

### Radius
A short radius scale (`0, 4, 8, 12, full`) applied consistently: inputs and cards share
a radius, pills use `full`. Mixed radii on sibling elements read as unfinished.

### Elevation / shadow
Elevation is a token scale, not a per-element shadow. Two or three levels (`sm`, `md`,
`lg`) mapped to a consistent light source; higher elevation = more blur and spread, not a
random new shadow. Elevation should encode hierarchy (a dropdown sits above a card),
not decoration.

### Motion
Duration and easing are tokens, published as CSS variables so every consumer reads one
source: `--duration-fast` (~150ms), `--duration-base` (~250ms), `--duration-slow`
(~400ms), plus `--ease-out` and `--ease-in` as real cubic-bezier curves (e.g.
`cubic-bezier(0.22, 1, 0.36, 1)` for ease-out, not the flat browser keyword) and
`--ease-spring` via a `linear()` spring approximation. Tailwind v4 wires these
through its `--ease-*` / `--animate-*` `@theme` namespaces. Micro-interactions use
`fast`, entrances `base`, and exits run shorter than their entrances. Always
honor `prefers-reduced-motion` — a token system includes the reduced variant, it is
not an afterthought.

## Semantic color tiering

Colors come in two tiers, and components use only the second:

1. **Primitive palette** — the raw ramp (`blue-500`, `gray-100`). Generated and tuned —
   that is `shadcn-theming`'s job; do not hand-pick these per component.
2. **Semantic tokens** — `background`, `foreground`, `primary`, `muted`, `border`,
   `destructive` — mapped onto primitives. Components reference the semantic token, never
   the primitive. This is what makes theming (light/dark, rebrand) a remap of one layer
   instead of a find-and-replace across the codebase.

A component using `blue-500` directly has broken the tier boundary; it should use
`primary`.

## Wiring tokens to the stack

- **Tailwind** — scales as tokens (`@theme` on v4, `theme.extend` on v3), consumed
  through the utilities that read them (`p-4`, `text-lg`).
- **CSS variables** — semantic tokens as custom properties (`--background`) so runtime
  theming works; the shadcn convention.

## Starting a token system

Pick the base unit and ratio (4px spacing, a 1.2–1.25 type ratio) — everything derives
from those two. Define the six families above as the smallest scale that covers real
needs, map semantic color onto the generated ramp (`shadcn-theming`), then wire it into
the stack. The system exists the moment arbitrary values stop appearing.

## Defer rule

- Generating and tuning the color palette itself (ramps, contrast, dark mode) →
  `shadcn-theming`.
- Deriving a token SYSTEM from a creative concept — surface/ink/accent ROLES, the
  three-role accent split, light/dark duality, the display tier → `theming-system`.
- Applying tokens in a specific stack's components → that stack's best-practices skill.
- Accessibility of the resulting contrast/targets → `/ui-ux:audit`.

## Anti-patterns

- **Off-scale values** — `margin: 13px`, `p-[13px]`, a font size picked per component.
- **Primitive colors in components** — `blue-500` instead of `primary`; theming now means
  find-and-replace.
- **Per-element shadows** — a new box-shadow per card instead of an elevation token.
- **Two systems drifting** — a Figma scale and a code scale maintained separately until
  they disagree; the code tokens are the source of truth.
- **Overgrown scales** — twelve spacing steps and nine radii nobody can keep straight; a
  scale earns its size by being small enough to hold in your head.
