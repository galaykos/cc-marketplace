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
   list, the ROUTE HORIZON (routes the site is known to be getting later and is NOT building
   now — an empty horizon is the common answer; a named one changes the STRUCTURE, because a
   terminal landing page and a front door with siblings coming are different builds), the page
   LENGTH (`standard` or `long-scroll` — long is legitimate, undeclared length
   is not), the MODE — `one-shot` by default, `guided` when `$ARGUMENTS` asks for it in ANY
   words ("guided", "section by section", "give me options", "ask me as you go"); that phrase
   is SCOPE, so strip it from the product idea before passing the idea to step 1 — the
   AMBITION (`standard` by default; `maximal` when `$ARGUMENTS` asks for reach in ANY words —
   "award winning", "awwwards", "over the top", "very graphical", "cinematic", or naming heavy
   motion libraries as the POINT of the brief rather than as a stack constraint; `restrained`
   when it asks for conventional or trust-first). Read
   `skills/creative-direction/references/ambition-tiers.md` for the tier's three reach floors
   and carry the pinned tier onto the build task and into the audit — an ambition echoed only
   as prose in a scope sentence binds nothing and is how a build ignores the bar it was given.
   Ambition words are SCOPE too: strip them from the product idea before step 1 — and what is
   not shipping. Echo the whole contract to the user BEFORE any file is written. If the
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
   FINALLY, once the archetype is classified and the concept exists, PERSIST both artifacts —
   the pinned contract INCLUDING its archetype row, and the divergence record — at the fixed
   paths `craft/offer-contract.md` and `craft/divergence-record.md` under the run's working
   area (the taskmaster docs area when the project has one, otherwise the session scratch;
   never the shipped tree). Persisting before the archetype is classified writes an empty
   Archetype row and leaves the content-depth gate with no anchor. The audit globs for exactly
   those names; a contract that was only spoken cannot be checked against.

1. **Research → briefs.** Run `/craft-layer:research <the product idea from step 0, with the
   mode/length instructions stripped out>` — never `$ARGUMENTS` verbatim, or "guided" is
   researched as part of the product. It reads the step-0 concept, divergence record and
   contract from the persisted `craft/` files and returns the briefs WITHOUT handing off (the
   chain owns steps 2 and 5), so `design-research` biases BOTH
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
   under the exchange cap `decision-rounds.md` sets, "decide the rest for me" always
   offered), stage options through
   `taskmaster:visual-decisions` / `/design-preview:preview` / `/shadcn-studio:stage` when
   installed, and write the section ledger. Fold each row's choice + locks into the build
   task so the picks reach step 6. Two skips, and they differ: `one-shot` skips this step
   entirely and lets the concept and archetype defaults decide, writing no ledger; a `guided`
   run with no interactive user (headless) still runs the agenda, auto-decides every item, and
   writes the ledger with every row `source: auto` so the choices stay reviewable.

4. **Asset plan — decide where the visual assets come from.** Apply the `asset-sourcing`
   skill: classify the assets the concept needs (icons, SVG/vector, 3D, illustration/imagery,
   animated-overlay content, fonts, video), run the build-vs-source-vs-commission decision
   (`skills/asset-sourcing/references/sourcing-decision.md`), and record provenance in the
   manifest (`.../references/licence-discipline.md`) — licence + source per shipped third-party
   asset. Runs BEFORE Build so the build-in-code-vs-source calls feed `/ui-ux:build`.
   This step OWNS the manifest file: write it into the project at one of the accepted names
   (`ASSETS` / `CREDITS` / `PROVENANCE` / `THIRD-PARTY-NOTICES`) as soon as the asset plan is
   decided, and carry the plan into step 6 on the build task's `Assets / provenance:` line, so
   the build sources what was decided. Skipping this because "everything is drawn in code"
   still owes the manifest a first-party declaration — the licence gate runs on static,
   all-in-code builds too, and an unwritten manifest is a finding nobody was assigned to
   prevent. And when the contract pinned `maximal`, an all-first-party manifest declaring that
   nothing shipped does not DISCHARGE this step: it satisfies the licence gate and fails the
   asset-posture floor, because the brief asked for the thing emptiness cannot deliver
   (`skills/creative-direction/references/ambition-tiers.md`).

