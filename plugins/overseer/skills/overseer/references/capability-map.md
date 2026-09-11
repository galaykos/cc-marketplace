# Capability map — which installed plugin runs which phase

`scripts/capability-scan.sh` prints this table filled in for the current project: one row
per phase, the installed plugins that cover it, and the ones missing. The scan unions
three sources, because each alone lies: `claude plugin list --json` filtered to `user`
scope or this project's path (the CLI is machine-wide and would count a plugin installed
in another repo), plus `enabledPlugins` from `.claude/settings.json`,
`.claude/settings.local.json` and `~/.claude/settings.json` (a hand-edited or `--persist`
entry the CLI does not always report). Without the `claude` CLI the scan prints `unknown`
and the install commands — it never guesses. It also prints one `# ci:` row per workflow
file with the branches it triggers on, flagged when the base branch is not among them.

| Phase | Preferred (cc-plugins-marketplace) | Also counts | Fallback when nothing is installed |
| --- | --- | --- | --- |
| understand | `stack-scan` (`/stack-scan:report`), `brain` (`/brain`, the map), `plugin-scout` | — | read manifests and lockfiles yourself; `find` the routes, pages, models, tests |
| shape | `taskmaster` (grill, visual-decisions, erd, walkthrough), `approaches` (compare, size), `design-lab`, `theme-design` | official `frontend-design` | write the spec yourself from the brief: goal, criteria, non-goals, ASCII wireframe; no mockup server |
| decide | `approaches` (approach-deliberation, build-vs-buy) | — | one paragraph per option, pick, kill-trigger, in `decisions.md` |
| plan | `taskmaster` (task-cards, coverage-check, verify-teeth), `code-architecture` (plan-before-code) | — | write cards yourself: one file set, one verify command, one done-criterion each |
| build | `task-runner` (run, --tracks, task-executor), `laravel`, `web-dev`, `ui-ux` (ui-ux-engineer), `database`, `security`, `testing` (test-engineer), `craft-layer` | project `.claude/skills/*` | dispatch general-purpose workers with the discipline preamble; one per disjoint file set |
| verify | `testing`, `code-architecture` (work-verification, drift-review), `task-runner` (behavioral-gate) | official `playwright` (not a marketplace plugin — the scan never lists it as installable), `claude-in-chrome` MCP | run the suite yourself; browser via Playwright MCP, Chrome MCP, or `npx playwright` — see acceptance.md |
| review | `code-review`, `ui-ux` (review, audit), `security`, `laravel`/`web-dev` review, `resilience`, `api-design`, `database` | — | one read-only reviewer subagent with the diff, `path:line — severity — problem — fix` |
| ship | `git-workflow` (`/git-workflow:finish`, skills `branch-completion`, `worktree-isolation`) | official `commit-commands` | offer merge / PR / keep via AskUserQuestion; headless: keep and print the command |
| guard | `command-guard`, `secret-scanning`, `candor`, `lean` | — | none — say in the charter that no destructive-command guard is active |

Rules:

- **Preferred beats fallback, fallback beats silence.** A phase with nothing installed is
  run inline by the overseer per the last column and recorded as `fallback` in
  `capabilities.tsv`; the charter names each fallback so the user can install the plugin
  and resume at full strength.
- **Offer installs once.** Interactive: one AskUserQuestion listing the missing preferred
  plugins with `/plugin install <name>@cc-plugins-marketplace` (or `/plugin-scout:suggest
  --full` when the scout is installed). Hands-off: record the commands in the charter, use
  the fallback, move on. Never run an install unasked, and remind that `/reload-plugins`
  is needed before a fresh install is active.
- **Project skills count.** A `.claude/skills/<name>/SKILL.md` in the target project (Laravel
  Boost ships several) is a build-phase source; pin it by absolute path in every worker
  prompt that touches its domain, the same as a marketplace skill.
- **A command you have and do not use is a decision.** `/stack-scan:report`,
  `/approaches:size`, `/ui-ux:audit`, `/git-workflow:finish` installed and skipped is fine
  when the inline route was cheaper — one `decision add` row per skip, so the user can see
  what strength was left on the table.
- **A missing stack plugin is a finding, not a blocker.** No `laravel` plugin in a Laravel
  repo: the worker prompt pins the project's own skill or, failing that, says "follow the
  conventions of sibling files" — and the charter's suggestions list carries the install.
