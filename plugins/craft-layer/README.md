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
   audience, the one primary action, the route list, the page length, the mode, the
   offer-spine slots the page owes), then generate a divergent concept (central metaphor,
   editorial voice, one signature interaction) that breaks the sameness defaults, before
   anything visual is decided.
1. **`/craft-layer:research`** — mine reference designs + interaction/layout patterns,
   emit a theme brief and a build task, biased toward the concept.
2. **`/ui-ux:theme`** — generate design tokens (light/dark) + live preview from the brief;
   `theming-system` derives the coherent token-system direction the brief carries.
3. **section-decisions** *(guided mode only)* — decide the page section by section with the
   user: the spine slots become a batched agenda, each section is offered as 2–3 structurally
   different treatments, and the picks land in a section ledger the build and audit read.
   Also runnable standalone as **`/craft-layer:sections`**. Skipped on `one-shot`.
4. **asset-sourcing** — decide where each visual asset comes from
   (build-vs-source-vs-commission) and record provenance under a licence gate, before the
   build.
5. **motion routing** — DECIDE the motion, **before** the build, starting from the concept's
   ONE signature interaction: which section owns it, which skill implements it, what tier it
   costs. craft-layer writes no animation code itself — it resolves the build task's `Motion:`
   and `Signature:` lines. Route each surface to its owning skill (`motion-tiers` for the
   base tier; `scroll-orchestration`, `page-transitions`, `kinetic-typography`,
   `interaction-fx`, `physics-motion`, `motion-sequencing`, `webgl-effects` as needed),
   then fold in the cross-cutting decisions: reduced-motion + reduced-bundle fallbacks, the
   **cumulative** motion budget, **RTL** effect-mirroring vs LTR-islands, and
   **accent-vs-surface contrast**.
