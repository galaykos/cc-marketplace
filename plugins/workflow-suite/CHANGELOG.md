# Changelog — workflow-suite

Consumer-facing changes only. Newest first. workflow-suite is the bundle
taskmaster-suite became on 2026-09-14; the entries below 0.1.0 are taskmaster-suite's <!-- removed-ok -->
own, with its version numbers (started at 0.17.0; earlier versions have no entries
rather than invented ones).

## 0.2.0

### Changed
- **The full-fidelity mockup escalation is a rung of `taskmaster:visual-decisions`**,
  not design-studio, which was retired on 2026-09-14. Members are unchanged; ui-ux was
  already one of the fifteen, so nothing installs or uninstalls differently.
  <!-- removed-ok -->

## 0.1.0

### Changed
- **Renamed from taskmaster-suite; process-suite and quality-principles-suite folded <!-- removed-ok -->
  in** (consolidation plan §3.3, wave 3). Fifteen members: the core-suite baseline
  (candor, code-review, git-workflow, hindsight, secret-scanning, skill-router,
  stack-scan) plus taskmaster, task-runner, approaches, code-architecture, testing,
  debugging, ui-ux and security. New against taskmaster-suite 0.19.0: code-review, <!-- removed-ok -->
  git-workflow, hindsight, secret-scanning, debugging. Not carried over from
  process-suite: api-design, ultra-deep-research, brain (install by name); from <!-- removed-ok -->
  quality-principles-suite: resilience (by name). ui-ux and security stay although the <!-- removed-ok -->
  plan's table left them out: the inclusion test below — a member stays when the
  pipeline hard-wires it — is a recorded rule with a reason, and the table gave none.
- Listing cost: ~23,900 entry-chars — fits the 1M tier (30,000); at 200k the README's
  settings line is `skillListingBudgetFraction: 0.04`. An existing taskmaster-suite, <!-- removed-ok -->
  process-suite or quality-principles-suite install: uninstall it with its own <!-- removed-ok -->
  `uninstall` command, then install this one.

## 0.19.0

### Changed
- `orchestration` merged into `task-runner` on 2026-09-14 (consolidation plan §3.1); <!-- removed-ok -->
  the bundle lists 10 members and loses nothing — the two skills, the lint and the
  ultra-assess hook ship in task-runner.

## 0.18.0

### Added
- `candor` joins the bundle (11 members). The Stop hooks that held a task-runner run
  to its gate pass and refused a naked completion claim moved into candor's one gate
  on 2026-09-14 (consolidation plan §4.2); without it the pipeline's two done-time
  gates would be prose.

## 0.17.2

### Changed
- `lane.tsv` rows for this plugin's chassis-generated artifacts are now rendered by
  `scripts/generate.sh` from `lane` keys on its `.chassis.json` objects (a
  `# generated:start` … `# generated:end` block) instead of being typed by hand —
  same territory, trigger and yields_to; `generate.sh --check` fails if the two drift.
  No behaviour change for a user of the plugin.

## 0.17.1

### Added
- **Context-window requirement declared, and gated.** On the default 200k window
  this bundle's skill listing (~15,366 entry-chars) overflows the host's 6,000-char
  budget and descriptions are silently dropped; on the 1M tier it fits. The README
  now says so and names the fix — `skillListingBudgetFraction: 0.03` in the
  project's settings.json — and `pc_listing_declaration` fails the build if the
  declaration disappears while the bundle still overflows. The declared numbers
  themselves are `recorded`, not checked.

## 0.17.0

### Removed
- **22 of 32 members.** The bundle now ships the pipeline and only what it
  dispatches into: `taskmaster`, `task-runner`, `orchestration`,
  `code-architecture`, `approaches`, `stack-scan`, `skill-router`, `ui-ux`,
  `testing`, `security`.

  Removed: a11y, api-design, api-docs-first, brain, claude-authoring,
  code-review, comment-discipline, database, debugging, dev-env, devops,
  git-workflow, hindsight, lean, observability, packages, performance,
  plugin-scout, resilience, sql, system-design, web-dev. **Every one is still
  shipped and still works — install it directly.** Some are near-core;
  `code-review` and `git-workflow` especially.

  **Why:** Claude Code budgets its skill listing — a ~15,000-char absolute
  default binds before the documented 1%-of-context fraction — and past it the
  host drops descriptions, leaving names only, with the surviving set varying
  between identical reloads. At 32 members this bundle was 156 artifacts and
  29,100 chars, **2.0x the cap**, so roughly half its catalogue was unreachable
  on any given reload — including parts of the pipeline core. The overflow was
  never a token cost (dropped text is not sent and not charged); it was
  reachability, and every member paid it. Measurement and cost model:
  `rationale/2026-08-31-token-cost-review.md`.

  **Honest limitation:** the trimmed bundle sits at **99% of the cap with no
  headroom**. It fits today. One new skill in any member puts it over again, and
  `scripts/context-budget.sh` now reports that band as `NEAR` rather than
  claiming it is safely under.

  *Superseded by 0.17.1:* the "~15,000-char cap" this entry measured against was
  a mis-derived constant. The real budget is a formula — 6,000 chars at the
  default 200k window, 30,000 at 1M — so this bundle is not at "99% of the cap":
  it is over the 200k floor (declare the settings fix) and comfortably under at
  1M. The 32→10 cut itself stands.
