# craft-layer

Create unique, high-craft, animated, **informative** web apps — CRMs, SaaS dashboards,
landing pages — on real projects across **React, Tailwind, Vite, Vue, Next, Nuxt, and
Laravel** (Inertia / Livewire). `craft-layer` is the orchestration layer that turns an
idea into a crafted app by composing the marketplace's existing UI/motion skills, adding
only what they lack: an offer contract that pins what the page sells, concept-first
creative direction, an optional guided section-decision loop, a research→brief playbook,
an asset-sourcing + licence gate, a concept→token-system derivation, a tiered motion
**decision** system, sprite guidance, information design, and a craft **audit**.

## The craft flow

`/craft-layer:craft <idea>` chains the whole path — it writes no framework code itself,
it orchestrates existing surfaces:

0. **creative-direction** — pin the offer contract (ONE product under its real name, the
   audience, the one primary action, the route list and route horizon, the page length, the
   mode, the **ambition tier**, the
   offer-spine slots the page owes), then generate a divergent concept (central metaphor,
   editorial voice, one signature interaction) that breaks the sameness defaults, before
   anything visual is decided.
1. **`/craft-layer:research`** — mine reference designs + interaction/layout patterns,
   emit a theme brief and a build task, biased toward the concept.
2. **`/ui-ux:theme`** — generate design tokens (light/dark) + live preview from the brief;
   `ui-ux:theming-system` derives the coherent token-system direction the brief carries.
3. **section-decisions** *(guided mode only)* — decide the page section by section with the
   user: the spine slots become a batched agenda, each section is offered as 2–3 structurally
   different treatments, and the picks land in a section ledger the build and audit read.
   Also runnable standalone as **`/craft-layer:sections`**. Skipped on `one-shot`.
4. **asset-sourcing** — decide where each visual asset comes from
   (build-vs-source-vs-commission) and record provenance under a licence gate, before the
   build. Same step, second decision: where each COMPONENT comes from — first-party ·
   registry block adapted · registry block as-is · installed library — so conventional
   furniture (nav, footer, pricing, FAQ, testimonial, form) is not rewritten from scratch
   while the signature section always is. A sourced block carries a greppable
   `component-source:` marker the licence gate reads; an unmarked one is invisible to it,
   which the reference states plainly instead of claiming a gate it does not have.
5. **motion routing** — DECIDE the motion, **before** the build, starting from the concept's
   ONE signature interaction: which section owns it, which skill implements it, what tier it
   costs. craft-layer writes no animation code itself — it resolves the build task's `Motion:`
   and `Signature:` lines. Route each surface to its owning skill (`motion-tiers` for the
   base tier; `scroll-orchestration`, `page-transitions`, `kinetic-typography`,
   `interaction-fx`, `physics-motion`, `webgl-effects` as needed),
   then fold in the cross-cutting decisions: reduced-motion + reduced-bundle fallbacks, the
   **cumulative** motion budget, **RTL** effect-mirroring vs LTR-islands, and
   **accent-vs-surface contrast**.
