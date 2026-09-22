# overseer

A program-level product owner for long, multi-session, multi-branch builds. You type one
sentence — `/overseer:start "Build a CRM that manages clients"` — and the plugin owns the
rest the way a product manager owns a roadmap: it discovers what the project and the
installed plugins can do, asks one round of questions, writes a milestone roadmap, and
delivers each milestone on its own branch by briefing the pipeline plugins already installed.
It accepts nothing it has not watched work: in a browser where the milestone has a screen,
in a captured run where it has none.

## What it ships

| Artifact | Kind | Does |
| --- | --- | --- |
| `/overseer:start` | command | opens a program: discover → clarify once → charter + roadmap → deliver the first milestone; `--model auto` is the only way a seat the overseer dispatches runs above opus |
| `/overseer:resume` | command | continues an open program in a fresh session from its recorded milestone status |
| `/overseer:status` | command | prints the board — milestones, branches, evidence, next |
| `overseer` | skill | the loop, the product-judgment rules, the acceptance protocol, the prompt templates |
| `hooks/announce.sh` | SessionStart hook | one line when a program is open, silent otherwise |
| `hooks/track-read.sh` | PostToolUse hook (Read) | while a program is open, ledgers each Read as `epoch, session, path` in `.claude/overseer/.reads`; prints nothing |
| `kinds.tsv` | data | milestone kind → the skill groups a gated dispatch must pin before accept, and the evidence profile accept demands (`ui`, the default, or `headless`); read by `program.sh` |
| `scripts/program.sh` | script | the state machine; the only writer of `.claude/overseer/program.json`; `init --model` (tier), `milestone add --kind --size`, `dispatch check` (prompt gate: preamble, scope, verify, skill path, `MODEL:` line within the tier; kinds worker, reader, reviewer, followup; size WARN), `decision add --assumed`, `suggestion add`, `log`, `close` (divergence gate, plugins-used line, archive with evidence paths rewritten) |
| `scripts/capability-scan.sh` | script | which installed plugins (user, project, local scope) cover which phase, the fallback for each gap, and the CI workflows with their trigger branches checked against the base branch |
| `evals/` | eval cases | two scaffolded cases for `claude plugin eval plugins/overseer --scaffold --ablation with-without`: the hands-off rigour pick and the green-suite acceptance refusal; the without-plugin arm is the control the score is measured against (CHANGELOG 0.4.0 carries the measured deltas and their caveats) |
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

`program.sh accept` closes a milestone only when its kind's evidence kinds are recorded,
each backed by a file that exists when recorded and still exists at accept. For a
milestone with a screen that is nine: the suite, types,
lint and build ran green; the happy path (success feedback in frame) and the error path
were driven in a real browser; the feature was walked at 375, 768 and 1280 px; the console
was read clean; the whole path was driven by keyboard; reduced motion was emulated. A green
test suite alone is refused with exit 2 and the list of what is missing. A kind with no
screen — `audit` (a read-only review or research pass), `library` (a script, CLI or package
change) — carries the `headless` evidence profile instead: `tests` plus a `run-log`, the
captured run of the command the milestone exists to make work. Nine browser kinds a
non-UI milestone can never record is how every one of them ended `parked` (measured
2026-09-16). A hands-off program
is refused until at least one ASSUMED decision is recorded. The script checks that files
exist, not what they show — the residual is stated in `skills/overseer/references/acceptance.md`.

## What it composes, and what happens without them

The overseer writes prompts; other plugins do the work. `capability-scan.sh` reports per
phase what is installed, and the skill's `references/capability-map.md` names the inline
fallback for each gap. Best with `taskmaster` (grill → spec → cards; `ultra` for the boost,
`goal-lean`/`goal` for hands-off by rigour), `task-runner` (scope-locked execution, `--tracks`), `git-workflow` (branch
finish), `task-runner` (delegation contracts), the stack plugins (`laravel`, `web-dev`,
`ui-ux`, `testing`, `security`) and the official `playwright` plugin or the Chrome MCP for
the browser walk. With none of them it still runs: specs, cards and reviews inline, workers
dispatched directly — weaker, and said so in the charter.

## Standing of the rules

