# core-suite

Meta-bundle: the **user-scope baseline** — the plugins worth enabling once,
globally, and keeping on in every repo you open. Every other bundle in this
marketplace answers "what does THIS project need?"; this one answers "what do I
want regardless of the project?". It was `always-on-suite` until 2026-09-14, when
the quality-suite bundle was merged into it and both names retired; the membership
rule is three-part, and it is prose — no script checks it:

1. **Project-agnostic** — the plugin's value does not depend on the stack. A
   leaked API key is a leak in a Laravel repo and a Rust repo alike.
2. **Safe as a permanent fixture** — nothing here assumes a stack, scaffolds
   files, or needs per-project state to avoid misfiring; the guards are
   fail-open and high-confidence-only.
3. **Adds no interruption you did not ask for** — the rule that keeps
   command-guard out. A permanent fixture that converts a silent host judgement
   into a permission click is paid for on every prompt in every repo, forever;
   that is a per-user opt-in, not a baseline.

What that buys you always-on: the write-time secret block, candor's five-clause
honesty Stop gate and its terse reply mode (inert until you set a level), the
one review entry (`/code-review:review`, which loads whatever stack rubrics you
have installed) with its comment discipline, file-aware skill auto-routing, git
workflow discipline, cross-session friction mining, and stack-scan's report,
audit and scout — `/stack-scan:suggest` bridges from this baseline to the
stack-matched tier per repo.

## Install

Install at **user scope** — that is the point of this bundle. `claude plugin
install` defaults to user scope from the CLI:

```bash
claude plugin marketplace add galaykos/cc-marketplace
claude plugin install core-suite@cc-plugins-marketplace
```

(From inside a session, `/plugin install` targets the project — fine for a
trial, but the global install is the intended shape.) Coming from
always-on-suite or quality-suite: run that bundle's own `uninstall` command
first, then install this one — the leaves you keep are re-resolved, not
re-downloaded. <!-- removed-ok -->

## Context-window requirement (read before installing)

**Standing: `gate` for the declaration's presence, `recorded` for its numbers** —
`pc_listing_declaration` fails the build if this section disappears while the
bundle overflows; nothing checks the figures below, so recompute them with
`bash scripts/context-budget.sh` before trusting them.

Claude Code budgets the skill listing it sends the model at
`contextWindowTokens x bytesPerToken x skillListingBudgetFraction` (default
fraction 0.01). On the default 200k window with a current-tokenizer model that is
**6,000 chars**, and this bundle's listing costs **~6,880 chars** (LC_ALL=C bytes
— the marketplace's deterministic measure, ~1% above what the CLI counts; recount
with `bash scripts/context-budget.sh`, listing channel). Over it the host reduces
entries to name-only in priority order, silently, so skills stop being reachable
without any error — and because this bundle is installed at user scope, every
repo pays.


`workflow-suite` contains all seven of these. Install one or the other, never
both: with workflow-suite present, `/core-suite:uninstall` keeps every member
(another installed bundle lists them) and removes only this bundle's own
manifest — a no-op that reads like a cleanup.

On the default 200k window this bundle is over the floor on its own, so add to
your user `settings.json` (the 1M tier fits with room to spare):

```json
{ "skillListingBudgetFraction": 0.02 }
```

That raises the listing budget to 12,000 chars at 200k. The fraction is a
ceiling, not a purchase — it only admits description text that was being evicted.

## What's included

