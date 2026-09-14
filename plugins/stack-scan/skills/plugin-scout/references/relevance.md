# The tier-3 relevance pass

Tiers 1 and 2 are lookups: a signal table and a curated list. Tier 3 is defined
by **subtraction** — "every catalog plugin not already in tier 1 or 2" — so
before this pass existed, no plugin ever entered the report because of anything
about the project in front of it. Roughly two fifths of the eligible set can
never be earned by any signal, so those rows printed the literal string
`universal` in every repo forever, and `--yes` never touched them.

This is the one step where the model judges instead of matching.

## What it costs, and why that is the right price

The 0.12 picker cut was a proportionality argument about **ceremony**: paging
every eligible row cost four AskUserQuestion calls and sixteen blocking
questions in every repo. That argument was right, and this pass does not
reopen it — **it adds no questions and no calls.** It reorders and annotates
rows the report already prints.

It is also nearly free in tokens: a default run already reads every catalog
description in `references/catalog.md`, and `SKILL.md`'s tier-3 rule already
says to read each row's keywords and description "to phrase the suggestion".
The reasoning is already paid for. This file spends it on selection instead of
throwing it away on wording.

## The contract

After the sweep and before the picker, lift **3-5** tier-3 rows into a group
headed `worth a look here` at the top of the tier-3 block.

1. **A reason, not evidence.** Every lifted row carries one line saying why it
   fits THIS repo. Evidence is a file and the key that matched; a reason is an
   argument from what the project is. The two words are not interchangeable and
   the report must never blur them — a reason is exactly the thing that could
   be wrong.
2. **It does not promote.** Tier 1 means a signal fired. A lifted row stays a
   tier-3 row, keeps its number, prints once, and the completeness rule
   (`SKILL.md` Report) is unaffected — the group is a reordering inside tier 3,
   not a fourth tier.
3. **Never auto-installed by `--yes`.** `--yes` covers tier 1 and tier 2 core only.
   A judgment call is the precise thing a human should confirm, so a lifted row
   is offered and never installed without a pick. Under `--full` this pass does
   not run: there is no picker, and every tier-3 row that survives stack exclusion
   installs behind the single plan confirm (skipped only by `--full --yes`).
4. **Zero is a legal answer.** If nothing in the remainder stands out, say
   "nothing in the remainder stands out for this repo" and print tier 3 as
   usual. Padding to reach three is the failure this pass exists to avoid, in
   the same way `references/signals.md`'s `—` rows refuse to pad.
5. **Read-only, like detection.** No installs, no package managers, no writes.

## What it may read

Detection's manifest set, plus the cheap project-shape facts a manifest cannot
carry:

- the README's opening paragraph — what the project says it is
- top-level directory names, and whether they look like an app, a library, a
  monorepo, a marketplace, infrastructure, or a docs site
- the language mix, and roughly how large the repo is
- the catalog descriptions already in context

Nothing here is evidence in the tier-1 sense, which is exactly why these facts
belong in a pass whose output is labelled a reason.

## Worked example — this marketplace repo

Run against `cc-marketplace` itself, detection finds `.github/workflows/` and a
`.sql` file and reports `devops` and `sql`. Everything that makes the repo what
it is — 60-odd plugins, skills, agents, hook scripts, generator templates —
produced nothing, because none of it is a manifest. Before this pass,
the since-demoted authoring plugin printed as `universal` in a repo whose entire <!-- removed-ok -->
content is Claude Code artifacts. (The general lesson stands, which is why the
pass is not just more rows.)

What the pass should lift there:

```
TIER 3 — no signal in this repo (40)
  worth a look here
    31 brain          60+ plugin dirs and no map; a fresh session starts cold
    18 code-review    the repo's own rule is "cite, don't restate" — its
                           comment-discipline skill is that rule for code
    44 approaches     most changes here are shape decisions (a gate? a hook?
                      a reference file?) rather than implementation
  quality/review:  16 a11y  17 performance  ...
```

Each line is an argument someone can disagree with. That is the point: a wrong
reason is visible and arguable, where `universal` was neither.

## Anti-patterns

- Lifting a row because its catalog keyword matches a word in the README.
  Keyword overlap is marketplace taxonomy, not fit — the same mistake
  `references/picker.md` documents for overlap pairs.
- Lifting the same three rows in every repo. If the group does not change
  between a Django API and a design-system monorepo, the pass is not running;
  it is a second core list wearing a different label.
- Writing a reason that restates the catalog description. "brain — builds a
  codebase map" is the description. "60+ plugin dirs and no map" is a reason.
- Filling to five. Three good ones beat five with two makeweights.

## Standing

**Agent-graded, entirely — with not one gate, not even the name one.** No
script checks that the pass ran, that a lifted row got a reason rather than a
description, that the reason is true, or that zero was reported honestly
instead of padded.

`pc_scout_names` does **not** read this file. It parses markdown table cells in
`SKILL.md`, `references/signals.md`, `references/any-core.md` and
`references/stack-relevance.md`; the plugin
names above live in prose and a fenced block, so a plugin deleted from the
marketplace would go stale here exactly the way a since-removed row went stale
in `references/signals.md` and shipped for two days — the bug that gate was
built for. <!-- removed-ok: naming the historical failure IS the argument for
why this file is ungated; rerouting it to a live plugin would delete the
evidence. --> Nothing catches the repeat. Treat the worked example as
illustration, re-read it against
`references/catalog.md` when plugins leave, and never copy a name out of it
into a suggestion without checking the catalog first.

The residual worth naming: this pass makes the report better only if the
reasons are good, and a plausible-sounding wrong reason is more persuasive than
`universal` was. That is a real cost, accepted deliberately — a suggestion the
user can argue with is worth more than one that says nothing, and rule 3 keeps
a bad reason from installing anything on its own.
