---
name: retrospective
description: Use after a milestone, task run, or feature lands — or when a session ends with lessons visibly unbanked — to run a five-minute retro that routes surprises into CLAUDE.md candidates, repetition into skill suggestions, and friction into process tweaks.
---

The pipeline has no memory by default: every run starts smart and ends
amnesiac. Decisions get ADRs (decision-records plugin); everything else
learned — the surprise, the friction, the thing re-derived for the third
time — evaporates. The retro is the write-back step: five minutes, three
sinks, then stop.

## When to run

- A task-runner run or taskmaster card set completes.
- A feature merges after non-trivial back-and-forth.
- A debugging session uncovered something structural about the project.
- The user says "retro", "what did we learn", "post-mortem" (for incident
  post-mortems with blame-pressure, stay blameless — mechanism, not actor).

Skip for: trivial tasks, runs that went exactly as planned with zero
surprises — "nothing to bank" is a legitimate one-line outcome.

## The protocol — evidence first

Collect from the ACTUAL session, not from vibes:

1. Surprises: what contradicted an assumption? (A kill-trigger that fired,
   a "turns out X doesn't support Y", a convention discovered mid-build.)
2. Friction: which step took visibly longer than its size warranted? Where
   did loops happen — repeated fix cycles, re-reads, re-derivations?
3. Repetition: what got done that has now been done two-plus times in this
   project?
4. Waste: what was produced and then discarded (wrong-path code, unused
   analysis) — and what would have caught it earlier?

Each finding needs a pointer to evidence (the failing command, the reworked
file, the repeated pattern). A retro finding without evidence is an opinion.

## The three sinks

Route every finding to exactly one sink; a finding with no sink gets dropped,
not hoarded:

| Sink | Takes | Output |
|---|---|---|
| CLAUDE.md candidate | durable project facts: conventions, constraints, gotchas ("migrations must be additive", "API X rate-limits at 10/s") | drafted line, proposed to user — never written silently |
| Skill / automation suggestion | repetition and routines — the third similar task, a checklist re-derived | handoff to routine-detector's protocol or /claude-authoring:new-skill |
| Process tweak | friction in HOW the work ran: cards too big, verify command wrong, missing gate | one-line change stated for next run |

Sink rules:

- CLAUDE.md candidates must be durable and project-true — not session trivia.
  Ten candidates a retro means the bar is too low; one or two is healthy.
- Skill suggestions follow the routine-detector etiquette: propose once,
  respect a no.
- Process tweaks that recur across retros are plugin/skill bugs — consider
  fixing the source skill instead of re-tweaking every run.

## Output shape

One page maximum:

    ## Retro: <scope>
    Surprises: <finding → sink> (evidence: <pointer>)
    Friction:  <finding → sink> (evidence: <pointer>)
    Repetition:<finding → sink>
    Dropped:   <findings with no sink, one line>
    Proposed CLAUDE.md lines: <draft, awaiting approval>

## Worked micro-example

Scope: 13-card run shipping domain agents to a plugin marketplace.

    ## Retro: domain-agents card run
    Surprises: validate.sh rejects unregistered plugin dirs, so full
      validation cannot run between per-plugin cards → process tweak:
      integration card owns the full gate; per-card verify stays targeted
      (evidence: validate.sh orphan-dir failure on card 01).
    Friction: three skill files landed under the 100-line floor and needed
      padding rounds → process tweak: draft skill bodies against the line
      budget before writing, not after (evidence: two fix cycles on card 09).
    Repetition: fourth plugin scaffolded by hand this month → skill
      suggestion: scaffold command (handed to /claude-authoring:new-plugin).
    Dropped: subagent prompt phrasing preferences — session trivia, no sink.
    Proposed CLAUDE.md lines (awaiting approval):
      - "scripts/validate.sh must pass before any commit touching plugins/"

Four findings, three banked, one dropped, one CLAUDE.md candidate. That ratio
is the shape of a healthy retro.

## Cadence and scope

- Per milestone or per feature — not per card, not per commit. The unit is
  "a stretch of work with room for surprise".
- Sessions ending mid-work: run a thin retro anyway if a surprise surfaced;
  unbanked surprises are the ones paid for twice.
- Scope the evidence window to the work under review — do not re-retro
  stretches already banked; standing findings live in CLAUDE.md now.

## Anti-patterns

- Retro theater: a page of process poetry with zero banked artifacts. The
  measure is what landed in a sink, not word count.
- Blame framing: "the agent failed to" — mechanism over actor, always; what
  gate would have caught it?
- Silent memory writes: CLAUDE.md is the user's file; draft and propose.
- Hoarding: findings kept "for later" in loose notes. Sink it or drop it.
- Retro recursion: retrospecting the retrospective. Once, then done.
- Skipping evidence: a learning that cannot point at a moment in the session
  is a guess wearing a conclusion's clothes.
