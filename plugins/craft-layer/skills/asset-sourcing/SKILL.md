---
name: asset-sourcing
description: Use when a web-app surface needs a visual asset — an icon system, SVG/vector, 3D model, animated modal/overlay, illustration or imagery, a font, or background video — and you must decide whether to build it in code, source an open asset, or commission it, in what format, at what bundle cost, under what licence. Routes each kind, pins the six-axis build-vs-source-vs-commission decision, and enforces a machine-findable licence/provenance gate; never names a vendor, never ships an asset.
---

## What this decides

This skill owns WHERE an award-grade visual asset comes from — build it in code,
source an open one, or commission it — and pins the format, bundle cost, and licence
of that choice. It does not author the asset, re-teach a runtime, or theme it. Those
jobs belong to neighbours — reference them by path, never restate:

- Sprite-sheet / raster-frame authoring, and background video motion:
  `plugins/craft-layer/skills/sprite-motion/SKILL.md`.
- Lottie-vs-Rive vector-motion playback + budget:
  `plugins/craft-layer/skills/motion-tiers/references/vector.md`.
- Three.js / R3F 3D correctness and the Tier-3 poly/texture budget:
  `plugins/threejs/skills/threejs-best-practices/SKILL.md`.
- Token / `currentColor` theming of an asset:
  `plugins/ui-ux/skills/design-tokens/SKILL.md`.
- Typeface-as-motion and variable-font selection:
  `plugins/craft-layer/skills/kinetic-typography/SKILL.md`.
- Modal mechanics (focus-trap, enter/exit, reduced-motion): `motion-tiers`,
  `plugins/craft-layer/skills/interaction-fx/SKILL.md`,
  `plugins/craft-layer/skills/page-transitions/SKILL.md`.
- Dialog / focus-order a11y of an overlay: `/a11y:audit`.

The net-new value here is the source decision, the categorical taxonomy, and the
licence/provenance gate — nothing this skill routes to owns those.

## Classify the asset, take the first that fits

Answer in order; the first kind that matches routes the decision:

1. An **icon** or a whole icon system (nav glyphs, action affordances, a set)? →
   `references/iconography.md`.
2. A flat **vector** — logo, diagram, line-art, decorative SVG? →
   `references/vector-3d.md` (SVG half).
3. A real **3D** model, product viewer, or AR object (glTF / GLB / USDZ)? →
   `references/vector-3d.md` (3D half) — budget + correctness hard-cited to threejs.
4. **Illustration or photographic imagery** — a hero, spot art, a content photo? →
   `references/illustration-imagery.md`.
5. **Animated overlay content** — a Lottie / animated-SVG / short video living inside
   a modal? → `references/animated-modals.md` (owns SOURCING the content; cites modal
   mechanics by path).
6. A **font** / typeface? → `kinetic-typography` (+ its `variable-fonts` reference)
   selects it; its LICENCE runs through the gate below.
7. Background or inline **video**? → `sprite-motion` owns the motion; its LICENCE runs
   through the gate below.

Every kind then passes the two cross-cutting gates before it ships.

## Per-kind one-liner

- **Icon** — a SYSTEM, not a pack: one stroke / grid / optical-size / corner /
  metaphor language, delivered as inline-SVG, SVG-sprite, or icon-font; `currentColor`
  for theming.
- **Vector** — hand-author or optimise SVG (SVGO), inline-vs-file by reuse; the source
  decision runs on the six axes.
- **3D** — glTF / GLB with Draco / meshopt, USDZ for AR; lazy-loaded and budget-gated —
  the numbers live in Tier-3 + threejs, not here.
- **Illustration / imagery** — custom-vs-open art direction, one visual language,
  AVIF / WebP delivered with a `<picture>` art-direction fallback.
- **Animated overlay** — build-vs-source the overlay motion (hand-code vs a shipped
  Lottie / `.riv` / video); reduced-motion + no-jank enter/exit are mandatory.
