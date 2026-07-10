---
name: design-tokens
description: Use when building or reviewing a design system's foundations — the spacing scale, type scale, radius, elevation/shadow, and motion tokens, plus semantic color tiering — so spacing, sizing, and rhythm come from a named scale instead of magic numbers. Pure color palette generation is shadcn-theming; this is the rest of the token system.
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
cap body measure around 60–75 characters for readability.

### Radius
A short radius scale (`0, 4, 8, 12, full`) applied consistently: inputs and cards share
a radius, pills use `full`. Mixed radii on sibling elements read as unfinished.

### Elevation / shadow
Elevation is a token scale, not a per-element shadow. Two or three levels (`sm`, `md`,
`lg`) mapped to a consistent light source; higher elevation = more blur and spread, not a
random new shadow. Elevation should encode hierarchy (a dropdown sits above a card),
not decoration.

### Motion
Duration and easing are tokens: a few durations (`fast ~150ms`, `base ~250ms`,
`slow ~400ms`) and a shared easing curve. Micro-interactions use `fast`, entrances
`base`. Always honor `prefers-reduced-motion` — a token system includes the reduced
variant, it is not an afterthought.

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

- **Tailwind** — extend `theme` with the scales; use the utility that reads them
  (`p-4`, `text-lg`, `rounded-md`), never arbitrary values (`p-[13px]`) except as a
  deliberate one-off with a comment.
- **CSS variables** — semantic tokens as custom properties (`--background`) so runtime
  theming works; this is the shadcn convention.

## Starting a token system

1. **Pick the base unit and ratio** — 4px spacing base, a type ratio (1.2–1.25). Everything
   derives from these two decisions.
2. **Define the six families** — spacing, type, radius, elevation, motion, and semantic
   color — as the smallest scale that covers real needs, not every value you might want.
3. **Map semantic color onto the palette** — `background`/`foreground`/`primary`/… onto
   the generated ramp (shadcn-theming), so components never touch a primitive.
4. **Wire into the stack** — Tailwind `theme` extension + CSS variables; then use only the
   scale utilities. The system exists the moment arbitrary values stop appearing.

## Reviewing a token system

- Spacing/sizing/radius come from scale steps; no magic numbers or arbitrary utilities.
- Type sizes are scale steps with deliberate line-heights; body measure is capped.
- Elevation and motion are token scales, not per-element values.
- Components reference semantic color tokens, never primitives.
- `prefers-reduced-motion` has a defined reduced variant.

## Defer rule

- Generating and tuning the color palette itself (ramps, contrast, dark mode) →
  `shadcn-theming`.
- Applying tokens in a specific stack's components → that stack's best-practices skill.
- Accessibility of the resulting contrast/targets → `/a11y:audit`.

## Anti-patterns

- **Magic numbers** — `margin: 13px`, `font-size: 15px`; values off the scale that only
  almost align.
- **Arbitrary Tailwind values** — `p-[13px]`, `text-[15px]` sprinkled instead of scale steps.
- **Primitive colors in components** — `blue-500` instead of `primary`; theming now means
  find-and-replace.
- **Per-element shadows** — a new box-shadow per card instead of an elevation token.
- **Motion without reduced-motion** — animations that ignore the user's preference.
- **Two systems drifting** — a Figma scale and a code scale maintained separately until
  they disagree; the code tokens are the source of truth.
- **A type size per component** — sizes chosen ad hoc instead of assigned a scale step.
- **Overgrown scales** — twelve spacing steps and nine radii nobody can keep straight; a
  scale earns its size by being small enough to hold in your head.
