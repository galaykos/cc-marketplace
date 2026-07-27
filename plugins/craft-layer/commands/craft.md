---
description: Create a crafted web app (CRM, SaaS, landing page) end to end — orchestrates design-research, token + component build, motion-tier selection, and a craft audit by chaining the marketplace's existing UI/motion surfaces.
argument-hint: [product-idea]
---

# /craft-layer:craft

Turn a product idea into a distinctive, animated, informative web app. This command **orchestrates** —
it writes no framework build logic itself; each step hands off to the command or skill that owns it, in
order, carrying each output into the next. `$ARGUMENTS` is the product idea; if nothing survives the
strips below, ask for a one-line idea and the target stack.

## Boost — `ultra-craft`

<!-- boost-preamble:start -->
BOOSTED when `$ARGUMENTS` carries `ultra-craft` / `ultracraft`, or a bare `ultra` as the FIRST token of
this command's own argument string. A bare `ultra` belonging to another command — `/caveman ultra`
ahead of this call — never fires it. When boosted, apply `skills/ultra-craft/SKILL.md`: `Ambition`
pins `maximal` and `Mode` pins `guided` rather than being read, `Boost: ultra-craft` is stamped into
the contract, step 1's research is LIVE and dated, the reference board is confirmed before step 2,
`creative-director` and `craft-reviewer` dispatch at the boosted tier, and step 8 runs. The token is
SCOPE — strip it before step 1. Print the skill's ⚡ banner first.
<!-- boost-preamble:end -->

## Steps

0. **Offer contract, then creative direction.** Apply the `creative-direction` skill. Its references
   OWN the detail below — read them; this step sequences them and does not restate them.

   **Upgrade the brief first**, then pin the contract, per `references/offer-contract.md`: Part 1a
   holds the `Raw brief:` / `Upgraded brief:` pair and the inference marks, Parts 5–7 hold page
   length, mode and ambition + route horizon, and Part 8 holds the RUN STAMP. Sharpening is not
   rewriting: where an upgrade and the raw line disagree, the raw line wins. Echo the contract before
   any file is written. If the brief admits several products or directions, ASK which one — building
   all of them is the failure this step exists to stop, and a boosted brief that also asks for
   conventional or cheap is two orders, so ASK which wins there too. Mode and ambition words are
   SCOPE: strip them from the idea before step 1. Carry the pinned ambition tier onto the build task
   and into the audit — a tier living only in a scope sentence binds nothing.

   **Then read the project memory** — `<project>/.craft-layer/run-log.md`; its last 5 rows are what
   this run must differ from. Create `<project>/.craft-layer/` with a `.gitignore` holding only `*`
   when absent; it holds what must OUTLIVE the session (run log, `waivers.json`, `shots/`) and is not
   the `craft/` working area. **Then DRAW the starting constraint** per `references/concept-deck.md`:
   one option per axis, seeded by the log and excluding the options its last 5 rows used. The deck is
   drawn from, never chosen from. An absent, empty or malformed log is EMPTY — warn, seed from a hash
   of the brief plus today's date, carry on.

   **Then dispatch `creative-director`** for a DIVERGENT concept — a central metaphor, an editorial
   voice, one signature interaction — breaking the sameness-fingerprint defaults and clearing the
   usability floor. Carry the concept and its divergence record into step 1, with the archetype's
   content-depth target and the palette-strategy mood. The metaphor is a design LANGUAGE, not a
   rebrand. **What it rules OUT goes into `craft/divergence-record.md`** on the three fixed
   `Banned genus:` / `Banned register:` / `Banned vocabulary:` keys, whose format and match semantics
   `concept-deck.md` owns — a ban left in the record's narrative reaches no builder and no gate.
   **Then run the CONCEPT FORK**, at every tier including `one-shot`, per that same reference.

   **Finally, persist** the contract, divergence record and content source at
   `craft/offer-contract.md`, `craft/divergence-record.md` and `craft/content-source.md`, under the
   run's working area — the taskmaster docs area when the project has one, else session scratch;
   never the shipped tree. Persist AFTER the archetype is classified or the Archetype row ships
   empty, and write the content source even when nothing was found: `source: none-located` is a
   recorded DECISION, and an absent artifact is indistinguishable from a run that never asked. Every
   artifact carries the Part 8 `Run:` stamp BYTE-IDENTICAL on its first line, the build task
   included; `craft-stamp` fails on disagreement.

