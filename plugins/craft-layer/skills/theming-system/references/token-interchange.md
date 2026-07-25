# Token interchange — the DTCG format as the system's serialization

> Last verified: 2026-07-25 — https://www.designtokens.org/tr/drafts/format/ ·
> https://www.w3.org/community/design-tokens/2025/10/28/design-tokens-specification-reaches-first-stable-version/

Read on demand from `theming-system`. Steps 1–5 derive a token SYSTEM as roles and
relationships. This file decides how that system is WRITTEN DOWN so it can leave the
codebase — into Figma, into a sibling platform, into a second brand — without being
re-derived from prose. It still ships no colour, hex, scalar, or named theme: the
kill-trigger applies here unchanged. It describes a container, never a value.

## Why name a format at all

A token system that exists only as CSS custom properties in one stylesheet is a
theme, not a system: nothing else can read its structure, the roles are implied by
naming convention alone, and a second brand or platform starts over. The Design Tokens
Community Group format module reached its first stable version (2025.10) in October
2025 and is what tooling has converged on, so it is the default answer to "where does
this system live when it is not CSS".

Naming the format is a DIRECTION decision — it belongs in the theme brief beside the
role relationships, because it constrains what the generated system must be able to
express. It is not a build step this skill performs.

## What the format actually requires

Enough to brief correctly; the spec owns the rest:

- Every token carries `$value`. Every token's type is DECLARED via `$type` — tooling is
  forbidden from inferring type by inspecting the value's shape, so an undeclared type is
  a defect, not a shorthand.
- Files use `.tokens` / `.tokens.json`.
- References come in two forms and they are not interchangeable: `{group.token}` braces
  target a WHOLE token value, and JSON Pointer (`#/path/to/target`) reaches INTO a value's
  properties. A system whose semantic tier aliases its primitive tier is using the first;
  a system that needs one field of a composite is using the second.
- Composite types exist for the shapes a design system actually has — typography, shadow,
  border, gradient, transition, strokeStyle — built from the base types (color, dimension,
  fontFamily, fontWeight, duration, cubicBezier, number). Several composites are still
  disputed in open spec issues, so treat typography/shadow as settled and border/transition
  /strokeStyle as liable to move.
- The format carries modern colour spaces and multi-brand/multi-mode structure natively —
  which is why the light/dark duality of `light-dark-duality.md` is expressible as designed
  modes rather than as two disconnected files.

## Mapping this skill's roles onto the format

The derivation already produces the right shape; the format only needs it named:

| This skill's output | Where it lands |
| --- | --- |
| Surface / ink / accent TIERS (`token-tiers.md`) | the semantic tier — tokens whose values are aliases |
| The ramps those tiers step along | the primitive tier — tokens with literal values |
| Display-vs-text/mark accent split (`accent-system.md`) | two distinct semantic tokens, never one token used twice |
| Light/dark duality (`light-dark-duality.md`) | modes on the collection, both authored, neither derived by inversion |
| Reserved status + chart palettes (`status-and-chart-palette.md`) | their own semantic groups, so a data series can never alias a status token |

Two tiers — primitive and semantic — is the floor. A third, component tier is a real
option and a real cost: tokenizing every variant × size × state × property multiplies
fast (a single button can reach the high hundreds of tokens, and the largest published
systems run to six figures of tokens across megabytes of JSON). Adopt the component tier
only when several independent framework implementations consume the same system;
otherwise add component tokens individually, where a component genuinely needs one.

## What this does NOT decide

- **Values.** Still `/ui-ux:theme` + `design-tokens`. The format is a container.
- **The pipeline.** Whichever transformer turns tokens into platform output, and whichever
  design tool round-trips them, are project choices — name the format, not the vendor.
  Check the transformer's own DTCG-version support before assuming the newest spec version
  round-trips; tooling has historically lagged the spec.
- **Whether to serialize at all.** A single-brand, single-platform build that will never
  export is allowed to stay in CSS custom properties. Then the direction says so
  explicitly, which is still a decision, rather than leaving it unasked.

## Anti-patterns

- **Implied roles** — shipping primitives only and letting naming convention carry the
  semantic tier; the alias layer IS the system.
- **Inferred types** — omitting `$type` because the value "looks like" a colour.
- **Inverted duality** — one authored mode plus a generated opposite; the format can hold
  both modes, so authoring one is a choice to have no designed dark mode.
- **Component tier by default** — reaching for the third tier before a second consumer
  exists, and inheriting the token explosion for nothing.
- **Format as a build step** — treating this as "export tokens later" rather than as a
  direction the brief carries; retrofitting structure onto a shipped theme is the
  re-derivation this file exists to prevent.
