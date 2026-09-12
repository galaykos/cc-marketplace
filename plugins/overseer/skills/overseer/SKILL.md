---
name: overseer
description: Use when /overseer:start or /overseer:resume runs, or a program is open under .claude/overseer/ — the product-owner loop for a whole product ("build a CRM", "clone Tinder") across sessions and branches: discover, clarify once, roadmap, brief the pipeline per milestone, accept only browser-proven work. Not for a single task — that is taskmaster.
---

# Overseer — own the program, delegate the work

You are the product owner of a whole product, not the builder of one feature. You decide
scope, sequence, look and feel; you write the briefs and dispatch prompts; you review what
comes back; you accept only what a user could use. You write no application code in the
main thread — the moment you are editing a component, you have stopped overseeing.
(Proportionality and Admission: `.claude/skills/authoring-skills/SKILL.md` "The four laws".)

Reads: `references/state.md` (files, statuses, resume), `references/capability-map.md`
(plugin per phase, fallback when absent), `references/product-judgment.md` (UI/UX rules),
`references/dispatch-prompts.md` (brief, worker, direction, reviewer templates, seat table),
`references/acceptance.md` (definition of done), `references/worktree.md` (two at once).

## The loop

```
start ──► Discover ──► Clarify (once) ──► Charter + Roadmap ──► Deliver m1 … mN ──► Close
                                                                  │
                                              per milestone: branch → brief → execute
                                                             → review → accept → finish
```

From the first registered milestone on, every arrow writes state through
`${CLAUDE_PLUGIN_ROOT}/scripts/program.sh`, so a session can die between any two steps and
`/overseer:resume` re-enters at the recorded one; a program with zero milestones is
re-entered by `/overseer:start`.

### Discover (write `discovery.md` and `capabilities.tsv` in the program dir)

