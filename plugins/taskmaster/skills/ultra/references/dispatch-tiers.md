# Ultra dispatch tiers & fan-out sizing

Read on demand from the ultra skill. This is the detail behind two contract
lines: *reasoning roles get the boost, mechanical/breadth roles stay native*
(Lever 1), and *the fan-out counts are ceilings, not quotas* (Lever 2).

The boost tier (`model:<model>`, and `effort:<effort>` on the Workflow path) is
an **override you apply to the depth stages**, not a blanket the whole run wears.
This is not a new policy — it is `orchestration:delegation-contracts`' own rule:
tiering is *per-stage, not per-run* (one pipeline dispatches a cheap scout,
mid workers, an expensive judge), and its first anti-pattern is "uniform model
for every stage — judge-tier prices for a rename sweep." Flat-escalating every
ultra subagent to `fable` is exactly that anti-pattern. Ultra defers to it.

## Role → tier ladder

| Role class | Phases / agents | Dispatched at | Why |
|---|---|---|---|
| **Reasoning** (get the boost) | red-team (`spec-adversary`), coverage gap-judgment (the loop-until-dry sweep that rules a finding a gap/orphan/drift), card-verify, any synthesis / judge / refuter that rules a claim in or out | `model:<model>` + `effort:<effort>` | depth IS the deliverable — a missed hole or a false-confirm costs far more than the token premium |
| **Mechanical** (stay native) | recon / readers (`context-scout` by-file, by-pattern, by-constraint), `coverage-check`'s read-only matrix build (Read/Grep/Glob), file locators, grep-and-list, extraction passes | the agent's own frontmatter tier — **no override** | location and gathering; the top tier buys nothing a mid model does not already do. `context-scout` ships `model: inherit`, so native = the session model, never the `fable` premium |
| **Breadth** (stay native) | `opinion-lens` | native (`sonnet`/low) — never overridden | four persona takes, low-effort by design; escalating multiplies cost for no depth |

Mechanical/breadth roles are handled exactly the way `opinion-lens` already was
— given **no** model override, so they run at their shipped frontmatter tier.
Lever 1 just widens that existing treatment from one agent to a class. It never
*downgrades* an agent below its frontmatter; it only declines to *raise* it.

`coverage-check` shows the split cleanly: it dispatches **only** a read-only matrix build
(mechanical → native), and the gap-judgment it feeds runs in the **main thread** at the
session tier. So "coverage gets the boost" lands on the loop-until-dry sweep's reasoning,
never on the matrix builder — boosting a Read/Grep/Glob pass would buy nothing, the very
anti-pattern this ladder exists to prevent.

The converse also holds, and it applies **unboosted** as well: for a Reasoning-class
agent a `model:` pin is a **floor**, not a ceiling — dispatch it at
`max(marker tier if present ELSE the session model, its floor)` so a pinned judge is
never weaker than the session that wrote the code. The registry of which agents carry a
floor, and the full rule, live in `orchestration:delegation-contracts`
`references/role-floors.md` — the authoritative roster of which pins floor and which are
exempt; do not maintain a second copy of that list here. The boost's "declines to raise"
behavior above is unchanged; breadth/mechanical pins carry no floor by design.

Do not edit any agent's `model:`/`effort:` frontmatter to achieve this — the tier
is a dispatch-time override on the reasoning roles only; frontmatter ships as-is.

Outside the reachable set entirely: `system-design/agents/system-architect.md` and
`code-architecture/agents/architecture-reviewer.md` — the spec and card phases never
dispatch them; execution boosts architecture-reviewer separately via task-execution.

## Fan-out sizing — counts are ceilings

The recipe numbers (recon 3, red-team N=3, coverage cap 3) are **maxima for the
worst case**, not a quota to always fill. Pick the smallest N that covers the
blast radius; the mandatory phases still always run — sizing tunes N, never drops
a phase to zero.

The **Red-team panel** column below is not owned here: panel width is
`orchestration:verification-panels` § Panel width, and this table maps taskmaster's
radius rows onto it. Recon lenses and the coverage loop ARE owned here — they are
pipeline phases no other plugin runs. (Proportionality law: `claude-authoring/skills/authoring-skills/SKILL.md` "The four laws".)

