# Any-project core (tier 2)

The curated list of marketplace plugins judged useful in **any** project,
regardless of detected stack. `SKILL.md`'s "Any-project core" section is the
short pointer; this file is the source of truth a reviewer checks against.

These rows sit between the signal-backed tier 1 and the universal remainder:
no manifest earns them, but their usefulness does not depend on the stack
either, so leaving them in the undifferentiated remainder undersold them.
Under `--yes` they auto-install alongside tier 1; without `--yes` they lead
the picker's early pages right after the tier-1 evidence rows.

## The list

| Plugin | Why any project |
|---|---|
| code-review | reviewing a diff for correctness and smells is stack-agnostic |
| debugging | root-cause-before-fix discipline applies to every bug in every language |
| testing | every project has (or needs) tests; pyramid, mocking, and flake discipline are cross-stack |
| git-workflow | every repo here is git; branch-finish and review-exchange discipline has no stack |
| code-architecture | plan-before-code, YAGNI, and verification-with-evidence are process, not stack |
| secret-scanning | any repo can leak a key; the pre-write block hook is language-independent |
| comment-discipline | every language has comments; the information-routing rule is universal |
| packages | dependency hygiene applies to any manifest-carrying project |

## Deliberate exclusions (near misses)

- `security` — its OWASP review is web-app-shaped (the catalog description maps
  it to PHP/Laravel and JS/Vue); a CLI or infra repo pays always-on context for
  little. It stays a tier-3 pick.
- `taskmaster`, `task-runner` — workflow pipelines, not floors; adopting a
  planning pipeline is a decision the user should make explicitly.
- `command-guard`, `candor`, `lean`, `skill-router`, `hindsight` — the
  always-on-suite bundle's user-scope baseline; point at that bundle (or a
  `--global` run) instead of re-installing its members per project.

## Rules

- Under `--yes`, every core row not yet installed installs with the same scope
  rules as tier 1 (`local` default, `project` with `--persist`, `user` with
  `--global`). Tier 3 never auto-installs.
- Without `--yes`, core rows are picker options like any other — nothing
  installs without a pick.
- Evidence column: the literal string `core` — the evidence is this file, not
  a manifest.

## Standing

**Recorded, curated by hand.** No script derives or checks this list against
the catalog; membership is a judgment about usefulness, not a measurement.
When plugins land in or leave the marketplace, re-judge the list against
`references/catalog.md` — and recount from the catalog rather than trusting
any count written here.
