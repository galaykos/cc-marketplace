# Changelog

core-suite is the bundle always-on-suite became on 2026-09-14; the entries below 0.1.0 <!-- removed-ok -->
are always-on-suite's own, with its version numbers. <!-- removed-ok -->

## 0.1.4

### Fixed
- **The uninstall no longer offers to delete plugins you installed yourself.** It now splits candidates by provenance and defaults to KEEPING anything without an auto-install marker. Measured 2026-09-15: that marker was present on 40 of 725 install records on one real machine, and four projects with a suite installed carried zero — so the old "remove every dependency" default was aimed squarely at hand-installed plugins.
- **The README named four of candor's five Stop clauses while calling them five.** The fifth (lockfile drift) is now named.
- **The README now warns against installing `workflow-suite` alongside this bundle.** All seven members here are in that one; with both installed, `/core-suite:uninstall` keeps every member and removes only this manifest — a no-op that reads like a cleanup.

## 0.1.1 — 2026-09-15

- **Called candor's Stop gate "four-clause" after it grew a fifth.** The bundle
  description is always-on text; every other surface (candor's own description, its
  README and hook header, and this bundle's own README) already said five, so the one
  artifact a user reads before installing was the one that was wrong. Found by a second
  branch review.

## 0.1.0 — 2026-09-14

- **Renamed from always-on-suite, and quality-suite folded in** (consolidation plan §3.3, <!-- removed-ok -->
  wave 3). Seven members: the six always-on members plus `code-review`, which was <!-- removed-ok -->
  quality-suite's review surface. Not taken from quality-suite: `code-architecture` <!-- removed-ok -->
  (workflow-suite carries it — plan-before-code is project work, not a baseline) and
  `command-guard` (the 0.2.0 exclusion below still holds: its ask tier turns the
  host's silent command classifier into a permission click on every repo; install it
  by hand with `CLAUDE_DESTRUCTIVE_GUARD=deny-only`). The plan's table also dropped
  `hindsight`; it stays because its ledgers live under `~/.claude` and user scope is
  its native home — the plan gave no reason, the 0.1.0 membership rule does.
- Listing cost at the default 200k window: ~6,880 entry-chars against the 6,000
  floor (recount: `bash scripts/context-budget.sh`, listing channel); the README
  names the `skillListingBudgetFraction: 0.02` line. An existing always-on-suite or <!-- removed-ok -->
  quality-suite install: uninstall it with its own `uninstall` command, then install <!-- removed-ok -->
  this one.

---

## 0.6.0

### Changed
- `terse` merged into `candor` on 2026-09-14 (consolidation plan §3.1), so the bundle <!-- removed-ok -->
  lists six members: candor now carries the terse reply mode (`/candor:level`) beside
  its Stop gate. Nothing a user of the bundle sets changes — the level file and
  `CC_TERSE` keep their names.

## 0.5.0

### Changed
- `plugin-scout` and `vercel-skills-scout` merged into `stack-scan` on 2026-09-14, so the <!-- removed-ok -->
  bundle now installs `stack-scan` in their place: `/stack-scan:suggest` carries both
  scouts (plugin mode and `--skills`). stack-scan was previously a deliberate exclusion
  ("per-project in what it reads"); it is a member now because the scout that bridged to
  the project tier lives inside it, and its report/audit commands are inert until invoked.
  Seven members.

## 0.4.0

### Removed
- `lean` leaves the bundle: the plugin was removed from the marketplace on
  2026-09-14 (consolidation plan, `rationale/marketplace-consolidation-plan-2026-09-14.md`).
  Its cost-model rule is stated inline by `code-architecture:coding-entry`; the
  goal-lean rigour tier is overseer's. Eight members remain. <!-- removed-ok -->

## 0.3.0

### Added
- `vercel-skills-scout` joins the bundle beside `plugin-scout`: the same scan-and-suggest
  shape for third-party skills.sh skills, project-agnostic, inert until invoked.
  (2026-09-03 marketplace review: it belonged to no suite.)

## 0.2.3

### Changed
- `lane.tsv` rows for this plugin's chassis-generated artifacts are now rendered by
  `scripts/generate.sh` from `lane` keys on its `.chassis.json` objects (a
  `# generated:start` … `# generated:end` block) instead of being typed by hand —
  same territory, trigger and yields_to; `generate.sh --check` fails if the two drift.
  No behaviour change for a user of the plugin.

## 0.2.2

### Changed
- README only: the exclusion notes name code-review's comment-discipline lane where they
  named the comment-discipline plugin (merged into code-review, 2026-09-02). Membership <!-- removed-ok -->
  and cost unchanged.

## 0.2.1

### Changed
- Regenerated `/always-on-suite:uninstall` from the shared template: it no longer
  names the `everything` meta-bundle as a scope that might also list a member, <!-- removed-ok -->
  because that bundle was removed from the marketplace. Membership and behaviour
  are unchanged.

## 0.2.0

### Removed
- **command-guard is no longer a member.** Not a quality judgement on the plugin —
  it is still shipped and still recommended, and this bundle's README now points
  at it under "Pairs well with". The reason is a new membership rule (rule 3, "adds
  no interruption you did not ask for") that command-guard's **ask** tier fails by
  construction, as its own README states: where the host classifies commands with a
  classifier of its own, a `PreToolUse` `ask` *overrides* that classifier, so the
  tier does not add a check — it replaces a silent judgement with a human click.
  Free once; paid on every prompt in every repo when the install is permanent and
  global, which is the only shape this bundle has.

  The deny tier does not have that problem and was never the objection. Install
  command-guard directly with `CLAUDE_DESTRUCTIVE_GUARD=deny-only` to keep the hard
  stops (`migrate:fresh`, `DROP DATABASE`, `rm -rf /`, `terraform destroy`) with the
  prompts silenced. That configuration is a genuine baseline; the default is not.

### Added
- **terse.** The 0.1.x README excluded it as "a per-user style choice that stays
  inert until you set a level". Inert-until-opted-in is what makes it *safe* here,
  and the pairing was the missed half: lean already prices what gets written to
  disk, and terse is the same discipline one surface over — what gets said in chat.
  Its own description puts code and files out of scope, so the two do not overlap.

### Changed
- README gains a **"What this costs, honestly"** section, because both members
  above are the bundle's two largest lines and the marketplace bundle table
  overstates one of them for this bundle's actual install shape:
  - terse is **848** always-on tokens with no level set and **1,891** with one.
    The `SessionStart` hook injects nothing until a level exists, so the off state
    is descriptions and nothing else. Net effect on the bundle, re-baselined:
    always-on 943 → **1,641**, activated 975 → **2,715**, dynamic unchanged at
    2,386 (command-guard's `PreToolUse` never ran in that channel anyway — the
    probe does not execute Bash-matched hooks, so its 0 there was never a
    measurement of silence).
  - skill-router reads ~2.3k per work-shaped prompt in that table, but the figure
    is built from **sibling** plugins' command frontmatter and the table is
    measured in the marketplace repo with all 52 leaves present. Re-measured
    against this bundle's eight members: **~602 tokens** (2,410 bytes).
- README records a limitation nothing else stated: **none of skill-router's 126
  routing rows names a plugin in this bundle**, so on a bare always-on install its
  `PostToolUse` router has nothing to route to. It is a forward-looking member —
  `/plugin-scout:suggest` brings the project tier, and skill-router is what makes <!-- removed-ok -->
  those skills fire on edit.
- **brain** is now named in "Deliberately not included" with its reason, rather than
  being unmentioned. It fails rule 2 twice: it scaffolds a committed `brain/`
  directory, and until `/brain index` runs its `SessionStart` hook greets you in
  every un-indexed repo.
- Member count is unchanged at 8.

## 0.1.1

Baseline release. No changelog was kept before 0.2.0; this file starts here rather
than inventing entries for releases nobody recorded.