6. **`/ui-ux:build`** — build components/layout in ONE pass (carrying the ledger's choices
   when step 3 ran, the asset plan, and step 5's resolved motion), applying `design-tokens`
   and `information-design`.
7. **`/craft-layer:audit`** — verify the craft gates (the signature interaction actually
   shipped, offer contract, content depth, ledger
   conformance, per-tier + cumulative budget, reduced-motion, contrast, licence + asset-fit,
   the newer-skill gates; delegating full a11y + performance). It measures asset and chunk
   sizes itself before dispatching, and any gate it cannot measure is reported
   `not measured` rather than guessed — then offers to route the findings to a worker.

### Why motion is decided before the build

Every other motion rule in this plugin is a **ceiling** — per-tier budgets, the cumulative
budget, reduced-motion paths, reduced-bundle fallbacks, lazy-loaded 3D. Ceilings stop bad
motion; they cannot produce good motion, and a page with no animation at all clears every one
of them. Two rules close that gap:

- **Step 5 runs before step 6.** Motion decided after a layout is committed can only be
  retrofitted onto markup that was not built for it, so the retrofit lands on the one thing a
  retrofit allows — fade-and-rise reveals. A pinned scroll act, a WebGL hero surface, a
  shared-element route transition, a physics stage: those are structural. They are in the
  build task or they never ship.
- **The signature is the motion floor.** The concept names ONE signature interaction at step 0;
  step 5 assigns it a section, an owning skill, and a tier on the build task's `Signature:`
  line; the audit checks the named mechanism actually shipped there. It is the only gate that
  fails a page for too *little* motion, and entrance reveals never count toward it. It is also
  what makes anime.js, Three.js, physics, and Lottie/Rive reachable at all — the tier picker
  takes the cheapest tier that fits on every ordinary surface, and only the signature surface
  is picked by what the move needs.

No divergence record persisted → the gate reports `not checked`, like every other gate whose
input is missing. It never fails a build that simply never saved one.

### What the run writes outside your app

Three working files, at fixed names so a later session — or a standalone
`/craft-layer:audit` — can find them by glob. They live in the taskmaster docs area when the
project has one, otherwise the session scratch area, and **never** in the shipped tree:

| File | Written by | Read by |
| --- | --- | --- |
| `craft/offer-contract.md` | step 0, after the archetype is classified | the audit's scope, length, mode and content-depth gates |
| `craft/divergence-record.md` | step 0, once the concept exists | the audit's anti-sameness gate and the plain-language what-line check |
| `craft/section-ledger.md` | step 3 (guided only) | `/ui-ux:build` via the build task, and the audit's conformance gate |

Missing any of them is not a failure — the gates that need them report `not checked` rather
than passing or failing a build that simply never saved one.

One file DOES land in the project: the asset **provenance manifest**, written at step 4 under
one of the names the licence gate globs for — `ASSETS`, `CREDITS`, `PROVENANCE`, or
`THIRD-PARTY-NOTICES`. A manifest at any other path reads as absent to the gate. An
all-in-code build still owes one, as a first-party declaration.

### Dating volatile facts

A research pass over this plugin found the architecture sound and the **facts** rotten.
Everything wrong was a claim with a shelf life — a library version, a bundle size, a
maintenance status, a Baseline state. One reference asserted that a runtime was lighter
than its alternative when it is roughly three times heavier, with no date on the claim to
suggest it might have aged.

So: **any file asserting an OBSERVED FACT ABOUT THE WORLD carries a `Last verified: <date>`
line under its title**, naming what the date covers. Three categories, and only the first
one dates:

| Category | Dates? | Examples |
| --- | --- | --- |
| **Observed fact** — true of something we do not control, and can change without notice | **yes** | a library's gzipped size, a release version, a maintenance status, a Baseline/support state, a licence's terms |
| **Policy** — a ceiling or rule this plugin CHOSE | no | "a decorative sprite sheet stays under ~150 KB", the contrast ratios, the section-count floors |
| **Identifier** — a name used to refer to a thing | no | `@theatre/core`, `motion/react`, `oklch()` |

A date on a timeless rule is noise, and noise is how a convention dies. Decision
procedures, taxonomies, and gates carry no date at all.

Two rules make it worth having:

- **A date on an unverified fact is worse than no date**, because it launders a guess into
  a checked claim. When only part of a file was re-verified, say which part
  (`physics-patterns.md` does).
- **One source of truth per number.** Where a SKILL body repeats a figure so a decision is
  pickable at a glance, the body names the reference as authoritative; on drift the
  reference is fixed and re-dated first, then mirrored. A SKILL body at its line cap
  discharges this through its References section rather than growing a second pointer —
  the delegation is what matters, not where it is written.

### Gates vs triggers

A **gate** is a defect type — wrong contrast, a missing spine slot, an absent signature. A
**trigger** is the condition that SURFACES a fault: the viewport, the zoom level, the motion
preference, the colour mode, the input device. Gate coverage can improve indefinitely while
the trigger set never changes, and any defect reachable only under an unfired trigger stays
invisible however careful the review is — so `/craft-layer:audit` reports both, and names the
triggers it did not fire.

`template/craft-gates/` ships the browser-driveable set as a drop-in Playwright suite
(200% zoom, reduced-motion, forced-colours, axe in both themes) plus the oklch-aware
contrast script. It runs in about two seconds. Copy it into a crafted project; the audit
hands it to any project that has no suite of its own.

### One-shot or guided

The offer contract declares a **mode**, in the same prompt as everything else:

| Mode | What happens | Use when |
| --- | --- | --- |
| `one-shot` *(default)* | the page is generated from the contract + concept, with the chain's own handoff points (stack, contract echo, token approval) still yours to answer | small page, a re-run, headless |
| `guided` | step 3 runs: you pick each section's treatment before it is built | broad or half-formed brief, the page IS the deliverable, or you want options |

`guided` is pinned by ASKING for it in any words — "guided", "section by section", "give me
options" — not by a flag.

```bash
# one-shot
/craft-layer:craft a landing page for Acme, an uptime monitor for solo devs

# guided, from the same prompt
/craft-layer:craft guided — a landing page for Acme, an uptime monitor for solo devs

# or decide sections for a page whose concept and tokens already exist
/craft-layer:sections the Acme landing page
```

Guided costs a handful of exchanges: **Shape** (one whole-page outline pick),
**Treatment** (3–4 sections batched per exchange, most consequential first), and at most one
**Signature** decision — under the exchange cap `section-decisions/references/decision-rounds.md`
sets, with *"decide the rest for me"* offered at every one and *"show me one option"* available
when you want a recommendation instead of a menu. It degrades
cleanly: no mockup plugins installed → written multiple-choice; headless → the whole agenda is
auto-decided, every ledger row marked `auto`, and reported.

## Skills

- **creative-direction** — the concept-first anti-sameness layer: generates a divergent
  concept (metaphor, editorial voice, one signature interaction), scores blind candidates,
  and records a divergence the audit checks; owns the offer-contract, content-depth, and
  sameness-fingerprint gates.
- **section-decisions** — the guided-build checkpoint: derives a decision agenda from the
  offer contract's spine slots (never an invented one), batches it into three capped rounds,
  offers 2–3 structurally different treatments per section, and records the picks in a
  section ledger the build task carries and the audit checks for conformance. Owns the
  agenda, the rounds, and the ledger; routes all option-drawing to `taskmaster:visual-decisions`,
  `/design-preview:preview`, `/shadcn-studio:stage` and `/ui-ux:theme`, each optional.
- **design-research** — a repeatable method to mine reference designs and patterns and
  emit briefs in the exact form `/ui-ux:theme` and `/ui-ux:build` consume.
- **theming-system** — derive a coherent token SYSTEM from the concept: surface/ink/accent
  tiers as roles, the three-role accent split (display · fill · text/mark), a reserved status palette, a chart
  palette tied to the theme, and a light/dark duality stepped from ramps. Emits roles +
  contrast rules and defers value generation to `/ui-ux:theme` + `design-tokens` +
  `shadcn-theming`; ships no colour or token value.
- **asset-sourcing** — build-vs-source-vs-commission for icons, SVG/vector, 3D models,
  animated overlays, and illustration/imagery: a categorical source taxonomy plus a hard,
  audited licence/provenance gate; reuses `sprite-motion` + the Vector tier.
- **motion-tiers** — the tier decision system: Framer Motion, anime.js, Three.js/R3F,
  and sprites — each with when-to-use, a perf budget, a `prefers-reduced-motion`
  fallback, a reduced-bundle fallback, and a per-framework tool binding — including
  **Tier 5 — Vector (Lottie / Rive)** for designer-authored vector motion.
- **sprite-motion** — sprite / sprite-sheet authoring: sheet formats, CSS `steps()` and
  `requestAnimationFrame` loops, reduced-motion poster frames, size budgets.
- **information-design** — hierarchy, data density, tables/dashboards, and when to reach
  for data-viz — for the data-dense CRM/SaaS targets.
- **scroll-orchestration** — the smooth-scroll substrate (Lenis) + scroll-driven
  animation contract; references `gsap.md` for ScrollTrigger and CSS scroll-driven as
  the reduced-bundle path.
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
- **motion-sequencing** — declarative multi-track choreography (theatre.js): the
  GSAP-timeline-vs-theatre decision, sheets driven by time or scroll, DOM + 3D-camera
  sync, the dev-only editor→runtime workflow, and a reduced-motion jump-to-final.

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
  rather than guessing when it has none. Delegates a11y → `/a11y:audit` and performance →
  `/performance:review`.

## Reuse map

craft-layer **references, never re-teaches**, these existing skills:

| Concern | Owned by |
| --- | --- |
| Design-token scales | `plugins/ui-ux/skills/design-tokens` |
| Palette / theme value generation (craft-layer's own `theming-system` derives the token-system DIRECTION; these own the VALUES) | `plugins/ui-ux/skills/shadcn-theming` + `/ui-ux:theme` |
| Motion library idioms (Framer, GSAP, anime.js) | `plugins/ui-ux/skills/motion-best-practices` (+ `references/animejs.md`) |
| GSAP timelines (motion-sequencing references, doesn't re-teach) | `plugins/ui-ux/skills/motion-best-practices/references/gsap.md` |
| Spring/tween alternative (physics-motion references, to decide when NOT to use physics) | `plugins/ui-ux/skills/motion-best-practices` |
| View Transitions API (page-transitions references it) | `plugins/ui-ux/skills/motion-best-practices` |
| Three.js / R3F correctness (webgl-effects + motion-sequencing camera reference it) | `plugins/threejs/skills/threejs-best-practices` |
| One-writer-per-property (physics-motion references) | `plugins/craft-layer/skills/motion-tiers/references/gotchas.md` |
| RTL / BiDi base rules (rtl-bidi.md references, adds only the motion decisions + LTR-islands) | `plugins/i18n/skills/i18n/SKILL.md` |
| Option staging for guided builds — consent gate, ASCII + shell HTML mockups (section-decisions decides WHAT to ask, never how to draw it) | `plugins/taskmaster/skills/visual-decisions` |
| Real-component option previews on a live server | `/design-preview:preview`, `/shadcn-studio:stage` |
| Validating the ASSEMBLED page after the section picks | `plugins/taskmaster/skills/experience-walkthrough` |
| Requirement clarification into a spec + cards (section-decisions consumes a spec, never re-interrogates it) | `plugins/taskmaster` |
| Full WCAG accessibility (craft checks only accent-vs-surface contrast itself) | `/a11y:audit` |
| Performance / Lighthouse (optional external delegation) | `/performance:review` requires the `performance` plugin; skipped if not installed |
| Chart form / color | the `dataviz` skill (external host skill, not in this repo) |

## Install

Ships in the **frontend-suite** bundle alongside `ui-ux`, `threejs`, `design-preview`,
`shadcn-studio`, and `a11y` — which is the recommended install, because two of those are not
optional in practice:

- **`ui-ux` — required.** craft-layer writes no build logic itself; `/ui-ux:theme` owns token
  generation (step 2) and `/ui-ux:build` owns the build (step 6). Without it the chain has no
  step 2 and no step 6.
- **`a11y` — required for the audit.** `/craft-layer:audit` delegates the full accessibility
  pass to `/a11y:audit` unconditionally; craft-layer checks only accent-vs-surface contrast
  itself.
- **`performance` — genuinely optional.** `/performance:review` is explicitly skipped when the
  plugin is absent.
- **`taskmaster`, `design-preview`, `shadcn-studio` — optional.** They stage guided-mode
  options at higher fidelity; without them decisions degrade to written multiple-choice and
  every gate still runs.
