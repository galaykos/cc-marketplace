# Ultra dispatch tiers & fan-out sizing

Read on demand from the ultra skill. The tier string, what `auto` resolves to, the floor,
the never-edit-frontmatter rule, which dispatch paths take `effort`, the `Workflow` opt-in
and the workflow-size cap are owned by `task-runner:verification-panels`
`references/dispatch-tier.md`; which agents carry a floor, boosted or not, by
`task-runner:delegation-contracts` `references/role-floors.md`. This file keeps what only
taskmaster's pipeline has: which of its roles get the boost, and how wide its fan-outs open.

## Role → tier ladder

| Role class | Phases / agents | Dispatched at | Why |
|---|---|---|---|
| **Reasoning** (get the boost) | red-team (`spec-adversary`), coverage gap-judgment (the loop-until-dry sweep that rules a finding a gap/orphan/drift), card-verify, any synthesis / judge / refuter that rules a claim in or out | the boost tier, `effort` set wherever the dispatch path takes it | depth IS the deliverable — a missed hole or a false-confirm costs far more than the token premium |
| **Mechanical** (stay native) | recon / readers (`context-scout`, one dispatch per lens — § Fan-out sizing defines the lenses), `coverage-check`'s read-only matrix build (Read/Grep/Glob), file locators, grep-and-list, extraction passes | the agent's own frontmatter tier — **no override** | location and gathering; `context-scout` ships `model: inherit`, so native = the session model |
| **Breadth** (stay native) | `opinion-lens` | native (`sonnet`/low) — never overridden | four blind persona takes, low-effort by design; a stronger model than the run's own would make their disagreement an artefact of tiering, not of persona |

The ladder never downgrades an agent below its frontmatter; it only declines to raise the
mechanical and breadth rows, and sets no `effort` on them (agent-graded).

`coverage-check` dispatches only the matrix build (mechanical); the gap-judgment it feeds runs
in the main thread at the session tier, so "coverage gets the boost" lands on that sweep and
never on the matrix builder.

Outside the reachable set: `code-architecture/agents/system-architect.md` and
`code-architecture/agents/architecture-reviewer.md` — the spec and card phases never dispatch
them; execution boosts architecture-reviewer separately via task-execution.

## Fan-out sizing

Pick the smallest N that covers the blast radius; sizing tunes N and never drops a
mandatory phase. Panel width is `task-runner:verification-panels` § Panel width, and the
Red-team column below maps taskmaster's radius rows onto it. Recon lenses and the coverage
loop are owned here — pipeline phases no other plugin runs.

A **recon lens** is one `context-scout` dispatch narrowed to part of its own six-section
report (`taskmaster/agents/context-scout.md`) — not a separate agent, not a flag. N=1 (the
unboosted default): one dispatch, all six sections. N=2: sections 1–2 (surface + patterns) |
3–4 (constraints + already-answered). N=3: add section 6 (visual surface, which carries the
theme-token table and is the section an all-in-one scout most often drops). Section 5, the
question list, is assembled in the main thread from the others — never a scan of its own.

| Blast radius | Recon lenses | Red-team panel | Coverage loop |
|---|---|---|---|
| **Small** — ≤2 files, isolated, low risk | 1 (inline scout) | 2 adversaries | 1 pass |
| **Medium** — the default shape | 2–3 | 3 adversaries | cap 2 rounds |
| **Large** — schema / auth / security / cross-cutting | 3 | 3 adversaries | cap 3 rounds |

Read the radius from the files the change plausibly touches and whether it crosses a trust
or data boundary (auth, money, PII, migrations, a public API): a two-file copy tweak is
Small, a new login method Large. When genuinely unsure, round up one row.

## Fan-out cost

On the `Workflow` path, before opening a stage: if `budget.total` is set and
`budget.remaining()` cannot fund it, shrink the stage toward its inline fallback — red-team
and coverage still run, at N=1 if that is all the budget funds. `budget.total == null` means
no token target, so the count ceilings alone apply; the inline path has no budget handle,
and there the counts are the only bound.

Each fan-out phase is its own `Workflow` call, so recon (≤3), spec-redteam (≤3) and a
coverage round (≤3) never sum against one workflow-size ceiling. The phase that collides is
card-verify: one pass per card over a large index is one wide stage, so verify cards in
waves that respect the guideline. Shrinking, and logging what was shrunk, follow
`dispatch-tier.md` § Native harness interop.
