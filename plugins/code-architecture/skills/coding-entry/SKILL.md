---
name: coding-entry
description: Use before the first edit of ad-hoc coding work typed straight into a session — loads the always-relevant discipline skills, primes the stack-matched ones by path, and decides in one line whether the task proceeds inline or belongs in the taskmaster pipeline. Not for work that already has a spec or cards.
---

## The window this covers

Skills reach work in exactly two ways today. A taskmaster card carries `Skills to apply`,
primed at dispatch. The skill-router nudges after a file is edited. Neither covers the
common case: a coding request typed straight into a session, where the first line is
written before anything says what the house rules are.

This skill owns that window and nothing else. It does not clarify requirements (grill
owns that), write a spec or cards (taskmaster), or execute a list (task-runner).

## Load, then prime — two different things

**Load** means read the body now. Reserved for skills that apply to every line of code
regardless of stack or surface. Six, ~11k tokens (43,984 bytes of body):

- `lean:cost-model` — the minimum that clears the bar, per cost surface
- `comment-discipline:comment-discipline` — where each fact belongs
- `testing:testing-best-practices` — what to test, and its `proportionality.md` for how much
- `code-architecture:plan-before-code` — which files change, before they do
- `code-architecture:low-cognitive-load` — the destinations a comment's content moves to
- `code-review:code-smells` — the catalogue

**Prime** means emit the resolved absolute path as an instruction to read it when that
surface is touched:

    prime: laravel-best-practices — Read /abs/path/to/laravel/skills/laravel-best-practices/SKILL.md
           before editing any .php file

Everything stack- or surface-matched is primed, never loaded. Loading the full set eagerly
measures 17.9k on a Laravel + Inertia + React repo and 37k worst case, against 12.4k for
this marketplace's entire always-on budget — paid before a line is read, most of it for
surfaces the task never touches. A primed line costs ~15 tokens and expands to the same
body only if the work reaches that file. The router's post-edit nudge is the backstop when
a primed path goes unread.

`references/skill-map.md` has the signal → skill table. Resolve each path against the
installed plugins root; name any signal whose plugin is absent rather than skipping it
silently.

## The triage line — required, not optional

Typing a slash command SILENCES two things that fire on a plain prompt:
`taskmaster/hooks/remind.sh` exits on `/*` ("slash commands manage their own flow"), and
so does `skill-router/hooks/route-prompt.sh`. So this skill does not run alongside the
clarify nudge — it replaces it, and must carry the decision itself or the user loses a
guardrail by using the command.

**Ask the ownership question first.** A deeper command may already own this shape of
work, in which case the right move is to hand over, not to size the task. Only when no
row matches does the size question below apply.

| The ask is | Hand to | Because |
|---|---|---|
| one component, layout, or restyle | `/ui-ux:build` | it already resolves the stack skill and injects the Read paths into its worker |
| a whole app, landing page, CRM, SaaS surface | `/craft-layer:craft` | owns the end-to-end chain |
| a page decided section by section | `/craft-layer:sections` | owns the batched option rounds |
| colours, tokens, a theme | `/ui-ux:theme` | owns the live-preview loop |
| an error, a failing test, a symptom | `/debugging:debug` | owns root-cause-before-fix |
| "what is the state of X", an unfamiliar library or vendor | `/ultra-deep-research:research` | owns cited, date-stamped findings |

Handing over is not a smaller answer. Those commands prime their own skills and carry
their own gates; re-implementing any of that here would be the fourth pipeline this
skill exists to avoid.

When none matches, emit exactly one line and act on it:

| Reading | Line | Then |
|---|---|---|
| small and reversible — mechanical, already decided, or a few lines each across a few files | `triage: trivial — proceeding inline` | do the work |
| large — a redesign, a new subsystem, wide non-mechanical edits — OR the risk clause below, OR the ask has an unresolved unknown | `triage: needs a spec — <the unknown>` | **stop**, hand to `/taskmaster:task` |
| a spec or cards already exist for this work | `triage: already spec'd` | hand to `/task-runner:run` |

