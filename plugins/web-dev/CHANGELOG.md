# Changelog — web-dev

Consumer-facing changes only. Newest first. Started at 0.11.0; earlier versions have no entries rather than invented ones.

## 0.11.0 — 2026-11-08

- **New `scripts/i18n_parity.py`, a translation parity checker.** It compares every locale in i18next (`locales/`, `public/locales/`) and vue-i18n (`src/locales/`, `src/i18n/`) JSON to the base locale and names missing keys, extra keys and placeholder sets that differ. An i18next `_one`/`_other` set counts as one key. It also reads Laravel `lang/`. Exit 0 parity, 1 findings, 2 usage or no base locale, 3 no locale files. `vite-best-practices` and `react-native-best-practices` say when to run it; `frontend-reviewer`, which cannot run it, lists it as not run on a locale diff.
- README lists `scripts/i18n_parity.py`.
