# Changelog — laravel

Consumer-facing changes only. Newest first. Started at 0.10.3; earlier versions have no entries rather than invented ones.

## 0.11.1 — 2026-11-16

- **`backend-engineer` checks before writing new code and before handing back.** Before adding a helper, class, component, factory or status list it greps the repo for one and extends what exists; it extracts a shape on its second use; after fixing a pattern it greps sibling files for the same pattern; it keeps a card's `<invariant>`, `<reuse>` and `<interface>` lines and reports how each invariant holds. Before hand-back it runs the project's own linters and analyzers on every touched file, tests included, in addition to the tests, and reports an analyzer whose config skips one of them. Why: reviews of two real runs traced most post-build fix rounds to cross-card contract gaps and code rewritten beside an existing helper, and one run never ran its configured analyzer. Its own verify step now reads "tests and `php artisan` checks, then the project checks", no longer "or a static analyzer".
- Standing: agent-graded (agent text; no harness reads a worker's return).

## 0.11.0 — 2026-11-08

- **New `scripts/i18n_parity.py`, a translation parity checker.** It compares every locale under `lang/` (PHP and JSON) to the base locale and names missing keys, extra keys and placeholder sets that differ. It also reads i18next and vue-i18n JSON. It parses PHP and never runs it; a file it cannot read is reported, not guessed. It skips the `lang/php_<locale>.json` files laravel-vue-i18n generates. Exit 0 parity, 1 findings, 2 usage or no base locale, 3 no locale files. `laravel-best-practices` says when to run it.
- README lists `scripts/i18n_parity.py`.

## 0.10.4 — 2026-10-31

- **`laravel-best-practices` now warns that `->change()` drops every modifier you do not restate (Laravel 11+).** The leverage map's Laravel 11 section adds that rule. It also adds Carbon 3's float and possibly negative `diffIn*` results, the `mariadb` driver's native `uuid()` column, and 11's end of support (security fixes ended 2026-03-12).
- **`inertia-best-practices` says where v3 puts the page data**: a `<script type="application/json">` element, no longer the `data-page` attribute. Props stay visible in View Source either way.
- **New eval case `change-drops-modifiers`.** It is an unmeasured candidate: no control arm has run.

## 0.10.3 — 2026-10-28

- **The `inertia-best-practices` skill's description now reads in short, plain sentences.** Same adapters, topics and version note; it keeps the words the model matches it on.