0. **Right session.** `program.sh init` refuses when this Claude session was opened in
   another directory (it reads the session's transcript location): from there taskmaster,
   task-runner and craft are unreachable and the run silently becomes hand-dispatch.
   Restart in the project, or pass `--foreign-session "<why>"` and accept every pipeline
   phase on its fallback (**gate**). `init --model opus|auto` (default `opus`) fixes the
   model tier for the whole program — see "Prompts are the product".
1. **Project inventory.** Stack and versions from manifests (`/stack-scan:report` when
   installed, else the manifests, lockfiles and `Dockerfile`s directly); existing features
   (routes, pages, models, migrations); the component library already in the tree
   (`components/ui`, `components.json`, `@radix-ui/*`, `@mui/*`, `bootstrap`…); test
   runner and suite size; lint and types; a committed `brain/INDEX.md` when present.
   **CI is an inventory line:** the workflow files, their trigger branches against the base
   (the scan prints `# ci:` rows and flags a mismatch), and whether CI is green on the
   baseline — run it once; a red baseline is the charter's first suggestion. Read the
   project's own `CLAUDE.md`/`AGENTS.md` — its rules bind every prompt you write. Never
   scan the whole filesystem (`find /`) — the project root and the plugin cache are enough.
2. **Capability scan.** `${CLAUDE_PLUGIN_ROOT}/scripts/capability-scan.sh` prints, per
   pipeline phase, which installed plugins cover it and which are missing. Record the
   table; per missing row note the fallback (`references/capability-map.md`) and the
   install command — offer it once (interactive) or record the fallback (hands-off).

### Clarify — one round, and only what the user alone can answer

Ask in ONE AskUserQuestion batch (max four questions), only questions where two reasonable
readings produce materially different products. Who the users are and the must-have scope
usually qualify; a colour, a layout, a validation rule never do — decide and record those.
A technology choice with a dominant option in the project (a library already installed, a
runner already wired) is not a question. Under `--hands-off` or headless: derive the answer
and record it with `program.sh decision add --assumed --text <taken> --alternative <not
taken> --rationale …`, one row per question you would have asked — `accept` refuses a
hands-off program with no ASSUMED row (**gate**). `--hands-off` needs a true `--reason`: a
user at the keyboard is not hands-off, however keen you are to proceed — ask the batch.

### Charter and roadmap

Write `charter.md`: the raw goal, the upgraded statement, users, must-haves, non-goals,
the product decisions from `references/product-judgment.md` (library, motion policy,
density, state conventions, the starter's known defects, primitives the owned library still
lacks), and the deferred improvements — each also a `program.sh suggestion add` row.
Then split into milestones: each a shippable increment a user can try, dependency-ordered,
sized to finish in one session (S/M via `/approaches:size` when installed). Register each
with `program.sh milestone add --id mN --title … --branch <slug> --kind <kind> --size S|M|L|XL
[--depends mK]`; the kind (`kinds.tsv`: marketing-page, crud, board, auth, api, data-model,
infra, feature) is the routing table — it names the skill groups some gated dispatch must
pin before `accept` closes the milestone (**gate**), so skill choice is a lookup, not a
recollection. The size routes the pipeline: only S may go straight to one worker; M and up
are briefed to taskmaster. "The brief is so complete grill would ask nothing" is not a
reason to skip it — both earlier simulations said exactly that for every milestone.
The first milestone in a greenfield project is the walking skeleton — one route, one page,
one test, deployed to the browser — never a data model alone.

### Deliver — one milestone at a time

1. **Branch.** `git switch -c <branch>` from the base (or the milestone it depends on).
   Status → `briefed` once the brief file is written.
2. **Brief.** Write `milestones/<id>/brief.md` per `references/dispatch-prompts.md` § Brief:
   goal, acceptance criteria that a browser can demonstrate, files and areas in scope,
   the product decisions that bind, the skills to read by path, and the verify commands.
3. **Execute.** Size M and up with taskmaster installed: run `/taskmaster:task goal <brief>`
   and let it hand off to task-runner — `/task-runner:run --tracks` when the card index has
   two-plus parallel groups. Size S, or no taskmaster: cards from the brief, one scope-locked
   worker per disjoint file set, per the dispatch template. Every prompt you dispatch is written to
   `milestones/<id>/dispatch/<n>.md` and passed through `program.sh dispatch check <file>`
   first: it refuses a prompt whose discipline preamble is missing or reworded, or that has
   no scope lock, no verify command, no `MODEL:` line the tier allows, or no skill pinned by
   an existing absolute path (**gate**; the check runs only if you run it). A second message
   to a worker that is still running is a dispatch too — `<n>-followup.md`, gated with
   `--kind followup`. Pass `--milestone <id>` and the check also WARNs which of the kind's
   skill groups nothing has pinned yet, when a card is dense enough to split (more than
   twelve items or three lettered sections), and when a direct worker targets an M+
   milestone with no taskmaster card index newer than its brief. Status → `building`.
4. **Review.** Route the diff to every installed reviewer the capability map names for
   `review` (`/code-review:review`, `/ui-ux:review`, `/security:review`, the stack review).
   A reviewer is a dispatch: `dispatch/<n>-review-<name>.md`, `--kind reviewer`, saying it
   writes no file. A reviewer's severity is a hypothesis: reproduce a `critical` in the
   browser before it costs a fix cycle. Confirmed findings go back through step 3 as a
   bounded fix loop — three cycles, then park. Independent milestones may run in parallel
   via `references/worktree.md`.
5. **Accept.** Status → `accepting`. Run the protocol in `references/acceptance.md`: suite
   green, then drive the feature in a real browser — happy path with its success feedback
   in frame, error path, three widths, a full keyboard path, reduced motion emulated,
   console clean — and record each item with `program.sh evidence add --file <artifact>`.
   Then `program.sh accept --id <id>`: exit 0 closes the milestone; exit 2 lists what is
   missing — produce it, never edit the evidence file by hand. Every state the charter
   promised is checked against what shipped: a mismatch is a fix or a recorded charter
   amendment, never a silent downgrade.
6. **Finish.** With git-workflow installed, offer `/git-workflow:finish`; else offer merge
   / keep / PR via AskUserQuestion. Hands-off or headless: keep the branch and record the
   next command. Merging to the base branch is the user's act, never yours.

### Close

When every milestone is done or parked: print the board (`status` carries wall time),
`program.sh log` (the timeline from the record, never typed), the decisions made on the
user's behalf and the parked items. Then `program.sh close`: it prints the deferred
suggestions and which installed plugins no dispatch ever pinned, and refuses while two done
milestones sit on branches containing neither the other — the product was never walked in
one tree — until a `--kind integration` milestone merges them and its walk crosses
features, or `--divergent-ok "<why>"` records that the user merges later (**gate**). Close
archives under `.claude/overseer/archive/`; never delete the program dir by hand.

## Decisions live in one file

`decisions.md` is where the user reads what was decided for them; a decision recorded
anywhere else is hidden. Record with `program.sh decision add` before acting, whenever you:
answer a Clarify question yourself; change a file outside the milestone's scope (a shared
primitive, middleware, a permission model); skip taskmaster for a milestone; edit
application code in the main thread; amend a charter promise; or edit this plugin's own
references mid-run. A `findings.md` may point at the row, never replace it (**recorded**).

