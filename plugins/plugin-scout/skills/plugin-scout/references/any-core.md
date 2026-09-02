# Any-project core (tier 2)

The curated list of marketplace plugins judged useful in **any** project,
regardless of detected stack. `SKILL.md`'s "Any-project core" section is the
short pointer; this file is the source of truth a reviewer checks against.

These rows sit between the signal-backed tier 1 and the universal remainder:
no manifest earns them, but their usefulness does not depend on the stack
either, so leaving them in the undifferentiated remainder undersold them.
Under `--yes` they auto-install alongside tier 1; without `--yes` they fill
the picker's core questions right after the tier-1 evidence rows.

## The membership test

A row belongs here only if it passes both:

1. **Stack-agnostic in substance** — its rubric does not name a language,
   framework or package manager. A plugin whose own description says
   "Composer/npm" fails this and belongs in `references/signals.md` behind the
   manifest that earns it.
2. **A floor, not a decision** — adopting it changes how existing work is
   checked, not which pipeline the team runs. Anything a user should opt into
   deliberately is a tier-3 pick.

## The list

| Plugin | Why any project |
|---|---|
| code-review | reviewing a diff for correctness and smells is stack-agnostic |
| debugging | root-cause-before-fix discipline applies to every bug in every language |
| testing | every project has (or needs) tests; pyramid, mocking, and flake discipline are cross-stack |
| git-workflow | every repo here is git; branch-finish and review-exchange discipline has no stack |
| code-architecture | plan-before-code, YAGNI, and verification-with-evidence are process, not stack |
| secret-scanning | any repo can leak a key; the pre-write block hook is language-independent |
| command-guard | irreversible data loss (`migrate:fresh`, `DROP DATABASE`, `rm -rf`) is language-independent, and its deny hook is the pair to secret-scanning's block |
| comment-discipline | every language has comments; the information-routing rule is universal |

## Deliberate exclusions (near misses)

- `stack-scan` (package-hygiene, formerly the packages plugin) — moved OUT of core to `references/signals.md`, earned by the <!-- removed-ok -->
  presence of a `package.json` or `composer.json`. Its own description is
  "Composer/npm dependency hygiene", so it fails membership test 1: a Python or
  Go repo was auto-installing a plugin whose entire rubric is about two manifests
  it does not have.
- `security` — its OWASP review is web-app-shaped (the catalog description maps
  it to PHP/Laravel and JS/Vue). It is now signal-earned in
  `references/signals.md` behind an auth dependency, rather than a tier-3 pick.
- `taskmaster`, `task-runner` — workflow pipelines, not floors; fails membership
  test 2. Adopting a planning pipeline is a decision the user should make
  explicitly.
- `candor`, `lean`, `skill-router`, `hindsight` — these change how the model
  talks, prices output, or routes across every session rather than how this
  project's code is checked, so per-project installation is the wrong unit for
  them. Point at the always-on-suite bundle or a `--global` run.

Note what that last bullet is NOT: "member of always-on-suite". `git-workflow`,
`secret-scanning` and `command-guard` are all members of that bundle and are all
in the core list, because the two write-time guards it ships are exactly the kind
of floor test 1 and 2 select for. The criterion is the membership test above, not
bundle membership — an earlier version of this file used the bundle as the
criterion and then contradicted itself twice.

## Rules

- Under `--yes`, every core row not yet installed installs with the same scope
  rules as tier 1 (`local` default, `project` with `--persist`, `user` with
  `--global`). Tier 3 never auto-installs.
- Without `--yes`, core rows are picker options like any other — nothing
  installs without a pick.
- Evidence column: the literal string `core` — the evidence is this file, not
  a manifest.
- Two of these ship write-time hooks (secret-scanning blocks secrets,
  command-guard denies destructive commands). A `--yes` run must name that in
  its summary: the user did not see a picker for them.

## Standing

**Recorded, curated by hand.** No script derives or checks this list against
the catalog; membership is a judgment about usefulness, not a measurement, and
the two-part test above is a rubric for a reviewer, not a check anything runs.

One narrow gate applies: `pc_scout_names` fails the build if a name in the
Plugin column above is not a live `marketplace.json` entry. That catches a
deleted plugin, and nothing else — it says nothing about whether a row still
deserves to be core.

When plugins land in or leave the marketplace, re-judge the list against
`references/catalog.md` — and recount from the catalog rather than trusting
any count written here.
