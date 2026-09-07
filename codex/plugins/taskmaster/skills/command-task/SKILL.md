---
name: command-task
description: "Grill a task to zero ambiguity, decide visuals with mockups, then emit a spec and single-prompt task cards"
---

Read [the Codex execution contract](../../references/codex.md) before using helpers or delegating.

<!-- Canonical pipeline — skills/command-taskmaster/SKILL.md is a thin alias that delegates here (validate.sh enforces its shape) -->

Run the full taskmaster pipeline on the user-supplied arguments (if empty, ask for a one-paragraph task
description first). Do not write implementation code at any step. If the user-supplied arguments is
still an idea without a concrete capability list, run the brainstorm skill first
(taskmaster:command-brainstorm) — its approved design doc becomes this pipeline's input and
pre-seeds the ledger.

For an explicit ultra-task or ultra-goal request, load the native ultra skill. Keep session model settings; goal mode continues only already-authorized work.

**Goal in this command:** auto-take every pipeline recommendation (derive one
first when none is labeled Recommended); the handoff auto-selects "Run now" and
runs through execution to a green suite; branch-finish/merge/PR stay manual.

1. Write the arc phase sentinel `.codex/cc-marketplace/cc-phase.json` —
   `{"phase":"shape","owner":"taskmaster:task","session_id":"<this session id>",`
   `"started_at":"<ISO-8601 UTC>"}`. This is what makes the prompt channel take
   turns: reminder hooks that own a later phase stand down while requirements are
   still being shaped, instead of all four talking over one prompt. **Remove it when
   this command finishes** — on the hand-off to `task-runner:command-run` (which writes its
   own `build` sentinel), and equally on an abandoned or interrupted run. A stale
   sentinel is bounded by a TTL rather than trusted, but the clear is still yours.

   Then, if the stack-scan plugin is installed (the installed-versions skill or
   stack-scan:command-report is available), run its inventory and hand the
   required-vs-installed table to context-scout as hard constraints. If it is not
   installed, skip that — context-scout falls back to reading manifests itself.
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
   surface section as the prior. When colour or theme is itself the decision,
   switch to `ui-ux:command-theme` instead. Every visual option renders on the local
   preview server at `${PREVIEW_PORT:-8123}` — never publish one as a remote
   artifact, which bypasses the consent gate, the ledger, and the viewport and
   push-reload controls those previews carry.
4. For multi-screen or whole-experience tasks (three-plus screens, or a flow whose
   sequence is itself a requirement), invoke the experience-walkthrough skill once
   visual decisions land: assemble the accepted picks into one clickable demo on
   the live preview URL, walk the user through it with a task script, and fold
   every discovered gap back into the ledger before freezing anything.
5. Write the spec per the grill skill's Stopping section — grill OWNS the
   spec-write sequence (approach decision → spec → lint); this step summarizes it,
   never run a stage twice. Decide the approach first when structurally different
   implementations exist (the blind panel per grill Stopping §1; skip for mechanical
   tasks). Then write `taskmaster-docs/specs/YYYY-MM-DD-<slug>.md`: a header with
   the raw + upgraded statement pair (under the `**Raw prompt:**` /
   `**Upgraded statement:**` labels), goal, decisions with sources, accepted
   assumptions, the approach with rejected alternatives and kill-trigger,
   non-goals, success criteria, and the converged ledger embedded as
   `## Ambiguity ledger (final)`; run `scripts/spec-ledger-lint.sh --spec <file>`
   until exit 0 (task-cards re-runs it later as the final gate) — plus the
   walkthrough file path and cross-screen contracts when step 4 ran.
6. Red-team the spec first when its blast radius warrants — run the `spec-redteam`
   skill to attack the frozen spec for holes (missing edge cases, unstated
   assumptions, conflicts, failure/security gaps) and resolve each before planning.
   Then, if the code-architecture plugin is installed (the plan-before-code skill
   is available), run a plan check on the spec before splitting cards — file-level
   change plan, unit ownership, interfaces — and fold any corrections back into
   the spec. Skip it when the plugin is not installed.
7. Invoke the task-cards skill to split the spec into single-prompt task cards
   under `taskmaster-docs/tasks/YYYY-MM-DD-<slug>/` with a `00-INDEX.md`, grouped into
   milestones when the run is large — cards sized per the approaches plugin's estimation
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
     Either the ask below runs as an a user question using the available interaction tool, or execution begins.
   - If the task-runner plugin is installed, ask via a user question using the available interaction tool: "Cards are
     ready. Start execution now?" with options "Run now (Recommended)" and "Stop
     here — I'll run it later". On "Run now", immediately invoke the
     task-execution skill from the task-runner plugin on the new `00-INDEX.md`,
     exactly as `task-runner:command-run taskmaster-docs/tasks/YYYY-MM-DD-<slug>/00-INDEX.md`
     would — same scope lock, same bounded verify-fix loops.
   - On "Stop here", or when a user question using the available interaction tool is unavailable (headless), print
     that exact command as the next step.
   - Without task-runner installed, give the card paths and note each card is
     designed to run in a fresh session.
