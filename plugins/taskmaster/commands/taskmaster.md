---
description: Shorthand for /taskmaster:task — grill to zero ambiguity, then emit a spec and single-prompt task cards
argument-hint: [task-description]
---

<!-- Alias of task.md — keep the pipeline steps in sync with commands/task.md -->

Run the full taskmaster pipeline on $ARGUMENTS (if empty, ask for a one-paragraph task
description first). Do not write implementation code at any step. If $ARGUMENTS is
still an idea without a concrete capability list, run the brainstorm skill first
(/taskmaster:brainstorm) — its approved design doc becomes this pipeline's input and
pre-seeds the ledger.

**Run-status line (always):** print ONE status line as the first visible output of
every run, boosted or not — a boosted run prints the ⚡ banner (owned by the
ultra/ultra-goal skill; the banner IS its status line); a standard run prints
`▷ taskmaster standard run — subagents inherit the session model (<model>) · effort: <effort> · boost: off` — substitute `<model>` with the session model and `<effort>` with `$CLAUDE_EFFORT` (resolve via `echo ${CLAUDE_EFFORT:-inherit}`); when the harness does not expose it, that prints the literal `inherit`.


**Ultra flag:** run in Extreme Boost mode ONLY when $ARGUMENTS *begins* with a
bare `ultra` token (this command invoked as `/taskmaster:<cmd> ultra …`) or
contains the explicit `ultra-task`/`ultratask` token. A bare `ultra` that is not
the first token of THIS command's own arguments — e.g. an earlier command's own
intensity flag in a chained message, such as a `caveman ultra` preceding this
command — is NOT a taskmaster trigger and never boosts this run; only
`ultra-task`/`ultratask`
crosses a command boundary. The `ultra`/`ultra-task` token may carry a
`-<model>[-<effort>]` suffix — e.g. `ultra-sonnet-xhigh`, `ultra-task-opus` (model
∈ auto|opus|sonnet|haiku|fable, default auto (session model or opus, whichever is higher); effort ∈ low|medium|high|xhigh|max,
default xhigh) — resolved per the `ultra` skill's Variants section. On a match, strip the matched token and treat the run
as `ULTRA-TASK ACTIVE` per the taskmaster `ultra` skill (the selected model on
reachable subagents, mandatory red-team + coverage, bounded Workflow fan-outs, the
⚡ banner, and the `Ultra: true (model=…, effort=…)` marker written into the card
index).

**Goal flag:** run in hands-off Extreme Boost mode ONLY when $ARGUMENTS *begins* with a
bare `goal` token (this command invoked as `/taskmaster:<cmd> goal …`) or contains
the explicit `ultra-goal`/`ultragoal` token. A bare `goal` that is not the first
token of THIS command's own arguments — e.g. an earlier command's flag in a chained
message — is NOT a taskmaster trigger and never activates this run; only
`ultra-goal`/`ultragoal` crosses a command boundary. The token may carry a
`-<model>[-<effort>]` suffix — e.g. `ultra-goal-sonnet-xhigh`, `goal-opus` (model ∈
auto|opus|sonnet|haiku|fable, default auto (session model or opus, whichever is higher); effort ∈ low|medium|high|xhigh|max, default
xhigh) — resolved per the taskmaster `ultra-goal` skill
(`skills/ultra-goal/SKILL.md`), the canonical owner of this mode. Ultra-goal implies
the full ULTRA-TASK boost: when an `ultra-task` token is also present its tier wins;
ultra-goal's suffix applies only when no ultra-task token is present. On a match,
strip the token and run as `ULTRA-GOAL ACTIVE` per that skill — auto-take every
pipeline recommendation (deriving one first when none is labeled Recommended); the
handoff step auto-selects "Run now" and runs through execution to a green suite;
branch-finish/merge/PR stay manual — stamping a `Goal: true (model=…, effort=…)`
marker into the card index and logging every auto-take to the goal ledger.