1. **Research → briefs.** Run `/craft-layer:research <the idea, mode words stripped>` — never
   `$ARGUMENTS` verbatim, or "guided" gets researched as part of the product. It reads the step-0
   artifacts and returns both briefs WITHOUT handing off (this chain owns steps 2 and 5). Detect the
   target stack here if not already known.

   **Finish the content source before either brief is written**, so both carry the client's own words
   instead of averaging toward the category. When the brief named a site, or the fork surfaced one,
   RETRIEVE it. A 403, 5xx or empty document ESCALATES to a real browser when one is available — the
   ladder in `skills/ultra-craft/references/research-mandate.md` under "When a fetch fails" **binds at
   every tier**, boosted or not. **Every brief-named URL, repo path and attached file gets a row** in
   that artifact's Sources table with its `Method` and date, fetched or failed; a named source with no
   row is a finding at every tier, because a brief-named URL is a supplied input rather than research —
   ambition buys mining DEPTH, not whether the run read what the user handed it. Copy nobody located
   ships as visible `{{lorem}}`; API and schema facts never substitute for marketing copy, which is how
   a sales page ships reading as documentation. On a boosted run the mining is LIVE per the research
   mandate, and `craft/reference-board.md` is persisted and echoed before step 2.

2. **Tokens.** Pass the theme brief to `/ui-ux:theme` for design tokens (light/dark) with a live
   colour preview. The brief carries a `theming-system`-derived token-system direction (roles, not
   values — shape per `concept-to-tokens.md`). Do not hand-roll palettes.

3. **Section decisions — only when the contract declares `guided`.** Apply `section-decisions` (or
   `/craft-layer:sections`): derive the agenda from the contract's spine slots, run the batched rounds
   (Shape → Treatment → Signature) under the exchange cap in `decision-rounds.md`, always offering
   "decide the rest for me", staging options through `taskmaster:visual-decisions` /
   `/design-preview:preview` / `/shadcn-studio:stage` when installed. Fold each row's choice and locks
   into the build task. Two skips, and they differ: `one-shot` skips entirely and writes no ledger; a
   `guided` run with no interactive user still runs the agenda, auto-decides, and writes every row
   `source: auto`.

4. **Asset plan, then component plan — both BEFORE the build.** Apply `asset-sourcing`: classify what
   the concept needs, run the build-vs-source-vs-commission decision (`sourcing-decision.md`), and
   write the provenance manifest into the project at an accepted name (`ASSETS` / `CREDITS` /
   `PROVENANCE` / `THIRD-PARTY-NOTICES`) — `licence-discipline.md` owns its shape. An all-in-code
   build still owes a first-party declaration; the licence gate runs on static builds too, and at
   `maximal` an all-first-party manifest satisfies that gate while FAILING the asset-posture floor.

   **Then components** (`.../component-sourcing.md`): four classes over conventional furniture, with
   three bindings that reference does not let you skip. It ALWAYS runs — a target already shipping a
   component library resolves immediately to `installed library`, a constraint recorded, never a
   licence for a second one. The signature section is always first-party. And a sourced block ships a
   one-line `component-source:` marker keyed to the same manifest, because the licence gate cannot
   otherwise SEE a pasted component. Carry the outcome onto the build task's
   `Components / provenance:` line and route each adapted block through the matching best-practice
   skill under `plugins/ui-ux/skills/`, so it is restyled to THIS build's tokens rather than shipped
   in its registry's dialect.

