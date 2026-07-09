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
constraints — all of it bounds the option space before the first question. Under
`ULTRA-TASK ACTIVE` (see the `ultra` skill), dispatch context-scout `model: opus`
with 3-lens Workflow recon and keep opinion-lens native.

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
- Visual and creative choices are staged, not settled in prose — see The staging
  area below, which brainstorm owns for the whole session.

## The staging area

Options with a surface get STAGED, not described. Keyed on context-scout's
Visual surface: `None` → skip; unknown (no scout) → a skippable offer; otherwise
staging is mandatory, floor included.

Brainstorm owns ONE session fidelity consent, asked once on the first staged
decision via AskUserQuestion, with NO dormant/none option — the floor is
describe-only, which still RECORDS a decision. It never delegates that choice:
visual-decisions is a rendering backend only, its first-use gate treated as
already answered (shell = "Full mockups", ASCII = "Quick ASCII only", never
"No mockups"). Route fidelity by decision kind and host (consent may downgrade):

| Decision | Tier |
|----------|------|
| Design, runnable Vite+React host | design-preview (real components) |
| Design, greenfield/non-React, interactivity matters | shadcn-studio sandbox |
| Design, structure/density/flow only | visual-decisions shell |
| Design, trivial layout | ASCII wireframe |
| Creative/concept | interactive tier only, else describe-only |

Creative never routes to the shell (bans text-native options) or ASCII
(structural); an interactive tier not installed drops to the next lower design
fidelity (describe-only for creative) — and say which fidelity was lost.
Sequencing holds one-question-at-a-time: the first visual/creative question
carries the consent question, then each stages exactly ONE decision's options and
the doc accretes only accepted picks — never a surface posing several at once.
Creative variants are authored as N divergent directions in the main thread (not
opinion-lens, which stays for design/architecture shapes), rendered side by side.

## Explore alternatives before committing

Never present the first workable idea as the design. When two or more genuinely
different design shapes are viable, do not generate them from one voice — that
anchors every "alternative" on a single draft. approaches plugin installed →
dispatch the four blind `opinion-lens` personas (Standards Purist,
Quality-over-Speed, Pragmatist-Minimalist, Skeptic-Investigator) on the design
question, then synthesize the alternatives and your recommendation from their
takes. Absent → propose 2–3 yourself, recommendation first and argued. If only
one approach exists, say so — "alternatives considered: none viable because X" is
a legitimate answer; silence is not. YAGNI applies at design level: strike every
capability the idea does not need this round; moved-to-later is a decision, not
a loss.

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

Write the approved design to `taskmaster-docs/specs/YYYY-MM-DD-<slug>-design.md`: the
problem, the chosen approach and the alternatives rejected (with reasons),
component map, data flow, error handling, success criteria, non-goals, and —
when the idea has a surface — a Staged decisions section (each pick: label,
serves/trades/breaks rationale, tier).

Then self-review with fresh eyes before showing it:

1. Placeholders — any TBD, TODO, or hand-wave left? Fix inline.
2. Contradictions — do sections disagree? Does the architecture actually
   support every described behavior?
3. Scope — still one implementable design, or did it grow into a decomposition
   candidate during writing?
4. Ambiguity — any sentence readable two ways? Pick one, make it explicit.
5. Staging — for a surface idea, is every visual/creative decision staged and
   recorded in Staged decisions? A self-review prompt, not a machine gate.

Then the user gate: ask the user to review the written doc — not the
conversation, the doc — and change it until they approve it.

## Handoff

The approved design feeds the grill pipeline, not the editor — but offer,
do not auto-run: ask "Continue into the grill pipeline now (Recommended)" /
"Stop at the approved design" via AskUserQuestion. On continue, run the grill
skill with the design doc as input. Most ledger dimensions arrive pre-answered
(CLEAR, source: the design doc); grill closes what design legitimately left
open — edge cases, sequencing, exact data shapes — then visual decisions,
walkthrough for multi-screen work, spec, cards. Skipping grill because "the
design covers it" ships the design's blind spots straight into code.

## Anti-patterns

- Code, scaffolding, or a "quick prototype" mid-brainstorm — the hard gate holds.
- First idea shown as the design, or your recommendation treated as the decision
  — alternatives can win, and the user picks every time.
- A firehose — five questions in one message, or a staged surface posing several
  decisions at once.
- Skipping the doc for a "simple" idea, or writing it after the code.
