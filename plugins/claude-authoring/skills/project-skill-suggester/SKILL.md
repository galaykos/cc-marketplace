---
name: project-skill-suggester
description: Use after a task is split into cards, when three-plus cards share the same uncaptured repo-specific knowledge (house convention, internal API/helper, subsystem rules) — propose capturing it as a project skill or agent; shape via routine-detector.
---

## What this skill does

It reads a freshly split set of task cards and, when many of them lean on the
same piece of repository-specific knowledge that no skill yet captures, offers
to turn that knowledge into a durable project skill (or agent) — so every later
task that touches the same ground starts from a loaded skill instead of a
re-explanation.

It is the proactive, single-task sibling of routine-detector. routine-detector
waits for a routine to recur three times across separate requests; this skill
reads the repetition already present inside one task's card set. It never
blocks work, never scaffolds on its own, and never nags.

## Where it fires in the pipeline

After task-cards writes `00-INDEX.md`, and before the task-runner handoff. The
card set is the evidence, so the check runs once the cards exist and is silent
unless it finds a candidate. It complements — never replaces — routine-detector
(repetition over time) and hindsight (cross-session mining); those stay the home
for post-hoc capture. This skill only inspects the task in front of it.

## Detection: cross-card repetition

A candidate is a cluster of **three or more cards** bound by the same
repository-specific subject. A card joins a cluster when it shows any of:

- **Shared subsystem path** — its Context files sit under the same module or
  directory as the others (`app/Billing/…`, `src/sync/…`).
- **Repeated house convention** — its instructions restate the same local rule
  the others do ("commands live in `app/Console`, one handle() method").
- **Repeated internal API or helper** — the same in-house client, service, or
  utility is described from memory in several cards.

Then apply the **durability filter**: the shared knowledge must be reusable
beyond this task — a convention, an internal-API usage pattern, a subsystem's
invariants — not one-off detail of the current work. Two cards, or three cards
that merely happen to touch nearby files without shared reusable knowledge, are
not a cluster. When in doubt, it is not a candidate.

## The coverage check

Before offering anything, confirm nothing already captures the knowledge:

- Name the installed plugin skills that plausibly cover it (sql, testing,
  a11y, the stack's ui-ux skill, and so on).
- Read any project skills already present under `.claude/skills/*/SKILL.md`.

If an existing skill covers the subject, stay silent — surfacing the right
existing skill at the right moment is skill-router's job, not this skill's.
Only genuinely uncovered knowledge is worth a new artifact.

## Protocol: after the cards, then propose

The offer never blocks or delays the cards, which are already complete. Sequence
is fixed:

1. The card set is written and the pipeline is ready to hand off.
2. Run the detection and coverage check above. No candidate → stay silent and
   let the handoff proceed.
3. One candidate → offer it as a selectable choice (AskUserQuestion): "Scaffold
   a project skill for `<subject>` now (Recommended)" / "Skip — leave it
   manual". Bare scaffold command only when headless.
4. On yes, hand the scaffold command a concrete draft: a kebab-case name and a
   one-line "Use when…" purpose synthesized from the cluster, so
   `/claude-authoring:new-skill` (or `new-agent`) starts from a draft, not an
   empty prompt.

Never scaffold without the yes. At most one candidate is surfaced per run.

## Artifact selection

Do not reinvent the choice of artifact — defer to routine-detector's shape
table (repeatable knowledge → project skill; delegated persona with its own
tools → agent; invoked-by-name action → command; always-run guarantee → hook).
For this skill the common outcomes are a **project skill** (a house convention
or subsystem's rules) and, when the repeated need is a multi-step read-only
investigation, an **agent**. Scaffold via `/claude-authoring:new-skill` and
`/claude-authoring:new-agent`; for format rules defer to the sibling
authoring-skills and authoring-agents skills.

## Suggestion etiquette

Identical to routine-detector's, and binding here too:

- **One suggestion per run.** Once offered, the same subject is not raised again
  this session, whatever the answer.
- **A declined suggestion is decided.** A no, in any phrasing, takes that
  subject off the table — do not re-pitch it later with a new angle.
- **Never scaffold without a yes.** No "I went ahead and created…". The artifact
  appears only after explicit agreement.
- **Keep the pitch small.** Name the subject, the cluster that evidences it, and
  the payoff in a few lines — not a paragraph of justification.

## Worked example

A task splits into seven cards; four of them (`03`, `05`, `06`, `08`) each
re-describe the project's in-house `LedgerClient` — how to open a unit of work,
the required idempotency key, the commit/rollback contract — and none of the
cards' "Skills to apply" names a covering skill. That is a four-card cluster of
durable, uncovered knowledge. After the index is written, offer:

> **Cluster:** cards 03, 05, 06, 08 each restate `LedgerClient` usage
> (unit-of-work, idempotency key, commit contract) — no skill covers it.
> **Payoff:** a `ledger-client` project skill loads that contract on every
> future ledger task instead of it being re-derived per card.
> **Scaffold:** "Scaffold the `ledger-client` skill now (Recommended)" / "Skip".

On yes, hand `/claude-authoring:new-skill` the name `ledger-client` and a
one-line purpose drawn from the cluster. On no, drop it for good.

## Anti-patterns

- **Firing on fewer than three cards.** Two cards sharing a file is a
  coincidence, not a routine worth a durable skill.
- **Suggesting already-covered knowledge.** If a plugin or project skill covers
  it, this is noise — that is skill-router's routing job, not a new artifact.
- **Capturing one-off task detail.** Knowledge that only matters for this task,
  not future ones, fails the durability filter. Let it go.
- **Scaffolding unprompted.** Files the user did not agree to are scope creep.
- **Re-pitching a declined subject.** The no was the answer.
- **Blocking the handoff.** The cards are done; the offer is a tail, never a gate.
