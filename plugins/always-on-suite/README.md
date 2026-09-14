# always-on-suite

Meta-bundle: the **user-scope baseline** — the plugins worth enabling once,
globally, and keeping on in every repo you open. Every other suite in this
marketplace answers "what does THIS project need?"; this one answers "what do I
want regardless of the project?". The membership rule is three-part, and it is
prose — no script checks it:

1. **Project-agnostic** — the plugin's value does not depend on the stack. A
   leaked API key is a leak in a Laravel repo and a Rust repo alike.
2. **Safe as a permanent fixture** — nothing here assumes a stack, scaffolds
   files, or needs per-project state to avoid misfiring; the guards are
   fail-open and high-confidence-only.
3. **Adds no interruption you did not ask for** — added 0.2.0, and it is the
   rule that removed command-guard. A permanent fixture that converts a silent
   host judgement into a permission click is paid for on every prompt in every
   repo, forever; that is a per-user opt-in, not a baseline.

What that buys you always-on: the write-time secret block, candor's honesty
Stop gate and its terse reply mode (inert until you set a level), file-aware
skill auto-routing, git workflow discipline,
cross-session friction mining, and stack-scan's two scout modes — marketplace
plugins, and third-party skills on skills.sh — that suggest what this bundle
deliberately leaves out — install it globally and `/stack-scan:suggest` bridges to
the stack-matched tier per repo.

## Install

Install at **user scope** — that is the point of this bundle. `claude plugin
install` defaults to user scope from the CLI:

```bash
claude plugin marketplace add galaykos/cc-marketplace
claude plugin install always-on-suite@cc-plugins-marketplace
```

(From inside a session, `/plugin install` targets the project — fine for a
trial, but the global install is the intended shape.)

## Context-window requirement (read before installing)

**Standing: `gate` for the declaration's presence, `recorded` for its numbers** —
`pc_listing_declaration` fails the build if this section disappears while the
bundle overflows; nothing checks the figures below, so recompute them with
`bash scripts/context-budget.sh` before trusting them.

Claude Code budgets the skill listing it sends the model at
`contextWindowTokens x bytesPerToken x skillListingBudgetFraction` (default
fraction 0.01). On the default 200k window with a current-tokenizer model that is
**6,000 chars**, and this bundle's listing costs **~6,664 chars** (LC_ALL=C bytes
— the marketplace's deterministic measure, ~1% above what the CLI counts; recount
with `bash scripts/context-budget.sh`, listing channel): over the floor since
0.3.0 added the skills.sh scout's two entries (now part of stack-scan). Over it the host reduces entries to name-only in priority
order, silently, so skills stop being reachable without any error — and because
this bundle is installed at user scope, every repo pays.

On the default 200k window this bundle is over the floor on its own, so add to
your user `settings.json` (the 1M tier fits with room to spare):

```json
{ "skillListingBudgetFraction": 0.02 }
```

That raises the listing budget to 12,000 chars at 200k. The fraction is a
ceiling, not a purchase — it only admits description text that was being evicted.

## What's included

- **secret-scanning** — PreToolUse hook that blocks high-confidence secrets at write time, plus `/secret-scanning:scan`
- **candor** — the marketplace's one Stop gate, four clauses a script can prove: a file:line citation resolving to nothing, a position retracted under pushback with no tool call in between, a completion claim with nothing executed after the last edit, a registered task-runner run ending without its gate pass; plus the terse reply mode (chat-message brevity as a shape contract, inert until you run `/candor:level` and pick a level — which is exactly why it is safe here) and `/candor:check`. The terse plugin was merged into candor on 2026-09-14
- **skill-router** — hook that auto-loads the matching best-practice skill on edit, in whatever language the file turns out to be
- **git-workflow** — worktree isolation, the branch finish protocol, and review-exchange rigor, plus `/git-workflow:finish`
- **hindsight** — mines session transcripts for recurring friction and proposes CLAUDE.md rules and skill ideas, applied only on approval; its ledgers already live under `~/.claude`, so user scope is its native home
- **stack-scan** — `/stack-scan:suggest` scans each project and suggests the stack-matched plugins this bundle intentionally excludes; `--skills` does the same for third-party skills on skills.sh. Its `/stack-scan:report` and `/stack-scan:audit` are project-agnostic and inert until invoked. (The two scouts were separate plugins, plugin-scout and vercel-skills-scout, until 2026-09-14) <!-- removed-ok -->

