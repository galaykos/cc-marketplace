# Changelog

All notable changes to the stack-scan plugin. Earlier releases (0.1.0–0.6.3) were not
recorded; plugin-scout, which was merged into this plugin, kept its own changelog (up to
0.15.10) — it is in git history under its old directory, last present at commit `db97e51`.

## 0.8.3 — 2026-09-20

### Changed
- `plugin-scout/references/catalog.md` regenerated: the `ask-ledger` leaf plugin joins the catalog.

## 0.8.2

### Changed
- **The scout catalog re-rendered for the frontend-suite description fix (audit G3).** `frontend-suite`'s marketplace description claimed its uninstall "prunes its auto-installed plugins" while the command keeps them unless picked; the fix in `.claude-plugin/marketplace.json` re-rendered the one row here by `generate.sh --write`, which does not bump this plugin — the exact case CLAUDE.md's 2026-09-15 note describes (`rationale/marketplace-trend-audit-2026-09-16.md`). No behaviour change.

## 0.8.1

### Changed
- **The scout catalog gains the `all-plugins` row, and `--full` excludes it by construction.** A new leaf plugin registered in the marketplace manifest; this catalog is generated from it, so the row arrives here by `generate.sh --write`. It still appears once in the tier-3 remainder like every leaf (completeness rule), but `references/stack-relevance.md` and `references/flags.md` now list it beside `stack-scan` in the `--full` exclusion: an installer of everything inside a curated plan defeats the plan, so `--full` names `/all-plugins:install` as the everything-door instead of installing it.

## 0.8.0

### Fixed
- **The `--skills` install command now actually installs.** The skill, the command and
  the README all printed `npx -y skills add <owner>/<repo> --skill <skillId> -y`, and
  `skills/vercel-skills-scout/references/mechanics.md` had already recorded that
  `--skill` matches the CLI's own DISPLAY name — passing the skills.sh `skillId` prints
  the repo's skill list and exits 0 **without installing**. All three call sites now
  print the two-command pair (`-l` to read the exact listed name, then
  `--skill '<listed name>' -y`) and confirm with `npx -y skills ls`, because exit 0
  proves nothing on that path.
- **`stack-scan` no longer suggests itself.** Two `references/signals.md` rows offered
  the plugin that is running the scout (a leftover from when `plugin-scout` was its own
  plugin, merged in 2026-09-14) — and the Report rule excludes `stack-scan` by
  construction, so neither row had anywhere to print. They are `—` routing rows now:
  a manifest names `/stack-scan:audit`, and an uncovered-stack manifest (`go.mod`,
  `pyproject.toml`, `Cargo.toml`, …) names `/stack-scan:report` plus
  `--skills`. `references/stack-relevance.md` said `--full` excluded `stack-scan` by
  construction in one paragraph and installed it anyway in another; settled to the
  first.

### Changed
- **`toolchain-experts` is a tier-1 signal.** A repo carrying `phpstan.neon`,
  `psalm.xml`, `eslint.config.*`, `biome.json`, `.stylelintrc*`, `tsconfig.json` or
  the matching devDependency now earns it with cited evidence and it joins the `--yes`
  set. It previously sat in the universal remainder — in the repos whose configured
  analyzers are the entire reason it exists.
- **The listing-cap warning stopped over-claiming.** "Skills stop being reachable" was
  measured false on 2026-09-15: removing a description outright changed firing by
  nothing (47/50 vs 47/50, `rationale/2026-09-15-listing-eviction-probe.md`). The cost
  figure still prints — it prices the SET, and the same probe found firing does drop
  when several adjacent skills contest one territory. Overlap, not bytes.
- **Scout references recounted after the 2026-09-14 consolidation**, which halved the
  catalog and left the arithmetic behind: `picker.md` billed the exhaustive picker at
  "4 calls and 16 blocking questions" over "51 rows" (in the same paragraph that
  criticises a frozen number), its sample report offered `a11y`, `performance`, `sql`,
  `mariadb`, `stack-scan` and a duplicated `database`, and its overlap argument quoted
  "26 of 63 rows"; `relevance.md` carried the same stale sample and a "0.12 picker cut"
  this plugin never had; `flags.md` said 21 of 27 leaves ship a hook (20 do) and still
  billed `--all` at "~5 calls and ~20 questions"; `stack-relevance.md` said 22 of 26
  leaves are any-stack (23). Every one of those is now derived at run time from
  `references/catalog.md` or stated as a ratio, not frozen as an integer.
- **`package-hygiene` is 27 lines shorter.** Cut: the semver definition, "commit the
  lockfile", and an Anti-patterns section that re-explained six rules the body already
  stated — all shapes `rationale/measured-zero-shapes.md` measured at zero delta. Kept:
  the two-segment tilde trap (composer `~1.2` ≠ npm `~1.2`), the three fix lanes, the
  override-expiry rule, and the `--omit=dev` flag drift. The anti-pattern NAMES stay as
  review handles.
- **Two descriptions now carry the phrasings users actually type** — `installed-versions`
  catches "what version of X is installed" and "which PHP/Node/framework does this
  project run"; `package-hygiene` catches `npm audit` / `composer audit` verbatim.
