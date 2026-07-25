# Build vs source vs commission — the decision

This reference owns the core decision the router points every asset kind at: given a
need, WHERE does the asset come from, and under what terms. It decides on six axes and
resolves to one of five categorical source classes. It names no vendors, no
marketplaces, and no packs — only categories and the criteria that pick between them.

The router (`../SKILL.md`) has already classified the KIND (icon, vector, 3D,
illustration/imagery, animated-overlay content, font, video) and sent the licence and
format specifics to the per-kind references. This file is kind-agnostic: the same six
axes and five classes apply whatever the asset is.

## The six axes

Score every candidate source against all six. No single axis decides alone; a source
wins when it is acceptable on every axis and best on the ones that matter for the
surface. Record the scoring so the craft audit can check the choice.

1. **Budget** — the human/time and money cost to obtain the asset at the required
   quality. Building in code is cheap for simple shapes and expensive for rich
   illustration; commissioning is the inverse. State the cost, do not hand-wave it.
2. **Licence** — can this asset ship, under what obligations (attribution, share-alike,
   licence-text bundling, ToS limits)? The full licence-class taxonomy and the
   machine-findable provenance requirement live in `licence-discipline.md`; this axis
   only asks "is the licence acceptable AND declarable" — an undeclarable licence
   fails here before any other axis matters.
3. **Format** — does the source yield the right format for the kind (SVG for icons and
   vector, glTF/GLB for 3D, AVIF/WebP for imagery, an open font format), with the
   fallback the kind requires? A source that only offers a wrong or lossy format is a
   format-axis failure even if it is free and permissively licensed.
4. **Perf / bundle** — the shipped weight and runtime cost. This axis REUSES the
   existing budgets — sprite/webgl weight and the Tier-3 poly/texture budget in
   `plugins/threejs/skills/threejs-best-practices/SKILL.md`, imagery/icon/font weight in
   `/performance:review`. No new byte numbers are invented here; a source that cannot
   meet the kind's existing budget fails this axis.
5. **Fidelity** — does the asset meet the award-grade quality bar for the surface
   (crispness, consistency with the rest of the system, art direction)? A cheap,
   correctly-licensed, well-formatted asset that looks generic still fails fidelity.
6. **Uniqueness** — is a bespoke asset REQUIRED here, or is a shared/common one
   acceptable? A hero, a brand mark, a signature illustration, or a distinctive icon
   system usually must be unique; a utility glyph rarely does. **Uniqueness feeds the
   existing anti-sameness gate**: a default stock hero or a default icon set is a
   fingerprint default — a same-as-everyone choice the anti-sameness reviewer flags,
   not a neutral one. High uniqueness pushes the decision toward build-in-code or
   commission; low uniqueness admits a shared open source.

The axes interact: a high-uniqueness, high-fidelity need with a modest budget points at
commission or build-in-code; a low-uniqueness utility need with a tight budget points at
build-in-code or an open-source library. Licence and format are gates — fail either and
the source is out regardless of the other four.

## When the answer is COMMISSION, say so and stop

This decision can return an answer the craft flow cannot execute. Commissioned
illustration, a photoreal 3D scene, a bespoke type sculpture — these are what the top of
the field is actually built from, and no orchestration layer produces them. The honest
failure mode is not admitting it: the axes get re-run until they yield something
build-in-code can satisfy, and the result is recorded as a decision when it was a
capitulation.

So when the axes point at commission:

- **Record commission as the answer**, in the asset plan and the provenance manifest,
  even when the build then ships a placeholder or a first-party substitute. The gap is
  the useful information — it tells whoever picks this up what the page is missing.
- **Name the substitute as a substitute.** A first-party mark standing in for
  commissioned artwork is a stand-in, not a choice, and the divergence record should not
  claim it as one.
- **A build whose every asset resolves to first-party has probably hit this ceiling
  rather than reasoned its way to a position.** Check whether the brief truly needed no
  imagery, or whether nothing here could have produced any. Both are legitimate; only one
  is a design decision.

## The five source classes

The taxonomy is CATEGORICAL. These are the only source classes; a specific vendor,
marketplace, stock site, or named pack is never the answer — the class is.

### 1. build-in-code

