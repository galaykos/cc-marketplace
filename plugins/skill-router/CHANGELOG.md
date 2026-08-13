# Changelog

All notable changes to the skill-router plugin.

## 0.11.0

### Fixed

- **The router was inert on every real install.** `prime.sh`, `route.sh` and
  `route-prompt.sh` each resolved the installed-plugins root as
  `dirname "$CLAUDE_PLUGIN_ROOT"`. That is correct only under a flat
  `<plugins>/<plugin>` layout; a real install is versioned
  (`<marketplace>/<plugin>/<version>`), so the result was
  `<marketplace>/<plugin>` — a directory whose only children are version
  numbers. Consequences, all silent:
  - every `owning_plugin` was reported not-installed, so **every glob rule was
    suppressed** and no edit ever produced a nudge;
  - `route-prompt.sh`'s catalog glob (`<root>/*/commands/*.md`) was one path
    segment short, matched nothing, and the hook exited before printing —
    **no command catalog was ever injected**;
  - `prime.sh`'s session index was filtered down to nothing.

  Resolution now lives in one place, `hooks/plugins-dir.sh`, and handles both
  layouts. Skill and command paths resolve through the version segment, and a
  cache holding several releases of one plugin contributes exactly one catalog
  entry (the highest version it can order).

### Added

- `hooks/plugins-dir.sh` — layout detection plus `pr_plugin_installed`,
  `pr_plugin_root` and `pr_plugin_roots`, sourced by all three hooks. Absent or
  unsourceable, every caller falls back to fire-if-uncertain; the router's
  declared bias is toward surfacing, never toward silence.
- `scripts/smoke/versioned-layout-tests.sh`, wired as its own CI step. It runs
  the firing, suppression, catalog-uniqueness and skill-path assertions against
  **both** layouts. This is the gate that was missing: the three existing router
  harnesses build a flat scratch layout by construction, so 73 green assertions
  could not see a bug that only exists under the layout users actually have.

### Notes

- The `~2.6k` dynamic-token figure in the README and in
  `context-budget-dynamic-baseline.json` is measured against a flat checkout. It
  is the cost a *working* router pays; before 0.11.0 a real install paid nothing,
  because nothing was emitted.
- Not addressed here: `rules.tsv` coverage. There is still no plain `*.php` row
  (only `*.blade.php`), and 44 glob + 11 content rows cover 127 shipped skills.
  A working router with sparse rules is a different problem from a dead one.
