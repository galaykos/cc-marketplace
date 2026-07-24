# Brief templates

Two fill-in briefs, each annotated with the command that consumes it. These are the
ONLY outputs of design-research — plain strings the existing commands already take.
Do not invent a token-intent file; nothing reads one.

Values (hex, px, token names) are NOT set here — the theme brief carries adjectives and
references, and `/ui-ux:theme` plus `plugins/ui-ux/skills/design-tokens/SKILL.md`
resolve them into a real palette and scale.

---

## Template 1 — Theme brief

**Consumed by:** `/ui-ux:theme` — passed as its `[brand-color-vibe-or-reference]`
argument (a single freeform string). The command runs its own stack detection, palette
generation, contrast checks, and live preview; hand it INTENT, not values.

Compose one string from these parts (drop any that do not apply):

```
<brand colour or hue family>, <vibe in 2–4 words>, echoing <reference site/brand>;
<light or dark priority>; surfaces <warm/cool/neutral, low-chroma>; type <serif/sans/
mono mix, display-vs-body contrast>; corners <sharp/rounded/pill>; depth <flat/
bordered/shadowed>; motion feel <snappy/smooth/dramatic>.
```

Filled example:

```
Deep indigo primary, warm-editorial and calm, echoing Linear's restraint; light-first
with a real dark mode; neutral low-chroma surfaces; humanist sans with high display
contrast; slightly-rounded corners; bordered depth over heavy shadow; smooth,
understated motion.
```

Rules:
- Adjectives and references only — no `#hex`, no `--token`, no px. `/ui-ux:theme` owns
  the numbers.
- If the target already has a brand palette/typeface, say "echo the existing brand" and
  name it, so the command re-uses rather than replaces it.
- One coherent voice — it must match the build task's patterns.

**Token-system direction (derived by `theming-system`).** Alongside the string above, the
theme brief carries a compact token-system-direction block whose SHAPE is owned by
`plugins/craft-layer/skills/theming-system/references/concept-to-tokens.md` —
`theming-system` derives it and `/ui-ux:theme` consumes it. Fill it as ROLES and direction
only (never a value): the surface/ink/accent tier direction, the status/chart role intent,
and the light/dark duality that the concept implies. Follow `concept-to-tokens.md` for the
block's exact three-line format; do not restate the payload here — thread it.

---

## Template 2 — Build task

**Consumed by:** `/ui-ux:build` — passed as its `[what-to-build]` argument. The
ui-ux-engineer worker applies the stack best-practice skill,
`plugins/ui-ux/skills/design-tokens/SKILL.md` (spacing/type/radius/elevation/motion from
the scale), and `shadcn-theming` when colour is in play. Carry the PATTERNS here.

```
Build <component/layout> in <where: route/file/section>.
Spine slots: <which offer-contract slots this section carries>.
Decided: <the section ledger's `choice` for this section — omit on a one-shot run>.
Locks: <the ledger's `locks` — the component, instrument, data need, or copy slot it commits>.
Layout: <grid/columns/hero composition, max-width, density>.
Components: <card anatomy, table/list density, form rhythm, key states>.
Interaction: <hover/focus, disclosure, scroll/transition behaviour>.
Motion: <what animates, entrance vs micro-interaction, energy> (per motion-tiers).
Responsive: <how it reflows at phone / tablet / full>.
Patterns borrowed from: <source URLs + the one-line why from the mining worksheet>.
```

Filled example:

```
Build the pricing section on /pricing. Layout: three-column card grid, centred,
max-width ~1100px, generous whitespace. Components: cards with tier name, price,
feature list, single CTA; the recommended tier raised with a border accent, not a
shadow. Interaction: subtle hover lift on cards; monthly/annual toggle with an
animated pill. Motion: cards fade-and-rise on scroll into view, staggered, calm
energy. Responsive: three columns → one, cards full-width at phone. Patterns from
stripe.com/pricing (tier hierarchy) and linear.app (restraint, border accents).
```

Rules:
- Patterns and structure, not colour — colour rides in the theme brief.
- Reference token DIRECTION by adjective ("compact density"), never token values; the
  worker resolves them via `design-tokens`.
- Name the source + why for each borrowed pattern, so the build is traceable.

---

## Consistency check before handing off

- The theme brief's vibe and the build task's patterns describe ONE product, under its
  REAL name — not a name the concept's metaphor invented.
- The build task names which offer-spine slots its section carries (plain-language what,
  audience, problem, how-it-works, price, proof, objection, primary CTA), so the pinned
  contract reaches the build instead of stopping at the concept
  (`plugins/craft-layer/skills/creative-direction/references/offer-contract.md`).
- Every genuinely open choice was decided, not guessed — staged through whichever staging
  surface is installed, or degraded to a written choice per `section-decisions`. On a
  `one-shot` run the concept and archetype defaults decide, which counts as decided.
- On a `guided` run, every section's `Decided` + `Locks` lines come from the section ledger —
  a build task written from the concept alone silently discards the user's picks.
- Neither brief contains hex/px/token names — only the decided direction and patterns.
