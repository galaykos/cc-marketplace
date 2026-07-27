# Accent system — the three-role accent split

This reference owns the DERIVATION of the accent split: how the single accent role divides
into a display/fill accent and a distinct text/mark accent, and what contrast STEP has to
sit between them and against each surface. It is the single home of the accent split.
It emits no colour value — no hex, no functional-colour scalar, no named colour used as a
value. Every entry below is a ROLE, a RELATIONSHIP, or a required RATIO, never a number and
never a colour. `token-tiers.md` NAMES the three accent roles; THIS file derives the steps
between them. Value GENERATION stays with `/ui-ux:theme`; VERIFICATION stays with the craft
gate — this file only derives.

## The split, and why it exists

A single accent that reads well as a big hero mark does not automatically read well as
small text or a thin icon on the same ground. The strength that makes a display accent sing
at large size is the strength that fails it at small size against its surface. So the accent
role divides into two:

- **display accent** — the expressive role for large, low-density moments: a hero, a
  display heading, a large mark. It carries no small text, so it can run at full strength;
  its only obligation is `≥3:1` against the surface it sits on.
- **fill accent** — a filled area that CARRIES TEXT ON IT: a solid button, a badge, a
  selected row. Its obligation runs INWARD — the label must clear `≥4.5:1` against the
  fill — which is a different constraint from every other accent role.
- **text/mark accent** — the restrained role for small text set in the accent and for small
  UI marks (icons, indicators, thin chart strokes, focus rings). It must satisfy the
  legibility rules against the SURFACE, so it is a distinct step from the display accent,
  not the same value reused smaller.

**Why fill is its own role, and not a use of display.** A display accent answers outward
(`≥3:1` against the page) and a fill answers inward (`≥4.5:1` for the text on it). On a
light ground those two pull in OPPOSITE directions: the display step wants to stay bright
to sing at hero scale, while the fill must go dark enough for light text to survive on it.
One value cannot serve both, and the failure is invisible until measured — a mid-toned
accent lands near `3:1` as a mark and near `3:1` again as a button ground, passing neither.
Collapsing display and fill is the single most common way an accent system that looks
correct fails on the primary button.

`token-tiers.md` names these three roles as tiers; this file derives the STEPS between them
and against each surface. Tiers name; accent-system derives — one home for the split, no
contradiction.

## Constrain the accent HUE before deriving its steps

The steps below are lightness work. They cannot rescue a hue that was wrong to begin with,
and one hue conflict recurs often enough to be structural rather than careless: **the accent
colliding with the reserved status palette.**

Status (`status-and-chart-palette.md`) is a FIXED four-role semantic ladder that most
products inherit rather than choose, and on a data-dense surface it is the loudest thing on
screen. The accent is FREE. So the free thing is constrained by the fixed one, never the
reverse — which is why status is reserved BEFORE the accent hue settles, not after.

Four filters on the hue, applied before any step derivation:

1. **Angular separation from every reserved status hue.** An accent sitting between two
   status roles makes a branded element read as a condition and a condition read as
   branding. The separation must hold for all four roles, not just the nearest.
2. **Survivable in all three accent roles.** The hue must admit a display step, a fill step
   dark or light enough to carry text, and a text/mark step — against EVERY surface in BOTH
   modes. A hue with no viable fill step is a hue that cannot have a primary button.
3. **Survives `forced-colors`.** Anything the accent alone distinguishes must also be
   distinguished by shape, position, or text, since the accent is discarded entirely under
   a forced-colours mode.
4. **Not a category default.** The hue families in `sameness-fingerprint.md` cost the build
   its authored feel before a word is read.

**Chroma follows from role, not from taste.** An accent that must coexist with a shouting
status set should be low-chroma and dark — closer to ink than to a brand colour — so the
loud roles stay loud. An accent that IS the product's expression, on a surface with little
status, can afford saturation. Decide which of those the brief is before picking a chroma.

## The required contrast rules

These ratios are REQUIRED rules the pairing must satisfy. They are the shared WCAG standard,
cited here as the constraint the derivation serves, not owned or invented here:

- **Small text in the accent** must clear `≥4.5:1` against the surface it sits on.
- **Non-text marks** — icons, indicators, thin chart strokes, focus rings, large type
  standing against its surface — must clear `≥3:1` against that surface.

"Big text" never excuses a low-contrast accent: the display accent earns its strength only
where it is not carrying small text or a thin mark.

### Which contrast algorithm — and why WCAG 2 is the one that gates

The ratios above are WCAG 2 relative-luminance ratios. Use them as the CONFORMANCE gate and
do not substitute another model, because no other model is normative: APCA was removed from
the WCAG 3 exploratory track in 2023, WCAG 3's own contrast algorithm is still recorded as
undetermined in its 2026 editor's draft, and WCAG 3 is not expected to reach Recommendation
before the end of the decade. WCAG 2 AA is also what the enforcement regimes reference.

This matters in practice because upstream scales may be tuned to a DIFFERENT model — some
published ramps guarantee their text steps in APCA lightness-contrast (Lc) values, not in
WCAG ratios, and the two disagree at the margins. So:

- A scale's own accessibility claim never discharges this derivation. Re-check the pairing
  in WCAG ratios against the actual surface, whatever the upstream scale promises.
- APCA may be used as a SUPPLEMENTARY signal — it models thin/light text better than WCAG 2
  does, so it is useful for catching a pairing that passes the ratio and still reads badly.
  It never overrides a WCAG failure, and a build never conforms "by APCA".
- Record which model a borrowed ramp was tuned to, so the mismatch is visible rather than
  discovered in an audit.

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
  owns only the accent SPLIT that applies them.
