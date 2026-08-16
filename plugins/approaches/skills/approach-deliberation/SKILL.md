---
name: approach-deliberation
description: Use before starting any non-trivial implementation, FIRST — multi-file changes, new capabilities, two-plus viable shapes: 2-3 structurally different approaches, trade-offs, a pick with kill-trigger surfaced for one-question approval. One deliberation per task — skips when opinion-round already ran. Picks the SHAPE; file-level planning is code-architecture:plan-before-code.
---

The failure mode this kills: first-idea anchoring. The first plausible approach
gets implemented, and its flaws surface mid-build as rework, fought-the-codebase
diffs, or a quiet restart. Three named candidates cost a few hundred tokens;
a wrong-path discovery at 70% implementation costs the whole branch.

## When to deliberate — and when not to

Deliberate when ANY of these holds:

- The change spans multiple files or introduces a new capability.
- Two or more shapes are genuinely viable (new module vs extend existing,
  sync vs async, migrate vs wrap).
- The territory is unfamiliar — new subsystem, new dependency, new domain.
- Getting it wrong is expensive to unwind (schema, public API, data shape).

Skip it — the first reasonable approach is correct — when:

- Bugfix with a located cause, mechanical rename/sweep, config tweak.
- One obvious continuation of an existing pattern (third handler in a file
  of handlers).
- `.claude/approaches/deliberated.json` exists and names this task. Read it FIRST —
  `{"task": "<short slug>", "by": "opinion-round|approach-deliberation", "at": "<ISO-8601>"}`
  — and on completion, write it. approach-deliberation is the user-initiated structural
  deliberation, opinion-round the description-routed blind persona round; each skips
  when the other already ran. That was prose on both sides with nothing recording that
  either HAD run, so a subagent, a compacted session, or a session resumed after a
  break re-litigated a decided shape. The marker is what makes the exclusion checkable
  rather than remembered. **Standing: agent-graded** — `pc_lanes_territory` proves the
  shared territory is declared and blessed; no gate proves this skill reads the file.
- A prior deliberation or spec already made this call; do not re-litigate.

## The protocol

1. Restate the goal in one sentence and the binding constraints (stack,
   compatibility floors, performance budgets) — read from the repo, never
   invented.
2. Generate 2–3 candidates that differ STRUCTURALLY. Each gets a name, the
   axis it optimizes, and a one-line file-level sketch. Three variants of one
   idea is one candidate wearing costumes — reject and diversify.
3. Build the trade-off table. Columns: effort, risk, reversibility, codebase
   fit, blast radius. Rows filled honestly — if the table only ever justifies
   the first idea, the table is theater.
4. Pick — and surface it, never self-approve it. One paragraph of reasoning
   that names what was given up, then one AskUserQuestion: "Proceed with
   <pick> (Recommended)" vs the strongest runner-up, one line of trade-off
   each. Proceed without asking only under CC_AUTOPROCEED=on or a hands-off
   goal run (ultra-goal / `Goal:` marker), recording the pick and options.
5. State the kill-trigger: the concrete mid-implementation discovery that
   would flip the choice ("if the API turns out not to support batch, switch
   to approach B"). A pick without a kill-trigger is a hope.
6. Hand the winner to plan-before-code (code-architecture) for the file-level
   plan.

## Axes menu

Force diversity by assigning each candidate a different axis:

- Simplest-possible: least code, fewest new concepts; accepts known limits.
- Incremental / tracer: thinnest end-to-end slice first, fatten later.
- Rework-minimizing: builds the structure the end-state needs from day one.
- Performance-first: optimizes the hot path at the cost of flexibility.
- Reversibility-first: cheapest to undo; feature flags, additive-only steps.

references/strategies.md maps named strategies (tracer bullet, spike,
strangler fig, inversion) to the dominant risk each one beats — read it
when a candidate needs a shape.

## Candidate quality bar

- Real: each candidate would actually ship if picked. A strawman built to
  lose corrupts the comparison and wastes the exercise.
- Sketched: one line naming the files/modules it creates or touches. An
  approach that cannot be sketched at file level is not yet an approach.
- Distinct: a reviewer could tell the resulting diffs apart at a glance.

## Kill-trigger discipline

Mid-implementation, when reality contradicts the pick's assumptions:

1. Stop at the contradiction — do not push through on sunk cost.
2. Re-run the comparison with the new fact; it usually takes three lines,
   because the table already exists.
3. Switching is cheap before the halfway mark and expensive after; the
   kill-trigger exists precisely to force the check early.
4. No new fact, just cold feet → keep going. Re-litigating a made decision
   without new information is its own anchoring failure.

## Handoffs

- Product shape unclear (what to build, for whom) → taskmaster brainstorm,
  not this skill. This skill starts after WHAT is settled.
- Requirements ambiguous → taskmaster grill first; deliberating over an
  ambiguous goal produces confident nonsense.
- Winner picked → plan-before-code for file-level planning, then implement.
- Pattern-level choice inside the winner (factory vs builder) → this plugin's
  own pattern-selection skill (`/approaches:pattern`).

## Worked micro-example

Task: add export-to-CSV for a large report.

- A "Stream it" (simplest): controller streams rows straight to the response.
  Sketch: one controller method. Limits: ties up a worker on huge exports.
- B "Queue it" (rework-minimizing): job writes to storage, user gets a link.
  Sketch: job class + notification + storage path.
- C "Paginate the API" (reversibility): client-side assembly via paged JSON.
  Sketch: API param + small frontend loop.

Pick: A — current maximum report is 20k rows, streams in under two seconds.
Kill-trigger: if product confirms the 500k-row tenant migrates in, switch to B.

## Anti-patterns

- Costume variants: three candidates that differ in naming, not structure.
- Trade-off theater: a table reverse-engineered from a pre-made choice.
- Deliberating the trivial: a typo fix does not get a candidate slate.
- Analysis loop: more than one round of comparison without new information —
  pick and move; the kill-trigger protects the downside.
- Silent switching: abandoning the picked approach mid-build without
  recording that the kill-trigger fired and what the new fact was.
