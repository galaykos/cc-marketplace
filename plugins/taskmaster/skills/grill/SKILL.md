---
name: grill
description: Use when a task request is vague, large, or open to more than one interpretation — before any plan, spec, or code. Runs batched clarifying-question rounds against an ambiguity ledger until every requirement is CLEAR or explicitly ASSUMED, grounding questions in codebase facts from the context-scout agent.
---

## The core rule

No plan, no spec, no implementation code while the ambiguity ledger holds an UNKNOWN
row or an unconfirmed ASSUMED row. Interrogation is the deliverable of this phase.
The cheapest bug is the one killed as a wrong assumption before a line existed.

Scale to blast radius: a one-file bugfix earns zero to two questions; a feature that
crosses module boundaries earns full rounds. Every question must be able to change
what gets built — if any answer leads to the same code, delete the question.

## Step 0 — scout before asking

Dispatch the `context-scout` agent with the raw task description before asking the
user anything. Fold its report into the ledger:

- "Already answered by code" entries become CLEAR rows with evidence. Never ask the
  user something the codebase answers — it burns trust and attention.
- "Only the user can answer" entries seed the first question round.
- Hard constraints (versions, configs, CI gates) become CLEAR rows that bound the
  option sets you offer.

## The ambiguity ledger

Maintain one table for the whole interrogation and reprint it, updated, after every
round so the user always sees what is settled and what still blocks:

| # | Item | Current understanding | Status | Source |
|---|------|----------------------|--------|--------|
| 1 | Auth method | Session-based, reuse existing middleware | CLEAR | config/auth.php:14 |
| 2 | Who can delete | Assumed: owner only | ASSUMED | default, round 2 |
| 3 | Bulk-action UX | ? | UNKNOWN | — |

Statuses: **CLEAR** (user said it, or code proves it), **ASSUMED** (a default was
chosen and named, awaiting confirmation), **UNKNOWN** (blocks implementation).

## Question dimensions

Walk these ten dimensions; skip any the scout or the prompt already settled:

1. Outcome — what changes for whom when this ships; the one-sentence "done" story.
2. Scope in — the concrete capabilities included.
3. Scope out / non-goals — what is explicitly NOT being built this round.
4. Actors — user roles, permissions, external systems that touch the feature.
5. Inputs and outputs — data shapes at every boundary, with real examples.
6. Constraints — stack, versions, performance budgets, compatibility floors.
7. Edge cases and failure behavior — empty states, conflicts, retries, limits.
8. Success criteria — the checks (tests, commands, observations) that prove "done".
9. Integration points — what existing code this must call, extend, or not break.
10. Priority and sequencing — what must land first, what can trail.

## Question mechanics

- Batch through `AskUserQuestion`: up to 4 questions per round, each single-topic.
  Multiple-choice beats open-ended — options are answers the user only has to
  recognize, not compose. Put your recommended option first, labeled
  "(Recommended)", and use `multiSelect` when choices are not mutually exclusive.
- Offer concrete options, never "flexible/it depends" filler. Wrong-but-concrete
  options provoke corrections; vague options provoke shrugs.
- Example-driven disambiguation: when words stay ambiguous, fabricate 2–3 concrete
  input → output examples ("user submits X, sees Y / sees Z — which?") and ask
  which is correct. One picked example beats three paragraphs of requirements.
- Visual decisions — switch to the `visual-decisions` skill from this plugin when
  the user must pick between options that look or flow differently (layout variants,
  component placement, user flows, architecture topology, data shapes); not for
  text-native tradeoffs, even on UI tasks. Use context-scout's Visual surface
  section as the prior. The skill asks its own fidelity consent on first use —
  never build a mockup before that gate; on a "no mockups" answer, present the
  choice as plain multiple-choice instead.
- "You decide" / "whatever you think": convert the row to ASSUMED with your named
  default and move on — but never silently. The user approves the assumption list
  at the end even if they delegated every call.
- Typical interrogations run 2–4 rounds. Round 1 is broad (outcome, scope, actors);
  later rounds go narrow (edge cases, examples, sequencing) using earlier answers.

## Big tasks: slice before grilling

When the task is a whole experience or crosses several subsystems (a full
landing-page experience, onboarding funnel, multi-view feature), do not run one
flat ledger — it explodes past readability by round 2:

- Round 1 becomes decomposition: propose the slices (screens, flows,
  capabilities) and confirm the slice list itself with the user first.
- The ledger gains a Slice column; grill slice by slice in priority order —
  depth-first beats breadth-first, a half-grilled everything helps no one.
- Cross-slice contracts (data one screen collects that another consumes) get
  their own ledger rows — they are the rows a per-slice view would miss.
- For multi-screen slices, run the experience-walkthrough skill after their
  visual decisions land: assemble accepted picks into a clickable demo and
  walk it before freezing the spec.

## Stopping and handoff

Stop when every row is CLEAR, or ASSUMED with the user having seen and accepted the
assumption list, or the user says "enough". Then:

1. Write the spec to `taskmaster-docs/specs/YYYY-MM-DD-<slug>.md`: goal, decisions (from CLEAR
   rows with sources), accepted assumptions, non-goals, success criteria.
2. Invoke the `task-cards` skill from this plugin to split the spec into
   single-prompt task cards.

Do not skip the written spec even when the ledger is short — the spec is what makes
each task card self-contained later.

## Headless fallback

If `AskUserQuestion` is unavailable (subagent context, non-interactive run): print
the ledger, list numbered assumptions with your chosen defaults, mark them ASSUMED,
proceed on those defaults, and flag the assumption list prominently in the final
output so the user can veto any of them afterward.

## Anti-patterns

- Asking what the codebase already answers — that is what the scout is for.
- Double-barreled questions ("should it paginate and cache?") — one topic each.
- Generic template questions detached from this task or this repo.
- Re-asking anything already CLEAR — the ledger exists so you never re-litigate.
- Accepting a vague answer on a scope-critical row: respond with 2–3 concrete
  options or examples instead of repeating the question louder.
- Interrogating trivial tasks — a typo fix does not get a questionnaire.
- Padding rounds to look thorough. The measure of a good interrogation is how much
  code it changed or prevented, not how many questions it asked.
