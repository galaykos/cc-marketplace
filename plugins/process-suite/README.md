# process-suite

Meta-bundle: the engineering-process category in one install — git workflow,
approach deliberation, hindsight mining,
build-vs-buy gates, rollout planning, docs upkeep, estimation, subagent
orchestration, task execution, stack scanning, plugin scouting, and intent
drift guarding. Uninstalls cleanly: `/process-suite:uninstall` removes the
bundle and prunes the plugins it auto-installed.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install process-suite@cc-plugins-marketplace
```

## What's included

- **git-workflow** — worktree isolation and the branch-finish protocol
  (verify, merge/PR/park, clean up), plus `/git-workflow:finish`
- **approaches** — 2-3 structurally different approaches with a kill-trigger
  before implementing, plus `/approaches:compare` and `/approaches:opinions`
- **hindsight** — mines session transcripts for cross-session friction,
  applied only on approval, plus `/hindsight:harvest`
- **build-vs-buy** — existing-solution check before hand-rolling a capability,
  plus `/build-vs-buy:check`
- **rollout** — feature flags, staged exposure, and a rollback path stated
  before ship, plus `/rollout:plan`
- **docs-upkeep** — documentation-drift detection with exact fixes, plus
  `/docs-upkeep:check`
- **estimation** — S/M/L/XL sizing with anchors and split triggers, plus
  `/estimation:size`
- **orchestration** — delegation contracts and verification panels for
  subagent fan-outs, plus `/orchestration:review`
- **task-runner** — scope-locked task execution with bounded verify-fix loops,
  plus `/task-runner:plan` and `/task-runner:run`
- **stack-scan** — inventory of installed runtimes, frameworks, and packages
  vs manifests, plus `/stack-scan:report`
- **plugin-scout** — stack-matched marketplace plugin suggestions, plus
  `/plugin-scout:suggest`
- **intent-guard** — warn-only drift guard against a declared task intent,
  plus `/intent-guard:intent` and `/intent-guard:status`

| Command | What it does |
|---------|--------------|
| `/process-suite:uninstall` | Uninstall the bundle AND prune every plugin it auto-installed — one step, no orphans; manually installed plugins are never touched |

## Pairs well with

- **taskmaster** — turns vague requests into specs and task cards that
  task-runner then executes
- **quality-suite** — the code-quality review category alongside this
  process discipline
- **claude-authoring** — scaffold the new commands, skills, and plugins these
  processes surface
