---
name: approach-deliberation
description: Use before starting any non-trivial implementation, FIRST — multi-file changes, new capabilities, a refactor/rewrite/restructure/migrate/rework request, two-plus viable shapes: 2-3 structurally different approaches (or four blind persona takes on rework-shaped work), trade-offs, a pick with kill-trigger surfaced for one-question approval. One deliberation per task. Picks the SHAPE; file-level planning is code-architecture:plan-before-code.
---

Two failure modes, one decision. **First-idea anchoring:** the first plausible
approach gets implemented and its flaws surface mid-build as rework or a quiet
restart. **Correlated opinions:** on rework-shaped tasks, one model role-playing
alternatives produces variations of a single view — every "option" anchors on the
same draft. Candidates cost a few hundred tokens; a wrong-path discovery at 70%
implementation costs the whole branch.

## When to deliberate — and when not to

Deliberate when ANY of these holds:

- The change spans multiple files or introduces a new capability.
- Two or more shapes are genuinely viable (new module vs extend existing, sync vs
  async, rewrite vs strangler, migrate vs wrap, extract vs restructure in place).
- The territory is unfamiliar — new subsystem, new dependency, new domain.
- Getting it wrong is expensive to unwind (schema, public API, data shape).

Skip it — the first reasonable approach is correct — when:

- Bugfix with a located cause, mechanical rename/sweep, config tweak, lint
  sweep, version bump, single-file change.
- One obvious continuation of an existing pattern (third handler in a file of
  handlers).
- A prior deliberation or spec already made this call; do not re-litigate.

Manual invocation via `/approaches:compare` or `/approaches:opinions` bypasses the
size gate — the user asked, so deliberate even a small task — but never the two
guards below. Requirements still ambiguous (no capability list, no success
criterion) → taskmaster grill first when installed; deliberating an ambiguous goal
produces confident nonsense.

## Double-run guard

One deliberation per task; a second is re-litigation, and the manual commands do
not bypass it. Check the MARKER, never memory — `.claude/approaches/deliberated.json`
(`{"task": "<short slug>", "by": "approach-deliberation", "at": "<ISO-8601>"}`):
read it FIRST, skip if it names this task, write it on completion. This was prose
with nothing recording that a deliberation HAD run, so a subagent, a compacted
session, or a session resumed after a break re-litigated a decided shape. The
marker is what makes the exclusion checkable rather than remembered. **Standing:
agent-graded** — `pc_lanes_territory` proves the territory is declared; no gate
proves this skill reads the file.

## Defer rule

The taskmaster pipeline is active on the same task — a grill ledger is open, a
brainstorm dialogue is running, or task cards are executing → step back, UNLESS
taskmaster itself dispatched this: grill and brainstorm run the panel at their
design/spec step and a ledger is open at that moment, so reading the ledger as a
stop signal there would cancel the round taskmaster just asked for.

## Pick the mechanism — slate or panel

Same protocol, same output, two ways of generating the candidates:

- **Inline slate (default).** You write 2–3 structurally different candidates
  yourself. Right for greenfield work, a new capability, or any task where the
  shapes are already legible.
- **Blind panel.** Four `opinion-lens` subagents argue in parallel, each blind to
  the others. Right when the prompt asks to refactor, rewrite, restructure,
  migrate, rework, or redesign EXISTING code — there the correlated-opinion
  failure bites hardest, because a draft plan already exists to anchor on.
  Mechanism, personas, and dispatch contract: `references/blind-panel.md`.
  Subagents unavailable → run the slate; there is no inline role-play of the
  panel, and the reference says why.

## The protocol

1. Restate the goal in one sentence and the binding constraints (stack,
   compatibility floors, performance budgets) — read from the repo, never
   invented.
2. Generate the candidates — slate or panel per above. Each gets a name, the axis
   it optimizes, and a one-line file-level sketch. Three variants of one idea is
   one candidate wearing costumes: reject and diversify.