- **Font** — selection defers to kinetic-typography; the gate carries its licence
  (SIL-OFL obliges shipping the licence text + Reserved-Font-Name).
- **Video** — sprite-motion owns encode / poster / fallback; the gate carries its
  licence.

## The source decision (six axes)

WHICH of the five source classes fits is decided in `references/sourcing-decision.md`
on six axes — budget · licence · format · perf/bundle · fidelity · **uniqueness** —
across build-in-code · open-source-lib · asset-marketplace · commission · AI-assisted.
The uniqueness axis feeds the EXISTING anti-sameness gate: a default stock hero or a
default icon set is a fingerprint default, not a neutral choice.

## Cross-cutting gates

Both apply on top of the routed kind, on every asset:

- **Licence / provenance gate** (INDEX-THIN — the schema lives in
  `references/licence-discipline.md`). Every build that ships a non-code visual or
  font asset carries a machine-findable provenance record per asset (licence-class +
  source); an all-in-code build still ships the manifest, asserting "no third-party
  assets". A missing manifest, an orphan asset, or an empty / `unknown` licence value
  is the finding — the gate checks declaration completeness + schema, not legal truth.
  Full licence classes, the obligations, and the manifest shape:
  `references/licence-discipline.md`.
  **A complete manifest is not automatically a discharged asset plan.** When the contract
  pinned `maximal`, a manifest declaring first-party-and-nothing-shipped passes THIS gate and
  fails the asset-posture floor — different questions, and the second one is why a build that
  was asked for reach can ship no imagery with every gate green
  (`../creative-direction/references/ambition-tiers.md`; the escape is build-in-code
  generative imagery, not commission — see `references/sourcing-decision.md`).
- **Reduced-bundle + reduced-motion fallback** — every asset kind ships a lighter path
  (static poster, lower-fidelity format, or an in-code fallback) AND a reduced-motion
  path. These reuse the EXISTING sprite / webgl budgets and motion-tier fallback rules —
  no new budget numbers are invented here.

## References

- `references/sourcing-decision.md` — build-vs-source-vs-commission on the six axes +
  the five categorical source classes and their selection criteria.
- `references/licence-discipline.md` — the licence / provenance gate: licence classes,
  what each obliges, and the machine-findable manifest requirement.
- `references/iconography.md` — icons as a system: consistency axes + icon-font vs
  inline-SVG vs SVG-sprite + `currentColor` theming + a11y.
- `references/vector-3d.md` — SVG/vector sourcing (SVGO, inline-vs-file) + 3D-model
  sourcing (glTF / GLB, Draco / meshopt, USDZ); all perf numbers cited to Tier-3.
- `references/illustration-imagery.md` — illustration + imagery art-direction
  (custom-vs-open, AVIF / WebP, `<picture>`), feeding the "no default stock hero".
- `references/animated-modals.md` — sourcing the animated overlay CONTENT; cites modal
  mechanics + `/a11y:audit` by path.

## Anti-patterns

- **Naming a vendor** — a commercial asset vendor, marketplace, stock site, or a named
  icon pack. Open formats / standards (glTF, GLB, AVIF, WebP, SVG, USDZ) and open tools
  / runtimes (SVGO, Draco, meshopt, Lottie, Rive) ARE fine to name; a vendor is the
  kill-trigger.
- **Shipping an asset** — this skill decides sourcing; it NEVER ships an actual icon
  set, model, or image. Ship an asset and it has become a catalog — stop and re-scope
  to categories + selection criteria.
- **Re-teaching a neighbour** — copying sprite-motion, Vector-tier, threejs, or
  design-tokens content in here instead of citing it by path; any restated budget
  NUMBER or re-taught API is a finding.
- **A shipped asset with no provenance** — a third-party or AI-assisted asset with no
  machine-findable licence + source record; the licence gate fails it.
- **A default posing as a choice** — a stock hero or a stock icon set shipped as the
  "neutral" default; the uniqueness axis flags it as a sameness fingerprint.