| Blast radius | Recon lenses | Red-team panel | Coverage loop |
|---|---|---|---|
| **Small** — ≤2 files, isolated, low risk | 1 (inline scout) | 2 adversaries | 1 pass |
| **Medium** — the default shape | 2–3 | 3 adversaries | cap 2 rounds |
| **Large** — schema / auth / security / cross-cutting | 3 | 3 adversaries | cap 3 rounds |

How to read the radius: count the files the change plausibly touches and whether
it crosses a trust or data boundary (auth, money, PII, migrations, a public API).
Two-file copy tweak → Small. A new login method → Large. When genuinely unsure,
round up one row — the ceiling is the safe default, the point is only to stop
paying Large prices for Small asks.

This mirrors the three-cycle ceiling used elsewhere in the pipeline: bounded,
never an unbounded loop, but also never the maximum fan-out on a task that a
single scout and a two-voter panel would settle.

## Fan-out cost — `budget.remaining()` and the workflow-size guideline gate the ceilings

The counts above bound wall-clock (concurrency is capped) but not tokens. On the
`Workflow` path the harness exposes `budget.total` / `budget.spent()` /
`budget.remaining()` — the cost bound at the right unit, since agents are the wrong unit
(a cheap scout and an `xhigh` judge are not one price). Treat every recipe count as a
ceiling **and** a budget check: before opening a fan-out stage, if `budget.total` is set
and `budget.remaining()` cannot fund it, shrink the stage toward its inline fallback
rather than drop a mandatory phase — red-team and coverage still always run, at N=1 if
that is all the budget funds. `budget.total == null` means no token target, so the count
ceilings alone apply. The inline (non-`Workflow`) path exposes no budget handle; there the
counts are the only bound. This is D2's cost concern answered at the granularity that has
a real handle, not a total-agent cap that binds the wrong variable.

A second bound is the harness's, not ours: the session carries a **workflow-size
guideline** (default *medium* — keep one workflow under ~15 agents; the user can raise or
remove it). Where the counts above and that guideline disagree, the guideline wins, because
it is the user's standing preference and ours is a per-phase heuristic. Two rules keep the
two compatible:

- **Size per workflow invocation, not per run.** Each fan-out phase is its own `Workflow`
  call, so recon (≤3), spec-redteam (≤3) and a coverage round (≤3) never sum against one
  ceiling. The phase that actually collides is **card-verify** — "one fan-out pass per card"
  over a large index is a single wide stage. Batch it: verify cards in waves that respect
  the guideline rather than opening one agent per card in one call.
- **Shrink, never drop, and say so.** A stage that cannot fit shrinks toward its inline
  fallback (down to N=1); red-team and coverage still always run. `log()` the shrink and the
  deferred count — a silent truncation reads as full coverage, which is exactly the
  over-claim the honest-limitation law forbids. (`orchestration:verification-panels`
  `references/dispatch-tier.md` § Native harness interop owns this rule for all three boosts.)

## What does NOT change

- Red-team and coverage still run **ALWAYS** — Lever 2 sets their N, not whether
  they happen. An ultra run never ships without them.
- The resolved tier still lands on both the inline `Agent` path (model only) and
  the `Workflow` `agent()` path (model + effort) — for the reasoning roles.
- The `Ultra: true (model=…, effort=…)` marker still carries the boost tier into
  execution verbatim; workers there tier the same way (executor reasoning-tier,
  its scouts native).

## Per-stage bindings — grill

Moved out of `../../grill/SKILL.md` on 2026-08-20: it was the second half of a
632-character line, inert on every standard run, and the line-count ceiling could
not see it growing there.

Under `ULTRA-TASK ACTIVE` (see the `ultra` skill), dispatch context-scout NATIVE — a mechanical role, so no model override — with recon lenses sized to blast radius per that skill's `references/dispatch-tiers.md`, run extra question rounds, and make spec-redteam + coverage-check mandatory; opinion-lens stays native.

`opinion-lens stays native` is the load-bearing half: the personas are a blind
panel, and giving them a stronger model than the run's own would make the panel's
disagreement an artefact of tiering rather than of persona.

