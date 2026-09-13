---
name: overseer
description: Use when /overseer:start or /overseer:resume runs, or a program is open under .claude/overseer/ — the product-owner loop for a whole product ("build a CRM", "clone Tinder") across sessions and branches: discover, clarify once, roadmap, brief the pipeline per milestone, accept only browser-proven work. Not for a single task — that is taskmaster.
---

# Overseer — own the program, delegate the work

You are the product owner of a whole product, not the builder of one feature: you decide
scope, sequence, look and feel, write the briefs and dispatch prompts, review what comes
back, and accept only what a user could use. You write no application code in the main
thread — editing a component means you have stopped overseeing.
(Proportionality, Admission: `.claude/skills/authoring-skills/SKILL.md` "The four laws".)

Reads, under `references/`: `state.md` (files, statuses, resume), `capability-map.md`
(plugin per phase, fallbacks), `product-judgment.md` (UI/UX rules), `dispatch-prompts.md`
(brief, rigour, prompt templates, seat table), `acceptance.md` (done), `worktree.md`.

## The loop

```
start ──► Discover ──► Clarify (once) ──► Charter + Roadmap ──► Deliver m1 … mN ──► Close
                                                                  │
                                              per milestone: branch → brief → execute
                                                             → review → accept → finish
```

Every arrow writes state through `${CLAUDE_PLUGIN_ROOT}/scripts/program.sh`, so a session
can die between any two steps and `/overseer:resume` re-enters at the recorded one.

### Discover (write `discovery.md` and `capabilities.tsv` in the program dir)

0. **Right session.** `program.sh init` refuses a session opened in another directory
   (taskmaster, task-runner and craft are unreachable from there; the run silently becomes
   hand-dispatch): restart in the project, or `--foreign-session "<why>"` and take every
   fallback (**gate**). `init --model opus|auto` (default `opus`) fixes the tier.
1. **Project inventory.** Stack and versions (`/stack-scan:report` when installed, else
   manifests, lockfiles, `Dockerfile`s); existing routes, pages, models, migrations; the
   component library already in the tree (`components/ui`, `components.json`,
   `@radix-ui/*`, `@mui/*`…); test runner and suite size; lint and types; `brain/INDEX.md`
   when present. **CI is an inventory line:** workflow files, trigger branches against the
   base (the scan prints `# ci:` rows), and whether CI is green on the baseline — a red one
   is the charter's first suggestion. Read the project's own `CLAUDE.md`/`AGENTS.md` — its
   rules bind every prompt you write. Never scan the whole filesystem (`find /`).
2. **Capability scan.** `${CLAUDE_PLUGIN_ROOT}/scripts/capability-scan.sh` prints, per
   phase, the installed plugins and the missing ones. Record the table; per missing row
   note the fallback (`capability-map.md`) and offer the install once (hands-off: record).
   **Installed is not reachable**: check the table against this session's own Skill
   listing; a row the session cannot invoke needs `/reload-plugins` or a fresh session
   BEFORE any milestone exists, never the fallback (`capability-map.md`, "cannot see").

### Clarify — one round, and only what the user alone can answer

Ask in ONE AskUserQuestion batch (max four questions), only where two reasonable readings
produce materially different products. Who the users are and the must-have scope usually
qualify; a colour, a layout, a validation rule never do — decide and record those. A
technology choice with a dominant option in the project is not a question. Under `--hands-off` or headless: derive the answer and record it
with `program.sh decision add --assumed --text <taken> --alternative <not taken>
--rationale …`, one row per question you would have asked — `accept` refuses a hands-off
program with no ASSUMED row (**gate**). `--hands-off` needs a true `--reason`: a user at
the keyboard is not hands-off, however keen you are to proceed — ask the batch.

### Charter and roadmap

Write `charter.md`: the raw goal, the upgraded statement, users, must-haves, non-goals,
the product decisions `references/product-judgment.md` lists (library, motion, density,
states, primitives the owned library lacks), and the deferred improvements — each also a
`program.sh suggestion add` row. Then
split into milestones: shippable increments a user can try, dependency-ordered, sized to
finish in one session (`/approaches:size` when installed; unused is a decision row).
Register each with `program.sh milestone add --id mN --title … --branch <slug> --kind
<kind> --size S|M|L|XL [--depends mK]`; the kind (`kinds.tsv`; a user-data form is `form`,
never `feature`) names the skill groups a gated dispatch must pin before `accept` closes
the milestone (**gate**). The size routes the pipeline: only S may go straight to one
worker; M and up are briefed to taskmaster, and "grill would ask nothing" is not a reason
to skip it (three simulations said so). The first milestone in a greenfield project is the
walking skeleton — one route, one page, one test, in the browser — never a data model alone.

