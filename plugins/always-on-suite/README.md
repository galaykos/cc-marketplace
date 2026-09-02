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
Stop gate, lean's output pricing, terse's chat-brevity contract (inert until
you set a level), file-aware skill auto-routing, git workflow discipline,
cross-session friction mining, and the scout that suggests the per-project
plugins this bundle deliberately leaves out — install it globally and
`/plugin-scout:suggest` bridges to the stack-matched tier per repo.

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

- **secret-scanning** — PreToolUse hook that blocks high-confidence secrets at write time, plus `/secret-scanning:scan`
- **candor** — a Stop gate on the two dishonesty shapes a script can prove: a file:line citation resolving to nothing, and a position retracted under pushback with no tool call in between, plus `/candor:check`
- **lean** — prices every line, test, comment and file as a debit, so the smallest change that satisfies the requirement is the one that ships
- **terse** — the same discipline one surface over: chat-message brevity as a shape contract. Inert until you run `/terse:commit` and pick a level, which is exactly why it is safe here — see the cost note below
- **skill-router** — hook that auto-loads the matching best-practice skill on edit, in whatever language the file turns out to be
- **git-workflow** — worktree isolation, the branch finish protocol, and review-exchange rigor, plus `/git-workflow:finish`
- **hindsight** — mines session transcripts for recurring friction and proposes CLAUDE.md rules and skill ideas, applied only on approval; its ledgers already live under `~/.claude`, so user scope is its native home
- **plugin-scout** — `/plugin-scout:suggest` scans each project and suggests the stack-matched plugins this bundle intentionally excludes

lean and terse do not overlap: lean prices what gets **written to disk** (code,
tests, comments, files, tool calls), terse shapes what gets **said in chat**,
and terse's own description puts code and files explicitly out of scope.

| Command | What it does |
|---------|--------------|
| `/always-on-suite:uninstall` | Uninstall the bundle AND prune every plugin it auto-installed — one step, no orphans; manually installed plugins are never touched |

## What this costs, honestly

Adding terse and dropping command-guard moved the bundle from **943 to 1,641**
always-on tokens, and from **975 to 2,715** with everything switched on. Both
figures are re-baselined in `scripts/context-budget-*baseline.json`; neither
number is hidden, and the growth is one member's.

- **terse** is that member and the largest single line in the bundle: **848**
  tokens of descriptions with no level set, **1,891** once you commit to one.
  Rule 2 holds because the `SessionStart` hook injects nothing at all until a
  level exists — off, you pay for the descriptions and nothing else. If you are
  never going to set a level, this is the member to drop.
- **skill-router** dominates the per-prompt channel at ~2.3k tokens in the
  marketplace bundle table, but that figure is built from the **sibling**
  plugins' command frontmatter, and the table is measured in the marketplace
  repo with all 52 leaves present — not the shape a user-scope baseline install
  has. Measured against this bundle's eight members, the same hook emits **~602
  tokens** (2,410 bytes). It grows as you add project-tier plugins, which is the
  point: it is the mechanism that makes them fire.

One consequence worth stating: **none of skill-router's 126 routing rows names a
plugin in this bundle.** On a bare always-on install its `PostToolUse` router has
nothing to route to. It is here forward-looking — `/plugin-scout:suggest` installs
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
- **stack-scan** — universal across stacks but per-project in what it reads;
  plugin-scout invokes it where it helps, so it arrives with the project tier.
- **code-review** (with its comment-discipline hooks) and the rest of quality-suite's
  enforcement half — quality gates you may want per project; that suite already
  exists for exactly that scope. The comment-discipline lane is the closest call: its
  `PreToolUse` lane denies, which is rule 3 again.

## Pairs well with

- **quality-suite** — the per-project enforcement gates, added where the code review actually happens
- **taskmaster-suite** — the full clarification-to-execution pipeline for project work
- **command-guard** — the destructive-command guard this bundle stopped shipping; install it directly and set `CLAUDE_DESTRUCTIVE_GUARD=deny-only` for the free half
