---
name: strategy-catalog
description: Use when choosing HOW to attack a task — a catalog of named implementation strategies (tracer bullet, walking skeleton, spike-then-rewrite, strangler fig, inversion, Polya loop, simplest-thing) each mapped to the dominant risk it beats, with failure modes and a selection table.
---

A strategy is a shape for the work, chosen by the dominant risk. Pick the risk
first, then the strategy that beats it. Every entry: when, how, and how it fails
when misapplied.

## Tracer bullet

- Beats: integration risk — the parts might not connect.
- How: build the thinnest end-to-end path through REAL layers (UI stub → API
  → DB → response) before widening any single layer. The bullet stays in the
  codebase and gets fattened, unlike a spike.
- Fails when: layers are already proven connected; then it is ceremony.

## Walking skeleton

- Beats: greenfield deployment risk — "works locally" projects that never ship.
- How: the smallest deployable system with CI/CD, config, and a health check,
  deployed to a real environment before feature one. Features hang off a
  skeleton that already walks.
- Fails when: bolted onto a mature system — it already has a skeleton.

## Spike, then rewrite

- Beats: unknown-tech risk — an API, library, or algorithm nobody has used.
- How: a time-boxed throwaway probe answering ONE question ("can the API do
  batch upserts?"). Then implement for real, informed. Iron rule: spike code
  dies; promoting a spike ships prototype quality as production.
- Fails when: the question was answerable by reading docs — spike laziness.

## Strangler fig

- Beats: legacy-replacement risk — big-bang rewrites that never land.
- How: new implementation grows around the old at a seam (router, facade,
  adapter); traffic moves route by route; old code dies only when unreferenced.
  Both run in parallel during migration, so each step is reversible.
- Fails when: the system is small enough to replace in one reviewable change —
  then the parallel period is pure overhead.

## Inversion

- Beats: unknown-unknowns in high-stakes changes.
- How: ask "what would guarantee this fails?" — list the failure routes
  (data loss path, silent corruption, unbounded queue, missing rollback),
  then design the approach so each route is blocked or detected.
- Fails when: it becomes doom brainstorming with no design consequence; every
  listed failure must map to a mitigation or an accepted risk.

## Polya loop

- Beats: stuck-ness on genuinely hard problems.
- How: four gates — understand (restate the problem, knowns/unknowns), plan
  (relate to a solved problem, simplify a variable), execute (one step at a
  time, checking each), look back (does the result satisfy the original
  statement, and what generalizes?). Skipping gate one causes most rework.
- Fails when: applied to routine work; the loop is for problems, not chores.

## Simplest thing that could work

- Beats: requirements uncertainty — when what users need is less settled than
  the tech.
- How: ship the crudest correct version, learn from real use, iterate. Accept
  known limits on purpose and write them down (they become the next iteration,
  not surprise debt).
- Fails when: the "simple" version bakes in an irreversible shape (schema,
  public API) — simplicity in reversible layers only.

## Top-down vs bottom-up

- Top-down (interfaces first): define the calling contract, stub the guts.
  Beats design risk — wrong module boundaries. Prefer when boundaries are the
  hard part.
- Bottom-up (primitives first): build and test the leaf utilities, compose
  upward. Beats correctness risk in tricky kernels (parsers, calculations).
  Prefer when the hard part is a core algorithm.
- Either fails alone on large work; alternate — sketch top-down, verify the
  riskiest primitive bottom-up, meet in the middle.

## Explain-first

- Beats: fuzzy-understanding risk — code written before the author can state
  what it must do.
- How: write the README section, docstring, or commit message BEFORE the
  implementation. Where the explanation stalls is exactly where understanding
  is missing.
- Fails when: it balloons into speculative documentation of unbuilt features.

## Selection table

| Dominant risk | Strategy |
|---|---|
| Parts might not connect | Tracer bullet |
| Might never deploy | Walking skeleton |
| Unknown tech/API | Spike, then rewrite |
| Legacy replacement stalls | Strangler fig |
| High stakes, unclear failure routes | Inversion |
| Genuinely hard, stuck | Polya loop |
| Requirements will shift | Simplest thing |
| Wrong boundaries | Top-down first |
| Tricky core algorithm | Bottom-up first |
| Can't state what it does | Explain-first |

Neighbors: red-green-refactor lives in the testing plugin (TDD workflow);
hypothesis-and-bisect debugging lives in the debugging plugin; deciding
BETWEEN candidate approaches is the approach-deliberation skill here — this
catalog supplies the shapes those candidates take.