| Command | What it does |
|---------|--------------|
| `/always-on-suite:uninstall` | Uninstall the bundle AND prune every plugin it auto-installed — one step, no orphans; manually installed plugins are never touched |

## What this costs, honestly

Adding terse and dropping command-guard moved the bundle from **943 to 1,641**
always-on tokens, and from **975 to 2,715** with everything switched on. Both
figures are re-baselined in `scripts/context-budget-*baseline.json`; neither
number is hidden, and the growth is one member's. 0.3.0 added the skills.sh scout:
**+146** always-on tokens (its two descriptions), nothing per prompt until invoked.
0.5.0 swapped the two scout plugins for stack-scan, which carries both scouts plus its
report and audit commands; recount the delta rather than trusting a number here.

- **candor** carries the terse reply mode since 0.6.0 (it was the separate
  terse member, the largest single line in the bundle at 848 tokens; recount
  candor's line now). Rule 2 holds because the `SessionStart` hook injects
  nothing at all until a level exists — off, you pay for the descriptions and
  nothing else.
- **skill-router** dominates the per-prompt channel at ~2.3k tokens in the
  marketplace bundle table, but that figure is built from the **sibling**
  plugins' command frontmatter, and the table is measured in the marketplace
  repo with every leaf present — not the shape a user-scope baseline install
  has. Measured against this bundle's own members it emits a fraction of that
  (recount: `bash scripts/context-budget.sh`, dynamic channel, with only this
  bundle installed). It grows as you add project-tier plugins, which is the
  point: it is the mechanism that makes them fire.

One consequence worth stating: **none of skill-router's 126 routing rows names a
plugin in this bundle.** On a bare always-on install its `PostToolUse` router has
nothing to route to. It is here forward-looking — `/stack-scan:suggest` installs
the project tier, and skill-router is what then surfaces those skills on edit.

## Deliberately not included

Each exclusion names its reason, so disagreeing with one is a one-plugin
install, not a fork of the bundle:

- **command-guard** — dropped from the bundle in 0.2.0, not from the
  marketplace. Its deny tier is genuinely free and genuinely baseline-shaped.
  Its **ask** tier is not: where the host classifies commands itself, a
  `PreToolUse` `ask` *overrides* that classifier, so the tier does not add a
  check — it replaces a silent judgement with a human click, on every repo,
  permanently. That is rule 3. The plugin ships the split itself:
  `CLAUDE_DESTRUCTIVE_GUARD=deny-only` keeps the hard stops and silences the
  prompts, which is the shape worth installing globally by hand.
- **fresh-take** — project-agnostic, but its consult dispatches a
  stronger-model subagent; a spend decision that should be opted into, not
  baselined.
- **brain** — project-agnostic and cheap (~89 tokens off), but it fails rule 2
  twice: it scaffolds a committed `brain/` directory, and until you run
  `/brain index` its `SessionStart` hook greets you in every un-indexed repo
  you open. Install it per project, where the map is worth committing.
- **code-review** (with its comment-discipline hooks) and the rest of quality-suite's
  enforcement half — quality gates you may want per project; that suite already
  exists for exactly that scope. The comment-discipline lane is the closest call: its
  `PreToolUse` lane denies, which is rule 3 again.

## Pairs well with

- **quality-suite** — the per-project enforcement gates, added where the code review actually happens
- **taskmaster-suite** — the full clarification-to-execution pipeline for project work
- **command-guard** — the destructive-command guard this bundle stopped shipping; install it directly and set `CLAUDE_DESTRUCTIVE_GUARD=deny-only` for the free half
