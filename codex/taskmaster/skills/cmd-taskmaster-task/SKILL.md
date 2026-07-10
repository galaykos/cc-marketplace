---
name: cmd-taskmaster-task
description: "Use when the user asks to grill a task until zero ambiguity, decide visual choices with mockups, then emit a spec and single-prompt task cards."
---

_This skill wraps the `/taskmaster:task` command; pass the command's input as the skill's argument (`$ARGUMENTS`)._


<!-- Canonical pipeline — keep commands/taskmaster.md (the /taskmaster alias) in sync -->

Run the full taskmaster pipeline on $ARGUMENTS (if empty, ask for a one-paragraph task
description first). Do not write implementation code at any step. If $ARGUMENTS is
still an idea without a concrete capability list, run the brainstorm skill first
(the `cmd-taskmaster-brainstorm` skill) — its approved design doc becomes this pipeline's input and
pre-seeds the ledger.

**Ultra flag:** run in Extreme Boost mode ONLY when $ARGUMENTS *begins* with a
bare `ultra` token (this command invoked as `/taskmaster:<cmd> ultra …`) or
contains the explicit `ultra-task`/`ultratask` token. A bare `ultra` that is not
the first token of THIS command's own arguments — e.g. an earlier command's own
intensity flag in a chained message, such as a `caveman ultra` preceding this
command — is NOT a taskmaster trigger and never boosts this run; only
`ultra-task`/`ultratask`
crosses a command boundary. The `ultra`/`ultra-task` token may carry a
`-<model>[-<effort>]` suffix — e.g. `ultra-sonnet-xhigh`, `ultra-task-opus` (model
∈ opus|sonnet|haiku|fable, default opus; effort ∈ low|medium|high|xhigh|max,
default max) — resolved per the `ultra` skill's Variants section. On a match, strip the matched token and treat the run
as `ULTRA-TASK ACTIVE` per the taskmaster `ultra` skill (the selected model on
reachable subagents, mandatory red-team + coverage, bounded Workflow fan-outs, the
⚡ banner, and the `Ultra: true (model=…, effort=…)` marker written into the card
index).

1. If the stack-scan plugin is installed (the installed-versions skill or
   the `cmd-stack-scan-report` skill is available), run its inventory first and hand the
   required-vs-installed table to context-scout as hard constraints. If it is not
   installed, skip this — context-scout falls back to reading manifests itself.
2. Invoke the grill skill from this plugin. Dispatch the context-scout agent on the
   task description and fold its report into the ambiguity ledger BEFORE asking the
   user anything.
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
5. Write the spec to `taskmaster-docs/specs/YYYY-MM-DD-<slug>.md`: goal, decisions with
   sources, accepted assumptions, non-goals, success criteria — plus the
   walkthrough file path and cross-screen contracts when step 4 ran.
6. Red-team the spec first when its blast radius warrants — run the `spec-redteam`
   skill to attack the frozen spec for holes (missing edge cases, unstated
   assumptions, conflicts, failure/security gaps) and resolve each before planning.
   Then, if the code-architecture plugin is installed (the plan-before-code skill
   is available), run a plan check on the spec before splitting cards — file-level
   change plan, unit ownership, interfaces — and fold any corrections back into
   the spec. If the decision-records plugin is installed, offer capturing the
   spec's significant decisions as ADRs (`the `cmd-decision-records-new` skill`). Skip either
   when its plugin is not installed.
7. Invoke the task-cards skill to split the spec into single-prompt task cards
   under `taskmaster-docs/tasks/YYYY-MM-DD-<slug>/` with a `00-INDEX.md`, grouped into
   milestones when the run is large — cards sized per the estimation plugin's
   skill when it is installed (S/M/L/XL; anything L+ is split).
8. Final output: the ledger summary (counts of CLEAR/ASSUMED), the spec path, and
   the card list in execution order with parallel groups (and milestones) marked.
9. Handoff — do not just print a command and stop:
   - If the task-runner plugin is installed, ask via AskUserQuestion: "Cards are
     ready. Start execution now?" with options "Run now (Recommended)" and "Stop
     here — I'll run it later". On "Run now", immediately invoke the
     task-execution skill from the task-runner plugin on the new `00-INDEX.md`,
     exactly as `the `cmd-task-runner-run` skill taskmaster-docs/tasks/YYYY-MM-DD-<slug>/00-INDEX.md`
     would — same scope lock, same bounded verify-fix loops.
   - On "Stop here", or when AskUserQuestion is unavailable (headless), print
     that exact command as the next step.
   - Without task-runner installed, give the card paths and note each card is
     designed to run in a fresh session.
