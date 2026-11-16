# Changelog — web-dev

Consumer-facing changes only. Newest first. Started at 0.11.0; earlier versions have no entries rather than invented ones.

## 0.11.1 — 2026-11-16

- **`web-developer` checks before writing new code and before handing back.** Before adding a helper, class, component, factory or status list it greps the repo for one and extends what exists; it extracts a shape on its second use; after fixing a pattern it greps sibling files for the same pattern; it keeps a card's `<invariant>`, `<reuse>` and `<interface>` lines and reports how each invariant holds. Before hand-back it runs the project's own linters and analyzers on every touched file, tests included, in addition to the tests, and reports an analyzer whose config skips one of them. Why: reviews of two real runs traced most post-build fix rounds to cross-card contract gaps and code rewritten beside an existing helper, and one run never ran its configured analyzer. Its own verify step now reads "tests and build, then the project checks", no longer "tests, linter, or build".
- Standing: agent-graded (agent text; no harness reads a worker's return).

## 0.11.0 — 2026-11-08

- **New `scripts/i18n_parity.py`, a translation parity checker.** It compares every locale in i18next (`locales/`, `public/locales/`) and vue-i18n (`src/locales/`, `src/i18n/`) JSON to the base locale and names missing keys, extra keys and placeholder sets that differ. An i18next `_one`/`_other` set counts as one key. It also reads Laravel `lang/`. Exit 0 parity, 1 findings, 2 usage or no base locale, 3 no locale files. `vite-best-practices` and `react-native-best-practices` say when to run it; `frontend-reviewer`, which cannot run it, lists it as not run on a locale diff.
- README lists `scripts/i18n_parity.py`.
