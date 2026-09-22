# Stack-skill baseline tests — evidence for the W6.5 removals

Date: 2026-07-27. Method: the house baseline loop
(`.claude/skills/authoring-skills/references/behavioral-testing.md`, RED step —
a project skill of this repo since the `claude-authoring` plugin was retired
2026-09-03): for each candidate skill, one seeded-violation fixture was reviewed
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
teeth): laravel (ships the shared backend-engineer worker), inertia, nextjs,
vite, threejs, react-native, and the db dialect plugins. These encode version
leverage maps and lockfile-pinning behavior, not idioms.

> **Corrected 2026-08-31.** This paragraph also named php, livewire, nuxt, vue3
> and node-backend as "kept deliberately" until then; all five were deleted on
> 2026-08-26 by `cfef9c1`. It matters more than a stale list usually would,
> because `scripts/lib/plugin-checks.sh:298-299` cites THIS FILE as the ground
> truth for `pc_removed_refs`' hardcoded denylist — so the gate and its own
> stated source disagreed. The defence this paragraph makes is also weaker than
> it reads: `rationale/eval-ablation-2026-08-20.md` §4 measured the
> lockfile-reading claim directly and got 3/3 control, 3/3 treatment, with every
> control run opening the manifest unprompted. The tier still ships on the
> refuted half of its own argument.

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

---

## 2026-09-22 — `estimation` + `/approaches:size` removed WITHOUT a measurement

**Removed:** `plugins/approaches/skills/estimation/` and
`plugins/approaches/commands/size.md` (approaches 0.10.0).

**Why.** Two reasons, neither of them a delta:

1. **Shape 2 verbatim** (`rationale/measured-zero-shapes.md` §2 — a checklist with no
   mechanism). The six-specialist panel's software reviewer scanned the ten checklist
   skills for bytes, references, a `Standing:` line and any mechanism, and `estimation`
   scored zero on the last three: prose classes (S/M/L/XL), prose anchors, prose
   multipliers, nothing that fails, nothing an eval reads
   (`rationale/specialist-panel-2026-09-22.md` §3.2, detail finding 12).
2. **Its one side effect was write-only.** The body instructed an append to
   `taskmaster-docs/estimation-ledger.md`. A repo-wide grep for that path returned
   exactly one hit — the instruction to write it. Zero readers, no gate, no skill, no
   script; a ledger nothing reads is a file, not a mechanism.

All three downstream citations (`taskmaster/skills/task-cards/SKILL.md`,
`taskmaster/commands/task.md`, `taskmaster/README.md`) were guarded by "if the
approaches plugin is installed", so the removed behaviour was already the fallback for
every install without approaches — which is most of them.

**Residual.** Card sizing is now unanchored judgment: taskmaster states the S/M/L/XL
rule inline in `task-cards` (M = a card the same person shipped in one sitting; L+ is
split or spiked) and nothing carries the uncertainty multipliers or the spike triggers
the skill listed. That is exactly today's behaviour whenever approaches is absent, so
the change is a loss only for installs that had it — and the loss is unmeasured in
both directions.

**The delta was NOT measured.** No control/treatment arm was run on `estimation`, here
or anywhere; the 2026-07-27 table above is a different set of skills. This removal
rests on shape and on a dead artifact, which is weaker evidence than the table above
and is stated as such. The panel offered the alternative explicitly
(`rationale/specialist-panel-2026-09-22.md` §4): one `--ablation with-without` run,
5+ runs, vote spread reported, pointed at either `solid-principles` or `estimation`,
and Software's own note said `estimation` was the cheaper of the two to retire if the
delta came back zero.

**Recommendation on shape.** Spend the one measurement on `solid-principles`, not on
this: `estimation` is gone on the write-only-ledger finding, which no eval was needed
to establish, while `solid-principles` is the largest surviving member of the same
shape and the result generalises to the other eight. If a future maintainer wants
`estimation` back, the bar is a control arm that fails a sizing prompt the skill
passes — not a re-reading of the prose.

**Gate.** `estimation` and `approaches:size` are now in `pc_removed_refs`' denylist
(`scripts/lib/plugin-checks.sh`), so a shipped doc routing a reader to either fails
`validate.sh`. Standing: **gate**. What it does not catch: "estimate", "sizing" and
"S/M/L/XL" name the same dead capability in prose and match nothing.