6. **`/ui-ux:build`** — build components/layout in ONE pass (carrying the ledger's choices
   when step 3 ran, the asset plan, and step 5's resolved motion), applying `design-tokens`
   and `information-design`.
7. **`/craft-layer:audit`** — verify the craft gates (the signature interaction actually
   shipped, ambition conformance, offer contract, content depth, ledger
   conformance, per-tier + cumulative budget, reduced-motion, contrast, licence + asset-fit,
   the newer-skill gates; delegating full a11y + performance). It measures asset and chunk
   sizes itself before dispatching, and any gate it cannot measure is reported
   `not measured` rather than guessed — then offers to route the findings to a worker.
   **The run is not complete until this step ran**, and its final line says so:
   `Craft audit: <ran | NOT RUN> · Gates: <n> checked · <n> not checked · <n> not measured`.
   A green project suite is not this step — it proves the code is correct and proves nothing
   about whether the signature shipped or the contract was honored, which is the way this
   chain most often ends one step early.

## What the run writes outside your app


Working files, at fixed names so a later session — or a standalone
`/craft-layer:audit` — can find them by glob. They live in the taskmaster docs area when the
project has one, otherwise the session scratch area, and **never** in the shipped tree:

| File | Written by | Read by |
| --- | --- | --- |
| `craft/offer-contract.md` | step 0, after the archetype is classified | the audit's scope, length, mode and content-depth gates |
| `craft/divergence-record.md` | step 0, once the concept exists | the audit's anti-sameness gate and the plain-language what-line check |
| `craft/content-source.md` | step 0/1, from the copy that already exists | step 1's briefs, the build, and the audit's content-fidelity gate |
| `craft/section-ledger.md` | step 3 (guided only) | `/ui-ux:build` via the build task, and the audit's conformance gate |
| `craft/reference-board.md` | step 1 at the `ultra-craft` boost, echoed to you before any file is written | the audit's boost-evidence gate, and step 2's concept work |
| `craft/build-task.md` | step 5, once its five lines resolve | `/ui-ux:build` at step 6, and the audit's signature, named-escalation, ambition, banned-vocabulary and buyer-REGISTER gates (`Spine regions:` is the register gate's only input) |

Missing any of them is not a failure — the gates that need them report `not checked` rather
than passing or failing a build that simply never saved one.

Fixed names are findable and collidable in the same move: a second craft run in one session
writes the same paths, and an abandoned run leaves its files exactly where the next audit
globs. So every one of them opens with a RUN STAMP — `Run: <YYYY-MM-DDTHH:MMZ> ·
<product-slug> · <absolute project root>`, computed once at step 0 and copied byte-identical
onto each artifact. When a glob matches more than one file the audit resolves it by that
stamp — a match stamped to another project is dropped, the newest agreeing stamp wins, and an
undecidable set is reported with every candidate rather than silently picking the first hit.
Artifacts whose stamps disagree are a finding: `divergence.mjs`'s `craft-stamp` assertion
fails when they do, when one is stamped to a different project, or when one carries no stamp
while a sibling does. Artifacts written before this rule carry none, and a lone unstamped one
is used and reported as such.

One file DOES land in the project: the asset **provenance manifest**, written at step 4 under
one of the names the licence gate globs for — `ASSETS`, `CREDITS`, `PROVENANCE`, or
`THIRD-PARTY-NOTICES`. A manifest at any other path reads as absent to the gate. An
all-in-code build still owes one, as a first-party declaration.

A second thing lands in the project, and it is deliberately not one of the three above:
`.craft-layer/`, carrying a `.gitignore` holding `*`. It is git-invisible, and it is the only
craft artifact that must OUTLIVE the session — a run log in session scratch has no memory to
offer the next run, which is the whole point of it. It holds `run-log.md` (the project memory)
and `waivers.json` (see the divergence gate below).


## Modes, ambition, and boost

- **Mode** — `guided` asks at each decision point; `one-shot` takes the
  recommendation and keeps going. Default is guided.
- **Ambition tier** — how far the concept reaches: `restrained`, `expressive`,
  `maximal`. Sets how many sameness-fingerprint defaults the concept must break.
- **Boost** — `/craft-layer:craft ultra-craft …` pins ambition `maximal` and mode
  `guided`, mandates live dated research echoed as a reference board before any
  file is written, escalates the concept and review tiers, and red-teams the
  shipped tree. `ultra` as the FIRST token of this command's own args does the
  same; another command's `ultra` never fires it.

The reasoning behind these gates — why motion is decided before the build, why two
runs no longer look alike, what "award-grade" does and does not mean — is in
`rationale/craft-layer-design.md`, which does not ship with the plugin.

### Award-grade scoring

The creative-director scores candidates against the only published award rubric in this
field: **Design 40% · Usability 30% · Creativity 20% · Content 10%** — usability outweighs
creativity by design, and substance is scored at all. The agent cites this note as its
source; when the rubric moves, fix and re-date it here first.

> Last verified: 2026-08-11 — https://www.awwwards.com/about-evaluation/

## Skills

