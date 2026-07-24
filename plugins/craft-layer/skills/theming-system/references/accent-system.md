# Accent system — the display-vs-text/mark split

This reference owns the DERIVATION of the accent split: how the single accent role divides
into a display/fill accent and a distinct text/mark accent, and what contrast STEP has to
sit between them and against each surface. It is the single home of the display-vs-text/mark split.
It emits no colour value — no hex, no functional-colour scalar, no named colour used as a
value. Every entry below is a ROLE, a RELATIONSHIP, or a required RATIO, never a number and
never a colour. `token-tiers.md` NAMES the two accent roles; THIS file derives the step
between them. Value GENERATION stays with `/ui-ux:theme`; VERIFICATION stays with the craft
gate — this file only derives.

## The split, and why it exists

A single accent that reads well as a big hero mark does not automatically read well as
small text or a thin icon on the same ground. The strength that makes a display accent sing
at large size is the strength that fails it at small size against its surface. So the accent
role divides into two:

- **display/fill accent** — the expressive role for large, low-density moments: a hero, a
  display heading, a large mark, a filled button. It carries no small text, so it can run at
  full strength.
- **text/mark accent** — the restrained role for small text set in the accent and for small
  UI marks (icons, indicators, thin chart strokes, focus rings). It must satisfy the
  legibility rules, so it is a distinct step from the display accent, not the same value
  reused smaller.

`token-tiers.md` names these two roles as tiers; this file derives the STEP between them and
against each surface. Tiers name; accent-system derives — one home for the split, no
contradiction.

## The required contrast rules

These ratios are REQUIRED rules the pairing must satisfy. They are the shared WCAG standard,
cited here as the constraint the derivation serves, not owned or invented here:

- **Small text in the accent** must clear `≥4.5:1` against the surface it sits on.
- **Non-text marks** — icons, indicators, thin chart strokes, focus rings, large type
  standing against its surface — must clear `≥3:1` against that surface.

"Big text" never excuses a low-contrast accent: the display accent earns its strength only
where it is not carrying small text or a thin mark.

## Deriving the step on a LIGHT ground

On a light ground the display accent is typically a bright, saturated tone that looks strong
at hero scale but drops below `≥4.5:1` as small text and below `≥3:1` as a thin mark. So on a
light ground the derivation reserves a DARKER step of the accent for the text/mark role:

- small accent text takes the darker text/mark step so it clears `≥4.5:1` against the light
  surface;
- icons and thin marks take the same darker step (or darker still) so they clear `≥3:1`
  against their surface;
- the bright display/fill accent is reserved for large type and fills, where it is not the
  thing being read at small size.

The step between display and text/mark is therefore a DIRECTION (darker) and a MAGNITUDE
(enough to cross the required ratio for each role), never a fixed tone.

## Deriving the step on a DARK ground

On a dark ground the relationship runs the inverse. The accent is usually a FILL with light
text set over it rather than accent-coloured small text on the page surface, so the
text/mark burden shifts:

- the light text OVER the accent fill must clear `≥4.5:1` against that fill — the fill, not
  the page, is the surface the small text is read against;
- accent marks that still land directly on the dark surface must clear `≥3:1` against it;
- the surface axis (base vs raised vs sunken, owned by `token-tiers.md` and
  `light-dark-duality.md`) already carries most of the dark-mode legibility, so the accent
  split here is mostly the inverse of the light-ground darker-step rule rather than a second
  independent derivation.

The point across both grounds: the display accent and the text/mark accent are always
separated by a deliberate contrast step sized to the required ratio for the role, with the
step's DIRECTION set by the ground.

## Ratio-is-a-rule, value-is-forbidden

Keep the boundary explicit so a fresh session neither strips the rules nor smuggles in
numbers. A contrast RATIO (`≥4.5:1`, `≥3:1`) is a REQUIRED rule and MUST survive here; it is
the whole point of the split. A colour VALUE (a hex, a functional-colour scalar, a named
colour used as a value) is FORBIDDEN here — that is the kill-trigger, and it is
`/ui-ux:theme`'s job to resolve the step to actual tones along the `design-tokens` ramps.
Ratios survive; colour values do not.

## Verification lives elsewhere

This file DERIVES the split; it does NOT check it. The accent-contrast gate is owned by
`/craft-layer:audit` (via the `craft-reviewer` step that verifies the accent clears contrast
on every surface AND size — large `≥3:1`, body `≥4.5:1`, and on a light theme a darker
text/mark step distinct from the display accent). Derived here, verified there — owner and
verifier stay split so neither drifts.

## What this file does not do

- It does not emit a colour, a hex, a functional-colour scalar, or a named colour used as a
  value — that is the kill-trigger; this file ships roles, relationships, and required
  ratios only.
- It does not NAME the accent tiers — `token-tiers.md` names display and text/mark as roles;
  this file only derives the step between them.
- It does not add a checker or restate the audit's checklist — `/craft-layer:audit` owns
  verification; this file points at it.
- It does not own the universal WCAG ratios — they are a shared external standard; this file
  owns only the display-vs-text/mark SPLIT that applies them.
