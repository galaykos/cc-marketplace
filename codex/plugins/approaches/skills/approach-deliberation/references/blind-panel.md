# The blind panel — four personas, one round

Read this when the deliberation runs as a BLIND PANEL rather than an inline
candidate slate. The SKILL body decides which; this file is the mechanism.

Merged here on 2026-08-21 from the former `opinion-round` skill. <!-- removed-ok --> Its own
`lane.tsv` already declared the two as one territory — "both decide the SHAPE of
a change and both say 'skip if the other already ran'" — and both ended in the
same output shape, the same marker, the same proceed rule, and the same
kill-trigger. Two skills, one decision, two copies of the bookkeeping.

## The personas — fixed, non-configurable

Four voices, always the same four — two push for more work (Purist, Quality), two
restrain it (Pragmatist, Skeptic). No adding, swapping, or renaming per task:
each round covers the same four blind spots.

- **Standards Purist** — argues the idiomatic, ecosystem-convention approach:
  framework defaults, community patterns, boring technology. Treats every
  deviation from industry norms as a cost that must be justified, not a style
  preference.
- **Quality-over-Speed** — argues the durable approach: tests first, the deeper
  refactor over the patch, paying down adjacent debt while the files are open.
  Accepts slower delivery as the explicit price.
- **Pragmatist-Minimalist** — argues the smallest reversible change that solves
  the stated problem: fewest files, least new abstraction, ship and iterate.
  Treats every added layer or "while we're here" as cost that must earn its
  place. The counterweight to Quality-over-Speed — banks speed-to-signal and easy
  rollback, not durability.
- **Skeptic-Investigator** — questions the premise itself: is the rewrite needed,
  is the old code actually broken, what claims are unverified? Lists the unknowns
  and proposes a spike or investigation when the evidence for any plan is thin.

## Blind-dispatch contract

Spawn the `opinion-lens` agent four times in parallel — one persona brief per
dispatch, all four in a single message so they run concurrently and blind to one
another, so no shared prior survives the blind. Each dispatch carries EXACTLY
three things:

1. The task description, verbatim from the user.
2. The repo path.
3. That persona's brief — and only that persona's.

Never include: a sibling's take, a main-thread draft plan, or the other persona
names. A dispatch that hints at what the others might say — or at what the main
thread already prefers — has broken the blind and bought three copies of one
opinion at triple the price.

Each take returns in a fixed shape:

- **`approach:`** — at most 5 lines, with a one-line file-level sketch.
- **`top risk:`** — the one thing most likely to sink this approach.
- **`would change my mind if:`** — the evidence that would flip this take.

No dissent field. A blind agent cannot dissent from takes it never saw;
disagreement is computed at synthesis, never reported by a persona.

When the orchestration plugin is installed, phrase the dispatches per its
delegation-contracts skill; otherwise the contract above suffices.

## Synthesis — inline, main thread

1. Build the convergence table, one row per persona:

   | Persona | Approach | Top risk | Verdict |
   |---------|----------|----------|---------|

   Verdict is one of: aligned / detail divergence / structural divergence.
2. Synthesize ONE pick — what was taken from whom, what was given up. Same output
   shape as the inline slate, so downstream handling is identical. With
   plan-before-code (code-architecture) installed the pick honors its scope lock —
   debt arguments never widen the change.
3. Then the body's proceed rule and kill-trigger apply unchanged. A **structural
   split** — plans differing in file-level shape, different modules created,
   different migration topology — is surfaced as competing options rather than
   resolved by the synthesizer.

One round is a hard cap — no re-dispatch, no tie-breaker agents, no rebuttal pass.

## No inline fallback — the rule that makes this a mechanism and not a style

If subagents are unavailable, **skip the panel entirely and run the inline slate
instead**. Role-playing the quartet in the main thread reintroduces exactly the
correlated-opinion failure the panel exists to kill: one model in four hats is one
opinion, bought four times.
