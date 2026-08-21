---
name: grill
description: Use when a task request is vague, large, or open to multiple interpretations — before any plan, spec, or code: batched clarifying-question rounds against an ambiguity ledger until every requirement is CLEAR or explicitly ASSUMED.
---

## The core rule

No plan, no spec, no implementation code while the ambiguity ledger holds an UNKNOWN
row or an unconfirmed ASSUMED row. Interrogation is the deliverable of this phase.
The cheapest bug is the one killed as a wrong assumption before a line existed.

Scale to blast radius: a one-file bugfix earns zero to two questions; a feature that
crosses module boundaries earns full rounds. Every question must be able to change
what gets built — if any answer leads to the same code, delete the question.

## Step 0 — scout before asking

Dispatch `context-scout` with the raw task description before asking the user anything. Fold its
report into the ledger, then derive an upgraded task statement from the raw prompt plus that report
per `references/prompt-upgrade.md` — sharpen the objective, name implied constraints, never
reinterpret scope. Boosted runs bind this step differently: `../ultra/references/dispatch-tiers.md`.

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
A volunteered starting point — expertise, how settled the thinking is, code
familiarity — becomes a ledger row; calibrate: an expert's silence is a
decision, a newcomer's silence is a gap.

## Persist and resume

After reprinting the ledger each round, also write it — a header carrying the raw +
upgraded statement pair plus the table — to `.claude/taskmaster/ledger-<slug>.md`
(gitignored; `<slug>` a kebab of the task description), so an interrupted
interrogation is not lost. At grill start, an unfinished
`.claude/taskmaster/ledger-*.md` offers Resume / Start fresh; Resume reuses the
stored statement (never re-derived), loads the table, continues from the first
UNKNOWN row — no re-scout, no re-asking resolved rows. Delete when the spec is written.

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
  choice as plain multiple-choice instead. Colour/theme IS the decision →
  `/ui-ux:theme`. Either way the options render on the local preview server —
  never stand one up with the built-in Artifact tool, which skips both skills.
- Data models — switch to the `erd` skill when the ledger touches persistent data (two-plus
  entities, any relation change); the approved model lands in the spec's Data Model section.
- "You decide" / "whatever you think": convert the row to ASSUMED with your named
  default and move on — but never silently. The user approves the assumption list
  at the end even if they delegated every call.
- Converge, don't loop: 2–4 rounds scaled to blast radius, broad then narrow. At the
  cap, or the first round that closes no new UNKNOWN, stop asking — convert remaining
  UNKNOWNs to ASSUMED with named defaults and route to Stopping (assumption list for veto). (Proportionality law: `claude-authoring/skills/authoring-skills/SKILL.md` "The four laws".)

## Big tasks: slice before grilling

When the task is a whole experience or crosses several subsystems (an
onboarding funnel, a multi-view feature), one flat ledger explodes by round 2:

- Round 1 becomes decomposition: propose the slices (screens, flows,
  capabilities) and confirm the slice list itself with the user first.
- The ledger gains a Slice column; grill slice by slice in priority order — depth-first beats breadth-first.
- Cross-slice contracts (data one screen collects that another consumes) get
  their own ledger rows — they are the rows a per-slice view would miss.
- Multi-screen slices: after their visual decisions land, run
  experience-walkthrough — accepted picks become a clickable demo, walked before the spec freezes.

## Stopping and handoff

Stop when every row is CLEAR, or ASSUMED with the user having seen and accepted the
assumption list, or the user says "enough". Then:

1. Decide the implementation approach when the settled requirements admit two or more
   structurally different implementations (new module vs extend, sync vs async, rewrite vs
   strangler) and the task is not mechanical. approaches plugin installed → run its opinion-round: dispatch the four blind `opinion-lens` personas
   (Standards Purist, Quality-over-Speed, Pragmatist-Minimalist, Skeptic-Investigator) per
   that skill's blind-dispatch contract, synthesize one pick + kill-trigger, then WRITE its
   marker `.claude/approaches/deliberated.json` (`{"task","by":"opinion-round","at"}`) —
   unwritten, the double-run guard is unarmed and `/approaches:opinions` re-litigates the
   settled pick. Absent → 2–3 inline and pick. Skip mechanical or single-approach tasks, or
   when an upstream brainstorm design already recorded the approach.
2. Write the spec to `taskmaster-docs/specs/YYYY-MM-DD-<slug>.md`: raw + upgraded statement pair,
   goal, decisions (CLEAR rows with sources), accepted assumptions, approach with rejected
   alternatives and kill-trigger, non-goals, success criteria, and the converged ledger embedded
   as `## Ambiguity ledger (final)`; run `${CLAUDE_PLUGIN_ROOT}/scripts/spec-ledger-lint.sh --spec <file>` (blocks
   UNKNOWN/missing/empty ledger) until exit 0. Staged visual/creative picks → invoke the
   `visual-contract` skill to bind them as `## Visual contract`.
3. Red-team the spec when its blast radius warrants — run the `spec-redteam` skill to
   attack the frozen spec for holes and resolve each before cards; trivial specs skip.
4. Invoke the `task-cards` skill from this plugin to split the spec into single-prompt task cards.

Do not skip the written spec even when the ledger is short — the spec is what makes
each task card self-contained later.

## Headless fallback

If `AskUserQuestion` is unavailable (subagent context, non-interactive run): print
the ledger, list numbered assumptions with your chosen defaults, mark them ASSUMED,
proceed on those defaults, and flag the assumption list prominently in the final
output so the user can veto any of them afterward.

## Anti-patterns

- Double-barreled questions ("should it paginate and cache?") — one topic each.
- Generic template questions detached from this task or this repo.
- Accepting a vague answer on a scope-critical row: respond with 2–3 concrete
  options or examples instead of repeating the question louder.
- Padding rounds to look thorough. The measure of a good interrogation is how much
  code it changed or prevented, not how many questions it asked.