**The risk clause — auth, data, migrations, concurrency, money, PII, or an irreversible
effect.** Irreversible means the world does not roll back: a mass email or notification, a
delete or purge, a payment, a third-party write, anything a scheduler will fire
unattended. It fires on one line as readily as on fifty. It is the same set the
`code-reviewer` agent and `lean:cost-model`'s blast-radius trigger name, on purpose.

File count is not the term and never was a good proxy: a 3-file rename is not a 3-file
redesign. Size is lines and non-mechanical spread. Schema and infrastructure work has no
entry command of its own for the same reason: a migration or a deploy change lands in the
second row by the risk clause, and `/taskmaster:task` (whose `erd` skill owns data
modelling) is where it should go anyway.

Both errors are real. Skipping a spec that was needed gave the run with 2x this
repository's comment density and 8x its tests-per-integration, every gate green. Running
the pipeline on a small task buys a spec doc, an index, cards, and a review pass per card
for a change one edit would have finished — the same volume problem seen from the other
side. Tiebreak on blast radius, not on unease. **Reversible means the effect is
reversible, not that the commit is** — `git revert` restores code, never a sent email, a
deleted object, or a charged card; those are the risk clause, whatever the diff size.

**Standing: agent-graded.** No script checks that "trivial" was judged honestly, that the
size call was, or that the budget line below was met. The lines are mandatory so the
judgments are at least visible and arguable in the transcript; that is the whole of their
enforcement, and pretending otherwise would be the over-claim this marketplace's has-teeth
convention forbids.

## Output shape

Five lines, then the work or the handoff. No preamble, no restatement of the ask.

    stack: laravel 11 · inertia · react 18 · mysql        (or: no manifest recognised)
    loaded: cost-model, comment-discipline, testing, plan-before-code, low-cognitive-load, code-smells
    primed: laravel-best-practices, inertia-best-practices, react-server-state, a11y-audit
    triage: trivial — proceeding inline
    budget: 1 file, 1 test (the boundary case), no comment, no delegation

`budget:` states this task's minimum BEFORE any code is written — files, tests, comments,
and actions — so overshoot is visible and arguable in the transcript instead of discovered
in review. Exceeding it is allowed and often right; name the trigger in the same clause
where the excess happens (blast radius, an observed defect, a stated criterion the minimum
misses, or the user asked). Unnamed excess is the failure.

Two floors the budget cannot go under. Minimum means risk coverage, not a count: never
drop a test that exists because a defect, a mutation, or an incident proved the suite
missed it. And a budget never argues a gate down — if this work later becomes cards, each
card's `Verify` must still name a specific test or asserted outcome (`verify-teeth-lint`
blocks a bare suite pass), and a negative control returning `vacuous` means the check had
no teeth, which is a coverage gap to fix, never an excess to trim.
`lean:cost-model` carries the surfaces and the trigger list.

When a work-type row matches, the handover replaces the triage and budget lines, and
nothing is loaded or primed — the receiving command sets its own:

    route: this is a component build → /ui-ux:build <the ask>

## Boundaries

- Requirements clarification, ambiguity ledgers, specs, cards, red-teams → `taskmaster`.
- Executing a defined list, scope lock, verify loops, completion gate → `task-runner`.
- Per-file skill routing after an edit → `skill-router`, which keeps working normally.
- Which files change and what each unit owns → `plan-before-code`, loaded above; this
  skill decides whether to plan at all, never what the plan says.

## Anti-patterns

- Loading a primed skill "to be safe" — that is the 37k version, and the budget it spends
  is invisible to `context-budget.sh` because skill bodies are unmetered by design.
- Emitting the triage line and then ignoring it. A `needs a spec` verdict followed by code
  is worse than no triage: it launders the decision.
- Running this when cards already exist. That is `/task-runner:run`, and re-priming
  duplicates what `Skills to apply` already carries per card.
- Growing a question round here. One turn of questions is grill's job and it does it
  better; this skill's job ends at naming the unknown.
