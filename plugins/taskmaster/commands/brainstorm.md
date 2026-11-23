---
description: Shape a fuzzy idea into an approved design doc, then hand off to the taskmaster pipeline
argument-hint: [idea]
---

Shape $ARGUMENTS into an approved design doc (if empty, ask what idea the user
wants to explore). No implementation code, scaffolding, or project files beyond
the design doc at any point (session state — mockups, the approaches marker — excepted).

<!-- boost-preamble:start — byte-identical across the four full taskmaster commands (taskmaster.md is a thin alias, gated separately); scripts/validate.sh enforces parity and hook-token agreement -->
**Run-status line (always):** print ONE status line as the first visible output of
every run — a boosted run prints the ⚡ banner (owned by the taskmaster `ultra`
skill; the banner IS its status line); a standard run prints
`▷ taskmaster standard run — session <model> · subagents inherit it unless their agent pins a tier · effort: <effort> · boost: off` — substitute `<model>` with the session model and `<effort>` with `$CLAUDE_EFFORT` (resolve via `echo ${CLAUDE_EFFORT:-inherit}`); when the harness does not expose it, that prints the literal `inherit`.

**Boost flags:** Extreme Boost fires ONLY when $ARGUMENTS *begins* with a bare
`ultra` (boost) or `goal` (boost + hands-off) token, or contains the explicit
`ultra-task`/`ultratask` or `ultra-goal`/`ultragoal` token. Only the explicit
tokens cross a command boundary — a bare token owned by an earlier chained
command (e.g. `caveman ultra` preceding this command) NEVER triggers this run.
No tier suffixes: the tier is fixed at model=auto, effort=xhigh (`auto` =
session model or opus, whichever is higher — escalate, never downgrade). On a
match, strip the matched token and apply the taskmaster `ultra` skill
(`skills/ultra/SKILL.md`) — `ULTRA-TASK ACTIVE`, or `ULTRA-GOAL ACTIVE` in Goal
mode for `goal`/`ultra-goal` — ⚡ banner first, `Ultra:`/`Goal:` markers per
that skill. A bare `goal-lean` first token is hands-off WITHOUT the boost: strip
it and apply the `ultra` skill's Goal-lean section (`ULTRA-GOAL ACTIVE (boost=off)`:
every Goal auto-take rule, standard tier, no red-team mandate, `▷` status line not
the ⚡ banner, marker `Goal: true (boost=off)`). It has no free-text form.
<!-- boost-preamble:end -->

**Goal in this command:** auto-take every design decision (derive-then-take) and
auto-select the "Continue" handoff into `/taskmaster:task`, which carries
hands-off downstream; branch-finish/merge/PR stay manual.

## Where this sits in the pipeline

Standing: recorded — brainstorm converges idea → design, `grill` design →
requirements, `task-cards` requirements → work. Run this while the shape is undecided,
where interrogating for edge cases would sharpen a thing that may not survive its
first alternative.

Hard rule, no exceptions: no implementation code, no scaffolding, no file
creation beyond the design doc until the design is approved. "Too simple to
need a design" is the classic leak — simple ideas carry the most unexamined
assumptions; their design can be five sentences, but it gets written and
approved.

First thing in every run, write the phase sentinel:
`bash "${CLAUDE_PLUGIN_ROOT}/scripts/phase-sentinel.sh" write shape --owner taskmaster:brainstorm --session "${CLAUDE_SESSION_ID}"`.
While it is live, `hooks/shape-guard.sh` denies any Write/Edit to a project file outside
`.cc-artifacts/`, `.claude/` and an older project's `taskmaster-docs/` (visual-decisions' `__design-preview__` scratch passes).
Clear it — `bash "${CLAUDE_PLUGIN_ROOT}/scripts/phase-sentinel.sh" clear --session "${CLAUDE_SESSION_ID}"` — once the user
approves the design doc, and equally when the run is stopped or abandoned. Never clear it to
get a write through. Standing: **gate** for Write/Edit/MultiEdit; writes through Bash or
NotebookEdit are not seen, so for them the rule is `unenforceable` and holds only because
you hold it.

## Context before questions

Same doctrine as grill: dispatch context-scout (and reuse the stack-scan
inventory when installed) BEFORE asking anything, with the brain map's absolute path
and any `brain map is behind HEAD` line per grill's Step 0. An idea conversation that
ignores the existing codebase produces designs the codebase rejects on contact.
Existing patterns, existing modules that half-do the idea, hard version
constraints — all of it bounds the option space before the first question. Under
a boost (`ULTRA-TASK ACTIVE` or `ULTRA-GOAL ACTIVE`; see the `ultra` skill), dispatch context-scout NATIVE (mechanical —
no override), lenses sized per that skill's `references/dispatch-tiers.md`; opinion-lens native.

## Scope check first

Before refining anything, size the idea. If it describes multiple independent
subsystems ("a portal with chat, billing, analytics, and an admin panel"),
do not brainstorm the platform — decompose:

- Name the independent pieces and their relationships.
- Agree an order with the user (value and risk first).
- Brainstorm ONLY the first piece through this command; each later piece gets
  its own design → grill → cards cycle when its turn comes.

## When the answer is no

A brainstorm may end without a design. When the purpose, the constraints or the scout report
show the idea should not be built, or not yet — the codebase already solves it, the cost
outweighs the stated outcome, a precondition is missing — say so with the reason instead of
shaping further: a detailed design makes a weak idea easier to continue, not better. Ask via
AskUserQuestion: "Stop here and record why (Recommended)" / "Keep shaping". On stop, write
`.cc-artifacts/taskmaster/no-go/YYYY-MM-DD-<slug>.md` — `Status: not building` or `not now`,
the reason, and what would change the answer — clear the phase sentinel, and offer no handoff.
Headless: record and stop. Goal mode has no such exit: there it is the `ultra` skill's
halt-with-evidence. Standing: agent-graded.

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

