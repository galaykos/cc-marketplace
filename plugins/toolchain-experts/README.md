# toolchain-experts

Five expert reviewers for PHP, TypeScript/JavaScript, React, Vue and CSS that **run
the project's own static analysis** and triage the real output, instead of reciting a
best-practice checklist.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install toolchain-experts@cc-plugins-marketplace
```

## Why it is shaped this way

This marketplace already measured the obvious version of this plugin and deleted it.
`rationale/stack-skill-baselines.md` (2026-07-27) ran a blind control against a
treatment on seeded-defect fixtures, one fixture per skill:

| Artifact | Seeded | Control | Treatment | Delta |
|---|---|---|---|---|
| TypeScript idiom checklist | 5 | 5/5 + extras | 5/5 | **0** |
| JavaScript idiom checklist | 7 | 7/7 + extras | 7/7 | **0** |
| Vue 2 idiom checklist | 5 | 5/5 + extras | 5/5 | **0** |
| React doctrine checklist | 6 | 6/6 **+ 6 more** | 5, all a subset of control | **negative** |
| Four CSS style catalogues | 5-6 | 4/5 to 6/6, plus extras in every arm | equal or worse | **0, and +1/−2 on css-grid** |

All of them were removed after baseline testing. The React result is the one that
shaped this plugin: the checklist did not merely fail to add, it **narrowed** the
review — the blind control alone caught a state-overwrite logic bug, a missing fetch
abort and an undefined-prop crash that the checklist-following treatment missed.

`rationale/measured-zero-shapes.md` records what has *not* measured zero: a mechanism
with an exit code, a decision procedure whose ORDER is the content, manifest-reading
behaviour, and installation-specific knowledge. Every artifact here is one of those
four, by construction.

## What you get

| Agent | Runs | Headline finding it alone can produce |
|---|---|---|
| **php-expert** | phpstan, psalm, phpcs, rector | The analysis level's reach — which bug class the configured level cannot see |
| **ts-expert** | tsc, eslint, biome, oxlint | Which compiler strictness flags are off, and the defect class each hides |
| **react-expert** | the eslint hook rules | Whether `exhaustive-deps` is enforced, demoted to a warning, or absent |
| **vue-expert** | vue-tsc, eslint-plugin-vue | Whether CI typechecks single-file components at all, or silently skips them |
| **ui-expert** | stylelint, pa11y, lighthouse-ci, axe | Which accessibility rules the project has switched off |

One skill, `analyzer-triage`, carries the step order all five follow. One script,
`scripts/detect-analyzers.sh`, is the mechanism.

## The mechanism

    bash scripts/detect-analyzers.sh [project-root]

Emits one greppable record per line — `analyzer`, `formatter`, `strictness`, `ci`,
`none` — naming each configured tool, its config path, its baseline, its exact
invocation, and which CI workflow actually runs it. Where a config's meaning depends on
the installed major — an absent `strict` is on from TypeScript 6 unless an `extends` base
may set it (`strict absent-via-extends-unresolved`), ESLint 9 loads `.eslintrc*` only under
`ESLINT_USE_FLAT_CONFIG=false` and ESLint 10 never (`eslintrc-not-loaded <major>`),
TypeScript 7 has no compiler API for vue-tsc, svelte-check, astro check or
typescript-eslint — it reads the version from `node_modules`, then `package-lock.json`, then
the `package.json` `devDependencies` or `dependencies` range, never a `peerDependencies`
one, and says which. Standing: gate — `detect-analyzers.test.sh` "TS 6, extends and no
local strict: …", "ESLint 9 with an .eslintrc: …" and "a peerDependencies range does not
decide the major, …". Residuals: pnpm and yarn lockfiles are not read; without `jq` the
range is the first one `package.json` names; ESLint 9 run with `ESLINT_USE_FLAT_CONFIG=false`
still draws `eslintrc-not-loaded`.

**Exit 1 means no analyzer is configured**, and that exit code is the point: it stops
an agent from falling back on a remembered checklist, which is the measured-negative
behaviour above. The agents are instructed to report the absence and stop.

## The three buckets

Every line of analyzer output lands in exactly one:

- **new defect** — flagged, and no baseline forgives it.
- **baselined debt** — already suppressed. Report the count, not the lines; "fixing"
  one breaks the build for everyone whose baseline still lists it.
- **config gap** — the tool *cannot see* this class because a rule is off. Reported
  last and loudest, because it is the finding that depends on files the model has not
  seen, and the one a checklist can never produce.

## What it does not do

- **It does not fix anything.** All five agents are `Read, Grep, Glob, Bash` — they
  run tools and report. Fixes route to the existing workers: `task-runner`'s
  task-executor, `laravel`'s backend-engineer, `web-dev`'s web-developer, `ui-ux`'s
  a11y-engineer.
- **It does not review component logic.** State, effects, keys, data fetching, prop
  flow → `web-dev`'s frontend-reviewer, which owns that rubric and grades React and
  Vue in their own vocabulary.
- **It does not replace `/ui-ux:audit`.** Automated accessibility checking catches a
  minority of WCAG failures; contrast, focus order, keyboard traps and meaningful alt
  text need the judgment pass.
- **It does not work on a project with no analyzer configured.** By design. That case
  returns one honest line instead of a plausible-looking review.

## Standing

- **Gate** — `scripts/__tests__/detect-analyzers.test.sh` runs on every PR through the
  repo-wide plugin-harness glob. It asserts the contract the agents depend on: an
  analyzer-free project exits 1, a baseline is reported before it can be re-flagged, a
  demoted rule surfaces its real severity, and a formatter is never promoted to an
  analyzer.
- **Agent-graded** — that each agent reads the baseline before running the tool, and
  labels an unenforced config's findings as suggestions. No script can prove either.
  Likewise the skip (since 0.4.0): an analyzer CI already passed on this HEAD is not run
  again — `gh run list --commit <HEAD>` must show every run for that SHA completed and
  successful, the step running the tool must not be advisory (`continue-on-error`,
  `|| true`) and the working tree must be clean. Without `gh`, offline or with no run for
  the SHA, the agent runs the tool as before; the config-gap report runs either way.
  Residual: a job skipped by a path filter or `if:`, or a step given a narrower path set
  than the files in scope, still reads as a pass.
- **Recorded, not measured** — the claim that these five outperform a blind control has
  **not** been ablated. That is the honest standing of a plugin whose own README opens
  with an ablation table, and it is stated rather than hidden. The design is argued
  from the shape list in `rationale/measured-zero-shapes.md`, which is an argument, not
  a measurement. A control/treatment run on a fixture carrying a baselined defect and a
  switched-off rule is the experiment that would settle it.