5. **Motion — decide it BEFORE the build.** This step DECIDES; step 6 implements. Motion decided after
   a layout is committed can only be retrofitted onto markup not built for it, which is how a page
   ends up with nothing but fade-and-rise reveals: the effects needing STRUCTURE — a pinned scroll
   act, a WebGL hero, a shared-element transition, a physics stage — must be in the build task or they
   cannot ship at all.

   **Start from the signature.** Read `craft/divergence-record.md` and make the concept's ONE
   signature interaction the first motion decision: which section owns it, which skill implements it,
   which tier it costs. It is the page's motion FLOOR and the only motion decision the audit checks by
   name. The tier picker takes the CHEAPEST tier that fits, so nothing reaches for anime.js, Three.js,
   physics or the Vector tier unless decided here. **At `maximal`** the four reach floors are in
   `.../ambition-tiers.md`; one of them the picker cannot satisfy by itself and so must be named here —
   at least one surface takes a tier the picker would NOT have chosen, marked
   `<surface>: <tier> (escalated ← <reason>)`. Without that named departure a `maximal` build clears
   three cheap capabilities and ships as `standard`. Buy reach with LAZY loading; the cumulative budget
   does not move for ambition. A floor the brief genuinely does not want is waived in the divergence
   record with a reason, never by silence.

   **Resolve five lines on the build task:**

   - `Motion:` — a named tier per surface plus fallbacks; at `maximal`, one `(escalated ← …)`
   - `Signature:` — the move, its section, its owning skill
   - `Ambition:` — the pinned tier; at `maximal`, which surface carries the graphic system, which
     capabilities make the three, and which carries the escalation
   - `Banned vocabulary:` — copied VERBATIM from the divergence record, `none` written out when
     nothing was ruled off. The only line not decided here: a step-0 ruling carried to the people who
     write the markup, who see no other part of the record.
   - `Spine regions:` — which REGION answers which offer-spine slot, as `<slot>=#<anchor>` pairs over
     the contract's eight slots. **ON ONE LINE, NEVER WRAPPED**: `spine-register` reads the line the
     key is on and nothing else, so every pair after a wrap is lost silently. Let the line be long. It
     resolves at every tier — `one-shot` writes no ledger to carry it; a `guided` run copies the
     ledger's `slot` + `section` columns.

   Reach for the owning skill per call — each references its library by path, never re-teach. **Tier**
   (the base per-surface choice) → `motion-tiers`: Framer Motion, anime.js, Three.js/R3F, sprites
   (`sprite-motion`), or the Vector tier (Lottie/Rive). **Scroll-driven** → `scroll-orchestration`; a
   scroll ACT's budget and three required states are in `references/scroll-acts.md`, and a
   play-forward sequence is an entrance, not a signature. **Route / page transitions** →
   `page-transitions` · **focal / variable-font type** → `kinetic-typography` · **pointer
   micro-interactions** → `interaction-fx` · **real 2D physics** → `physics-motion` · **multi-track
   choreography** → `motion-sequencing` · **postprocessing / shaders** → `webgl-effects` ·
   **data-dense surfaces** → `information-design`.

   Then fold in the cross-cutting decisions: each tier's `prefers-reduced-motion` and reduced-bundle
   fallback; the **cumulative** motion-JS budget, one heavy engine eager and the rest lazy
   (`motion-tiers/references/tier-budgets.md`); on an RTL target, mirror direction-bearing motion while
   keeping charts, numerals and code as LTR islands (`.../rtl-bidi.md`); and an accent that clears
   contrast on every surface it lands on. **Finally persist `craft/build-task.md`** beside the other
   artifacts, carrying step 0's `Run:` stamp BYTE-IDENTICAL — a task stamped to a different run is one
   a previous run left behind, and the audit fails it rather than reading it as this build's.

6. **Build.** Pass the build task — the section ledger's choices when step 3 ran, step 4's
   `Assets / provenance:` and `Components / provenance:` lines, and step 5's five lines — to
   `/ui-ux:build`, applying `design-tokens` and, for data-dense CRM/SaaS surfaces,
   `information-design`. ONE pass: layout and motion land together, because the signature and the
   scroll device are structural, not decoration applied afterwards. A section assigned to a registry
   block is restyled to this build's tokens IN THAT SAME PASS and ships its `component-source:` marker.

   **Each region `Spine regions:` names ships its anchor** — the `id` goes on the element HOLDING that
   slot's copy, not on a wrapper or a self-closing component invocation, or the register gate addresses
   nothing and reports the slot unchecked. The three BUYER regions — plain-what, audience, problem —
   answer a buyer's question, so an endpoint or schema fact standing in for the answer is a finding
   there, while the same disclosure is exactly what `how it works` and `objection` are FOR
   (`.../register-corpus.md`). **Every dispatch carries the `Banned vocabulary:` line**; a section built
   before the line existed is re-checked, not assumed clean.

7. **Audit — the run is NOT complete until this has run.** Run `/craft-layer:audit` on the result and
   resolve every failed gate before declaring the surface done. That command OWNS the audit — the gate
   suite and its inputs, opening the captured shots, the three consequences, the two-line report, and
   appending the run log. Do not restate its rules here or run its gates from this step.

   One thing belongs to THIS step, because it is a property of step 6's fan-out rather than an audit
   gate: **the banned-vocabulary grep runs once, tree-wide, after every builder has returned** — not
   during, and not once per agent. During a fan-out the result is about a sibling's half-saved file;
   per agent it is green over a subset while the ban is checked nowhere
   (`orchestration:delegation-contracts` `references/tree-wide-gates.md`). `Banned vocabulary: none`,
   or no line at all, reports `not checked` — never a pass.

8. **Red-team the result AND the fixes — BOOSTED runs only.** Attack the shipped tree against the
   persisted contract and divergence record: blind refuters each told to REFUTE that the run honored
   what it pinned, N=3 as a CEILING sized to blast radius, composing
   `orchestration:verification-panels` when installed; no Workflow tool means ONE inline pass, labeled
   `inline heuristic pass — single model, uncorroborated`. The three rules the panel owes are in
   `skills/ultra-craft/references/red-team-contract.md`. An unboosted run skips this entirely. (Proportionality law: `claude-authoring/skills/authoring-skills/SKILL.md` "The four laws".)

## Notes

- Reuse over rebuild: this command re-teaches nothing — token, motion-library and R3F detail live in
  `design-tokens`, `motion-best-practices` and `threejs-best-practices`. It sequences them.
- Natural stop points after step 2 (tokens), step 3 (sections) and step 6 (built); any step's command
  runs standalone. `guided` is the answer to a broad brief: a few exchanges up front beat discovering
  at the audit that a whole build answered the wrong question.