- `installed-versions`' ecosystem reference stopped naming the downstream consumers of
  a resolved pnpm `catalog:` version as `vite`, `nextjs`, `vue3` and `react` — all four were removed as
  plugins — so it points at `web-dev`, which ships the skills that branch on a major.

## 0.7.8

### Changed
- **The scout catalog re-renders `code-review`'s description.** That plugin corrected the deny bound its description had stated as "once per file per session" when the hooks had moved to twice; this catalog is generated from the marketplace manifest, so it carried the stale figure until regenerated. No behaviour here changed.

## 0.7.7

### Changed
- **Scout catalogue regenerated** for the new `toolchain-experts` plugin, so
  `/stack-scan:suggest` can offer it to a repo that has analyzers configured. Generated
  by `scripts/generate.sh --write`; edit the marketplace entry, never the catalogue row.

## 0.7.6

### Changed
- **`design-studio` removed from every scout reference** (`signals.md`, <!-- removed-ok -->
  `stack-relevance.md`, `picker.md`, `flags.md`, `official-complements.md`): the plugin
  was retired on 2026-09-14. The two `components.json` signal rows now earn `ui-ux` and
  print shadcn's own MCP install line, which is what a configured registry actually
  calls for; the JS/web stack class lists two plugins, not three; and the `MCP servers
  added:` plan line says out loud that no plugin in this marketplace ships one today,
  while the `Beyond this marketplace` block still prints playwright, context7 and
  serena as the user's own trust decision. <!-- removed-ok -->

- `licence-scan.sh` says which lockfiles it reads. A pnpm/yarn/bun repo exited 3 with a
  message naming only `package-lock.json` and `composer.lock`, which reads as "no
  dependencies here" when the truth is "this lane cannot see yours" — those lockfiles
  carry no per-package `license` field. It now names the lockfile it found and points at
  `npm install --package-lock-only` or the package manager's own licence tooling.
  Harness case added. (Shipped in 0.7.6 with no entry; added by a second branch review.)
- `plugin-scout` catalog regenerated for the corrected `candor` and `core-suite`
  descriptions (five-clause gate). Generated file, no behaviour change in the scan.

## 0.7.5

- `plugin-scout` catalog regenerated: the hindsight row now says it mines session AND
  subagent transcripts and files defects against the running plugin artifact
  (hindsight 0.9.0). Generated file, no behaviour change in the scan.

## 0.7.4

- `plugin-scout` references recounted after the 2026-09-14 consolidation:
  `stack-relevance.md` said "eight bundles", "35 eligible leaves" and "the two domain
  leaves" (there are four bundles, 26 eligible leaves and no domain leaf); `flags.md`
  said 23 of 36 leaves ship a hook (21 of 27); `official-complements.md` named
  `terse:commit` as the `/commit` overlap (dropped in candor 0.3.0). Doc-only; the
  picker and the scan read the catalog, not these numbers.

## 0.7.3

### Changed
- The bundles were rebuilt 2026-09-14 (eight → four): `picker.md`'s bundle examples and
  `any-core.md`'s global-scope pointer name `core-suite`, `workflow-suite` and
  `frontend-suite`; the README's pipeline-bundle row names workflow-suite. `catalog.md`
  regenerated. No behaviour change.

## 0.7.2

### Changed
- plugin-scout references name candor's terse reply mode where they named the terse
  plugin, which was merged into candor on 2026-09-14. `catalog.md` regenerated.

## 0.7.1

### Changed
- plugin-scout references (`signals.md`, `stack-relevance.md`, `picker.md`, `flags.md`,
  `official-complements.md`) suggest `design-studio` where they suggested <!-- removed-ok -->
  design-lab — theme-design and design-lab were merged into it (2026-09-14
  consolidation plan). `catalog.md` regenerated.

## 0.7.0

### Added
- **The plugin-scout and vercel-skills-scout plugins merged into this one** (2026-09-14
  consolidation plan, `rationale/marketplace-consolidation-plan-2026-09-14.md`). Both
  read the same manifests this plugin already inventories, and the plugin boundary had
  forced two byte-identical copies of the TTY picker script.
- `/stack-scan:suggest` — the three-tier marketplace suggestion with every flag
  `/plugin-scout:suggest` carried (`--yes`, `--full`, `--stack`, `--all`, `--persist`, <!-- removed-ok -->
  `--global`), plus a `--skills [query]` mode that runs the former
  `/vercel-skills-scout:suggest` — skills.sh search with provenance, preview and <!-- removed-ok -->
  explicit picks only. The two modes never combine: `--skills` beside any plugin-mode
  flag aborts, so the third-party side keeps its no-auto-install floor as a mode rule
  rather than a plugin boundary.
- Skills `plugin-scout` and `vercel-skills-scout` ship here under their old names, with
  every reference file; `scripts/pick.sh` and its harness ship once.
- The generated marketplace catalog now renders to
  `skills/plugin-scout/references/catalog.md` under this plugin.

### Changed
- Detection in the plugin-scout skill runs this plugin's own `/stack-scan:report` for
  version truth instead of checking whether a sibling is installed.
- The `--full` exclusion-by-construction is now `stack-scan` itself (the host of the
  scout), not `plugin-scout`.
- Keyword `research` added for the skills.sh mode.

### Removed (marketplace-wide)
- `pc_pick_parity` and its harness cases: with one copy of the picker there is nothing
  to keep in step.
