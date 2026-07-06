---
name: second-opinions
description: Use when a prompt asks to refactor, rewrite, migrate, redesign, restructure, overhaul, or modernize existing code — a fixed trio of opinion personas (Standards Purist, Quality-over-Speed, Skeptic-Investigator) argue the approach inline, converge to one pick with a kill-trigger in a single round, and work proceeds automatically unless the personas split on the structural shape of the plan.
---

The failure mode this kills: one-perspective planning on rework-shaped tasks.
A refactor or migration planned from a single viewpoint inherits that
viewpoint's blind spot — the idiomatic path that ignores debt, the thorough
path that gold-plates, the fast path built on an unverified premise. Three
fixed personas argue once, cheaply, before the first file changes.

## The gate

Fire only when BOTH hold:

- The work spans multiple files.
- Two or more structurally different shapes are genuinely viable
  (rewrite vs strangler, migrate vs wrap, extract vs restructure in place).

Skip silently — no announcement, no stub round — when:

- The change is trivial, mechanical, or single-file: renames, lint sweeps,
  version bumps, a located bugfix.
- approach-deliberation already ran for this task, or a prior opinion round
  did. One deliberation per task; a second is re-litigation.

Manual invocation via `/approaches:opinions` bypasses the size gate — the
user asked, so argue even a small task — but never the double-run guard.

## The personas — fixed, non-configurable

Three voices, always the same three. No adding, swapping, or renaming them
per task: the value is that each round covers the same three blind spots.

- **Standards Purist** — argues the idiomatic, ecosystem-convention
  approach: framework defaults, community patterns, boring technology.
  Treats every deviation from industry norms as a cost that must be
  justified, not a style preference.
- **Quality-over-Speed** — argues the durable approach: tests first,
  the deeper refactor over the patch, paying down adjacent debt while the
  files are open. Accepts slower delivery as the explicit price.
- **Skeptic-Investigator** — questions the premise itself: is the rewrite
  needed, is the old code actually broken, what claims are unverified?
  Lists the unknowns and proposes a spike or investigation when the
  evidence for any plan is thin.

## The protocol

Inline, in the main thread, single pass. Never spawn subagents for this —
three short takes do not justify dispatch overhead, and subagent panels are
orchestration/verification-panels territory.

1. Each persona speaks in at most 5 lines: its approach (with a one-line
   file-level sketch), its top risk, and where it dissents from the other
   two. A persona with nothing distinct to say says "concur" in one line.
2. Build the convergence table — one row per persona:

   | Persona | Approach | Top risk | Verdict |
   |---------|----------|----------|---------|

   Verdict is one of: aligned / detail dissent / structural dissent.
3. Synthesize ONE pick: a short paragraph naming what was taken from whom
   and what was given up — the same output shape approach-deliberation
   produces, so downstream handling is identical.
4. State the kill-trigger: the concrete mid-implementation discovery that
   would flip the pick. A pick without a kill-trigger is a hope.

One round is a hard cap. The personas do not rebut the synthesis, do not
get a second pass, and are not reconvened later in the task. If reality
contradicts the pick mid-build, that is the kill-trigger firing — handle
it as approach-deliberation prescribes, not by re-running the round.

## The proceed rule

- **Broadly aligned** — same file-level shape, different emphasis →
  proceed with the pick immediately. Do not ask permission to start.
- **Structural split** — the plans differ in file-level shape (different
  modules created, different migration topology), not in detail →
  AskUserQuestion with the competing plans as options, one line of
  trade-off each. This is the ONLY case that interrupts the user.
- **Detail-level dissent** — same shape, disagreement on ordering, test
  depth, naming → record the dissent in the verdict block and proceed.

The bar for "structural" is the deliberation bar: could a reviewer tell
the resulting diffs apart at a glance? If not, it is detail. Default to
proceeding; the interrupt exists for forked roads, not for taste.

## Companions

- decision-records plugin installed → offer `/decision-records:new` for
  the pick, once, after the verdict block. Not installed → skip silently;
  never suggest installing it mid-task.
- The user explicitly ran `/approaches:compare` → defer entirely to
  approach-deliberation. That skill owns the full candidate-slate
  treatment; running both on one task is a double deliberation.

## Worked micro-example

Prompt: "modernize the legacy payments module".

- Purist: incremental port to the framework's payment abstractions,
  module by module. Risk: long coexistence of old and new. Dissents from
  a big-bang rewrite.
- Quality: characterization tests over the legacy module first, then
  refactor behind them. Risk: test-writing eats the budget. Dissents on
  starting any port untested.
- Skeptic: "modernize" is unverified — which parts actually hurt? Spike:
  profile call sites for a day, then scope. Risk: a day spent confirming
  the obvious. Dissents on committing to full scope now.

Verdicts: aligned on shape (incremental, behind tests), detail dissent on
sequencing. Pick: Skeptic's one-day scoping spike, then Quality's
characterization tests, then Purist's incremental port of the two hot
submodules only. Kill-trigger: if the spike shows the pain is isolated to
one adapter, drop the port and patch the adapter. Proceed — no question
asked, dissent recorded.

## Anti-patterns

- **Standing advisory voices**: personas that keep commenting as the work
  proceeds. They exist for one round, then they are gone.
- **Blocking on consensus**: waiting for three-way agreement before
  starting. Alignment on shape is enough; dissent is recorded, not
  resolved.
- **Re-running the round**: a second deliberation without a fired
  kill-trigger is anchoring in committee form.
- **Subagent panels**: spawning agents to play the personas. This skill
  is inline by design; adversarial agent panels belong to
  orchestration/verification-panels.
- **Persona drift**: inventing a fourth voice or retuning the trio to fit
  the task. Fixed personas are the coverage guarantee.