- **secret-scanning** — PreToolUse hook that blocks high-confidence secrets at write time, plus `/secret-scanning:scan`
- **candor** — the marketplace's one Stop gate, five clauses a script can prove: a file:line citation resolving to nothing, a position retracted under pushback with no tool call in between, a completion claim with nothing executed after the last edit, a registered task-runner run ending without its gate pass, a dependency manifest changed without its lockfile; plus the terse reply mode (inert until you run `/candor:level` and pick a level — which is exactly why it is safe here) and `/candor:check`
- **code-review** — `/code-review:review`, the one review entry: it loads every stack rubric you have installed for whatever the diff touches, and carries the comment discipline (no-comment default; write-time denies for restatement, commented-out code and signature-repeating docblocks). Rule 3 holds because its PreToolUse lane denies only an edit that adds a banned comment — a gate on a defect, never a click per prompt
- **skill-router** — hook that auto-loads the matching best-practice skill on edit, in whatever language the file turns out to be
- **git-workflow** — worktree isolation, the branch finish protocol, and review-exchange rigor, plus `/git-workflow:finish`
- **hindsight** — mines session transcripts for recurring friction and proposes CLAUDE.md rules and skill ideas, applied only on approval; its ledgers already live under `~/.claude`, so user scope is its native home
- **stack-scan** — `/stack-scan:suggest` scans each project and suggests the stack-matched plugins this bundle intentionally excludes; `--skills` does the same for third-party skills on skills.sh. Its `/stack-scan:report` and `/stack-scan:audit` are project-agnostic and inert until invoked

| Command | What it does |
|---------|--------------|
| `/core-suite:uninstall` | Uninstall the bundle AND remove every plugin it lists as a dependency at the same scope, minus anything another installed suite also lists — one step, no orphans. It cannot tell an auto-install from one you made yourself: install records routinely carry no marker, so a dependency you installed by hand appears in the removal list and the confirm step is what protects it |

## What this costs, honestly

Always-on, the bundle pays its members' descriptions and nothing else until a
mechanism fires: the figures are in the marketplace README's bundle table,
rendered from `scripts/context-budget-*baseline.json` — recount them with
`bash scripts/context-budget.sh` rather than trusting a number typed here (the
numbers this section used to carry were stale within two releases).

- **candor** carries the terse reply mode. Rule 2 holds because the
  `SessionStart` hook injects nothing at all until a level exists — off, you pay
  for the descriptions and nothing else.
- **code-review** is the largest per-edit line: four PostToolUse hooks
  (conventions, scan, density, verbosity) run on every edit. Measured on the
  first noisy `.tsx` edit of a session they emit two envelopes, 787 bytes
  (consolidation plan §4.3, 2026-09-14); after that they are silent unless a
  finding exists.
- **skill-router** dominates the per-prompt channel in the marketplace bundle
  table, but that figure is built from the **sibling** plugins' command
  frontmatter, measured in the marketplace repo with every leaf present — not
  the shape a user-scope baseline install has. Against this bundle's own members
  it emits a fraction of that. It grows as you add project-tier plugins, which is
  the point: it is the mechanism that makes them fire.

## Deliberately not included

Each exclusion names its reason, so disagreeing with one is a one-plugin
install, not a fork of the bundle:

- **command-guard** — in the marketplace, not in this bundle. Its deny tier is
  genuinely free and genuinely baseline-shaped. Its **ask** tier is not: where
  the host classifies commands itself, a `PreToolUse` `ask` *overrides* that
  classifier, so the tier does not add a check — it replaces a silent judgement
  with a human click, on every repo, permanently. That is rule 3. The plugin
  ships the split itself: `CLAUDE_DESTRUCTIVE_GUARD=deny-only` keeps the hard
  stops and silences the prompts, which is the shape worth installing globally
  by hand. (The consolidation plan's bundle table listed it here; this recorded
  exclusion predates the table and carries the reason, so it stands.)
- **code-architecture** — was quality-suite's; plan-before-code, drift review
  and work verification are project work, so it rides in `workflow-suite`. <!-- removed-ok -->
- **approaches** — project-agnostic, but `/approaches:consult` dispatches a
  stronger-model subagent; a spend decision that should be opted into, not
  baselined.
- **brain** — project-agnostic and cheap, but it fails rule 2 twice: it
  scaffolds a committed `brain/` directory, and until you run `/brain index`
  its `SessionStart` hook greets you in every un-indexed repo you open. Install
  it per project, where the map is worth committing.

## Pairs well with

- **workflow-suite** — this baseline plus the whole clarify → spec → cards → execute pipeline, for project work
- **frontend-suite** / **craft-suite** — the stack and studio tiers `/stack-scan:suggest` points at
- **command-guard** — the destructive-command guard this bundle leaves out; install it directly and set `CLAUDE_DESTRUCTIVE_GUARD=deny-only` for the free half