5. **Motion — decide it BEFORE the build.** This step DECIDES; step 6's `/ui-ux:build`
   implements; craft-layer writes no animation code itself. Motion decided AFTER a layout is
   committed can only be retrofitted onto markup that was not built for it, which is how a
   page ends up with nothing but fade-and-rise reveals: the effects that need STRUCTURE — a
   pinned scroll act, a WebGL hero surface, a shared-element route transition, a physics
   stage — must be in the build task or they cannot ship at all.
   START FROM THE SIGNATURE. Read the persisted `craft/divergence-record.md` and make the
   concept's ONE signature interaction the first motion decision: which section owns it (the
   ledger's `signature` row when step 3 wrote one), which craft skill implements it, and
   which tier it costs. The signature is the page's motion FLOOR — every other surface is
   that plus a baseline — and it is the only motion decision the audit can check by name. A
   run whose signature never reaches the build task has lost the concept for a second time
   (step 1 is the first), and the tier picker will not recover it: it takes the CHEAPEST tier
   that fits each surface, so nothing reaches for anime.js, Three.js, physics, or the Vector
   tier unless a decision here demands it.
   WHEN THE CONTRACT PINNED `maximal`, this step owes the reach floors too
   (`skills/creative-direction/references/ambition-tiers.md`): at least THREE distinct motion
   capabilities driving real surfaces — a tier or a sibling engine each count once — and at
   least one AUTHORED graphic system — generative or
   procedural canvas, a WebGL/shader surface, a programmatic SVG system, sprites, or a
   designer-authored vector asset. Rules, borders, icons and type treatment are composition,
   not a graphic system. Buy the reach with LAZY loading, never with a second eager engine:
   the cumulative budget does not move for ambition, and a floor cleared by breaking a ceiling
   has traded one finding for a worse one. A floor the brief genuinely does not want is waived
   in the divergence record with the reason — never by silence.
   Then work out what each remaining surface needs, and resolve THREE lines on the build task:
   `Motion:` — a named tier per surface plus the fallbacks below — `Signature:` — the
   move, its section, and its owning skill — and `Ambition:` — the pinned tier, plus, at
   `maximal`, which surface carries the graphic system and which tiers make up the three. Reach for the owning skill to make each call
   (each references its library by path — never re-teach):
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
   - **Data-dense surfaces** → `information-design` (also applied in step 6).

   Then fold in the cross-cutting decisions: apply each tier's `prefers-reduced-motion`
   and reduced-bundle fallback; budget the **cumulative** motion JS (one heavy engine
   eager, the rest lazy — `motion-tiers/references/tier-budgets.md`); on an **RTL** target
   mirror direction-bearing motion while keeping charts/numerals/code as LTR-islands
   (`motion-tiers/references/rtl-bidi.md`); and pick the **accent so it clears contrast on
   every surface** it lands on (verified in step 7).

6. **Build.** Pass the build task — carrying the section ledger's choices when step 3 ran,
   the asset plan from step 4, and step 5's resolved `Motion:`, `Signature:` and `Ambition:`
   lines — to
   `/ui-ux:build` to lay out components and screens, applying `design-tokens` and, for
   data-dense CRM/SaaS surfaces, the `information-design` skill (hierarchy, density,
   tables/dashboards, when-to-dataviz). ONE pass: layout and motion land together, because
   the signature and the scroll device are structural, not decoration applied afterwards.

7. **Audit — the run is NOT complete until this has run.** Run `/craft-layer:audit` on the
   result to verify the craft gates
   (the **signature interaction actually shipped** on the section step 5 assigned it,
   the pinned **ambition** honored — at `maximal`, the three reach floors,
   reduced-motion per tier, lazy + static-fallback 3D, per-tier + **cumulative** motion
   budget, sprite/asset budgets, **accent-vs-surface contrast**, and the newer-skill
   gates — page-transition fallback, WebGL GPU budget, interaction-fx cursor a11y, physics
   body-cap, sequencing studio-excluded-from-prod) and, via its delegation, full
   accessibility and performance. Resolve any failed gate before declaring the surface done.

   **A green project suite is not this step.** The most likely way this chain fails is that
   step 6 ends with the target's own gate passing — a test run, a typecheck, a lint, a build —
   and the run reads that as done and stops. The project's suite proves the code is correct.
   It proves nothing about whether the signature shipped, the contract was honored, the
   ambition was reached, or the divergence record's claims are true of what was built: those
   are checked HERE and nowhere else, by an agent this step dispatches. A build that skipped
   this step has no craft verdict, however green it is.

   So the run's final message owes one line, and it is the report the user gets instead of a
   claim: `Craft audit: <ran | NOT RUN> · Gates: <n> checked · <n> not checked · <n> not
   measured`. `NOT RUN` is a legitimate outcome — the audit needs a reachable target, and
   headless or unbuildable runs cannot produce one — but it is stated, never implied by
   silence. Declaring a surface done without that line is the finding this step exists to
   prevent.

## Notes

- Reuse over rebuild: this command never re-teaches token, motion-library, or R3F
  detail — those live in `design-tokens`, `motion-best-practices`, and
  `threejs-best-practices`. It sequences them.
- Stop points are natural after step 2 (tokens approved), step 3 (sections decided) and
  step 6 (built); a user can run any step's command standalone.
- `guided` is the answer to a broad or half-formed brief: a handful of exchanges up front
  beats discovering at the audit that a whole build answered the wrong question.
