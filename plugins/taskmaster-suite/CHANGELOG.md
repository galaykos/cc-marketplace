# Changelog — taskmaster-suite

Consumer-facing changes only. Newest first. Started at 0.17.0; earlier versions
have no entries rather than invented ones.

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