- **creative-direction** — the concept-first anti-sameness layer: generates a divergent
  concept (metaphor, editorial voice, one signature interaction), scores blind candidates,
  and records a divergence the audit checks; owns the offer-contract, ambition-tier,
  content-depth, and sameness-fingerprint gates.
- **section-decisions** — the guided-build checkpoint: derives a decision agenda from the
  offer contract's spine slots (never an invented one), batches it into three capped rounds,
  offers 2–3 structurally different treatments per section, and records the picks in a
  section ledger the build task carries and the audit checks for conformance. Owns the
  agenda, the rounds, and the ledger; routes all option-drawing to `taskmaster:visual-decisions`,
  `/design-lab:preview` and `/ui-ux:theme`, each optional.
- **design-research** — a repeatable method to mine reference designs and patterns and
  emit briefs in the exact form `/ui-ux:theme` and `/ui-ux:build` consume.
- **theming-system** — MOVED to the `ui-ux` plugin (2026-07-27); it sits beside
  `design-tokens` and `shadcn-theming`, which own the same concern. The craft flow
  still uses it: `/craft-layer:research` and `/craft-layer:craft` invoke
  `ui-ux:theming-system` to derive the token-system direction the brief carries.
- **asset-sourcing** — build-vs-source-vs-commission for icons, SVG/vector, 3D models,
  animated overlays, and illustration/imagery: a categorical source taxonomy plus a hard,
  audited licence/provenance gate; reuses motion-tiers tier 4 + the Vector tier. It also owns
  the COMPONENT decision — four classes over conventional furniture, the signature always
  first-party, the origin recorded per block — with an explicit table of which of its rules
  are gates and which are recorded-but-unenforced.
- **motion-tiers** — the tier decision system, named for the JOB rather than the package
  that currently does it: **UI state / layout** (Framer Motion), **Timeline / SVG**
  (anime.js), **3D / WebGL** (Three.js/R3F), **Sprites**, and **Vector** (Lottie / Rive)
  — each with when-to-use, a perf budget, a `prefers-reduced-motion` fallback, a
  reduced-bundle fallback, and a per-framework tool binding. A superseded package is then
  a fact to re-verify, not a taxonomy to rewrite.
- **information-design** — hierarchy, data density, tables/dashboards, and when to reach
  for data-viz — for the data-dense CRM/SaaS targets.
- **scroll-orchestration** — the smooth-scroll substrate (Lenis) + scroll-driven
  animation contract; references `gsap.md` for ScrollTrigger and CSS scroll-driven as
  the reduced-bundle path. Its `references/scroll-acts.md` owns the scroll ACT — a pinned
  scene, a scrubbed frame sequence, a scroll-revealed panel — with the frame budget, the
  three states each act owes, and the rule that a sequence the visitor can only watch
  advance is an entrance reveal with more frames.
- **kinetic-typography** — animated + variable-font type: split-text reveals,
  variable-font axes on scroll/hover, phrase cross-fades (references the split-text and
  gradient-clip/aria gotchas rather than re-teaching them).
- **page-transitions** — route/page view-transitions: the decision, shared-element
  choreography across React/Next/Nuxt/Astro, reduced-motion + unsupported-browser
  fallback (references the View Transitions API rather than re-teaching it).
- **webgl-effects** — postprocessing + custom shaders as an effect layer on Tier 3: the
  GPU-cost decision, scroll/pointer shader uniforms, a pass budget, and a
  static/reduced-motion fallback (references `threejs-best-practices` + `webgl-3d.md`).
- **interaction-fx** — pointer micro-interactions (custom cursor, magnetic, tilt, drag):
  the affordance-vs-decoration decision, the a11y rules, one rAF pointer loop, and
  reduced-motion (references Framer + the one-writer gotcha).
- **physics-motion** — real 2D physics (matter.js): the real-physics-vs-spring decision,
  gravity/collision/drag-inertia, a one-world/rAF/body-cap budget, a keyboard route, and a
  settled/static reduced-motion fallback (a motion source, not a tier).

## Commands

- **`/craft-layer:craft`** — the idea→app orchestrator (chain above). Add `guided` to decide
  the page section by section as part of the same prompt.
