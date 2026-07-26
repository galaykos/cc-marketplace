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

## Boost — `ultra-craft`

<!-- boost-preamble:start -->
This run is BOOSTED when `$ARGUMENTS` carries `ultra-craft` (or `ultracraft`), or a
bare `ultra` as the FIRST token of this command's own argument string. A bare
`ultra` belonging to another command — `/caveman ultra` ahead of this call, a flag
of some other tool — never fires it. When boosted, apply the `ultra-craft` skill
(`skills/ultra-craft/SKILL.md`) and honor its six bindings: `Ambition` is pinned
`maximal` and `Mode` is pinned `guided` in step 0 rather than read from the brief,
`Boost: ultra-craft` is stamped into the persisted contract, step 1's research is
LIVE and dated per `skills/ultra-craft/references/research-mandate.md`, the
reference board is echoed and confirmed before step 2, `creative-director` and
`craft-reviewer` dispatch at the boosted tier, and step 7 is followed by a red-team
of the shipped tree. The boost token is SCOPE — strip it from the product idea
before step 1, exactly as mode and ambition words are stripped. Print the skill's ⚡
banner first, with its cost line.
<!-- boost-preamble:end -->

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
   not shipping. A BOOSTED run (see Boost above) does not READ these two rows: it pins
   `Ambition: maximal` and `Mode: guided` outright and records `Boost: ultra-craft`. Where a
   boosted brief ALSO asks for conventional, trust-first, fast or cheap, the two orders
   conflict — ASK which one wins rather than picking silently. Echo the whole contract to the user BEFORE any file is written. If the
   brief admits several products, positionings, or directions, ASK which one; presenting
   options and then building all of them is the failure this step exists to stop, and a
   token/kit showcase is not a site route unless asked for. Carry the contract's offer
   spine (plain-language what, audience, problem, how-it-works, price, proof, objection,
   one CTA) into step 1 so both briefs owe it.
   THEN classify the brief's work-type archetype (`skills/creative-direction/references/archetypes.md`).
   BEFORE the deck draw, read the PROJECT MEMORY: `<project>/.craft-layer/run-log.md` when it
   exists — its last 5 rows are what THIS run has to differ from. When the directory does not
   exist, create `<project>/.craft-layer/` carrying a `.gitignore` whose only line is `*`, so
   nothing under it is ever committed. `.craft-layer/` is NOT the `craft/` working area and does
   not move it — it holds only what must OUTLIVE the session (the run log, `waivers.json`,
   `shots/`), so the log is never written to the session scratch, while the three `craft/`
   artifacts keep the paths and the working-area rule stated below, unchanged.
   THEN DRAW the run's starting constraint: one option per axis from
   `skills/creative-direction/references/concept-deck.md`, seeded by the run log and excluding
   the options its last 5 rows used. The deck is drawn from, never chosen from. An absent,
   empty or MALFORMED log is treated as EMPTY — warn, seed the draw from a hash of the brief
   text plus today's date, and carry on; a bad log never fails a run. Carry the five drawn
   options into the dispatch below as the room the candidates are generated inside.
   THEN dispatch the `creative-director` agent to generate a DIVERGENT concept — a central
   metaphor, an editorial voice, and one signature interaction — that breaks the
   sameness-fingerprint defaults (`.../references/sameness-fingerprint.md`) and clears the
   usability floor. Carry the concept AND its divergence record into step 1, plus the
   archetype's content-depth target (`.../references/content-depth.md`) and the
   palette-strategy mood + don't-repeat-recent nudge (`.../references/palette-strategy.md`).
   Without this, mining averages the brief into the recurring spine — this step is what
   makes the build distinct, and the concept must actually reach the briefs (below) or it
   evaporates. The metaphor is a design LANGUAGE, not a rebrand — the real product name
   stays in the title, hero, and nav.
   THEN run the CONCEPT FORK, and run it at EVERY tier — `one-shot` included. Have the
   dispatch return 2–3 candidates instead of one, present each as { the five-axis deck draw ·
   central metaphor · editorial voice · signature interaction }, and ask which one the build
   runs on with `AskUserQuestion`. The concept fork forks on CONCEPT — the spine and the
   signature move — never on three shades of one accent: `/ui-ux:theme` already forks on
   colour at its own step, and a second colour fork here would buy nothing. Variety a human
   picked beats variety a model reports having produced. A headless run, or one the user
   leaves unanswered, AUTO-PICKS the top-scored candidate and records `source: auto` on the
   chosen row — the same lane a `guided` ledger already uses — so an unattended choice stays
   reviewable instead of invisible. Degenerate case: when fewer than 2 candidates clear the
   usability floor there is nothing to fork BETWEEN, so do NOT ask — inherit the agent's
   existing weak-round path (regenerate once, then return the winner flagged
   `low-confidence` for human review). The chosen candidate's draw is the one persisted
   below, logged in step 7 and gated by the audit; the unchosen draws are discarded.
   FINALLY, once the archetype is classified and the concept exists, PERSIST both artifacts —
   the pinned contract INCLUDING its archetype row and its `Boost` row, and the divergence
   record — at the fixed
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
   ON A BOOSTED RUN this step's mining is LIVE, not recalled: fetch every source, six minimum
   across the three lanes, each carrying a URL, a fetch date and a why-line, per
   `skills/ultra-craft/references/research-mandate.md`. That file also names THREE galleries
   that all get a category-scoped search with the query recorded — `land-book.com`,
   `awwwards.com`, `dribbble.com` — and holds the rule that a dribbble shot is direction
   only, never evidence a pattern ships. Searching and sourcing are separate counts. Then persist
   `craft/reference-board.md` beside the other two artifacts and ECHO it to the user before
   step 2 generates anything — sources, patterns pulled, the direction they imply, the
   sameness defaults being broken, and the section agenda step 3 will run. The user confirms
   or redirects THERE. A board compiled after the tokens exist reports a decision instead of
   making one.

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

   **Show the result forming.** After each major section lands — the hero, then the
   signature section, then the assembled page — capture ONE shot at the primary breakpoint
   and show it to the user. Name them so the order reads at a glance: `build-01-hero.png`,
   `build-02-signature.png`, `build-03-full.png`, and so on in the order they land.
   This is not a second preview system and never a second server. It reuses step 7's capture
   path exactly: the same `<project>/.craft-layer/shots/` directory, the same settle sequence
   (scroll to the bottom, let what that fires finish, return to the top), against the SAME
   dev server the build is already running on. A staged mockup can drift from what ships —
   here the preview IS the artifact, which is the only reason it is worth showing.
   Shots are pruned at the start of each run, so this run's progressive images never mix with
   the previous run's; step 7's suite prunes again when it captures its own breakpoint grid,
   so the `build-NN` images are an in-flight view — shown when they are taken — rather than
   an archive.
   NO DEV SERVER, no browser, or a target that cannot be served: step 6 emits nothing and
   SAYS so in one line — `Progressive shots: none (no dev server)`. It never blocks the
   build, never holds a section back waiting for a picture, and never implies a preview
   nobody saw.