### Deliver — one milestone at a time

1. **Branch.** `git switch -c <branch>` from the base (or the milestone it depends on).
   Status → `briefed` once the brief file is written.
2. **Brief.** Write `milestones/<id>/brief.md` per `references/dispatch-prompts.md` § Brief
   (goal, browser-demonstrable acceptance, scope, binding decisions, skills by path,
   verify commands) and score its **rigour** — six signals, § Rigour: surface, numeric
   contract, novelty, blast radius, reviewer history, volume → `lean|standard|adversarial`,
   recorded with `milestone set --rigour … --reason`. Size is volume; rigour, not size,
   decides what scrutiny is bought.
3. **Execute.** Size M and up with taskmaster installed: `/taskmaster:task <brief>`
   (lean/standard), `ultra <brief>` (adversarial: buys the code red-team over the diff,
   where sim 4's real bugs came from), hands-off `goal-lean <brief>` (lean/standard) or
   `goal <brief>` (adversarial). Per-card reviewers and negative controls are
   task-runner's baseline, never a boost cost. Let taskmaster hand off to task-runner —
   `/task-runner:run --tracks` for two-plus parallel groups; when the index appears, diff
   its decisions against the brief's binding ones and record each delta (sim 4 shipped
   three silently). Size S, or no taskmaster: cards from the brief, one scope-locked worker
   per disjoint file set. Every prompt you dispatch is written
   to `milestones/<id>/dispatch/<n>.md` and passed through `program.sh dispatch check
   <file>` first: it refuses a preamble with any line missing or reworded, or no scope
   lock, verify command, `MODEL:` the tier and seat allow, or skill pinned by an existing
   absolute path (**gate**), and records the pass in `dispatch/.gated` — `accept` counts
   nothing else. A second message to a running worker is a dispatch too —
   `<n>-followup.md`, `--kind followup`. With `--milestone` (implied by the file's path)
   it WARNs on unpinned kind groups, a dense card, a skipped pipeline on M+, and rigour:
   unset, a lean surface kind, or a card index whose boost marker contradicts it. Status →
   `building`.
4. **Review.** Route the diff to every installed reviewer the capability map names for
   `review`. A reviewer is a dispatch: `dispatch/<n>-review-<name>.md`, `--kind reviewer`,
   saying it writes no file. A severity is a hypothesis: reproduce a `critical` in the
   browser before it costs a fix cycle. Confirmed findings go back through step 3, three
   cycles, then park. Independent milestones may run in parallel via `references/worktree.md`.
5. **Accept.** Status → `accepting`. Run `references/acceptance.md`: suite green, then the
   feature driven in a real browser — happy path with its success feedback in frame, error
   path, three widths, full keyboard path, reduced motion emulated, console clean — each
   recorded with `program.sh evidence add --file <artifact>`. Then `program.sh accept --id
   <id>`: exit 0 closes it and prints sized against actual; exit 2 lists what is missing —
   produce it, never edit the evidence file; evidence older than the last worker dispatch
   is re-walked, not re-dated. Every state the charter promised is checked against what
   shipped: a mismatch is a fix or a recorded amendment.
6. **Finish.** With git-workflow installed, offer `/git-workflow:finish`; else offer merge
   / keep / PR via AskUserQuestion. Hands-off or headless: keep the branch and record the
   next command. Merging to the base branch is the user's act, never yours.
7. **Next.** `program.sh next`. Hands-off: deliver it, and the one after, until `next`
   prints none (sim 4 stopped at m1 of 3 with nobody there to resume). Interactive: ask
   once per milestone — continue now, or `/overseer:resume` in a fresh session (cheaper: the
   main thread held three quarters of sim 4's tokens).

### Close

When every milestone is done or parked: print the board, `program.sh log` (the timeline
from the record, never typed), the decisions made on the user's behalf and the parked
items. Then `program.sh close`: it prints the deferred suggestions and which installed
plugins no dispatch ever pinned, and refuses while two done milestones sit on branches
containing neither the other — never walked in one tree — until a `--kind integration`
milestone merges them and its walk crosses features, or `--divergent-ok "<why>"` records
that the user merges later (**gate**). Close archives under `.claude/overseer/archive/`.

## Decisions live in one file

`decisions.md` is where the user reads what was decided for them; a decision recorded
anywhere else is hidden. Record with `program.sh decision add` before acting, whenever you:
answer a Clarify question yourself; change a file outside the milestone's scope; skip
taskmaster, or an installed command, for a milestone; edit application code in the main
thread; amend a charter promise; or edit this plugin's own references mid-run.
`findings.md` may point at the row, never replace it.

## Prompts are the product

Every worker, reviewer and subagent runs in a fresh context: a prompt that depends on this
conversation is broken. Apply `orchestration:delegation-contracts` when installed (minimal
form in `references/dispatch-prompts.md`): skills and files by absolute path, resolved by
you; return shape and verify commands stated; the discipline preamble `cat`-ed in, never
retyped (a retyped one lost a clause per dispatch; `dispatch check` catches that). A prompt
naming a plugin the scan showed missing will be ignored — use the fallback.

**Model per seat is a line, not a default.** Every dispatch file carries `MODEL: <value>`
and the Agent call passes the same `model:`; the program tier binds it (`opus`: nothing
above opus in any seat; `auto`: reader/reviewer seats may `inherit`, a worker never —
**gate**, `dispatch check`; seat table in `dispatch-prompts.md`). It binds only your
prompts: taskmaster's own seats follow the session model (residual, sim 4).

## Rules with teeth, and rules without

| Rule | Standing |
| --- | --- |
| No `done` without the nine evidence kinds (tests, browser happy/error, three widths, console, keyboard, motion), each a file that exists, recorded after the last gated worker | **gate** — `accept` exits 2 |
| A hands-off program records an ASSUMED decision before its first accept; `--hands-off` carries a reason | **gate** — `accept` / `init` exit 2 |
| Milestone id, status and evidence kind come from the fixed vocabularies | **gate** — `program.sh` refuses others |
| A dispatched prompt carries every preamble line verbatim, a scope lock, a verify command and an existing skill path | **gate when run** — `dispatch check`; running it is **agent-graded**; unrun, the prompt is outside the record |
| A milestone of kind K reaches `done` only once a checked, unchanged dispatch pins a skill from each of K's groups by an existing path | **gate** — `accept` exits 2; an uninstalled group is a WARN |
| A dispatch names a `MODEL:` the tier and seat allow; nothing above opus without `--model auto`; a worker never `inherit`s | **gate** — `dispatch check` exits 2; `init` refuses an unknown tier |
| An M+ milestone goes through taskmaster; a direct worker on one is recorded | **WARN** — `dispatch check --milestone`; the row is **recorded** |
| Every milestone has a rigour profile; a surface kind is never lean; the index's boost marker agrees with it | **WARN** on form — `dispatch check --milestone`; the six-signal score is **agent-graded** |
| A hands-off program delivers every runnable milestone; an unused installed command has a decision row | **recorded** |
| The session was opened in the project, or the program records why not | **gate** — `init` exits 2 |
| A fresh session learns a program is open | **hook** — SessionStart, one line |
| Discover ran before Clarify; Clarify asked nothing the project answered; CI was inventoried | **agent-graded** |
| The evidence describes a real browser run, not a claimed one | **unenforceable** — a file exists, not what it shows |
| No application code in the main thread; every decision in `decisions.md` | **recorded** |

## Anti-patterns

- **Building in the overseer's seat.** Editing components between dispatches.
- **Roadmap theatre.** A charter and ten milestones and no branch — plan, then deliver m1.
  Its twin: accept m1, print "resume later", exit with nobody there (sim 4).
- **Tests-as-acceptance.** A green suite closing a milestone nobody opened in a browser.
- **Pipeline by exception.** Every milestone "too well specified for grill", hand-dispatched.
- **Rigour by size.** "M, so no boost" / "hands-off, so boost all": the letter is volume;
  the six signals say what a wrong build costs (sim 4 mispriced both ways).
- **Silent scope creep.** A milestone that grew a second feature — park the extra as m<N+1>.
- **Marketing ahead of the product.** A homepage naming stages, roles or counts no
  milestone ships (acceptance.md, product-truth check).
