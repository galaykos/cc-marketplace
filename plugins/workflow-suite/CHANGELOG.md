# Changelog — workflow-suite

Consumer-facing changes only. Newest first. workflow-suite is the bundle
taskmaster-suite became on 2026-09-14; the entries below 0.1.0 are taskmaster-suite's <!-- removed-ok -->
own, with its version numbers (started at 0.17.0; earlier versions have no entries
rather than invented ones).

## 0.2.7 — 2026-09-16

### Changed
- **`/workflow-suite:uninstall` now carries `disable-model-invocation: true`** (audit D1, `rationale/marketplace-trend-audit-2026-09-16.md`). A bundle uninstall is a side-effect workflow the user times, the shape the host's own docs name for the flag (`/deploy`): the model can no longer pick it from its description, and the description leaves the always-on listing. Rendered from `templates/suite-uninstall.md.tmpl`; the command body is unchanged. Standing: the flag's presence is a **gate** (`generate.sh --check` byte-matches the rendered command to the template); what the host does with it is **recorded** — measured once on a plugin skill, 2026-08-21 (`rationale/host-lever-probes-2026-08-21.md`); on a command it rests on the host's doc sentence (audit T2), and nothing re-runs either.

### Fixed
- **The root README's bundle table said `0.04` for this bundle while this README says `0.05`** (audit G2). The generator string behind the table is corrected; `generate.sh --check` was green with both copies of the wrong number agreeing, which is why the drift survived 0.2.6's re-measurement.

## 0.2.6

### Fixed
- **"Pairs well with craft-suite — … and ui-ux's real-component preview" contradicted this README's own exclusions list**, which already said the full-fidelity escalation is a rung of `taskmaster:visual-decisions` — a skill this bundle ships. Installing craft-suite for it bought nothing. The line now names what craft-suite actually adds (craft-layer's creative direction, motion catalog, WebGL) and says where the preview lives.
- **The testing member was described as shipping "test review".** It ships one command, `/testing:flake-hunt`, plus the test-engineer agent; test review rides the code-review fan-in. Corrected.
- **Listing-cost figures re-measured**: 24,165 entry-chars, not "~23,900" (both places). The first measurement in this release read 23,775 and recommended `0.04` with a 225-char margin; four members then grew their descriptions in the same release and the bundle crossed 24,000, so the README now recommends `0.05` and says why. One new skill in any member moves the figure, and the symptom is silent eviction rather than an error.

## 0.2.5

### Fixed
- **The uninstall no longer deletes the plugins you just chose to keep.** Step 6 passed `--prune` on the bundle line unconditionally, described in the command as "a harmless no-op otherwise" — but `claude plugin uninstall --prune` also removes auto-installed dependencies that are no longer needed, which is exactly the set you decline on any pick other than "remove the bundle and its N auto-installed plugins". It was a no-op only when N was 0, the common case, which is how it survived. `--prune` is now conditional on the pick.
- **Provenance is now read from the record for YOUR scope.** `installed_plugins.json` maps each plugin id to an ARRAY of records, one per scope/project, and the step said "check each candidate's record" — so a plugin auto-installed in some other project read as auto-installed here. Measured 2026-09-15 on one machine: 67 of 74 plugin ids carried more than one record and 30 had records that DISAGREE about `auto`, every disagreement in the delete-it direction.

## 0.2.3

### Fixed
- **The uninstall no longer offers to delete plugins you installed yourself** — same provenance split as the other bundles; it defaults to keeping anything it cannot prove it installed.
- **The README now warns against installing `core-suite` alongside this bundle**, which is a strict subset of it.

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

## Inherited history — taskmaster-suite (before 2026-09-14)

The entries below carry taskmaster-suite's own version numbers and are not releases of
this bundle; they are kept as `###` headings so the changelog-coverage gate cannot
mistake one for a current entry.

### 0.19.0

### Changed
- `orchestration` merged into `task-runner` on 2026-09-14 (consolidation plan §3.1); <!-- removed-ok -->
  the bundle lists 10 members and loses nothing — the two skills, the lint and the
  ultra-assess hook ship in task-runner.

### 0.18.0

### Added
- `candor` joins the bundle (11 members). The Stop hooks that held a task-runner run
  to its gate pass and refused a naked completion claim moved into candor's one gate
  on 2026-09-14 (consolidation plan §4.2); without it the pipeline's two done-time
  gates would be prose.

### 0.17.2

### Changed
- `lane.tsv` rows for this plugin's chassis-generated artifacts are now rendered by
  `scripts/generate.sh` from `lane` keys on its `.chassis.json` objects (a
  `# generated:start` … `# generated:end` block) instead of being typed by hand —
  same territory, trigger and yields_to; `generate.sh --check` fails if the two drift.
  No behaviour change for a user of the plugin.

### 0.17.1

### Added
- **Context-window requirement declared, and gated.** On the default 200k window
  this bundle's skill listing (~15,366 entry-chars) overflows the host's 6,000-char
  budget and descriptions are silently dropped; on the 1M tier it fits. The README
  now says so and names the fix — `skillListingBudgetFraction: 0.03` in the
  project's settings.json — and `pc_listing_declaration` fails the build if the
  declaration disappears while the bundle still overflows. The declared numbers
  themselves are `recorded`, not checked.

### 0.17.0

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
