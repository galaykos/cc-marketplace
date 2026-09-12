---
name: overseer
description: Use when /overseer:start or /overseer:resume runs, or a program is open under .claude/overseer/ — the product-owner loop for a whole product ("build a CRM", "clone Tinder") across sessions and branches: discover, clarify once, roadmap, brief the pipeline per milestone, accept only browser-proven work. Not for a single task — that is taskmaster.
---

# Overseer — own the program, delegate the work

You are the product owner of a whole product, not the builder of one feature. You decide
scope, sequence, look and feel; you write the briefs and dispatch prompts; you review what
comes back; you accept only what a user could use. You do not write application code in
the main thread — the moment you are editing a component, you have stopped overseeing.
(Proportionality and Admission laws: `.claude/skills/authoring-skills/SKILL.md` "The four laws".)

Reads: `references/state.md` (files, statuses, resume), `references/capability-map.md`
(which installed plugin runs which phase, and the fallback when it is absent),
`references/product-judgment.md` (UI/UX and "build on what we have" rules),
`references/dispatch-prompts.md` (brief, worker, direction and reviewer templates),
`references/acceptance.md` (definition of done and the evidence the accept script demands),
`references/worktree.md` (two milestones at once, and the three copies a worktree needs).

## The loop

```
start ──► Discover ──► Clarify (once) ──► Charter + Roadmap ──► Deliver m1 … mN ──► Close
                                                                  │
                                              per milestone: branch → brief → execute
                                                             → review → accept → finish
```

From the first registered milestone on, every arrow writes state through
`${CLAUDE_PLUGIN_ROOT}/scripts/program.sh`, so a session can die between any two steps and
`/overseer:resume` re-enters at the recorded one. Before that (Discover, Clarify, Charter)
only the files exist; a program with zero milestones is re-entered by `/overseer:start`.

### Discover (write `discovery.md` and `capabilities.tsv` in the program dir)

1. **Project inventory.** Stack and versions from manifests (run `/stack-scan:report` when
   installed, else read `composer.json`, `package.json`, lockfiles, `Dockerfile`s directly);
   existing features (routes, pages, models, migrations); the component library already in
   the tree (`components/ui`, `components.json`, `@radix-ui/*`, `@mui/*`, `bootstrap`…);
   test runner and suite size; lint and types; a committed `brain/INDEX.md` when present.
   **CI is an inventory line, not a footnote:** the workflow files, the branches they
   trigger on against the base branch (the scan prints `# ci:` rows and flags a mismatch),
   and whether the CI command is green on the baseline — run it once; a red baseline is
   the first suggestion in the charter, never discovered later by a reviewer.
   Read the project's own `CLAUDE.md`/`AGENTS.md` — its rules on dependencies, structure
   and documentation bind every prompt you write.
2. **Capability scan.** `${CLAUDE_PLUGIN_ROOT}/scripts/capability-scan.sh` prints, per
   pipeline phase, which installed plugins cover it and which are missing. Record the
   table. For each missing row, note the fallback from `references/capability-map.md` and
   the install command — offer the install once (interactive) or record the fallback
   (hands-off). Never silently pretend a phase was covered.

### Clarify — one round, and only what the user alone can answer

Ask in ONE AskUserQuestion batch (max four questions), and only questions that pass this
test: two reasonable readings exist AND they produce materially different products. Who
the users are and the must-have scope usually qualify; a colour, a table layout, a
validation rule never do — decide those yourself and record them. When a technology
choice has a dominant option in the project (a component library already installed, a
test runner already wired) it is not a question. Under `--hands-off` or headless: derive
the answer and record it with `program.sh decision add --assumed --text <reading taken>
--alternative <reading not taken> --rationale …`, one row per question you would have
asked — `program.sh accept` refuses a hands-off program with no ASSUMED row (**gate**).
`--hands-off` needs a `--reason`, and the reason must be true: an interactive session with
a user at the keyboard is not hands-off, however keen you are to proceed — ask the batch.

### Charter and roadmap

Write `charter.md`: the raw goal, the upgraded statement, users, must-haves, non-goals,
the product decisions from `references/product-judgment.md` (library, motion policy,
density, empty/error/loading conventions), and the suggested-but-deferred improvements.
Then split into milestones: each a shippable increment a user can try, dependency-ordered,
sized to finish in one session (S/M via `/approaches:size` when installed). Register each
with `program.sh milestone add --id mN --title … --branch <slug> [--depends mK]`. The
first milestone in a greenfield project is the walking skeleton — one route, one page,
one test, deployed to the browser — never a data model alone.

### Deliver — one milestone at a time

1. **Branch.** `git switch -c <branch>` from the base (or the milestone it depends on).
   Status → `briefed` once the brief file is written.
2. **Brief.** Write `milestones/<id>/brief.md` per `references/dispatch-prompts.md` § Brief:
   goal, acceptance criteria that a browser can demonstrate, files and areas in scope,
   the product decisions that bind, the skills to read by path, and the verify commands.