1. If the stack-scan plugin is installed (the installed-versions skill or
   /stack-scan:report is available), run its inventory first and hand the
   required-vs-installed table to context-scout as hard constraints. If it is not
   installed, skip this — context-scout falls back to reading manifests itself.
2. Invoke the grill skill from this plugin. Dispatch the context-scout agent on the
   task description and fold its report into the ambiguity ledger BEFORE asking the
   user anything. Then, after that fold and before the question rounds, derive the
   upgraded task statement from the raw prompt plus the scout report per grill's
   prompt-upgrade reference.
3. Run batched question rounds per the grill skill until every ledger row is CLEAR
   or explicitly accepted as ASSUMED. For whole-experience tasks, slice first per
   the grill skill's big-task rule. Switch to the visual-decisions skill when a
   choice is between options that look or flow differently (layout, flow,
   architecture shape, data shape) — the skill asks fidelity consent (full mockups
   / ASCII only / none) on first use per session, with context-scout's Visual
   surface section as the prior.
4. For multi-screen or whole-experience tasks (three-plus screens, or a flow whose
   sequence is itself a requirement), invoke the experience-walkthrough skill once
   visual decisions land: assemble the accepted picks into one clickable demo on
   the live preview URL, walk the user through it with a task script, and fold
   every discovered gap back into the ledger before freezing anything.
5. Write the spec to `taskmaster-docs/specs/YYYY-MM-DD-<slug>.md`: a header with the raw +
   upgraded statement pair (under the `**Raw prompt:**` / `**Upgraded statement:**`
   labels), goal, decisions with sources, accepted assumptions, non-goals, success
   criteria — plus the walkthrough file path and cross-screen contracts when step 4 ran.
6. Red-team the spec first when its blast radius warrants — run the `spec-redteam`
   skill to attack the frozen spec for holes (missing edge cases, unstated
   assumptions, conflicts, failure/security gaps) and resolve each before planning.
   Then, if the code-architecture plugin is installed (the plan-before-code skill
   is available), run a plan check on the spec before splitting cards — file-level
   change plan, unit ownership, interfaces — and fold any corrections back into
   the spec. Skip it when the plugin is not installed.
7. Invoke the task-cards skill to split the spec into single-prompt task cards
   under `taskmaster-docs/tasks/YYYY-MM-DD-<slug>/` with a `00-INDEX.md`, grouped into
   milestones when the run is large — cards sized per the estimation plugin's
   skill when it is installed (S/M/L/XL; anything L+ is split).
8. Final output: the ledger summary (counts of CLEAR/ASSUMED), the spec path, and
   the card list in execution order with parallel groups (and milestones) marked.
9. Handoff — do not just print a command and stop:
   - **Skip the ask when execution is already authorized.** If the user settled it
     earlier this session — an answer that chose the pipeline's weight, an explicit
     "just do it", a prior "Run now" — the decision is granted; invoke task-execution
     directly and report the result. Re-asking a settled decision stalls the turn.
   - **Never substitute prose for the ask.** Ending a turn with "next: run the cards,
     or I edit the file now" is not a handoff — those two labels are the same work, so
     the choice is false, and a plain-text offer yields a dead turn with nothing started.
     Either the ask below runs as an AskUserQuestion, or execution begins.
   - If the task-runner plugin is installed, ask via AskUserQuestion: "Cards are
     ready. Start execution now?" with options "Run now (Recommended)" and "Stop
     here — I'll run it later". On "Run now", immediately invoke the
     task-execution skill from the task-runner plugin on the new `00-INDEX.md`,
     exactly as `/task-runner:run taskmaster-docs/tasks/YYYY-MM-DD-<slug>/00-INDEX.md`
     would — same scope lock, same bounded verify-fix loops.
   - On "Stop here", or when AskUserQuestion is unavailable (headless), print
     that exact command as the next step.
   - Without task-runner installed, give the card paths and note each card is
     designed to run in a fresh session.
