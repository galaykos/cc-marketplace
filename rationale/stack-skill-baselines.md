# Stack-skill baseline tests — evidence for the W6.5 removals

Date: 2026-07-27. Method: the house baseline loop
(`claude-authoring/skills/authoring-skills/references/behavioral-testing.md`,
RED step): for each candidate skill, one seeded-violation fixture was reviewed
by two blind agents on the same model (claude-sonnet-5) — a CONTROL forbidden
from reading any skill, and a TREATMENT instructed to read the SKILL.md first
and apply its checklist, tagging findings it would not have made without it.
Verdict rule: no seeded violation caught by treatment-but-not-control, and no
distinctive advice beyond the model's own → the skill restates the model →
remove ("no failure to capture → don't ship it").

## Results

| Skill | Seeded | Control | Treatment | Delta | Verdict |
|---|---|---|---|---|---|
| vue2-best-practices | 5 | 5/5 + extras (both reactivity traps, filters, mixin collision) | 5/5 | 0 | REMOVE plugin |
| javascript-best-practices | 7 | 7/7 + implicit globals, dead var | 7/7 | 0 | REMOVE plugin |
| typescript-best-practices | 5 | 5/5 + res.ok, encodeURIComponent, return types | 5/5 | 0 | REMOVE plugin |
| react-best-practices | 6 | 6/6 **+ 6 more** (shape-mismatch logic bug, abort/cleanup, undefined-prop guard) | 5 findings, all ⊂ control | **negative** | REMOVE skill + command |
| bootstrap-best-practices | 6 | 6/6 + v5 renames (ms-, data-bs-, btn-close), aria wiring | 6/6 | 0 | REMOVE skill |
| css3-best-practices | 6 | 6/6 + token scale, color-mix derivation | 5/6, [SKILL] tags falsified by control | ≤0 | REMOVE skill |
| flexbox-best-practices | 6 | 6/6 + min-width:auto trap | 6/6 | 0 | REMOVE skill |
| css-grid-best-practices | 5 | 4/5 + 2 bugs treatment missed (98% arithmetic, magic offset) | 5/5 (grid-vs-flex routing) | +1 / −2 | REMOVE skill |

Most damning single result: the react TREATMENT returned five findings — every
one also found by the blind control — while the control alone additionally
caught a real logic bug (order object overwriting user-details state, breaking
`details.name`), the missing fetch abort/cleanup, and an undefined-prop crash.
The checklist narrowed the review.

## What was removed and what stayed

Removed: `vue2`, `javascript`, `typescript` plugins (whole);
`react-best-practices` skill + `/react:review` (react keeps
`react-server-state` — it encodes a library-choice discipline, untested here
but not idiom-restating by construction); ui-ux skills `bootstrap-`,
`css3-`, `css-grid-`, `flexbox-best-practices`.

Kept deliberately (tier 1, not tested — highest training-cutoff drift and/or
teeth): laravel (ships the shared backend-engineer worker), php, livewire,
inertia, nextjs, nuxt, vue3, vite, threejs, node-backend, react-native, and
the db dialect plugins. These encode version leverage maps and lockfile-pinning
behavior, not idioms.

## Residuals (honest scope)

- One fixture, one run per skill — variance unmeasured. Fixtures seeded from
  general framework knowledge, which biases toward what models know; a fixture
  built from each skill's most exotic rule might show a delta these did not.
- Version-pinning behavior ("read the lockfile before advising") was not
  exercised — fixtures had no manifests. That behavior is the stated reason
  tier 1 survives untested.
- Trigger/dispatch value (skill-router rows, description routing) is separate
  from body value and was not measured; routing rows for removed skills were
  deleted or re-pointed (react rows now route `react-server-state`).
- Model was sonnet; a weaker model might benefit more from the checklists. The
  marketplace's default subagent tier is sonnet-or-better.