| Rule | Standing |
| --- | --- |
| no `done` without the kind's evidence kinds (nine with a screen, `tests` + `run-log` headless), each with a file that still exists; hands-off needs a reason and an ASSUMED decision; fixed status and kind vocabularies | **gate** — `scripts/program.sh`, harness `scripts/__tests__/program.test.sh` |
| close refuses two done milestones on branches that contain neither the other until an `integration` milestone is done or `--divergent-ok` records why | **gate** — `program.sh close` exit 2 |
| a milestone of kind K reaches `done` only after a dispatch that passed `dispatch check` (recorded in `dispatch/.gated`, unchanged since) pinned a skill from each of K's groups (`kinds.tsv`) by a path that exists; every required evidence row postdates the last gated worker or follow-up dispatch; `init` refuses a session opened in another project unless `--foreign-session` says why | **gate** — `program.sh accept` / `init` exit 2 |
| a worker prompt carries every line of the discipline preamble verbatim, a scope lock and a verify command; a reader/reviewer prompt a return shape and the read-only statement, no preamble (it is worker discipline); every kind an existing skill path and a `MODEL:` line the program tier allows — nothing above opus unless the program was started `--model auto`, and a worker never `inherit`s | **gate when run** — `program.sh dispatch check`; running it is agent-graded, and a prompt never checked is not part of the record |
| a milestone sized M or larger is briefed to taskmaster; a direct worker on one needs a decision row | **WARN** — `dispatch check --milestone`; the row is recorded |
| each milestone carries a rigour profile (`lean`/`standard`/`adversarial`) scored from six brief signals; a surface kind is never lean; the card index's boost marker agrees with it | **WARN** on form (unset, surface-lean, marker mismatch) — `dispatch check --milestone`; the score is **agent-graded** |
| taskmaster's own red-team and coverage seats follow the session model under `goal`, whatever the overseer's tier | **residual** — hold every seat at opus by starting the session with `claude --model opus` |
| a fresh session learns a program is open | **hook** — SessionStart, one line |
| discover before clarify (CI included); ask only what the project cannot answer; no code in the main thread; every decision in `decisions.md` | **agent-graded** / **recorded** |
| a recorded artifact was opened (`Read`) in this session since it last changed — a screenshot nobody looked at is refused | **gate** — `program.sh evidence add` exit 2 against the Read ledger; fail-open with a WARN when no session id or no Read was tracked |
| what the artifact shows, and that the run behind it was real | **agent-graded** / **unenforceable** — content is judged, provenance is not checkable |

## Limits

- State is machine-local and gitignored; a teammate's clone has no program.
- The session must run from the target project: `taskmaster`, `task-runner`,
  `craft-layer` and every hook are cwd-bound, so a program driven from another directory
  falls back to direct dispatch and inline design direction (both simulations did).
- **A fresh project's first session sees only user-scope plugins.** `enabledPlugins` get
  registered on that start and loaded on the next; the capability scan cannot tell. Open one
  throwaway session (or `/reload-plugins`) before `/overseer:start` in a new project, and
  expect Discover to check the scan against the session's own Skill list (simulation 4).
- **The boost is bought per milestone by rigour, not by size.** taskmaster's
  `ultra`/`goal` marker adds the code red-team, coverage loop-until-dry and tier
  escalation on top of a standard run; the per-card reviewers, the negative control and
  (past three criteria) the spec red-team run without it. In simulation 4 that phase was
  40 of 119 minutes and found the real bugs; the profile (`dispatch-prompts.md` § Rigour)
  says when it is worth it. Hands-off buys it the same way: `goal-lean` (taskmaster
  ≥0.42.1, task-runner ≥0.32.0) for lean and standard milestones, `goal` for adversarial;
  on an older pipeline `goal` is the only autonomous token and the cost is a decision row.
- **One milestone per session is the cheap shape.** The main thread, not the workers, held
  three quarters of simulation 4's tokens; `accept` prints the next milestone and the rule
  (hands-off: continue here; interactive: continue now or `/overseer:resume` fresh).
- A plugin installed from a git marketplace is a cache snapshot: an edit during a program
  reaches the hook and the skill only after a reinstall. A directory marketplace whose
  plugin entry is a symlink is live — `${CLAUDE_PLUGIN_ROOT}` resolved to the working tree
  in simulation 3, so an edit mid-run changes the script the running program calls.
- Merge and PR are never taken by the overseer — offered, or left as the next command.
- A dependency the target project's own `CLAUDE.md` forbids is not added, however
  convenient; the charter records the suggestion instead.