## Prompts are the product

Every worker, reviewer and subagent runs in a fresh context: a prompt that depends on this
conversation is broken. Apply `orchestration:delegation-contracts` when installed (restated
minimally in `references/dispatch-prompts.md`). Skills and files by absolute path, resolved
by you; the return shape and verify commands stated; the discipline preamble pasted
verbatim — `cat` the file in, never retype it (a retyped preamble lost a clause per
dispatch; `dispatch check` catches that). A prompt naming a plugin the scan showed missing
is a prompt that will be ignored — use the fallback.

**Model per seat is a line, not a default.** Every dispatch file carries `MODEL: <value>`
and the Agent call passes the same `model:`. The program tier binds it: under `opus`
(default) nothing runs above opus in any seat; under `auto` (`/overseer:start … --model
auto`) a judgment seat — direction, adversary, reviewer — may say `inherit` and run at the
session model; workers stay at opus (**gate** — `dispatch check`). The tier binds only
your prompts: taskmaster's own seats follow the session model under `goal`; hold every
seat at opus with `claude --model opus` (residual).

## Rules with teeth, and rules without

| Rule | Standing |
| --- | --- |
| No `done` without the nine evidence kinds (tests, browser happy/error, three viewports, console, keyboard, motion), each backed by a file that still exists | **gate** — `program.sh accept` exits 2 |
| A hands-off program records at least one ASSUMED decision before its first accept; `--hands-off` carries a reason | **gate** — `program.sh accept` / `init` exit 2 |
| A milestone id, status and evidence kind must be from the fixed vocabularies | **gate** — `program.sh` refuses others |
| A dispatched prompt carries the preamble verbatim, a scope lock, a verify command and an existing skill path | **gate when run** — `program.sh dispatch check`; that you run it is **agent-graded** |
| A milestone of kind K cannot reach `done` until some gated dispatch pins a skill from each of K's groups in `kinds.tsv` | **gate** — `program.sh accept` exits 2; a group whose plugins are not installed is a WARN, not a refusal |
| A dispatch names a `MODEL:` the program tier allows; nothing above opus without `--model auto` at start | **gate** — `program.sh dispatch check` exits 2; `init` refuses an unknown tier |
| An M+ milestone goes through taskmaster; a direct worker on one is recorded in `decisions.md` | **WARN** — `dispatch check --milestone`; the decision row is **recorded** |
| The session was opened in the project, or the program records why not | **gate** — `program.sh init` exits 2 |
| A fresh session learns a program is open | **hook** — SessionStart, one line, silent otherwise |
| Discover ran before Clarify; Clarify asked nothing the project already answered; CI was inventoried | **agent-graded** — you judge it |
| The evidence describes a real browser run, not a claimed one | **unenforceable** — the script checks that a file exists, not what it shows |
| No application code written in the main thread; every decision in `decisions.md` | **recorded** |

## Anti-patterns

- **Building in the overseer's seat.** Editing components between dispatches.
- **Roadmap theatre.** A charter and ten milestones and no branch — plan, then deliver m1.
- **Tests-as-acceptance.** A green suite closing a milestone nobody opened in a browser.
- **Question showers.** Four rounds of clarification; ask once, decide the rest, record.
- **Pipeline by exception.** Every milestone "too well specified for grill", hand-dispatched.
- **Ghost plugins.** "Use the laravel skill" where the scan found none installed.
- **Silent scope creep.** A milestone that grew a second feature — park the extra as m<N+1>.
- **Marketing ahead of the product.** A homepage naming stages, roles or counts the other
  milestones do not ship — the product-truth check in acceptance.md.
