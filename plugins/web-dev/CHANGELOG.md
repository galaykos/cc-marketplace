# Changelog — web-dev

Consumer-facing changes only. Newest first. Started at 0.11.0; earlier versions have no entries rather than invented ones.

## 0.12.1 — 2026-11-23

- **web-developer reaches the rubric skills without a dispatcher.** When no dispatch injects a skill's Read path, the worker now Reads this plugin's skills at `${CLAUDE_PLUGIN_ROOT}/skills/<name>/SKILL.md` and another plugin's from its `installPath` in `claude plugin list --json`, falling back to the plugin cache. Only skills matching the detected stack are read, and one it cannot find or is denied is named in its return as not applied. Before, a direct dispatch with no skill-router evidence ran without its rubric and said nothing. A literal `CLAUDE_PLUGIN_ROOT` inside a skill it Reads is read as that skill's plugin root, so scripts a skill names resolve. Standing: recorded; `pc_agent_skill_reach` checks the body names each skill, not that the agent reads it.
- **web-developer names its five skills and drops a browser it never had.** The rubric names the skills instead of pointing at frontmatter the agent never sees; `client-widgets.md` is an absolute path; browser proof is the Playwright CLI through Bash, else reported unverified for the caller's walk. Standing: gate (`pc_agent_skill_reach`) for the names; recorded for the rest.
- **frontend-reviewer reaches its rubric and fetches live docs.** It names nextjs, vite, react-native and inertia best-practices in its body and Reads them by path (inertia through the plugin cache), gains WebFetch for version-sensitive claims, reports Bash-only rubric steps (the SSR `curl`, codemods) as not run, and names accessibility as not reviewed when ui-ux's a11y-audit is absent. Standing: gate (`pc_agent_skill_reach`) for the names; recorded for the rest.

## 0.12.0 — 2026-11-21

- **New PreToolUse Bash hook `expo-prebuild-guard.sh`, this plugin's first.** From Expo SDK 57 a bare `expo prebuild` clears and regenerates `ios/` and `android/`. The hook asks before a prebuild without `--no-clean` when those dirs hold uncommitted or untracked files, are committed and not gitignored (the bare workflow), or sit outside git. A CNG project whose native dirs are gitignored gets no ask; below SDK 57 only a typed `--clean` asks. Asks, never denies.
- README: the Expo bullet said `expo prebuild --clean` overwrites hand edits; from SDK 57 the bare command does. The preloaded `a11y-audit` body's stale byte and token counts are replaced by a recount command.
- Standing: gate for the hook's patterns (`scripts/__tests__/expo-prebuild-guard.test.sh`, 18 cases, 10 of them must stay silent). Misses: `npm run prebuild` and other wrappers, `eas build --local`, a `cd` through a variable.

## 0.11.1 — 2026-11-16

- **`web-developer` checks before writing new code and before handing back.** Before adding a helper, class, component, factory or status list it greps the repo for one and extends what exists; it extracts a shape on its second use; after fixing a pattern it greps sibling files for the same pattern; it keeps a card's `<invariant>`, `<reuse>` and `<interface>` lines and reports how each invariant holds. Before hand-back it runs the project's own linters and analyzers on every touched file, tests included, in addition to the tests, and reports an analyzer whose config skips one of them. Why: reviews of two real runs traced most post-build fix rounds to cross-card contract gaps and code rewritten beside an existing helper, and one run never ran its configured analyzer. Its own verify step now reads "tests and build, then the project checks", no longer "tests, linter, or build".
- Standing: agent-graded (agent text; no harness reads a worker's return).

## 0.11.0 — 2026-11-08

- **New `scripts/i18n_parity.py`, a translation parity checker.** It compares every locale in i18next (`locales/`, `public/locales/`) and vue-i18n (`src/locales/`, `src/i18n/`) JSON to the base locale and names missing keys, extra keys and placeholder sets that differ. An i18next `_one`/`_other` set counts as one key. It also reads Laravel `lang/`. Exit 0 parity, 1 findings, 2 usage or no base locale, 3 no locale files. `vite-best-practices` and `react-native-best-practices` say when to run it; `frontend-reviewer`, which cannot run it, lists it as not run on a locale diff.
- README lists `scripts/i18n_parity.py`.
