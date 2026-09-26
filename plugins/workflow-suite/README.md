# workflow-suite

Meta-bundle: the whole idea-to-shipped pipeline in one install. The core-suite
baseline (candor, code-review, git-workflow, hindsight, secret-scanning,
skill-router, stack-scan) plus what the pipeline dispatches into — taskmaster
clarification and cards, task-runner execution carrying the delegation contracts
and verification panels, approaches deliberation, code-architecture
plan-before-code and work verification, testing, debugging, and the ui-ux and
security lanes the cards route to. It was `taskmaster-suite` until 2026-09-14,
when process-suite and quality-principles-suite were merged into it and the three
names retired. Uninstalls cleanly: `/workflow-suite:uninstall` removes the bundle and
every plugin it lists as a dependency at the same scope, minus anything another
installed suite also lists — it cannot tell a hand-install from an auto-install, so
read the list it prints.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install workflow-suite@cc-plugins-marketplace
```

Coming from taskmaster-suite, process-suite or quality-principles-suite: run that
bundle's own `uninstall` command first, then install this one. <!-- removed-ok -->

## Context-window requirement (read before installing)

**Standing: `gate` for the declaration's presence, `recorded` for its numbers** —
`pc_listing_declaration` fails the build if this section disappears while the
bundle still overflows; nothing checks the figures below, so recompute them with
`bash scripts/context-budget.sh` before trusting them.

Claude Code budgets the skill listing it sends the model at
`contextWindowTokens x bytesPerToken x skillListingBudgetFraction` (default
fraction 0.01). On the default 200k window with a current-tokenizer model that is
**6,000 chars**, and this bundle's listing costs **22,929 chars** (LC_ALL=C bytes
— the marketplace's deterministic measure, ~1% above what the CLI counts; measured
2026-09-16, `bash scripts/context-budget.sh`, listing channel) — over
budget, the host reduces entries to name-only in priority order, silently, so
skills stop being reachable without any error.

On the 1M-context tier (30,000 chars) this bundle fits. If you run the default
200k window, add to the `settings.json` of the project where you use this bundle:

```json
{ "skillListingBudgetFraction": 0.05 }
```

That raises the listing budget to 30,000 chars at 200k. The cost is real but
small: the fraction is a ceiling, not a purchase — it only admits description
text that was previously being evicted.

**Why 0.05 and not 0.04:** headroom. 0.04 is 24,000 chars and this bundle measured
22,929 on 2026-09-16, after its members' side-effect commands left the listing —
4% under, and it sat 165 chars OVER the day before. The next description edit in any
of the sixteen members could cross it again, and the symptom is silent eviction, not
an error. Recount before trusting any number on this page.

## What's included

The baseline, in every repo (see `core-suite`'s README for the membership rule):

> **Do not install `core-suite` alongside this one.** Every one of core-suite's
> seven members is already in the list below — it is a strict subset, not an
> overlap. Installing both buys nothing and breaks the exit: `/core-suite:uninstall`
> keeps a member whenever another installed bundle lists it, so with this bundle
> present it keeps all seven and removes only the core-suite manifest. Pick the
> bundle that matches the repo; use core-suite at user scope for the machine-wide
> baseline, this one at project scope where the whole pipeline is wanted.


- **candor** — the Stop gate: its clauses 3 and 4 are the evidence-at-claim gate and the registered-run gate, so a run in this bundle cannot end by narration; plus the terse reply mode, inert until set
- **code-review** — `/code-review:review`, the one review entry, loading every installed stack rubric; comment discipline on write
- **git-workflow** — worktree isolation, `/git-workflow:finish` (the ship phase), review-exchange rigor
- **hindsight** — cross-session friction mining, applied only on approval
- **secret-scanning** — write-time secret block
- **skill-router** — file-aware skill auto-routing on edit; the mechanism that makes the stack tier fire
- **stack-scan** — installed-version inventory before version-dependent advice; `/stack-scan:suggest` for the leaves this bundle leaves out

The pipeline:

- **taskmaster** — clarification-to-spec: grill, brainstorm, red-team, coverage, task cards (`/taskmaster:task`); `ultra` / `goal` / `goal-lean` for the boost and hands-off modes
- **task-runner** — executes task lists with scope lock and bounded verify-fix loops (`/task-runner:run`), the delegation contracts every dispatch is held to, the verification panels, `--tracks` for concurrent milestones
- **approaches** — deliberates the change shape before implementation (`/approaches:opinions`, `/approaches:compare`), the build-vs-buy, rollout and pattern-selection disciplines, and `/approaches:consult` — a blind stronger-model second opinion when stuck
- **code-architecture** — plan-before-code (the `plan` phase), SOLID/YAGNI audits, drift review, work verification (the `verify` phase, enforced at Stop by candor)
- **testing** — TDD discipline, the test-engineer agent cards dispatch to, and `/testing:flake-hunt`, its only command: test review rides the code-review fan-in, not a per-plugin review entry
- **debugging** — `/debugging:debug`, root cause with evidence before any fix
- **ui-ux** — the engineer and reviewer agents the pipeline's visual cards route to, `/ui-ux:theme`, the WCAG audit
- **ui-libraries** — the component-library skills (MUI, Astryx, ReUI, Aceternity, `component-libraries`) split out of ui-ux on 2026-09-26, so a card on a non-shadcn stack still gets its library's rules
- **security** — `/security:review`, threat modeling, the engineer the pipeline's security cards dispatch to

## What's excluded, and why

**The inclusion test, in order of precedence: a plugin stays when the pipeline
hard-wires it into the default flow.** ui-ux is in for exactly that reason — the
closed agent-tag set routes visual cards to its engineer/reviewer agents, and
specs bind `/ui-ux:theme`; without it those cards degrade to generic routing.
testing and security stay because task cards dispatch into both. (The 2026-09-14
consolidation plan's bundle table left ui-ux and security out; this test is a
recorded rule with a reason and the table gave none, so they stay.)

**The ceiling that shapes this list is not ours.** Claude Code budgets its skill
listing by the formula above — **6,000 chars on the default 200k window, 30,000 at
1M** — and past it the host drops descriptions, leaving names only. The overflow
is never a token cost (dropped text is never sent) — it is **reachability**, paid
by every member including the pipeline core. At fifteen members (22,929
entry-chars, 2026-09-16; the sixteenth, ui-libraries, is skills moved out of ui-ux, not new ones) the bundle fits at 1M outright and at 200k with the settings line
above; the measurement and the cost model are in
`rationale/2026-08-31-token-cost-review.md`.

**Everything left out is still shipped and still works — install it by name.**
From process-suite: `api-design` (consume docs before integrating, drift scan), <!-- removed-ok -->
`ultra-deep-research` (a research harness, opt-in), `brain` (a committed codebase
map; its SessionStart hook greets every un-indexed repo). From
quality-principles-suite: `resilience` (one review command over six concern <!-- removed-ok -->
rubrics). Stack leaves — `laravel`, `web-dev`, `database`, `devops` — are
stack-specific; `/stack-scan:suggest` names each when the project's manifests
earn it. The full-fidelity escalation above taskmaster's shell mockup is a rung of
that same skill, not a separate install. `command-guard`
is a per-user opt-in (core-suite's README says why).

## Uninstall

| Command | What it does |
|---------|--------------|
| `/workflow-suite:uninstall` | Uninstall the bundle AND remove every plugin it lists as a dependency at the same scope, minus anything another installed suite also lists — one step, no orphans. It cannot tell an auto-install from one you made yourself: install records routinely carry no marker, so a dependency you installed by hand appears in the removal list and the confirm step is what protects it |

## Pairs well with

- **frontend-suite** — React/Vue/TS framework specifics (web-dev) left out of this bundle
- **craft-suite** — the creative-build studio: craft-layer's creative direction, tiered motion catalog and WebGL effects, plus ui-ux. (Not the real-component preview — that is a rung of `taskmaster:visual-decisions`, which this bundle already ships.)
- **database**, **laravel**, **devops** — the stack leaves, by name
