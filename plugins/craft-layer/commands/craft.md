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
   FIRST UPGRADE THE BRIEF, before a single contract row is pinned. Derive, from the user's
   raw words: a SHARPENED objective (the same job said precisely), the constraints the brief
   IMPLIES but never states (an audience that implies a reading level, a named stack that
   implies a render mode, "for our sales team" that implies auth and internal-only), and what
   it left UNDECIDED — the calls someone has to make that the brief does not make. Sharpening
   is not rewriting: an upgrade that widens the job, swaps the product, or invents a route the
   user never asked for has REPLACED the scope, and where the two disagree the raw line wins.
   ECHO the pair together, `Raw brief:` (their words, verbatim) above `Upgraded brief:` (the
   sharpened objective, then the implied constraints, then the undecided list), so the user can
   see what was read into their words at the one moment it is cheap to correct. This is a
   READOUT, not a question — it adds NO exchange to a `one-shot` run, which still carves out
   exactly one (the concept fork below), and asks nothing extra of a `guided` one.
   THEN pin the offer contract (`skills/creative-direction/references/offer-contract.md`):
   one product under its real name, the audience, the ONE primary action, the exact route
   list, the ROUTE HORIZON (routes the site is known to be getting later and is NOT building
   now — an empty horizon is the common answer; a named one changes the STRUCTURE, because a
   terminal landing page and a front door with siblings coming are different builds), the page
   LENGTH (`standard` or `long-scroll` — long is legitimate, undeclared length
   is not), the MODE — `one-shot` by default, `guided` when `$ARGUMENTS` asks for it in ANY
   words ("guided", "section by section", "give me options", "ask me as you go"); that phrase
   is SCOPE, so strip it from the product idea before passing the idea to step 1 — the
   AMBITION — pinned by TOKEN when one is present, and read from the prose otherwise.
   A leading `maximal`, `standard` or `restrained` — lowercase, no punctuation, as the first
   token of this command's own argument string, or the first token AFTER a boost token that
   owns that slot (`ultra`, `ultra-craft`, `ultracraft`) — pins the row OUTRIGHT and echoes it
   unmarked. This is the half `ultra-craft`
   already had and this row did not: a user could explicitly demand the expensive PROCESS and
   only hint at the expensive OUTPUT, which is backwards, because ambition is the one that
   spends bundle weight. Without a token the row is still read from the prose —
   `maximal` when `$ARGUMENTS` asks for reach in ANY words —
   "award winning", "awwwards", "over the top", "very graphical", "cinematic", or naming heavy
   motion libraries as the POINT of the brief rather than as a stack constraint; `restrained`
   when it asks for conventional or trust-first; `standard` by default — and what is NOT
   SHIPPING, which closes the row list.
   THREE THINGS THE TOKEN DOES NOT DO. It does not allocate run resources — model tier,
   research depth and exchange count stay `ultra-craft`'s job, and `ambition-tiers.md` is
   explicit that `maximal` on its own never boosts the pipeline; wanting the run to work
   harder is a different request from wanting the page to reach further, and this token
   answers only the second. It does not override a CONTRADICTING brief: `restrained` in front
   of "an award-winning showpiece" is two orders, not one, so ASK which wins — the same ask
   `ambition-tiers.md` already mandates for ambiguous words and this step already mandates for
   a boosted-plus-conventional brief. And it does not silently beat a BOOST; that conflict is
   asked too. An unmarked echo distinguishes a token from PROSE INFERENCE and from nothing
   else — a boosted run also pins unmarked — so do not read the absence of a mark as proof a
   human typed it.
   Read
   `skills/creative-direction/references/ambition-tiers.md` for the tier's four reach floors
   and carry the pinned tier onto the build task and into the audit — an ambition echoed only
   as prose in a scope sentence binds nothing and is how a build ignores the bar it was given.
   Ambition words are SCOPE too — the token included: strip them from the product idea before
   step 1, and ECHO THE STRIP. `maximal`, `standard` and `restrained` are ordinary English
   words, so a product genuinely called "Maximal Fitness" or "Standard Chartered" loses its
   first word to this rule; showing the strip is what makes that visible while correcting it
   still costs one sentence. If nothing survives the strip, the empty-argument path at the top
   of this command fires — it is evaluated on what REMAINS, never on the raw string.
   A BOOSTED run (see Boost above) does not READ these two rows: it pins
   `Ambition: maximal` and `Mode: guided` outright and records `Boost: ultra-craft`. Where a
   boosted brief ALSO asks for conventional, trust-first, fast or cheap, the two orders
   conflict — ASK which one wins rather than picking silently. Echo the whole contract to the user BEFORE any file is written, and MARK
   EVERY ROW THAT WAS INFERRED rather than read. A row the user stated stands unmarked; a row
   this step derived carries the phrase or signal it came FROM — `Ambition: maximal (inferred ←
   "make it pop")`, `Mode: one-shot (inferred ← no mode words in the brief)`, `Stack: Next.js
   (inferred ← "App Router" in the brief)`. Nine rows are routinely inferred rather than read —
   mode, ambition, boost, archetype, palette mood, type strategy, stack, motion tier, content
   depth — and the audit will not reconstruct a contract row from what shipped, so a row inferred
   wrong here is never caught downstream: it just propagates. The mark is what makes a wrong read
   visible while fixing it still costs one sentence. If the
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
   `shots/`), so the log is never written to the session scratch, while the `craft/`
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
   WHAT THE DIRECTOR RULES OUT IS PART OF THE RECORD, NOT PART OF ITS PROSE. When the
   concept step rules a genus, register or vocabulary off — most often a prior build in a
   sibling directory that the drawn options default straight back into — write it into
   `craft/divergence-record.md` as the NEGATIVE-CONSTRAINTS BLOCK on its three fixed keys,
   `Banned genus:` / `Banned register:` / `Banned vocabulary:`, per
   `skills/creative-direction/references/concept-deck.md`. Two rules bind it. Never restate
   a ban as `<deck axis>: not …` — the audit's machine gate parses every `Key: value` line
   of this record and a key naming a deck axis OVERWRITES the drawn option, so the
   draw-repeat assertion then grades a constraint string against the run history, with no
   error and no symptom. And `Banned vocabulary:` carries LITERAL terms, comma-separated,
   because step 5 copies that line onto the build task and step 7 greps the whole shipped
   tree for those terms: a ruling that stayed in the record's narrative reached no builder
   and no gate, which is exactly how a build ships the genus its own concept step forbade.
   THEN run the CONCEPT FORK, and run it at EVERY tier — `one-shot` included. Have the
   dispatch return 2–3 candidates instead of one, present each as { the five-axis deck draw ·
   central metaphor · editorial voice · signature interaction }, and ask which one the build
   runs on with `AskUserQuestion`. That ONE call carries a SECOND QUESTION — does copy for
   this page already EXIST (the live site, a doc, a deck), or does the build ship visible
   `{{lorem}}` slots? It is an additional question inside the same call, never a second call,
   so it adds NO exchange to a `one-shot` run, which still carves out exactly this one; and a
   URL or path the brief ALREADY named is a supplied input rather than a question — read it
   without asking. Headless, unattended or unanswered → `source: none-located` and visible
   `{{lorem}}` slots, never invented copy. The rules that bind ingested copy — verbatim
   claims, legal blocks in full, the `{{lorem}}` default, the fetch date the audit reads —
   are in `skills/creative-direction/references/content-source.md`.
   The concept fork forks on CONCEPT — the spine and the
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
   FINALLY, once the archetype is classified and the concept exists, PERSIST the run's
   artifacts —
   the pinned contract INCLUDING its archetype row, its `Boost` row, the `Raw brief:` /
   `Upgraded brief:` pair and every `(inferred ← …)` mark with its basis, the divergence
   record, and the CONTENT SOURCE the fork's second question resolved — at the fixed
   paths `craft/offer-contract.md`, `craft/divergence-record.md` and
   `craft/content-source.md` under the run's working
   area (the taskmaster docs area when the project has one, otherwise the session scratch;
   never the shipped tree). Persisting before the archetype is classified writes an empty
   Archetype row and leaves the content-depth gate with no anchor.
   EVERY ARTIFACT OPENS WITH THE RUN STAMP. Compute it ONCE here — `Run:
   <YYYY-MM-DDTHH:MMZ> · <product-slug> · <absolute path of the target project root>` — and
   copy it BYTE-IDENTICAL onto the first line under each artifact's title, the build task and
   the reference board included when later steps write them
   (`skills/creative-direction/references/offer-contract.md` Part 8, which holds the field
   shapes and the audit's tiebreak). Fixed names are what make these files findable and what
   makes them collidable: a second run in this session writes the same fixed paths, and an
   abandoned run leaves its artifacts exactly where the audit globs — which has already
   happened, with a previous run's contract read as the current run's and a person, not a
   gate, catching it. The stamp is the only thing that tells one run's artifacts from
   another's, so a re-read clock per file defeats it; two artifacts whose stamps disagree are
   a finding at step 7 rather than a coincidence. The content source is
   written even when nothing was located — `source: none-located` is a recorded DECISION,
   and an absent artifact is indistinguishable from a run that never asked. The audit globs
   for exactly
   those names; a contract that was only spoken cannot be checked against — and a brief pair or
   an inference mark that lived only in the echo evaporates with the transcript, leaving the
   propagation it exists to stop exactly where it was. Written into the file, both are readable
   by every later step, and by the next session.

1. **Research → briefs.** Run `/craft-layer:research <the product idea from step 0, with the
   mode/length instructions stripped out>` — never `$ARGUMENTS` verbatim, or "guided" is
   researched as part of the product. It reads the step-0 concept, divergence record and
   contract from the persisted `craft/` files and returns the briefs WITHOUT handing off (the
   chain owns steps 2 and 5), so `design-research` biases BOTH
   briefs toward the concept (its mining method is unchanged; the concept steers what it
   elaborates and which defaults to break). It emits a freeform theme brief and a
   component/layout build task. Detect the target stack here if not already known.
   BEFORE mining anything, FINISH THE CONTENT SOURCE. Lane C of the mining method already
   points the run at the target's own marketing site
   (`skills/design-research/references/mining-method.md`); when the brief named one, or the
   step-0 fork surfaced one, RETRIEVE it and complete `craft/content-source.md` before either
   brief is written, so both carry the client's own words instead of averaging toward the
   category. A retrieval that returns 403, 5xx or an empty document ESCALATES to a real
   browser when one is available — the ladder is in
   `skills/ultra-craft/references/research-mandate.md` under "When a fetch fails", and THAT
   SECTION binds at every tier, boosted or not — and the attempt, the escalation and its
   result are recorded either way.
   EVERY BRIEF-NAMED URL, REPO PATH AND ATTACHED FILE GETS A ROW in that artifact's Sources
   table — its `Method` and its date, fetched or failed. Lane C is not a new instruction: it
   already points at the target's own assets and it carries no ambition gate, so what was
   missing when a run walked past a refusal was the RECORD, not the rule. The audit rebuilds
   the expected list from the contract's verbatim `Raw brief:`, so a named source with no row
   is a finding — at every tier, because this artifact is written at every tier. A brief-named
   URL is a SUPPLIED INPUT rather than research: what ambition and the boost buy is mining
   DEPTH, and neither decides whether the run read what the user handed it. A boosted run
   additionally carries the same source on `craft/reference-board.md` as a brand-assets-lane
   row, where it counts toward the six-source floor. Copy nobody located ships as a visible `{{lorem}}`; the
   product's API, schema and spec facts are never a substitute for its marketing copy, which
   is how a sales page ships reading as documentation.
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

   **THEN decide where the COMPONENTS come from, on the same step and for the same reason.**
   A section is not an asset and has its own decision
   (`skills/asset-sourcing/references/component-sourcing.md`): four classes — first-party ·
   registry block adapted · registry block as-is · installed library — over conventional
   furniture (nav, footer, pricing table, FAQ, testimonial, form). It runs BEFORE the build
   because a block sourced after a layout is committed is a retrofit, exactly as motion is.
   Three bindings. It ALWAYS runs: a target that already ships a component library resolves
   it IMMEDIATELY to `installed library` — a constraint being recorded, never a choice, and
   never a licence to introduce a second one — rather than suppressing the decision and
   recording nothing. The concept's SIGNATURE section is always first-party; a block
   published for general reuse cannot carry the one move that is this brief's alone. And a
   sourced block ships a one-line `component-source:` marker keyed to the same manifest step
   4 already owns, because the licence gate cannot otherwise SEE a pasted component — that
   marker is the only thing standing between a sourced block and invisibility, and an
   unmarked one stays invisible, which that reference states rather than hides.
   Which registry a block came from is recorded, not gated: registries have different house
   styles, so the choice is a real fork in visual outcome, but nothing asserts don't-repeat-
   recent on it the way `divergence.mjs` does on hues and typefaces. Carry the outcome into
   step 6 on the build task's `Components / provenance:` line — class per section, the origin
   named for anything sourced — and route each adapted block through the matching
   best-practice skill under `plugins/ui-ux/skills/` (`/ui-ux:build` resolves it) so the block
   is restyled to THIS build's tokens rather than shipped in its registry's dialect.

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
   AND — the fourth floor, which is the only one the picker cannot satisfy by itself — at least
   one surface takes a tier the picker would NOT have chosen, marked on the `Motion:` line as
   `<surface>: <tier> (escalated ← <reason>)`. This is the direct inverse of the
   cheapest-that-fits rule above: floor 1 counts capabilities and three cheap ones satisfy a
   count, so without a named departure a `maximal` build clears every floor and ships as a
   `standard` one. The mark names what the surface departed FROM, exactly as `(inferred ← …)`
   names what a contract row was read from, and for the same reason — a preference nobody
   recorded cannot be audited. Buy it lazily; an escalation onto a second eager engine has
   failed the cumulative budget instead.
   Then work out what each remaining surface needs, and resolve FIVE lines on the build task:
   `Motion:` — a named tier per surface plus the fallbacks below, and at `maximal` at least one
   `(escalated ← <reason>)` entry — `Signature:` — the
   move, its section, and its owning skill — `Ambition:` — the pinned tier, plus, at
   `maximal`, which surface carries the graphic system, which capabilities make up the three,
   and which surface carries the escalation — and `Banned vocabulary:` — copied VERBATIM from
   the divergence record's negative-constraints block, with `none` written out when the
   concept step ruled nothing off. `Banned vocabulary:` is the only one of the five that is not
   a decision made HERE: it is a step-0 ruling being carried to the people who write the markup,
   and it exists because the other lines are the only part of the record the builders
   are handed. A concept constraint that reaches only the record is a constraint the build
   cannot obey. Copy it under the match semantics
   `skills/creative-direction/references/concept-deck.md` states — word-bounded and
   case-insensitive, a term under ~4 characters given as a quoted phrase — so a ban on `REV`
   does not arrive as a gate that fires on `Reviews`.
   THE FIFTH LINE IS `Spine regions:` — which REGION of the page answers which offer-spine
   slot, written as `<slot>=#<anchor>` pairs over the contract's eight slots, ON ONE LINE AND
   NEVER WRAPPED (`skills/creative-direction/references/register-corpus.md`). The gate reads
   the line the key is on and nothing else, so a continuation line is read as its own line:
   every pair after a wrap is lost without a word, and a wrap falling before a buyer slot
   leaves the gate nothing to grade and it SKIPs. Let the line be long — the same hard rule,
   in the same words, that `concept-deck.md` states for the `Banned …` keys. It resolves here, at every
   tier, because the section names already exist by this step and because `one-shot` — the
   default, and the mode that shipped the failure — writes no ledger to carry it: a `guided`
   run copies the ledger's `slot` + `section` columns onto the line rather than re-deriving
   them. Without the mapping the register gate cannot tell an endpoint standing in for the
   plain-what line from the same endpoint doing its job inside `how it works`, so it degrades
   to a whole-page grep that fires on every correct limits list. Reach for the owning skill to make each call
   (each references its library by path — never re-teach):
   - **Tier** (the base per-surface choice) via `motion-tiers`: Framer Motion, anime.js,
     Three.js/R3F, sprites (`sprite-motion`), or the Vector tier (Lottie/Rive).
   - **Scroll-driven** (smooth scroll, scrub, pin, parallax) → `scroll-orchestration`
     (Lenis + ScrollTrigger); for a scroll ACT — a pinned scene, a scrubbed frame sequence, a
     scroll-revealed panel — its budget and its three required states are in that skill's
     `references/scroll-acts.md`, and a play-forward sequence is an entrance, not a signature.
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

   FINALLY, once all five lines are resolved, PERSIST them at `craft/build-task.md`, beside
   the contract and the divergence record, carrying step 0's `Run:` stamp on its first line
   BYTE-IDENTICAL — a build task stamped to a different run is a build task the previous run
   left behind, and step 7 fails it rather than reading its lines as this build's. The audit grades the signature against the build
   task's `Signature:` line, floor 4 against its `Motion:` line, the reach floors against its
   `Ambition:` line, the shipped tree against its `Banned vocabulary:` line, and the three
   BUYER slots' register against its `Spine regions:` line, and none of them can read a task
   that exists only in the dispatch. Persist
   AFTER the lines exist, never before: a build task written early is the empty-Archetype-row
   failure step 0 already names, one step down. A line that lived only in a handoff cannot be
   checked, for exactly the reason a contract that was only spoken cannot.

6. **Build.** Pass the build task — carrying the section ledger's choices when step 3 ran,
   step 4's `Assets / provenance:` AND `Components / provenance:` lines, and step 5's resolved
   `Motion:`, `Signature:`, `Ambition:`,
   `Banned vocabulary:` and `Spine regions:` lines — to
   `/ui-ux:build` to lay out components and screens, applying `design-tokens` and, for
   data-dense CRM/SaaS surfaces, the `information-design` skill (hierarchy, density,
   tables/dashboards, when-to-dataviz). ONE pass: layout and motion land together, because
   the signature and the scroll device are structural, not decoration applied afterwards.
   A section the `Components / provenance:` line assigns to a registry block is restyled to
   this build's tokens and composition IN THAT SAME PASS and ships its `component-source:`
   marker: a block pasted now and "themed later" is the unrestyled block the audit calls a
   finding, and an unmarked one is invisible to the licence gate altogether.
   EACH REGION THE `Spine regions:` LINE NAMES SHIPS ITS ANCHOR — the `id` goes on the element
   that HOLDS that slot's copy, not on a wrapper or a self-closing component invocation, or the
   register gate addresses nothing and reports the slot unchecked. The dispatch that writes a
   buyer region — plain-what, audience, problem — carries the rule with it: those three answer
   a buyer's question, so an endpoint, a token scope, a status code or a schema fact standing
   in for the answer is a finding there, while the same disclosure is exactly what `how it
   works` and `objection` are FOR (`skills/creative-direction/references/register-corpus.md`).
   EVERY dispatch carries the `Banned vocabulary:` line, and a section built before the line
   existed is re-checked against it rather than assumed clean. When the build fans out across
   parallel agents, the ban is NOT discharged by each agent grepping its own files: that is N
   green reports for a property verified nowhere, and it is what step 7's single tree-wide
   grep exists to catch (the general rule, with the concurrency caveat that goes with it, is
   `orchestration:delegation-contracts`' `references/tree-wide-gates.md`).

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
   the pinned **ambition** honored — at `maximal`, the four reach floors,
   reduced-motion per tier, lazy + static-fallback 3D, per-tier + **cumulative** motion
   budget, sprite/asset budgets, **accent-vs-surface contrast**, and the newer-skill
   gates — page-transition fallback, WebGL GPU budget, interaction-fx cursor a11y, physics
   body-cap, sequencing studio-excluded-from-prod) and, via its delegation, full
   accessibility and performance. Resolve any failed gate before declaring the surface done.

   **Run the banned-vocabulary grep HERE, once, over everything.** The build task's
   `Banned vocabulary:` line is a cross-cutting property, and this step is the first moment
   the whole tree exists and nothing is still being written into it. One grep of the entire
   shipped source for the line's terms, run after every builder has returned — not during,
   and not once per agent. During a fan-out the result is about a sibling's half-saved file
   rather than about the build; per agent it is green over a subset while the ban is checked
   nowhere. `Banned vocabulary: none`, or no line at all, reports `not checked`, never a pass.

   **Install the gate suite, then LOOK at what it captured.** The suite is
   `${CLAUDE_PLUGIN_ROOT}/template/craft-gates/` — `gates.spec.ts`, `contrast.mjs` and
   `divergence.mjs`. When the project has no suite of its own, INSTALL it rather than
   recommending it: copy all three in (the two `.mjs` files beside the project's other
   scripts), `npm i -D @playwright/test @axe-core/playwright && npx playwright install
   chromium`, and point it at the dev server step 6 already has up —
   `BASE_URL=<that server> CRAFT_EXPECT_TITLE=<the contract's product name> npx playwright
   test`, then `node scripts/contrast.mjs` and
   `node scripts/divergence.mjs`. No second server and no second capture path: the surface
   the build is running on is the one the pictures are taken from.
   PASS THE ARTIFACT PATHS, or two of its assertions grade nothing. `divergence.mjs` resolves
   `craft/…` relative to the PROJECT ROOT, and this command persists those artifacts to the
   run's working area — which on a project with no `taskmaster-docs/` is the session scratch,
   OUTSIDE the project. So the common case is the one that silently degrades: the register gate
   and the stamp gate both report `not checked`, the run reads as clean, and the reviewer is
   forbidden from re-deriving the register verdict by eye. Hand them in explicitly, using the
   same paths step 0 and step 5 already wrote:
   `CRAFT_CONTRACT=<…/craft/offer-contract.md> CRAFT_DIVERGENCE_RECORD=<…/craft/divergence-record.md>
   CRAFT_BUILD_TASK=<…/craft/build-task.md> CRAFT_CONTENT_SOURCE=<…/craft/content-source.md>
   CLAUDE_PLUGIN_ROOT=<craft-layer root> node scripts/divergence.mjs`. A gate that cannot find
   its input is not a gate that passed.
   PASS `CRAFT_EXPECT_TITLE` — the suite cannot derive it. It runs inside the target project
   and cannot reach the persisted contract, so the ONE thing that proves the shots are of THIS
   build has to be handed in from here, where the contract's product name is already known.
   Omit it and the suite reports `IDENTITY NOT MEASURED` and captures anyway: a legitimate
   outcome, but it means nothing checked that the server on that port is yours. A dev port held
   by a different project is the ordinary case, not the exotic one — a run that shipped this
   gate found `:5173` serving an unrelated app while its own build sat on `:5182`, and every
   shot would have been another application's, opened and reported as this build's.
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
     Its assertions include `spine-register`, which reads the build task's `Spine regions:`
     line and grades the plain-what / audience / problem regions against the register corpus,
     so a non-zero exit can also mean every spine slot was ANSWERED in an integrator's voice.
     Run it with `CLAUDE_PLUGIN_ROOT` set so both corpora are the live ones rather than the
     frozen snapshots it prints when they are not.
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
