---
name: opinion-round
description: Use when a prompt asks to refactor, rewrite, restructure, migrate, rework, or redesign existing code — four BLIND parallel opinion personas argue the shape; the pick is surfaced for one-question approval (CC_AUTOPROCEED=on or a hands-off goal run proceeds without asking). One deliberation per task — skips when approach-deliberation already ran; requirements still ambiguous → taskmaster grill first.
---

The failure mode this kills: correlated opinions on rework-shaped tasks.
One model role-playing the personas produces variations of a single
view — every "persona" anchors on the same draft plan. Independence is
the point: four BLIND subagents, each given only its own brief, argue
once, cheaply, before the first file changes.

## The gate

Fire only when BOTH hold:

- The work spans multiple files.
- Two or more structurally different shapes are genuinely viable
  (rewrite vs strangler, migrate vs wrap, extract vs restructure in place).

Skip silently — no announcement, no stub round — when the change is
trivial, mechanical, or single-file: renames, lint sweeps, version
bumps, a located bugfix.

Requirements still ambiguous — no capability list, no success
criterion → taskmaster grill first when installed; deliberating an
ambiguous goal produces confident nonsense.

Manual invocation via `/approaches:opinions` bypasses the size gate —
the user asked, so argue even a small task — but never the two guards
below.

## Double-run guard

approach-deliberation already ran for this task, or a prior opinion
round did → skip. One deliberation per task; a second is re-litigation.
The manual command does not bypass this guard.

## Defer rule

The taskmaster pipeline is active on the same task — a grill ledger is
open, a brainstorm dialogue is running, or task cards are executing →
the round steps back. Taskmaster now runs its own blind
persona round (these four briefs) at its design and spec step; a second
round here would only re-litigate that settled one.

## The personas — fixed, non-configurable

Four voices, always the same four — two push for more work (Purist,
Quality), two restrain it (Pragmatist, Skeptic). No adding, swapping, or
renaming per task: each round covers the same four blind spots.

- **Standards Purist** — argues the idiomatic, ecosystem-convention
  approach: framework defaults, community patterns, boring technology.
  Treats every deviation from industry norms as a cost that must be
  justified, not a style preference.
- **Quality-over-Speed** — argues the durable approach: tests first, the
  deeper refactor over the patch, paying down adjacent debt while the
  files are open. Accepts slower delivery as the explicit price.
- **Pragmatist-Minimalist** — argues the smallest reversible change that
  solves the stated problem: fewest files, least new abstraction, ship
  and iterate. Treats every added layer or "while we're here" as cost
  that must earn its place. The counterweight to Quality-over-Speed —
  banks speed-to-signal and easy rollback, not durability.
- **Skeptic-Investigator** — questions the premise itself: is the
  rewrite needed, is the old code actually broken, what claims are
  unverified? Lists the unknowns and proposes a spike or investigation
  when the evidence for any plan is thin.

## Blind-dispatch contract

Spawn the `opinion-lens` agent four times in parallel — one persona
brief per dispatch, all four in a single message so they run
concurrently and blind to one another, so no shared prior survives
the blind. Each dispatch carries EXACTLY
three things:

1. The task description, verbatim from the user.
2. The repo path.
3. That persona's brief — and only that persona's.

Never include: a sibling's take, a main-thread draft plan, or the other
persona names. A dispatch that hints at what the others might say — or
at what the main thread already prefers — has broken the blind and
bought three copies of one opinion at triple the price.

Each take returns in a fixed shape:

- **`approach:`** — at most 5 lines, with a one-line file-level sketch.
- **`top risk:`** — the one thing most likely to sink this approach.
- **`would change my mind if:`** — the evidence that would flip this take.

No dissent field. A blind agent cannot dissent from takes it never saw;
disagreement is computed at synthesis, never reported by a persona.

When the orchestration plugin is installed, phrase the dispatches per
its delegation-contracts skill; otherwise the contract above suffices.

## Synthesis — inline, main thread

1. Build the convergence table, one row per persona:

   | Persona | Approach | Top risk | Verdict |
   |---------|----------|----------|---------|

   Verdict is one of: aligned / detail divergence / structural divergence.
2. Synthesize ONE pick — what was taken from whom, what was given up;
   approach-deliberation's output shape, so downstream handling is
   identical. With plan-before-code (code-architecture) installed the pick
   honors its scope lock — debt arguments never widen the change.
3. State the kill-trigger: the concrete mid-implementation discovery
   that would flip the pick. A pick without a kill-trigger is a hope.

One round is a hard cap — no re-dispatch, no tie-breaker agents, no
rebuttal pass. If reality contradicts the pick mid-build, that is the
kill-trigger firing; handle it as approach-deliberation prescribes.

If subagents are unavailable, skip the round entirely. There is no
inline fallback: role-playing the quartet in the main thread reintroduces
exactly the correlated-opinion failure this skill exists to kill.

## The proceed rule — the pick is surfaced, never self-approved

- **Broadly aligned / detail divergence** — synthesize the one pick
  (divergence recorded in the verdict), then one AskUserQuestion:
  "Proceed with <pick> (Recommended)" vs the strongest alternative.
- **Structural split** — the plans differ in file-level shape (different
  modules created, different migration topology) → AskUserQuestion with
  the competing plans as options, one line of trade-off each.

The bar for "structural": could a reviewer tell the resulting diffs
apart at a glance? Proceed without asking — recording the pick and
options — only under CC_AUTOPROCEED=on or a hands-off goal run
(ultra-goal / `Goal:` marker), which auto-takes the Recommended option.

## Companions

- The user explicitly ran `/approaches:compare` → defer entirely to
  approach-deliberation; running both on one task is a double deliberation.

## Anti-patterns

- **Standing voices**: personas that keep commenting as work proceeds.
  They exist for one round of dispatches, then they are gone.
- **Blocking on consensus**: waiting for three-way agreement before
  starting. Alignment on shape is enough; divergence is recorded, not
  resolved.
- **Re-running the round**: a second deliberation without a fired
  kill-trigger is anchoring in committee form.
- **Inline role-play fallback**: playing the four personas in the main
  thread when dispatch is unavailable or inconvenient. One model in
  four hats is one opinion; skip the round instead.
- **Leaking takes**: including one persona's take — or any main-thread
  leaning — in another persona's dispatch. The blind is the product.
