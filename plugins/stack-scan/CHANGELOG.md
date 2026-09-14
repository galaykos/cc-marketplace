# Changelog

All notable changes to the stack-scan plugin. Earlier releases (0.1.0–0.6.3) were not
recorded; plugin-scout, which was merged into this plugin, kept its own changelog (up to
0.15.10) — it is in git history under its old directory, last present at commit `db97e51`.

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
  `official-complements.md`) suggest `design-studio` where they suggested
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
