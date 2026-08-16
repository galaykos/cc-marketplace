# Changelog

All notable changes to the task-runner plugin.

## 0.28.1

### Added
- **`lane.tsv`** — declares the territory and phase of `task-executor` and the
  completion-gate Stop hook, so no sibling can silently claim the same job.

### Changed
- **`/task-runner:run` writes `.claude/cc-phase.json`** (`phase: build`) alongside the
  existing `active-run.json`, and clears both at step 9. The two are deliberately
  separate: `active-run.json` registers a RUN for this plugin's own Stop gate, while
  `cc-phase.json` declares a PHASE that every installed reminder hook reads — including
  in installs that have neither task-runner nor taskmaster. It is what stops a
  "clarify before your first code edit" nudge firing on turn 40 of an executing run.
- **`completion-gate` is declared `phase: any`**, not `verify`: a Stop gate has to fire
  whenever a turn tries to end, and scoping it to one arc phase would have let a turn
  ending during `build` escape it entirely.

## 0.28.0

### Fixed

- **The card-agent resolution map did not bind on the `Workflow` path.**
  `skills/task-execution/references/routing.md` resolves a card's `Agent:` tag to
  a worker (`laravel:backend-engineer`, `security:security-engineer`, …, else
  `task-executor`) and said only "dispatch the resolved worker with that prompt".
  A `Workflow` `agent()` call without `agentType` spawns the generic workflow
  subagent: steps 1–2 run, the prompt arrives, and the worker's own contract does
  not. The whole map is decorative on that path, and nothing in the run says so.

  What went missing in practice, on a 30-card fan-out: `task-executor`'s *"match
  the surrounding file's naming, idiom, and comment density"* and its *"new
  behavior no test exercises is named as untested"* rule. Neither reached a
  single writing agent. The output carried roughly twice the repository's own
  comment density and eight times its tests-per-integration, and every gate
  passed green — the checks that existed measure correctness, not proportion.

  Step 5 now names both dispatch forms (`subagent_type` on the Agent path,
  `agentType` on the `Workflow` path), states what is lost when it is omitted,
  and requires the bound agent to be logged per card in the run report.

- `skills/track-orchestration/references/algorithm.md` step 3 — the wave batch
  now passes `agentType: 'task-runner:task-executor'` alongside `model:`/`effort:`,
  under the same "this is a parameter of the call, not prose in the prompt" rule
  the tier already had. Also records why a track worker stays `task-executor`
  rather than a specialist: it runs mixed cards inline as a leaf, so there is no
  per-card resolution to bind, and skill priming carries the framework knowledge.

### Notes

- **Standing: agent-graded.** `scripts/validate.sh` gates shipped `agent(<args>)`
  code samples (`pc_dispatch_binding`), which is what catches a recipe. It cannot
  read a prose dispatch instruction and confirm an orchestrator obeyed it, and it
  cannot see a `Workflow` script composed at runtime — which is how the original
  failure happened. The per-card run-report line is the only thing that makes an
  unbound dispatch visible after the fact.
- Not addressed here: nothing in this marketplace measures test or comment
  *proportion* against a repository's own house style. Every surface pushes test
  count up (`verify-teeth`, `behavioral-gate`, the negative control,
  `coverage-check`) and none pushes back.