3. Build the trade-off table. Columns: effort, risk, reversibility, codebase fit,
   blast radius. Rows filled honestly — if the table only ever justifies the first
   idea, the table is theater.
4. Pick — and surface it, never self-approve it. One paragraph of reasoning naming
   what was given up, then one AskUserQuestion: "Proceed with <pick>
   (Recommended)" vs the strongest runner-up, one line of trade-off each. When the
   candidates differ in file-level SHAPE (different modules created, different
   migration topology), offer the competing plans as the options instead. Proceed
   without asking only under CC_AUTOPROCEED=on or a hands-off goal run
   (ultra-goal / `Goal:` marker), recording the pick and the options.
5. State the kill-trigger: the concrete mid-implementation discovery that would
   flip the choice ("if the API turns out not to support batch, switch to
   approach B"). A pick without a kill-trigger is a hope.
6. Hand the winner to plan-before-code (code-architecture) for the file-level plan.

## Candidate quality bar

- Real: each candidate would actually ship if picked. A strawman built to lose
  corrupts the comparison and wastes the exercise.
- Sketched: one line naming the files/modules it creates or touches. An approach
  that cannot be sketched at file level is not yet an approach.
- Distinct: a reviewer could tell the resulting diffs apart at a glance. That is
  also the bar for calling a divergence "structural" in step 4.

## Axes menu

Force diversity by assigning each candidate a different axis: simplest-possible
(least code, accepts known limits) · incremental/tracer (thinnest end-to-end slice
first) · rework-minimizing (builds the end-state structure now) · performance-first
(hot path over flexibility) · reversibility-first (feature flags, additive-only).
`references/strategies.md` maps named strategies — tracer bullet, spike, strangler
fig, inversion — to the dominant risk each beats.

A slate, end to end. Task: add export-to-CSV for a large report.

- A "Stream it" (simplest): controller streams rows straight to the response.
  Sketch: one controller method. Limits: ties up a worker on huge exports.
- B "Queue it" (rework-minimizing): job writes to storage, user gets a link.
  Sketch: job class + notification + storage path.
- C "Paginate the API" (reversibility): client-side assembly via paged JSON.
  Sketch: API param + small frontend loop.

Pick: A — current maximum report is 20k rows, streams in under two seconds.
Kill-trigger: if product confirms the 500k-row tenant migrates in, switch to B.

Three variants of one idea would be one candidate wearing costumes; these differ in
which risk they accept.

## Kill-trigger discipline

Mid-implementation, when reality contradicts the pick's assumptions:

1. Stop at the contradiction — do not push through on sunk cost.
2. Re-run the comparison with the new fact; it usually takes three lines, because
   the table already exists.
3. Switching is cheap before the halfway mark and expensive after; the
   kill-trigger exists precisely to force the check early.
4. No new fact, just cold feet → keep going. Re-litigating a made decision without
   new information is its own anchoring failure.

## Handoffs

- Product shape unclear (what to build, for whom) → taskmaster brainstorm. This
  skill starts after WHAT is settled.
- Winner picked → plan-before-code for file-level planning, then implement.
- Pattern-level choice inside the winner (factory vs builder) → this plugin's
  pattern-selection skill (`/approaches:pattern`).

## Anti-patterns

- **Costume variants**: candidates that differ in naming, not structure.
- **Trade-off theater**: a table reverse-engineered from a pre-made choice.
- **Deliberating the trivial**: a typo fix does not get a candidate slate.
- **Analysis loop**: more than one round without new information — pick and move;
  the kill-trigger protects the downside. A second panel is anchoring in
  committee form.
- **Standing voices**: personas that keep commenting as work proceeds. They exist
  for one round of dispatches, then they are gone.
- **Blocking on consensus**: waiting for agreement before starting. Alignment on
  shape is enough; divergence is recorded, not resolved.
- **Silent switching**: abandoning the pick mid-build without recording that the
  kill-trigger fired and what the new fact was.