- **`/craft-layer:sections`** — the guided section-decision loop standalone: for a page whose
  concept and tokens already exist, or to re-decide one section later. Decides; builds nothing.
- **`/craft-layer:research`** — run the design-research playbook standalone.
- **`/craft-layer:audit`** — audit a project against the craft gates.

## Agents

- **creative-director** — read-only agent that generates and scores divergent creative
  concepts (metaphor, editorial voice, signature interaction) and returns the winner plus a
  divergence record the craft audit checks.
- **craft-reviewer** — read-only reviewer for the craft gates (signature-interaction shipped,
  offer contract, content depth,
  anti-sameness, section-ledger conformance, reduced-motion per tier, lazy + static-fallback
  3D, per-tier budgets, sprite/asset budgets, licence + asset-fit, accent-vs-surface
  contrast). Cites the sizes and ratios the audit measured for it, and reports `not measured`
  rather than guessing when it has none. Delegates a11y → `/ui-ux:audit` and performance →
  `/resilience:performance-review`.

## Reuse map

craft-layer **references, never re-teaches**, these existing skills:

| Concern | Owned by |
| --- | --- |
| Design-token scales | `plugins/ui-ux/skills/design-tokens` |
| Palette / theme value generation (craft-layer's own `ui-ux:theming-system` derives the token-system DIRECTION; these own the VALUES) | `plugins/ui-ux/skills/shadcn-theming` + `/ui-ux:theme` |
| Motion library idioms (Framer, GSAP, anime.js) | `plugins/ui-ux/skills/motion-best-practices` (+ `references/animejs.md`) |
| GSAP timelines | `plugins/ui-ux/skills/motion-best-practices/references/gsap.md` |
| Spring/tween alternative (physics-motion references, to decide when NOT to use physics) | `plugins/ui-ux/skills/motion-best-practices` |
| View Transitions API (page-transitions references it) | `plugins/ui-ux/skills/motion-best-practices` |
| Three.js / R3F correctness (webgl-effects references it) | `skills/threejs-best-practices` in this plugin, reviewed by `/craft-layer:review` |
| One-writer-per-property (physics-motion references) | `plugins/craft-layer/skills/motion-tiers/references/gotchas.md` |
| RTL / BiDi base rules (the four-rule floor plus the motion decisions + LTR-islands) | `plugins/craft-layer/skills/motion-tiers/references/rtl-bidi.md` |
| Option staging for guided builds — consent gate, ASCII + shell HTML mockups (section-decisions decides WHAT to ask, never how to draw it) | `plugins/taskmaster/skills/visual-decisions` |
| Real-component option previews on a live server | `/design-lab:preview` |
| Validating the ASSEMBLED page after the section picks | `plugins/taskmaster/skills/experience-walkthrough` |
| Requirement clarification into a spec + cards (section-decisions consumes a spec, never re-interrogates it) | `plugins/taskmaster` |
| Full WCAG accessibility (craft checks only accent-vs-surface contrast itself) | `/ui-ux:audit` |
| Performance / Lighthouse (optional external delegation) | `/resilience:performance-review` requires the `resilience` plugin; skipped if not installed |
| Chart form / color | the `dataviz` skill (external host skill, not in this repo) |

## Install

Ships in the **craft-suite** bundle alongside `ui-ux` and `design-lab` — which is
the recommended install, because one of those is not optional in practice:

- **`ui-ux` — required.** craft-layer writes no build logic itself; `/ui-ux:theme` owns token
  generation (step 2) and `/ui-ux:build` owns the build (step 6). Without it the chain has no
  step 2 and no step 6.
- **`a11y` — required for the audit.** `/craft-layer:audit` delegates the full accessibility
  pass to `/ui-ux:audit` unconditionally; craft-layer checks only accent-vs-surface contrast
  itself.
- **`resilience` (performance review) — genuinely optional.** `/resilience:performance-review` is explicitly skipped when the
  plugin is absent.
- **`taskmaster`, `design-lab` — optional.** They stage guided-mode
  options at higher fidelity; without them decisions degrade to written multiple-choice and
  every gate still runs.
