# Changelog — plugin-scout

Consumer-facing changes only. A version bump with nothing here is a number; this
file is what makes an upgrade readable. Newest first.

## 0.11.2

### Fixed
- **The Install section renders as a list again.** Items 2, 3 and 4 began mid-line, so
  markdown folded the whole four-step install procedure into item 1 and it read as one
  run-on paragraph. The jam first appears at `879a4f3`, at a body of exactly 150 lines
  — lines for a new Detection paragraph were clawed back by unwrapping the list. Same
  failure `24879ad` had already fixed in vite, which survived only because vite had two
  lines of slack and this had none.

## 0.11.1

### Changed
- **Regenerated `catalog.md`** after three marketplace descriptions were shortened
  (comment-discipline, quality-suite, quality-principles-suite). The catalog is a
  chassis-generated view of every plugin's manifest description, so a description
  edit anywhere in the marketplace drifts this file until `scripts/generate.sh
  --write` runs. No behaviour change; the rows the scout ranks are unchanged, only
  their wording.

## 0.11.0

### Changed
- **`--yes` installs more than before.** The auto-installer now covers tier-1
  signal-backed picks (including `references/signals.md` evidence rows, which
  previously sat outside the auto-set) PLUS the new tier-2 any-project core —
  eight curated stack-agnostic plugins listed in `references/any-core.md`. A
  `--yes` run that used to install only what a manifest earned now also brings
  code-review, debugging, testing, git-workflow, code-architecture,
  secret-scanning, comment-discipline, and packages. Tier 3 still never
  auto-installs.
- **The report and picker now iterate the whole catalog.** Three tiers instead
  of two; every marketplace leaf (except bundles and plugin-scout itself)
  appears exactly once, and the picker pages until all of it was offered. A
  tier-1 stack plugin whose signal did not fire is no longer silently dropped —
  it shows as tier 3 with "no signal detected".

### Added
- **`--global` flag**: installs this run at `--scope user` — machine-wide,
  every repo — with a required notice saying so. Mutually exclusive with
  `--persist`; combinable with `--yes`. Default scope stays `local`,
  `--persist` stays `project`.
- `references/any-core.md`: the curated any-project core list, with per-row
  rationale, deliberate exclusions, and its standing (recorded, hand-curated —
  no script derives it).