7. **Audit — the run is NOT complete until this has run.** Run `/craft-layer:audit` on the
   result to verify the craft gates
   (the **signature interaction actually shipped** on the section step 5 assigned it,
   the pinned **ambition** honored — at `maximal`, the three reach floors,
   reduced-motion per tier, lazy + static-fallback 3D, per-tier + **cumulative** motion
   budget, sprite/asset budgets, **accent-vs-surface contrast**, and the newer-skill
   gates — page-transition fallback, WebGL GPU budget, interaction-fx cursor a11y, physics
   body-cap, sequencing studio-excluded-from-prod) and, via its delegation, full
   accessibility and performance. Resolve any failed gate before declaring the surface done.

   **Install the gate suite, then LOOK at what it captured.** The suite is
   `${CLAUDE_PLUGIN_ROOT}/template/craft-gates/` — `gates.spec.ts`, `contrast.mjs` and
   `divergence.mjs`. When the project has no suite of its own, INSTALL it rather than
   recommending it: copy all three in (the two `.mjs` files beside the project's other
   scripts), `npm i -D @playwright/test @axe-core/playwright && npx playwright install
   chromium`, and point it at the dev server step 6 already has up —
   `BASE_URL=<that server> npx playwright test`, then `node scripts/contrast.mjs` and
   `node scripts/divergence.mjs`. No second server and no second capture path: the surface
   the build is running on is the one the pictures are taken from.
   The capture trigger writes PNGs into `<project>/.craft-layer/shots/` — two per breakpoint
   at 390, 768 and 1280, light and dark, after a scroll-settle. OPEN THEM. Every tier opens
   them, not only a boosted run: Read each image and say what is actually visible, hunting
   the class every DOM assertion in that suite passes — text clipped at a container or
   viewBox edge, labels or annotations overlapping each other, truncation ellipses, a fixed
   element covering the content beneath it, and any element whose rendered position differs
   from where the markup implies it sits. A shot that was written and never opened is not a
   look, and reporting it as one is exactly the claim this step exists to stop.
   When capture cannot happen — no package manager, no reachable server, a headless target
   with no browser — report `Visual: NOT CAPTURED (<reason>)` and carry on. Before concluding
   that, retry with an ABSOLUTE PATH inside an allowed root: a tool that refuses one path is
   not a tool that cannot write.
   Three consequences, and they are deliberately different:
   - `divergence.mjs` exiting non-zero is a step-7 FINDING with the same standing as every
     other craft gate — resolve it, or waive it in `<project>/.craft-layer/waivers.json` with
     a reason, before the surface is called done. Exit 2 is `not measured`, never a pass.
   - A defect FOUND in an opened shot IS a finding, on the same list as the gate failures,
     whatever the DOM checks reported.
   - `Visual: NOT CAPTURED` is REPORTED, never blocking — the same standing as the legitimate
     `NOT RUN` below. The unacceptable outcome is neither of those; it is silence.

   **A green project suite is not this step.** The most likely way this chain fails is that
   step 6 ends with the target's own gate passing — a test run, a typecheck, a lint, a build —
   and the run reads that as done and stops. The project's suite proves the code is correct.
   It proves nothing about whether the signature shipped, the contract was honored, the
   ambition was reached, or the divergence record's claims are true of what was built: those
   are checked HERE and nowhere else, by an agent this step dispatches. A build that skipped
   this step has no craft verdict, however green it is.

   So the run's final message owes two lines, and they are the report the user gets instead
   of a claim: `Craft audit: <ran | NOT RUN> · Gates: <n> checked · <n> not checked · <n> not
   measured`, and beneath it `Visual: <n> shots opened` — or `Visual: NOT CAPTURED
   (<reason>)`. `NOT RUN` is a legitimate outcome — the audit needs a reachable target, and
   headless or unbuildable runs cannot produce one — but it is stated, never implied by
   silence, and so is a capture that did not happen. Declaring a surface done without those
   lines is the finding this step exists to prevent.

   **Then append the run log.** Once the audit has run, append ONE row to
   `<project>/.craft-layer/run-log.md` (create the file with its header when missing) and trim
   it to the last 5 rows. The row is a markdown table row with these seven columns, in this
   order:

   ```
   | date | brief-slug | hue-family | type-strategy | spine | signature | draw |
   ```

   `draw` holds the five drawn concept-deck options joined by ` / `. Three rules bind the log,
   and each one is what keeps it honest: a row is appended only AFTER the audit runs, so a
   failed or abandoned run appends NOTHING; the file is trimmed to its last 5 rows on every
   append, so the memory is a window and not an archive; and a malformed or hand-edited log is
   treated as EMPTY and warned about, never as a fatal error. This log is the project memory the
   NEXT run diverges from — an unwritten row makes the next run repeat this one.

