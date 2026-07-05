---
name: decision-records
description: Use when a significant technical decision lands — an approach pick, schema or API shape, dependency adoption, pattern choice — to persist it as an Architecture Decision Record in taskmaster-docs/adr/ before the reasoning evaporates from the conversation.
---

Decisions made in conversation die with the transcript. Six months later the
code shows WHAT was built; nobody remembers why alternative B lost, so it gets
re-proposed, re-litigated, or worse — half-implemented over the winner. An ADR
is one page that keeps the reasoning alive next to the code.

## What earns an ADR

- An approach-deliberation pick (approaches plugin) — the table and
  kill-trigger are already written; persisting them is two minutes.
- Schema shapes, public API contracts, wire formats — expensive to unwind.
- Dependency adoptions and build-vs-buy verdicts.
- Pattern or topology choices: sync vs async, monolith split, caching layer.
- Anything a future maintainer would ask "why on earth is it like this?"

What does not: reversible one-file choices, naming, formatting, anything a
later refactor can undo in an afternoon. An ADR log full of trivia buries the
decisions that matter.

## Template

    # NNN — <decision title, imperative>

    Status: proposed | accepted | superseded by MMM
    Date: YYYY-MM-DD

    ## Context
    <the forces: constraints, requirements, and facts that made this a
    decision at all — two to five sentences>

    ## Options considered
    - <A>: <one line> — rejected because <reason>
    - <B>: <one line> — rejected because <reason>
    - <C — chosen>: <one line>

    ## Decision
    <what was decided, stated as a present-tense fact>

    ## Consequences
    - Good: <what this buys>
    - Bad: <what this costs or forecloses — every real decision has a cost>

    ## Revisit when
    <the concrete trigger that should reopen this decision — the
    kill-trigger from approach deliberation lands here>

## Rules

- Location `taskmaster-docs/adr/`, filename `NNN-kebab-slug.md`, NNN sequential from 001.
- One decision per record. A record needing "and" in its title is two records.
- Losers get honest one-liners. "Rejected because inferior" preserves nothing;
  "rejected because it doubles deploy complexity for 5% gain" prevents the
  re-proposal.
- Consequences must include at least one Bad. A decision with no downside
  recorded was not examined, only ratified.
- ADRs are immutable history: to change course, write a new ADR and mark the
  old one `superseded by NNN`. Never edit a superseded record's reasoning —
  the wrong-turn trail is half the value.
- Link the ADR from the PR description or spec that implements it.

## When it fires

- approach-deliberation completes a pick → offer to persist it; the options
  table, reasoning paragraph, and kill-trigger map one-to-one onto the
  template.
- grill (taskmaster) closes a ledger row with architectural weight → same
  offer.
- A conversation contains "let's go with", "we decided", "instead of" about
  anything on the earns-an-ADR list → suggest capturing before moving on.
- Never write one silently: propose, show the draft, let the user amend.

## Reading discipline

Before proposing a decision in an area, check `taskmaster-docs/adr/` for standing
records:

- An accepted ADR answers the question → follow it, do not re-litigate.
- Reality now contradicts its context (its revisit-when fired) → say so
  explicitly and draft the superseding record; contradiction is the one
  legitimate reopening.
- Ignoring a standing ADR because it is inconvenient is how codebases grow
  two competing conventions.

## Worked micro-example

    # 007 — Store report exports on disk, not in the database

    Status: accepted
    Date: 2026-07-05

    ## Context
    Exports reach 200MB; the DB backup window is already tight and blobs
    would double it. Retention policy is 30 days.

    ## Options considered
    - DB blob column: rejected — doubles backup size for transient data
    - S3: rejected — no cloud dependency allowed in this deployment (ADR 003)
    - Local disk + cron cleanup (chosen)

    ## Decision
    Exports are written to storage/exports/, cleaned by a daily job.

    ## Consequences
    - Good: backups unaffected; cleanup is one cron line
    - Bad: exports do not survive host migration; multi-host needs rework

    ## Revisit when
    Deployment goes multi-host, or the cloud-dependency rule (ADR 003) falls.

Sixteen lines. The Bad consequence and revisit-when are what make it worth
having: the multi-host migration will find this record before it finds the bug.

## Anti-patterns

- ADR theater: recording trivia to look rigorous, burying real decisions.
- Retroactive fiction: writing the record to justify what was already built
  rather than what was actually weighed at the time.
- Editing superseded records to look prescient.
- Orphan records: an ADR nothing links to and no code implements.
- Skipping the Bad consequence — the reader most needs the cost you paid.
