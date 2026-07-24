---
description: Create a crafted web app (CRM, SaaS, landing page) end to end — orchestrates design-research, token + component build, motion-tier selection, and a craft audit by chaining the marketplace's existing UI/motion surfaces.
argument-hint: [product-idea]
---

# /craft-layer:craft

Turn a product idea into a distinctive, animated, informative web app. This command
**orchestrates** existing surfaces — it writes no framework build logic itself; each
step hands off to the command or skill that owns it. Run the steps in order, carrying
each step's output into the next.

`$ARGUMENTS` is the product idea (e.g. "a SaaS analytics dashboard for logistics
teams"). If empty, ask for a one-line product idea and the target stack
(React/Next/Vue/Nuxt/Laravel) before starting.

## Steps

0. **Offer contract, then creative direction.** Apply the `creative-direction` skill.
   FIRST pin the offer contract (`skills/creative-direction/references/offer-contract.md`):
   one product under its real name, the audience, the ONE primary action, the exact route
   list, the page LENGTH (`standard` or `long-scroll` — long is legitimate, undeclared length
   is not), the MODE (`one-shot`, or `guided` to decide the page section by section with the
   user at step 3), and what is not shipping — echoed to the user BEFORE any file is written. If the
   brief admits several products, positionings, or directions, ASK which one; presenting
   options and then building all of them is the failure this step exists to stop, and a
   token/kit showcase is not a site route unless asked for. Carry the contract's offer
   spine (plain-language what, audience, problem, how-it-works, price, proof, objection,
   one CTA) into step 1 so both briefs owe it.
   THEN classify the brief's work-type archetype (`skills/creative-direction/references/archetypes.md`),
   and dispatch the `creative-director` agent to generate a DIVERGENT concept — a central
   metaphor, an editorial voice, and one signature interaction — that breaks the
   sameness-fingerprint defaults (`.../references/sameness-fingerprint.md`) and clears the
   usability floor. Carry the concept AND its divergence record into step 1, plus the
   archetype's content-depth target (`.../references/content-depth.md`) and the
   palette-strategy mood + don't-repeat-recent nudge (`.../references/palette-strategy.md`).
   Without this, mining averages the brief into the recurring spine — this step is what
   makes the build distinct, and the concept must actually reach the briefs (below) or it
   evaporates. The metaphor is a design LANGUAGE, not a rebrand — the real product name
   stays in the title, hero, and nav.

1. **Research → briefs.** Run `/craft-layer:research $ARGUMENTS`, passing the step-0
   concept + divergence record + palette mood as inputs so `design-research` biases BOTH
   briefs toward the concept (its mining method is unchanged; the concept steers what it
   elaborates and which defaults to break). It emits a freeform theme brief and a
   component/layout build task. Detect the target stack here if not already known.

2. **Tokens.** Pass the theme brief to `/ui-ux:theme` to generate design tokens
   (light/dark) with a live colour preview. The brief carries a `theming-system`-derived
   token-system direction (roles/direction, not values — shape per `concept-to-tokens.md`)
   that `/ui-ux:theme` consumes. Do not hand-roll palettes — `/ui-ux:theme` owns generation.

3. **Section decisions — only when the contract declares `guided`.** Apply the
   `section-decisions` skill (or run `/craft-layer:sections` standalone): derive the agenda
   from the contract's spine slots, run the batched rounds (Shape → Treatment → Signature,
   six exchanges maximum, "decide the rest for me" always offered), stage options through
   `taskmaster:visual-decisions` / `/design-preview:preview` / `/shadcn-studio:stage` when
   installed, and write the section ledger. Fold each row's choice + locks into the build
   task so the picks reach step 5. `one-shot` (or headless): skip the exchanges, and let the
   concept and archetype defaults decide — this step is the checkpoint, not a requirement.

4. **Asset plan — decide where the visual assets come from.** Apply the `asset-sourcing`
   skill: classify the assets the concept needs (icons, SVG/vector, 3D, illustration/imagery,
   animated-overlay content, fonts, video), run the build-vs-source-vs-commission decision
   (`skills/asset-sourcing/references/sourcing-decision.md`), and record provenance in the
   manifest (`.../references/licence-discipline.md`) — licence + source per shipped third-party
   asset. Runs BEFORE Build so the build-in-code-vs-source calls feed `/ui-ux:build`.

5. **Build.** Pass the build task — carrying the section ledger's choices when step 3 ran —
   to `/ui-ux:build` to lay out components and screens,
   applying `design-tokens` and, for data-dense CRM/SaaS surfaces, the
   `information-design` skill (hierarchy, density, tables/dashboards, when-to-dataviz).

6. **Motion — route across the craft skills.** Decide what each surface needs, then reach
   for the owning skill (each references its library by path — never re-teach):
   - **Tier** (the base per-surface choice) via `motion-tiers`: Framer Motion, anime.js,
     Three.js/R3F, sprites (`sprite-motion`), or the Vector tier (Lottie/Rive).
   - **Scroll-driven** (smooth scroll, scrub, pin, parallax) → `scroll-orchestration`
     (Lenis + ScrollTrigger).
   - **Route / page transitions** → `page-transitions` (View Transitions + fallback).
   - **Focal / variable-font type** → `kinetic-typography`.
   - **Pointer micro-interactions** (custom cursor, magnetic, tilt, drag) → `interaction-fx`.
   - **Real 2D physics** (gravity, collision, drag-inertia) → `physics-motion`.
   - **Multi-track / editor-authored choreography** → `motion-sequencing`.
   - **Postprocessing / custom shaders on a 3D scene** → `webgl-effects`.
   - **Data-dense surfaces** → `information-design` (also applied in step 5).

   Then fold in the cross-cutting decisions: apply each tier's `prefers-reduced-motion`
   and reduced-bundle fallback; budget the **cumulative** motion JS (one heavy engine
   eager, the rest lazy — `motion-tiers/references/tier-budgets.md`); on an **RTL** target
   mirror direction-bearing motion while keeping charts/numerals/code as LTR-islands
   (`motion-tiers/references/rtl-bidi.md`); and pick the **accent so it clears contrast on
   every surface** it lands on (verified in step 7).

7. **Audit.** Run `/craft-layer:audit` on the result to verify the craft gates
   (reduced-motion per tier, lazy + static-fallback 3D, per-tier + **cumulative** motion
   budget, sprite/asset budgets, **accent-vs-surface contrast**, and the newer-skill
   gates — page-transition fallback, WebGL GPU budget, interaction-fx cursor a11y, physics
   body-cap, sequencing studio-excluded-from-prod) and, via its delegation, full
   accessibility and performance. Resolve any failed gate before declaring the surface done.

## Notes

- Reuse over rebuild: this command never re-teaches token, motion-library, or R3F
  detail — those live in `design-tokens`, `motion-best-practices`, and
  `threejs-best-practices`. It sequences them.
- Stop points are natural after step 2 (tokens approved), step 3 (sections decided) and
  step 5 (skeleton built); a user can run any step's command standalone.
- `guided` is the answer to a broad or half-formed brief: a handful of exchanges up front
  beats discovering at the audit that a whole build answered the wrong question.