ONE fidelity consent per session, and in a brainstorm-led run brainstorm is the
step that asks it — once, on the first staged decision, via AskUserQuestion. The
question's WORDING is owned by `visual-decisions`; brainstorm's one exception is
dropping the dormant/none option, because the floor here is describe-only which still
RECORDS a decision. Whichever step reaches the gate first asks it and the answer
then holds all session, so erd and visual-decisions reuse it and never re-ask.
Brainstorm does not hand the ASKING off mid-run:
visual-decisions is a rendering backend only, its first-use gate treated as
already answered (shell = "Full mockups", ASCII = "Quick ASCII only", never
"No mockups"). Route fidelity by decision kind and host (consent may downgrade):

| Decision | Tier |
|----------|------|
| Design, runnable Vite/Laravel host with components | visual-decisions, real-component rung |
| Design, structure/density/flow only | visual-decisions shell |
| Design, trivial layout | ASCII wireframe |
| Creative/concept | visual-decisions shell as a creative pass; describe-only when the user declined mockups |

A creative decision is staged on a creative pass: a shell page whose `<body>` carries
`data-vd-pass-kind="creative"`, where each frame is one direction and frames may differ in
concept, copy and tone. The count rule (3 directions by default, up to 5, never more than 6)
and the Palette, Style and Type switchers apply; the layout-only rule does not. Creative never
routes to ASCII, which carries structure and not concept. When the user declined mockups,
describe each direction in words and say which fidelity was lost.
Sequencing holds one-question-at-a-time: the first visual/creative question
carries the consent question, then each stages exactly ONE decision's options and
the doc accretes only accepted picks — never a surface posing several at once.
Creative variants are authored as N divergent directions in the main thread (not
opinion-lens, which stays for design/architecture shapes), rendered side by side. Each direction
is drafted before any is refined, by the same blind-drafting rule as § Explore alternatives.
Once a decision's own option set exists (never earlier) and consent allows mockups,
ask ONE opt-in question: up to 2 matching starters plus gallery/INDEX.md matches when
present, shown beside the decision's own options as reference, never the option set,
one per surface. Fold picks into current.html per visual-decisions' references/shell-authoring.md.

## Explore alternatives before committing

Never present the first workable idea as the design. When two or more genuinely different
design shapes are viable, generate them as structurally different candidates, never as
variations on one draft. approaches plugin installed → follow `approaches:approach-deliberation`,
which owns the mechanism choice: its inline slate by default, its blind panel
(`references/blind-panel.md`, which owns the persona roster and the dispatch contract) only
when the idea reworks existing code. Synthesize alternatives + recommendation, then WRITE the
round's marker `<repo root>/.cc-artifacts/approaches/deliberated.json`: unwritten, the
double-run guard is unarmed and the question is re-litigated downstream.
Its pick-approval is satisfied here by the design doc's approval gate below.
Absent → propose 2–3 yourself with their tradeoffs, recommendation first and argued. Draft them
before you pick one. Draft them blind to each other: one fresh subagent per candidate when the run
already fans out, otherwise one step that lists k candidates, each with your estimated probability,
and keeps at least one unlikely candidate (verbalized sampling, arXiv 2510.01171). Rank and
criticise only after all exist. Why: one context drafting options in sequence fixates on its first.
LLM ideas cluster across 22 models (arXiv 2501.19361) and fixate early (arXiv 2602.20408). Pooled
solo ideation beat group ideation in 18 of 22 experiments (Diehl & Stroebe 1987). Debate beat
"no criticism" rules (Nemeth et al. 2004). Standing: agent-graded. If only one approach exists, say so — "alternatives considered: none viable
because X" is a legitimate answer; silence is not. YAGNI applies at design level: strike
every capability the idea does not need this round; moved-to-later is a decision, not a loss.

## Present the design in sections

When the shape is settled, present the design incrementally — architecture,
components and their single responsibilities, data flow, error handling,
testing approach — each section scaled to its complexity, approval collected
per section rather than as one big "looks good?" at the end. Unit boundaries are
`code-architecture:solid-principles` and `code-architecture:system-design` when that
plugin is installed; brainstorm's own job is that the boundary gets DECIDED on the
whiteboard, not discovered mid-card.

## The design doc

Write the approved design to `.cc-artifacts/taskmaster/specs/YYYY-MM-DD-<slug>-design.md`: the
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

The approved design feeds the taskmaster pipeline, not the editor — but offer,
do not auto-run: ask via AskUserQuestion whether to continue into the taskmaster
pipeline now — "Continue (Recommended)" runs `/taskmaster:task` with the design
doc as input; "Stop here" prints that command for later. Goal mode auto-selects
Continue (above); headless without Goal stops after the doc and prints the command. Grill seeds its ledger from the doc: most ledger
dimensions arrive pre-answered (CLEAR, source: the design doc); grill closes what
design legitimately left open — edge cases, sequencing, exact data shapes — then
visual decisions, walkthrough for multi-screen work, spec, cards. Skipping grill
because "the design covers it" ships the design's blind spots straight into code.

## Anti-patterns

- Code, scaffolding, or a "quick prototype" mid-brainstorm — the hard gate holds.
- First idea shown as the design, or your recommendation treated as the decision
  — alternatives can win, and the user picks every time.
- A firehose — five questions in one message, or a staged surface posing several
  decisions at once.
- Skipping the doc for a "simple" idea, or writing it after the code.
