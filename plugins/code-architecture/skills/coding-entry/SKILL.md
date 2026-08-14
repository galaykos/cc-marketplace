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
regardless of stack or surface. Five, ~9.5k tokens:

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
| single file, mechanical, or the change is already decided | `triage: trivial — proceeding inline` | do the work |
| 3+ files, OR touches auth / data / migrations / concurrency / money, OR the ask has an unresolved unknown | `triage: needs a spec — <the unknown>` | **stop**, hand to `/taskmaster:task` |
| a spec or cards already exist for this work | `triage: already spec'd` | hand to `/task-runner:run` |

Schema and infrastructure work has no entry command of its own on purpose: a migration or
a deploy change lands in the second row by blast radius, and `/taskmaster:task` (whose
`erd` skill owns data modelling) is where it should go anyway.

Ambiguity resolves toward the spec. The cost of one taskmaster round is minutes; the cost
of the other error is the run that produced 2x this repository's comment density and 8x
its tests-per-integration with every gate green.

**Standing: agent-graded.** No script checks that "trivial" was judged honestly. The line
is mandatory so the judgment is at least visible and arguable in the transcript; that is
the whole of its enforcement, and pretending otherwise would be the over-claim this
marketplace's has-teeth convention forbids.

## Output shape

Four lines, then the work or the handoff. No preamble, no restatement of the ask.

    stack: laravel 11 · inertia · react 18 · mysql        (or: no manifest recognised)
    loaded: comment-discipline, testing, plan-before-code, low-cognitive-load, code-smells
    primed: laravel-best-practices, inertia-best-practices, react-server-state, a11y-audit
    triage: trivial — proceeding inline

When a work-type row matches, the fourth line is the handover instead, and nothing is
loaded or primed — the receiving command does its own:

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