8. **Red-team the result AND the fixes — BOOSTED runs only.** Once the audit's gates are
   resolved, attack the shipped tree against the persisted contract and the divergence
   record: blind refuters each told to REFUTE that the run honored what it pinned, N=3 as a
   CEILING sized to blast radius, composing `orchestration:verification-panels` when
   installed. No Workflow tool means ONE inline pass, labeled `inline heuristic pass — single
   model, uncorroborated`. Record what was attacked and what survived; never report a panel
   that did not run.
   Three rules the panel owes are in `skills/ultra-craft/references/red-team-contract.md`,
   and each exists because a gate-clean build shipped a defect that inverted its own claim:
   **sweep** an interactive signature's reachable STATE SPACE rather than reasoning about
   representative values (the run that produced the rule had a drag handle sitting outside
   the region it defined in 107,016 of 107,016 states, which every gate passed); attack the
   post-audit **fix list** as its own claim set, since a fix report is a confident
   self-assessment written by the author of the defects; and **render the surface and look
   at it** before calling it verified — clipped text, overlapping annotations and truncation
   are invisible to every DOM assertion, and a refused screenshot path is a reason to retry
   with an absolute path in an allowed root, never a reason to declare capture impossible.
   An unboosted run skips this step entirely and says so in no line at all — it was never owed.

## Notes

- Reuse over rebuild: this command never re-teaches token, motion-library, or R3F
  detail — those live in `design-tokens`, `motion-best-practices`, and
  `threejs-best-practices`. It sequences them.
- Stop points are natural after step 2 (tokens approved), step 3 (sections decided) and
  step 6 (built); a user can run any step's command standalone.
- `guided` is the answer to a broad or half-formed brief: a handful of exchanges up front
  beats discovering at the audit that a whole build answered the wrong question.
