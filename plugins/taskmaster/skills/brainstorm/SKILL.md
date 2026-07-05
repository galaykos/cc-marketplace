---
name: brainstorm
description: Use when the request is still an idea rather than a task — no concrete capability list, an "I want something like…", a product thought that could go five directions. Shapes the idea into an approved design through one-question-at-a-time dialogue, explored alternatives, and sectional design approval, then hands the design doc to the grill pipeline. Upstream of grill; never writes implementation code.
---

## Where this sits in the pipeline

grill extracts requirements for a task the user can already name. This skill
runs EARLIER: the idea is fuzzy, the shape is undecided, and interrogating for
edge cases would be premature — you would be sharpening details of a thing that
might not survive its first alternative. Brainstorm converges idea → design;
grill converges design → requirements; task-cards converge requirements → work.

Hard gate, no exceptions: no implementation code, no scaffolding, no file
creation beyond the design doc until the design is approved. "Too simple to
need a design" is the classic leak — simple ideas carry the most unexamined
assumptions; their design can be five sentences, but it gets written and
approved.

## Context before questions

Same doctrine as grill: dispatch context-scout (and reuse the stack-scan
inventory when installed) BEFORE asking anything. An idea conversation that
ignores the existing codebase produces designs the codebase rejects on contact.
Existing patterns, existing modules that half-do the idea, hard version
constraints — all of it bounds the option space before the first question.

## Scope check first

Before refining anything, size the idea. If it describes multiple independent
subsystems ("a portal with chat, billing, analytics, and an admin panel"),
do not brainstorm the platform — decompose:

- Name the independent pieces and their relationships.
- Agree an order with the user (value and risk first).
- Brainstorm ONLY the first piece through this skill; each later piece gets
  its own design → grill → cards cycle when its turn comes.

## One question at a time

Unlike grill's batched rounds, brainstorming asks ONE question per message.
Divergent exploration means each answer legitimately changes what is worth
asking next — a batch built before the answer is a batch half-wasted. Rules:

- Multiple choice when possible; concrete options provoke corrections, open
  questions provoke essays.
- Focus the sequence on purpose (what problem, for whom), constraints (stack,
  budget, deadline, compatibility), and success criteria (how we know it
  worked).
- When a question is genuinely visual (layout, flow shape), switch to the
  visual-decisions skill and its live preview URL — but only for questions
  that are visual, not merely UI-flavored.

## Explore alternatives before committing

Never present the first workable idea as the design. Propose 2–3 genuinely
different approaches with honest tradeoffs, your recommendation first and
argued. If only one approach exists, say so and say why — "alternatives
considered: none viable because X" is a legitimate answer; silence is not.
YAGNI applies at design level: strike every capability the idea does not need
this round; moved-to-later is a decision, not a loss.

## Present the design in sections

When the shape is settled, present the design incrementally — architecture,
components and their single responsibilities, data flow, error handling,
testing approach — each section scaled to its complexity, approval collected
per section rather than as one big "looks good?" at the end. Design units for
isolation: one purpose per unit, communication through named interfaces, and
for every unit an answer to "what does it do, how is it used, what does it
depend on". A unit whose internals must be read to be understood has a
boundary problem worth fixing on the whiteboard, not in the code.

## The design doc

Write the approved design to `docs/specs/YYYY-MM-DD-<slug>-design.md`: the
problem, the chosen approach and the alternatives rejected (with reasons),
component map, data flow, error handling, success criteria, non-goals.

Then self-review with fresh eyes before showing it:

1. Placeholders — any TBD, TODO, or hand-wave left? Fix inline.
2. Contradictions — do sections disagree? Does the architecture actually
   support every described behavior?
3. Scope — still one implementable design, or did it grow into a decomposition
   candidate during writing?
4. Ambiguity — any sentence readable two ways? Pick one, make it explicit.

Then the user gate: ask the user to review the written doc — not the
conversation, the doc — and change it until they approve it.

## Handoff

The approved design feeds the grill pipeline, not the editor: run the grill
skill with the design doc as input. Most ledger dimensions arrive pre-answered
(CLEAR, source: the design doc); grill closes what design legitimately left
open — edge cases, sequencing, exact data shapes — then visual decisions,
walkthrough for multi-screen work, spec, cards. Skipping grill because "the
design covers it" ships the design's blind spots straight into code.

## Anti-patterns

- Writing code, scaffolding, or "just a quick prototype" mid-brainstorm.
- First idea presented as the design — alternatives exist to be beaten, and
  sometimes they win.
- Question firehose: five questions in one message is an interrogation form,
  not a dialogue.
- Refining details of an idea that needed decomposition first.
- The design doc written after implementation as documentation theater.
- Treating your recommendation as the decision — the user picks, every time.
- Skipping the doc for "simple" ideas — five sentences, written and approved,
  still beats zero.
