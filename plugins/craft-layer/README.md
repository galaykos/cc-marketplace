# craft-layer

Create unique, high-craft, animated, **informative** web apps — CRMs, SaaS dashboards,
landing pages — on real projects across **React, Tailwind, Vite, Vue, Next, Nuxt, and
Laravel** (Inertia / Livewire). `craft-layer` is the orchestration layer that turns an
idea into a crafted app by composing the marketplace's existing UI/motion skills, adding
only what they lack: a research→brief playbook, a tiered motion **decision** system,
sprite guidance, information design, and a craft **audit**.

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
5. **`/ui-ux:build`** — build components/layout (carrying the ledger's choices when step 3
   ran), applying `design-tokens` and `information-design`.
6. **motion routing** — route each surface to its owning skill (`motion-tiers` for the
   base tier; `scroll-orchestration`, `page-transitions`, `kinetic-typography`,
   `interaction-fx`, `physics-motion`, `motion-sequencing`, `webgl-effects` as needed),
   then fold in the cross-cutting decisions: reduced-motion + reduced-bundle fallbacks, the
   **cumulative** motion budget, **RTL** effect-mirroring vs LTR-islands, and
   **accent-vs-surface contrast**.
7. **`/craft-layer:audit`** — verify the craft gates (offer contract, ledger conformance,
   per-tier + cumulative budget, reduced-motion, contrast, licence + asset-fit, the
   newer-skill gates; delegating full a11y + performance).

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
sets, with *"decide the rest for me"* and *"show me one option"* offered at every one. It degrades
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
  tiers as roles, the display-vs-text/mark accent split, a reserved status palette, a chart
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
- **craft-reviewer** — read-only reviewer for the craft gates (reduced-motion per tier,
  lazy + static-fallback 3D, per-tier budgets, sprite/asset budgets, licence + asset-fit,
  accent-vs-surface contrast). Delegates a11y → `/a11y:audit` and performance →
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
| Chart form / color | the `dataviz` skill |

## Install

Ships in the **frontend-suite** bundle alongside `ui-ux`, `threejs`, `design-preview`,
`shadcn-studio`, and `a11y` — which is the recommended install, because two of those are not
optional in practice:

- **`ui-ux` — required.** craft-layer writes no build logic itself; `/ui-ux:theme` owns token
  generation (step 2) and `/ui-ux:build` owns the build (step 5). Without it the chain has no
  step 2 and no step 5.
- **`a11y` — required for the audit.** `/craft-layer:audit` delegates the full accessibility
  pass to `/a11y:audit` unconditionally; craft-layer checks only accent-vs-surface contrast
  itself.
- **`performance` — genuinely optional.** `/performance:review` is explicitly skipped when the
  plugin is absent.
- **`taskmaster`, `design-preview`, `shadcn-studio` — optional.** They stage guided-mode
  options at higher fidelity; without them decisions degrade to written multiple-choice and
  every gate still runs.
