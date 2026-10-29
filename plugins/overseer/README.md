# overseer

A program-level product owner for long, multi-session, multi-branch builds. You type one
sentence: `/overseer:start "Build a CRM that manages clients"`. The plugin owns the rest,
the way a product manager owns a roadmap. It discovers what the project and the installed
plugins can do. It asks one round of questions and writes a milestone roadmap. It delivers
each milestone on its own branch by briefing the plan-and-build plugins already installed.
It accepts nothing it has not watched work. Where the milestone has a screen, it watches in
a browser; where it has none, in a captured run.

**Not sure where to start? Start with `/work <what you want done>`** (or `/code-architecture:work`): it sends a whole product here and anything smaller to a spec or an inline change.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install overseer@cc-plugins-marketplace
```

## What it ships

| Artifact | Kind | Does |
| --- | --- | --- |
| `/overseer:start` | command | opens a program: discover → clarify once → charter + roadmap → deliver the first milestone; `--model auto` is the only way a seat the overseer dispatches runs above opus |
| `/overseer:resume` | command | prints the five-line resume first, then continues an open program in a fresh session from its recorded milestone status |
| `/overseer:status` | command | prints the board — milestones, branches, evidence, next |
| `overseer` | skill | the loop, the product-judgment rules, the acceptance protocol, the prompt templates |
| `hooks/announce.sh` | SessionStart hook | one line when a program is open, silent otherwise |
| `hooks/track-read.sh` | PostToolUse hook (Read) | while a program is open, ledgers each Read as `epoch, session, path` in `.claude/overseer/.reads`; prints nothing |
| `hooks/status-line.ts` | hooks module (Claude Code ≥ 2.1.291) | pins the next open milestone as a status line under the prompt; see Mods |
| `kinds.tsv` | data | milestone kind → the skill groups a gated dispatch must pin before accept, and the evidence profile accept demands (`ui`, the default, or `headless`); read by `program.sh` |
| `scripts/program.sh` | script | the state machine; the only writer of `.claude/overseer/program.json`; `init --model` (tier), `milestone add --kind --size`, `dispatch check` (prompt gate: preamble, scope, verify, skill path, `MODEL:` line within the tier; kinds worker, reader, reviewer, followup; size WARN), `decision add --assumed`, `suggestion add`, `log`, `resume` (five plain lines on where the program stands), `close` (divergence gate, plugins-used line, archive with evidence paths rewritten) |
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

## Coming back to a program

`program.sh resume` prints where the program stands in five plain lines of at most 100
characters each, read from the state files. `/overseer:resume` runs it first and shows the
lines before anything else. It runs only when you ask: the SessionStart hook still prints
its one line and nothing more.

```
Program: Build a CRM that manages clients — 1/3 milestones done
Now: m2 Client import from CSV — being built, branch overseer/m2-import
Next: check the workers or dispatch the brief for m2
Last decision: Client lists use the shadcn data table already in the tree
Open: 2 suggestions, 0 parked milestones — .claude/overseer/suggestions.md, program.json
```

- **Program**: the goal, cut at a word to fit, and how many milestones are done (and parked,
  when any).
- **Now**: the milestone in progress (briefed, building or accepting), else the next one that
  can start, with its status in plain words and its branch. When none can start, what the
  first open one waits on; when all are done or parked, that.
- **Next**: one action from that status: start it (queued), check the workers or dispatch the
  brief (briefed, building), run accept (accepting), close the program (all done or parked).
- **Last decision**: the newest row of `decisions.md`, cut to fit.
- **Open**: deferred suggestions in `suggestions.md`, parked milestones in `program.json`.

With no program it prints one line saying so. A missing `decisions.md` or `suggestions.md`,
or a `program.json` that is not valid, is named on the line that needed it. It writes
nothing and always exits 0. **Standing: gate** — `scripts/__tests__/program.test.sh` holds
each line to its shape and length; whether the lines are enough to pick the work up again
is not tested.

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
non-UI milestone can never record is how every one of them ended `parked`. A hands-off
program
is refused until at least one ASSUMED decision is recorded. The script checks that files
exist, not what they show — the residual is stated in `skills/overseer/references/acceptance.md`.

Once a milestone is accepted, `accept` prints what it took. Both lines count from one start:
the earliest of the milestone's briefed and building times and the time `dispatch check`
gated its first dispatch (stored in `dispatch/.gated` since 0.7.4; an older row has none).
The first line is the roadmap size beside the actual dispatches, diff and minutes. The second
is the process cost, measured from this session's transcript and its agent transcripts
(`subagents/agent-*.jsonl`, and `subagents/workflows/*/agent-*.jsonl` for Workflow agents):

```
Process cost since 14:02: 6 agents · 1.84M tokens (main 0.41M, subagents 1.43M; 87% cache reads) · 38 min
```

Every record from the start on counts by its own timestamp, once per message across the
files; **agents** are the agent transcripts holding at least one counted record. It shows no
prices, and compaction writes no usage record, so its tokens are missing. A milestone
delivered across sessions shows only the session that accepts it. The Workflow layout was
read on a CLI 2.1.295 session only; that 2.1.310 writes it the same way is assumed. When the
transcript cannot be read the line says `Process cost: unknown — <reason>` and accept still
exits 0. **Standing: recorded** — it reports and gates nothing.

## What it composes, and what happens without them

The overseer writes prompts; other plugins do the work. `capability-scan.sh` reports per
phase what is installed, and the skill's `references/capability-map.md` names the inline
fallback for each gap. Best with `taskmaster` (grill → spec → cards; `ultra` for the boost,
`goal-lean`/`goal` for hands-off by rigour), `task-runner` (scope-locked execution, `--tracks`), `git-workflow` (branch
finish), `task-runner` (delegation contracts), the stack plugins (`laravel`, `web-dev`,
`ui-ux`, `testing`, `security`) and the official `playwright` plugin or the Chrome MCP for
the browser walk. With none of them it still runs: specs, cards and reviews inline, workers
dispatched directly — weaker, and said so in the charter.

## Mods (Claude Code ≥ 2.1.291)

Since 0.6.0 the plugin also ships a hooks module, `hooks/status-line.ts`, listed under
`modules` in `hooks/hooks.json` beside the classic hooks (`announce.sh`, `track-read.sh`),
which fire with or without it. It reads `program.json` and writes nothing.

- **Status line.** While `.claude/overseer/program.json` (at the git toplevel of the
  session's directory) names a next milestone, one line is pinned under the prompt:
  `overseer  milestone <k>/<n>  <id> <title> (<status>)` — the milestone `program.sh next`
  names (every dependency done; a parked one never counts as done), `k` its place in the
  roadmap, `n` the milestone count. It clears when no milestone is open, when the open ones
  wait only on a parked one, and when the file is gone (`program.sh close` archives it) or
  unreadable.
- **Refresh.** At session start and after every main-loop `Bash`, `Write`, `Edit` or
  `MultiEdit` call, the calls that can change the file (`program.sh` runs through Bash):
  the module checks the file's modification time and re-reads it only when that moved, so
  an edit made outside the session shows at the next such call, not at once. A subagent's
  tool calls do not refresh it (since 0.6.2), nor, since 0.7.0, does a read-only call
  (`Read`, `Grep`, `Glob` and every other tool). **Gate** — `tests/status-line.test.ts`,
  "leaves a read-only main-loop call to the next call that can write".
- **A git call per writing call.** Unless the line is switched off, every main-loop
  `Bash`, `Write`, `Edit` or `MultiEdit` call waits for a refresh that runs `git rev-parse`
  once to find the git toplevel; `CC_OVERSEER_STATUS=off` removes it.
- **Off switch.** `CC_OVERSEER_STATUS=off` (or `0`, `false`), or the `/config` option
  `cc_overseer_status` off; the variable wins over the option. Off clears the line at the
  next refresh.
- **CLI floor.** With mods off in the host, on a CLI below 2.1.287 (which loads no module)
  or on 2.1.288-2.1.290, the module passes every hook through and the classic hooks work
  exactly as before. On CLI 2.1.287 with mods on the module still registers its `tool.call`
  hook (the version check runs inside it), and that CLI's own bug — a plugin's `tool.call`
  hook breaking Bash and file search in worktree subagents, fixed in 2.1.288 — applies even
  with the switch off: upgrade the CLI or turn mods off.

Standing: **gate** — `tests/status-line.test.ts` runs under `claude plugin test` in CI (the
marketplace repository's `scripts/mod-tests.sh`), so a regression in a tested case fails
the build; `scripts/__tests__/status-core.test.sh` holds the milestone rule to
`program.sh`'s own. Untested here: the drawn line (the test kit records the text, not the
screen) and the git call per writing call, which no test counts. That a subagent's tool call
leaves the line to the next main-loop one is a gate (`tests/status-line.test.ts`).

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
