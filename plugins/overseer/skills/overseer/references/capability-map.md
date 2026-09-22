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

**The scan cannot see the session.** Installed and enabled is not the same as invocable:
a project's first-ever session registers its `enabledPlugins` and loads only user-scope
ones (simulation 4's first launch: 62 slash commands, 233 after a restart), and the scan
reads the same settings files the CLI just registered from. The Discover step therefore
compares the table against the session's own Skill listing; a row the session cannot
invoke is `unreachable`, and the remedy is `/reload-plugins` (interactive) or a fresh
session (headless) before any milestone is registered — a fallback there would quietly
re-run the hand-dispatch path every earlier simulation took. Standing: agent-graded.

| Phase | Preferred (cc-plugins-marketplace) | Also counts | Fallback when nothing is installed |
| --- | --- | --- | --- |
| understand | `stack-scan` (`/stack-scan:report`, `/stack-scan:suggest`), `brain` (`/brain`, the map) | — | read manifests and lockfiles yourself; `find` the routes, pages, models, tests |
| shape | `taskmaster` (grill, visual-decisions, erd, walkthrough), `approaches` (compare, size), `ui-ux` (theme, build) | official `frontend-design` | write the spec yourself from the brief: goal, criteria, non-goals, ASCII wireframe; no mockup server |
| decide | `approaches` (approach-deliberation, build-vs-buy) | — | one paragraph per option, pick, kill-trigger, in `decisions.md` |
| plan | `taskmaster` (task-cards, coverage-check, verify-teeth), `code-architecture` (plan-before-code) | — | write cards yourself: one file set, one verify command, one done-criterion each |
| build | `task-runner` (run, --tracks, task-executor), `laravel`, `web-dev`, `ui-ux` (ui-ux-engineer), `database`, `security`, `testing` (test-engineer), `craft-layer` (a per-milestone build tool for a crafted surface — a landing or marketing page; it consumes a spec, it never owns the program) | project `.claude/skills/*` | dispatch general-purpose workers with the discipline preamble; one per disjoint file set |
| verify | `testing`, `code-architecture` (work-verification, drift-review), `task-runner` (behavioral-gate) | official `playwright` (not a marketplace plugin — the scan never lists it as installable), `claude-in-chrome` MCP | run the suite yourself; browser via Playwright MCP, Chrome MCP, or `npx playwright` — see acceptance.md |
| review | `code-review` (the fan-in; loads the laravel, web-dev, database and ui-ux skills the diff touches — their own review commands were retired 2026-09-14), `ui-ux` (audit), `security`, `resilience` (`--concern`), `api-design` | — | one read-only reviewer subagent with the diff, `path:line — severity — problem — fix` |
| ship | `git-workflow` (`/git-workflow:finish`, skills `branch-completion`, `worktree-isolation`) | official `commit-commands` | offer three spelled-out destinations via AskUserQuestion — merge locally (into the base branch, no review), push and open a PR (for review), keep the branch open (leave it, come back); headless: keep and print the command |
| guard | `command-guard`, `secret-scanning`, `candor` | — | none — say in the charter that no destructive-command guard is active |

Rules:

- **Preferred beats fallback, fallback beats silence.** A phase with nothing installed is
  run inline by the overseer per the last column and recorded as `fallback` in
  `capabilities.tsv`; the charter names each fallback so the user can install the plugin
  and resume at full strength.
- **Offer installs once.** Interactive: one AskUserQuestion listing the missing preferred
  plugins with `/plugin install <name>@cc-plugins-marketplace` (or `/stack-scan:suggest
  --full` when stack-scan is installed). Hands-off: record the commands in the charter, use
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

## Routing by milestone kind (`kinds.tsv`, **gate** at accept)

Which phase a plugin covers is the table above; which skills a given milestone must pin is
`${CLAUDE_PLUGIN_ROOT}/kinds.tsv`, one row per kind. `milestone add --kind` records the
kind; `dispatch check --milestone <id>` WARNs for every group no gated dispatch has pinned
yet; `accept` refuses while one is still unpinned. The row's 4th column is the EVIDENCE
profile — `ui` (default) demands the nine-kind browser walk, `headless` demands `tests`
plus `run-log` for a kind with no screen (`acceptance.md`). A pin counts only from a file `dispatch
check` passed and unchanged since, and only by a path that exists. A group whose every
alternative is not installed is a WARN with the fallback, never a refusal — the run is
weaker and says so (the `stack` group is installed only when a project skill or a
laravel/web-dev skill really is).

| kind | must pin (one per group) | when |
| --- | --- | --- |
| feature | a stack skill · testing | anything no row below fits (the default) |
| marketing-page | craft-layer direction · a motion skill · a11y-audit · a styling skill | a page whose job is to sell |
| crud | stack · testing · a11y-audit · a styling skill | list/create/edit/delete of one resource |
| board | crud's set + motion or interaction-fx | drag, reorder, kanban, calendar |
| auth | stack · testing · security-review or api-auth | login, roles, permissions, tokens |
| form | stack · testing · a11y-audit · security-review or api-auth | a form collecting user data — contact, application, sign-up; never `feature` |
| api | stack · testing · api-design · api-auth or security-review | an HTTP or GraphQL surface |
| data-model | stack · a database skill · testing | schema, migrations, indexes |
| infra | a devops skill | CI, containers, deploy |
| game | stack · testing · a11y-audit · motion or interaction-fx | a game or motion-heavy interactive screen |
| integration | testing | merge the done branches and walk the product across them; `close` needs one when done branches diverge |
| audit | a stack skill | a read-only review, research or inventory pass — no testing group, nothing new is written; evidence profile `headless` |
| library | stack · testing | a non-UI code change: script, CLI, package, build step; evidence profile `headless` |

"stack" is any project skill under `.claude/skills/` or any `laravel`/`web-dev` plugin skill.
The rows are the two simulations' pins written down; a kind the table lacks is `feature`
plus a decision row naming what you pinned and why — and a row to add here.
