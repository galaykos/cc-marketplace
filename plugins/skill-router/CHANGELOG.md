# Changelog

All notable changes to the skill-router plugin.

## 0.12.1

### Fixed

- `README.md` § Adding a file route told you to put prompt routes in
  `prompt-rules.tsv`. **That file has never existed in this plugin.**
  Prompt-shaped routing was removed deliberately —
  `hooks/route-prompt.sh`'s header records the reason ("a table only ever routes
  the phrasings its author thought of, and every new plugin needed a new row")
  and the command catalog plus model judgment replaced it. The section now says
  so explicitly, including that adding such a table is a decided-against design,
  so the next person to look does not go build the file the docs promised.

## 0.12.0

### Added

- **Engine-specific database routing.** `mysql-best-practices`,
  `mariadb-best-practices` and `postgresql-best-practices` shipped with no
  file-routing channel at all — they were named in this file's own limitation
  block as unrouted. Six rows now route them on `*.sql` and `**/migrations/**`,
  discriminated by a compose-image-first marker chain (compose → `.env.example`
  `DB_CONNECTION` → composer.json → package.json).

  The last two links are deliberate and invert the router's usual
  fire-if-uncertain bias, for these rows only: the three engine skills are
  mutually exclusive and their advice conflicts, so a repo with a composer.json
  and no database hint gets none of them rather than all three. A bare directory
  of `.sql` files with no manifests still fires all three — no signal, fail-open,
  and the one place the conflicting-advice cost is accepted. Three known misses
  are listed in `rules.tsv` rather than left to be discovered.

- **Plain-source rows for Go, Ruby and Rust** — `*.go`, `*.rb`, `*.rs` route to
  `low-cognitive-load` + `solid-principles`, matching what `*.ts` / `*.js` /
  `*.py` already did. The limitation block recorded this gap; it is now closed
  and the text says so.

- Twelve `# co-fire-ok:` declarations for the new pairs. Generic + engine on one
  file is intended (portable SQL vs what only that engine does); the engine rows
  discriminate against each other by distinct markers and need no blessing.

### Notes

- Correction to 0.11.0's note: `*.php` was NOT missing. Lines 78-79 have carried
  Laravel and plain-PHP rows behind `composer.json` markers all along.
- Still unrouted, deliberately: `code-smells`, `reuse-hygiene`, `yagni-check`,
  `plan-before-code`. `comment-discipline` stays absent by design — its own
  PreToolUse/PostToolUse hook is its delivery channel.
- No context-budget change: the dynamic channel measures a synthetic edit to
  `src/example.ts`, which no new row matches.

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
