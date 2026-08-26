# always-on-suite

Meta-bundle: the **user-scope baseline** — the plugins worth enabling once,
globally, and keeping on in every repo you open. Every other suite in this
marketplace answers "what does THIS project need?"; this one answers "what do I
want regardless of the project?". The membership rule is two-part, and it is
prose — no script checks it:

1. **Project-agnostic** — the plugin's value does not depend on the stack. A
   destructive `rm -rf` is destructive in a Laravel repo and a Rust repo alike.
2. **Safe as a permanent fixture** — nothing here assumes a stack, scaffolds
   files, or needs per-project state to avoid misfiring; the guards are
   fail-open and high-confidence-only.

What that buys you always-on: the two write-time safety guards
(destructive-command blocking, secret-leak prevention), candor's honesty Stop
gate, lean's output pricing, file-aware skill auto-routing, git workflow
discipline, cross-session friction mining, and the scout that suggests the
per-project plugins this bundle deliberately leaves out — install it globally
and `/plugin-scout:suggest` bridges to the stack-matched tier per repo.

## Install

Install at **user scope** — that is the point of this bundle. `claude plugin
install` defaults to user scope from the CLI:

```bash
claude plugin marketplace add galaykos/cc-marketplace
claude plugin install always-on-suite@cc-plugins-marketplace
```

(From inside a session, `/plugin install` targets the project — fine for a
trial, but the global install is the intended shape.)

## What's included

- **command-guard** — PreToolUse hook that denies irreversible destructive commands and asks on scoped ones, plus `/command-guard:check`
- **secret-scanning** — PreToolUse hook that blocks high-confidence secrets at write time, plus `/secret-scanning:scan`
- **candor** — a Stop gate on the two dishonesty shapes a script can prove: an unverified claim stated as done, and a silent scope reduction, plus `/candor:check`
- **lean** — prices every line, test, comment and file as a debit, so the smallest change that satisfies the requirement is the one that ships
- **skill-router** — hook that auto-loads the matching best-practice skill on edit, in whatever language the file turns out to be
- **git-workflow** — worktree isolation, the branch finish protocol, and review-exchange rigor, plus `/git-workflow:finish`
- **hindsight** — mines session transcripts for recurring friction and proposes CLAUDE.md rules and skill ideas, applied only on approval; its ledgers already live under `~/.claude`, so user scope is its native home
- **plugin-scout** — `/plugin-scout:suggest` scans each project and suggests the stack-matched plugins this bundle intentionally excludes

| Command | What it does |
|---------|--------------|
| `/always-on-suite:uninstall` | Uninstall the bundle AND prune every plugin it auto-installed — one step, no orphans; manually installed plugins are never touched |

## Deliberately not included

Each exclusion names its reason, so disagreeing with one is a one-plugin
install, not a fork of the bundle:

- **terse** — passes rule 1 but is a per-user style choice that stays inert
  until you set a level; install it directly if you want it, and it will sit in
  user scope just as happily.
- **fresh-take** — project-agnostic, but its consult dispatches a
  stronger-model subagent; a spend decision that should be opted into, not
  baselined.
- **stack-scan** — universal across stacks but per-project in what it reads;
  plugin-scout invokes it where it helps, so it arrives with the project tier.
- **code-review / comment-discipline** and the rest of quality-suite's
  enforcement half — quality gates you may want per project; that suite already
  exists for exactly that scope.

## Pairs well with

- **quality-suite** — the per-project enforcement gates, added where the code review actually happens
- **taskmaster-suite** — the full clarification-to-execution pipeline for project work
- **terse** — the chat-brevity contract, if fixed prose budgets are your taste
