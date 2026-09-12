# overseer

A program-level product owner for long, multi-session, multi-branch builds. You type one
sentence — `/overseer:start "Build a CRM that manages clients"` — and the plugin owns the
rest the way a product manager owns a roadmap: it discovers what the project and the
installed plugins can do, asks one round of questions, writes a milestone roadmap, and
delivers each milestone on its own branch by briefing the pipeline plugins already installed.
It accepts nothing it has not watched work in a browser.

## What it ships

| Artifact | Kind | Does |
| --- | --- | --- |
| `/overseer:start` | command | opens a program: discover → clarify once → charter + roadmap → deliver the first milestone |
| `/overseer:resume` | command | continues an open program in a fresh session from its recorded milestone status |
| `/overseer:status` | command | prints the board — milestones, branches, evidence, next |
| `overseer` | skill | the loop, the product-judgment rules, the acceptance protocol, the prompt templates |
| `hooks/announce.sh` | SessionStart hook | one line when a program is open, silent otherwise |
| `scripts/program.sh` | script | the state machine; the only writer of `.claude/overseer/program.json`; also `dispatch check` (prompt gate; kinds worker, reader, reviewer, followup), `decision add --assumed`, `close` (archive, evidence paths rewritten) |
| `scripts/capability-scan.sh` | script | which installed plugins (user, project, local scope) cover which phase, the fallback for each gap, and the CI workflows with their trigger branches checked against the base branch |
| `scripts/skill-path.sh` | script | the absolute `SKILL.md` path to pin in a prompt, resolved through the CLI's install path (cache fallback names its route) |

## The loop

```
/overseer:start "goal"
  Discover   project inventory + capability scan            → discovery.md, capabilities.tsv
  Clarify    ONE AskUserQuestion batch, only what the user alone can answer
  Charter    users, must-haves, non-goals, product decisions → charter.md
  Roadmap    shippable milestones, dependency-ordered        → program.sh milestone add
  Deliver    per milestone: branch → brief → taskmaster/task-runner → reviewers → accept → finish
  Close      board, decisions taken for you, parked items, suggested improvements
```

Each step writes state, so the session can end anywhere and `/overseer:resume` picks up.

## What "done" means here

`program.sh accept` closes a milestone only when nine evidence kinds are recorded, each
backed by a file that exists when recorded and still exists at accept: the suite, types,
lint and build ran green; the happy path (success feedback in frame) and the error path
were driven in a real browser; the feature was walked at 375, 768 and 1280 px; the console
was read clean; the whole path was driven by keyboard; reduced motion was emulated. A green
test suite alone is refused with exit 2 and the list of what is missing. A hands-off program
is refused until at least one ASSUMED decision is recorded. The script checks that files
exist, not what they show — the residual is stated in `skills/overseer/references/acceptance.md`.

## What it composes, and what happens without them

The overseer writes prompts; other plugins do the work. `capability-scan.sh` reports per
phase what is installed, and the skill's `references/capability-map.md` names the inline
fallback for each gap. Best with `taskmaster` (grill → spec → cards, hands-off via
`ultra-goal`), `task-runner` (scope-locked execution, `--tracks`), `git-workflow` (branch
finish), `orchestration` (delegation contracts), the stack plugins (`laravel`, `web-dev`,
`ui-ux`, `testing`, `security`) and the official `playwright` plugin or the Chrome MCP for
the browser walk. With none of them it still runs: specs, cards and reviews inline, workers
dispatched directly — weaker, and said so in the charter.

## Standing of the rules

| Rule | Standing |
| --- | --- |
| no `done` without the nine evidence kinds, each with a file that still exists; hands-off needs a reason and an ASSUMED decision; fixed status and kind vocabularies | **gate** — `scripts/program.sh`, harness `scripts/__tests__/program.test.sh` |
| a dispatched prompt carries the discipline preamble verbatim, a scope lock, a verify command, an existing skill path | **gate when run** — `program.sh dispatch check`; running it is agent-graded |
| a fresh session learns a program is open | **hook** — SessionStart, one line |
| discover before clarify (CI included); ask only what the project cannot answer; no code in the main thread; every decision in `decisions.md` | **agent-graded** / **recorded** |
| the recorded browser evidence describes a real run | **unenforceable** — file existence is checked, content is not |

## Limits

- State is machine-local and gitignored; a teammate's clone has no program.
- The session must run from the target project: `taskmaster`, `task-runner`,
  `craft-layer` and every hook are cwd-bound, so a program driven from another directory
  falls back to direct dispatch and inline design direction (both simulations did).
- An installed copy of this plugin is a cache snapshot; a plugin edit during a program
  reaches the hook and the skill only after a reinstall.
- Merge and PR are never taken by the overseer — offered, or left as the next command.
- A dependency the target project's own `CLAUDE.md` forbids is not added, however
  convenient; the charter records the suggestion instead.