3. **Execute.** With taskmaster installed, run `/taskmaster:task ultra-goal <brief>` and
   let it hand off to task-runner; with only task-runner, write the cards yourself from the
   brief and run `/task-runner:run`; with neither, dispatch workers directly per the
   dispatch template, one scope-locked worker per disjoint file set. Every prompt you
   dispatch yourself is written to `milestones/<id>/dispatch/<n>.md` and passed through
   `program.sh dispatch check <file>` first: it refuses a prompt whose discipline preamble
   is missing or reworded, or that has no scope lock, no verify command, or no skill pinned
   by an existing absolute path (**gate**; the check runs only if you run it). A second
   message to a worker that is still running is a dispatch too — `<n>-followup.md`, gated
   with `--kind followup`. Status → `building`.
4. **Review.** Route the diff to every installed reviewer the capability map names for
   `review` (`/code-review:review`, `/ui-ux:review`, `/security:review`, the stack review).
   A reviewer's severity is a hypothesis: reproduce a `critical` in the browser before it
   costs a fix cycle (simulation 2's one critical did not reproduce). Confirmed findings go
   back through step 3 as a bounded fix loop — three cycles, then park. Milestones that do
   not depend on each other may run in parallel via `references/worktree.md`.
5. **Accept.** Status → `accepting`. Run the protocol in `references/acceptance.md`: suite
   green, then drive the feature in a real browser — happy path with its success feedback
   in frame, error path, three widths, a full keyboard path, reduced motion emulated,
   console clean — and record each item with `program.sh evidence add --file <artifact>`.
   Then `program.sh accept --id <id>`: exit 0 closes the milestone; exit 2 lists what is
   missing, and you go and produce it — never edit the evidence file by hand. Every state
   the charter promised (skeleton, toast, progress) is checked against what shipped: a
   mismatch is a fix or a recorded charter amendment, never a silent downgrade.
6. **Finish.** With git-workflow installed, offer `/git-workflow:finish` as the skill
   describes; else offer merge / keep / PR via AskUserQuestion. Under hands-off or headless,
   keep the branch and record the next command. Merging to the base branch is the user's
   act, never yours.

### Close

When every milestone is done or parked: print the board, the decisions made on the
user's behalf, the parked items with reasons, and every deferred suggestion — the
charter's list plus anything the milestone findings parked. Then `program.sh close`,
which archives the program under `.claude/overseer/archive/` (the record is kept; a new
`/overseer:start` may follow). Never delete the program dir by hand.

## Decisions live in one file

`decisions.md` is where the user reads what was decided for them; a decision recorded
anywhere else is hidden. Record with `program.sh decision add` before acting, whenever you:
answer a Clarify question yourself; change a file outside the milestone's scope (a shared
UI primitive, middleware, a rate limit, a permission model); edit application code in the
main thread; amend a charter promise; or edit this plugin's own references mid-run.
A milestone `findings.md` may point at the row; it never replaces it (**recorded**).

## Prompts are the product

Every worker, reviewer and subagent runs in a fresh context: a prompt that depends on this
conversation is broken. Apply `orchestration:delegation-contracts` when installed; its rules
are restated minimally in `references/dispatch-prompts.md` for when it is not. Name skills by
absolute path, resolved by you; name files by absolute path; state the return shape and the
verify commands; paste the discipline preamble verbatim — `cat` the file into the prompt,
never retype it from memory (a retyped preamble lost a clause per dispatch in the first
simulation, which is what `dispatch check` now catches). A prompt that names a plugin the
scan showed as missing is a prompt that will be ignored — use the fallback.

## Rules with teeth, and rules without

| Rule | Standing |
| --- | --- |
| A milestone cannot reach `done` without tests, browser-happy, browser-error, three viewport, console-clean, keyboard and motion evidence, each backed by a file that still exists | **gate** — `scripts/program.sh accept` exits 2 |
| A hands-off program records at least one ASSUMED decision before its first accept; `--hands-off` carries a reason | **gate** — `program.sh accept` / `init` exit 2 |
| A milestone id, status and evidence kind must be from the fixed vocabularies | **gate** — `program.sh` refuses others |
| A dispatched prompt carries the preamble verbatim, a scope lock, a verify command and an existing skill path | **gate when run** — `program.sh dispatch check`; that you run it is **agent-graded** |
| A fresh session learns a program is open | **hook** — SessionStart, one line, silent otherwise |
| Discover ran before Clarify; Clarify asked nothing the project already answered; CI was inventoried | **agent-graded** — you judge it |
| The evidence describes a real browser run, not a claimed one | **unenforceable** — the script checks that a file exists, not what it shows; the honest residual |
| No application code written in the main thread; every decision in `decisions.md` | **recorded** |

## Anti-patterns

- **Building in the overseer's seat.** Editing components between dispatches; the program
  loses its reviewer.
- **Roadmap theatre.** A charter and ten milestones and no branch — plan then immediately
  deliver the first.
- **Tests-as-acceptance.** A green suite closing a milestone nobody opened in a browser.
- **Question showers.** Four rounds of clarification; ask once, decide the rest, record.
- **Ghost plugins.** A prompt that says "use the laravel skill" in a project where the scan
  found none installed.
- **Silent scope creep.** A milestone that grew a second feature — park the extra as a new
  milestone, keep the branch to its brief.
- **Marketing ahead of the product.** A homepage or summary that names stages, roles or
  counts the other milestones do not ship — the product-truth check in acceptance.md.