The asset is authored as code/markup in the repo — an SVG hand-written or generated,
a shape drawn with CSS/Canvas/WebGL, a 3D primitive composed in the scene graph.
- **Pick when** uniqueness is high, the shape is simple-to-moderate, exact control and
  themeability matter, and there must be zero third-party licence surface. Icons,
  logos, diagrams, simple decorative vector, and geometric 3D favour this class.
- **Licence** — first-party by definition; the provenance manifest records it as
  `origin: first-party`, no external licence-class.
- **Cost/risk** — engineering time; rich illustration or organic 3D is expensive or
  infeasible to hand-author at award-grade fidelity.

### 2. open-source-lib

The asset (or the runtime that plays it) comes from an openly-licensed library or an
open, redistributable asset collection — used categorically, never named here.
- **Pick when** uniqueness is low, a well-formatted open asset exists at the required
  fidelity, and its licence is permissive/declarable. Utility icon sets, common vector
  shapes, and open runtimes for vector motion (Lottie/Rive) fit here.
- **Licence** — `permissive` / `public-domain/CC0` / `CC-BY`; attribution obligations
  and licence-text bundling (e.g. SIL-OFL fonts) are enforced by `licence-discipline.md`.
- **Cost/risk** — near-zero cost, but sameness risk (see the uniqueness axis) and a
  provenance obligation that MUST be declared.

### 3. asset-marketplace

A licensed asset is obtained through a commercial asset marketplace as a CATEGORY —
this file names no specific marketplace and ships nothing from one.
- **Pick when** an open-source asset does not exist at the fidelity required, the need
  is not unique enough to justify commissioning, and the budget allows a paid,
  clearly-licensed asset. Mid-fidelity illustration, imagery, and 3D models fit here.
- **Licence** — typically `commercial`; the licence terms and any per-seat/redistribution
  limits are recorded per `licence-discipline.md`, and the licence must be shippable.
- **Cost/risk** — money + the sameness risk of a widely-sold asset (uniqueness axis);
  the kill-trigger forbids naming the marketplace or shipping the asset from this skill.

### 4. commission

A bespoke asset is commissioned from a human creator (illustrator, 3D artist,
type designer, motion designer).
- **Pick when** uniqueness AND fidelity are both high and no build-in-code path reaches
  the bar — signature illustration, a brand-defining 3D object, a custom typeface.
- **Licence** — `commissioned`; the deliverable's rights/usage terms are recorded and
  must permit the intended shipping.
- **Cost/risk** — highest money and lead-time cost; reserved for assets that carry the
  surface's identity.

### 5. AI-assisted

The asset is generated or substantially derived with an AI tool.
- **Pick when** it accelerates a first-party asset AND the tool's terms permit the use;
  treat output as provenance-uncertain until verified.
- **Licence** — `AI-assisted`: provenance-uncertain / ToS-bound. Record the tool and its
  terms per `licence-discipline.md`; never assume the output is unencumbered.
- **Cost/risk** — provenance and rights uncertainty, plus a real sameness/quality risk;
  the fidelity and uniqueness axes still apply.

## Selection criteria (summary)

- High uniqueness + high fidelity, infeasible to hand-author → **commission**.
- High uniqueness + moderate complexity, controllable in code → **build-in-code**.
- Low uniqueness, open asset exists at fidelity, declarable licence → **open-source-lib**.
- Mid fidelity, no open asset, unique-enough to pay but not to commission → **asset-marketplace**.
- Accelerating a first-party asset, tool terms permit → **AI-assisted** (record provenance).
- Any class → the licence must be acceptable AND declarable, and the format + existing
  perf budget must be met, or the class is out on a gate axis.

## Kill-trigger boundary (binding)

**Allowed:** open formats / standards / techniques (glTF, GLB, AVIF, WebP, SVG, USDZ)
and de-facto open tools / runtimes (SVGO, Draco, meshopt, Lottie, Rive) — the latitude
motion-tiers takes with Framer / anime / Three.js. **Kill-trigger:** a commercial asset
VENDOR / MARKETPLACE / stock site, a named ICON PACK, or shipping an actual asset.

Naming a category (`asset-marketplace`, `commission`) is required and correct; naming a
specific vendor, marketplace, stock site, or pack, or committing an actual icon set,
model, or image into a plugin, means this framework has become a catalog — stop and
re-scope to categories + selection criteria.
