# Changelog — plugin-scout

Consumer-facing changes only, with one structural exception:
`references/catalog.md` is generated from every other plugin's description, so a
description edit anywhere in the marketplace forces a version bump here and an
entry below. Those entries say "regenerated catalog" and carry no behaviour
change — skip them on an upgrade. A version bump with nothing here is a number;
this file is what makes an upgrade readable. Newest first.

## 0.13.10

### Changed
- The any-project core drops the comment-discipline row: its rule ships inside <!-- removed-ok -->
  code-review (already core) since 2026-09-02. Regenerated catalog.

## 0.13.9

### Changed
- The observability and performance signal rows suggest `resilience`, which absorbed <!-- removed-ok -->
  both plugins on 2026-09-02. Regenerated catalog.

## 0.13.8

### Changed
- The "also api-docs-first" signal row is gone: the docs-first check ships inside <!-- removed-ok -->
  api-design since 2026-09-02, which the `api-design` row already suggests. Regenerated catalog.

## 0.13.7

### Changed
- Regenerated catalog: ui-ux, craft-layer, craft-suite, frontend-suite, quality-principles-suite
  descriptions after the a11y and threejs merges (2026-09-02). <!-- removed-ok -->

## 0.13.6

### Changed
- **The manifest-present signal suggests `stack-scan`**, which absorbed the packages <!-- removed-ok -->
  plugin on 2026-09-02. Regenerated catalog.

## 0.13.5

### Changed
- **The Dockerfile/compose signal suggests `devops`**, which absorbed dev-env on <!-- removed-ok -->
  2026-09-02. Regenerated catalog.

## 0.13.4

### Changed
- **The MariaDB tier-1 signal suggests `database`**, which absorbed the sql and
  mariadb plugins on 2026-09-02; the `sql` overlap pair is gone with the plugin. <!-- removed-ok -->
  `db-suite` is removed — three members that now live in one plugin do not earn a <!-- removed-ok -->
  bundle. Regenerated catalog.

## 0.13.3

### Changed
- **The Inertia tier-1 signal suggests `laravel`**, which absorbed the inertia plugin <!-- removed-ok -->
  on 2026-09-02; the `web-dev` overlap pair shrinks to `laravel`. Regenerated catalog.

## 0.13.2

### Changed
- **Three tier-1 stack signals now point at one plugin.** `next`, `react-native`, and
  `vite` + `vite.config.*` each suggest `web-dev`, which absorbed the three stack
  plugins on 2026-09-02. The overlap pair for `web-dev` shrinks to `laravel` and
  `inertia`. Regenerated catalog: three rows gone, `web-dev`, `frontend-suite` and
  `php-suite` descriptions updated.

## 0.13.1

### Fixed
- **A plugin enabled only in the user's own `~/.claude/settings.json` is now counted
  as installed.** Preflight built the installed set from `claude plugin list`
  (filtered to user scope or this project) unioned with the two PROJECT settings
  files. A user-scope install normally arrives via the CLI half, so the gap was
  narrow — but an `enabledPlugins` entry added by hand to `~/.claude/settings.json`,
  or written by a tool other than the CLI, was reported by neither half, and the row
  was offered as though it were missing. The union now reads that file too. Nobody
  is re-offered a plugin they already run everywhere.

## 0.13.0

### Added

- **The remainder is judged, not just swept.** Tier 3 was defined by subtraction
  — "every catalog plugin not in tier 1 or 2" — so no plugin ever entered the
  report because of anything about the project in front of it, and roughly two
  fifths of the eligible set could not be earned by any signal at all: they
  printed the literal string `universal` in every repo, forever. A relevance
  pass now lifts 3-5 remainder rows that fit THIS repo into a `worth a look
  here` group, each carrying a one-line **reason** (an argument from what the
  project is) as opposed to evidence (a file and a key). It adds no questions
  and no AskUserQuestion calls, never promotes a row to tier 1, is never
  `--yes`-eligible, and reports "nothing stands out" instead of padding.
  Contract and anti-patterns: `references/relevance.md`.
- **Six new evidence-bearing signal rows** in `references/signals.md`, for
  plugins that previously had no route out of the remainder at all:
  `claude-authoring` (the repo ships a `.claude-plugin/` manifest — deliberately
  not `.claude/`, which only means the repo *uses* Claude Code), `database`
  (ORM deps or a migrations dir), `shadcn-studio` (`components.json` plus a
  Tailwind setup), `api-docs-first` (the same OpenAPI evidence `api-design`
  reads), `performance` (a measurement tool already in the manifest), and
  `resilience` (retry, breaker or queue libraries).

### Fixed

- **A range dropped rows that exist.** `scripts/pick.sh` clamped `N-M` to the
  rows file's LINE COUNT rather than its highest row NUMBER. Report numbers are
  stable while installed rows are filtered out of the pick list, so the file is
  sparse whenever anything is installed — every run after the first. Over rows
  1, 2, 5, 8, typing `1-8` returned `1 2`: two requested, existing rows dropped
  in silence, while the diagnostics blamed rows 3 and 4, which do not exist.
  Exit 0 throughout, so nothing downstream could tell. A range now spans the
  numbers the file actually carries, and a gap is not a rejected token.
- **A huge range operand wrapped into a valid pick.** `$(( ))` wraps mod 2^64
  without a word, so `1-18446744073709551620` came back as `1 2 3 4` — a wrong
  pick reported as clean success, the same class as the `1-3-2` bug the harness
  was built for, through a different door. Operands over nine digits are now
  refused before any arithmetic.
- **`01` meant two different things.** Accepted as a range operand (`01-02`
  picked rows 1-2) and rejected as a bare number (`skip: no row 01`). Leading
  zeros are now stripped in both forms.
- **An unreadable rows file leaked a raw tool error.** The guard tested `-f`
  but not `-r`, so `cut` failed under `set -e` and printed
  `cut: …: Permission denied` in place of the usage line. It is now the third
  named invocation error.
- **The TTY hint pasted as two arguments** when the rows path contained a
  space. That line exists to be pasted verbatim; it is now quoted.
- **`pick.sh`'s header claimed a parity the code never had** — that both
  branches take numbers, ranges and names. The entire parser is in the numbered
  branch; fzf selects rows directly and cannot expand a range.
- Prose corrections, no behaviour change: the bundle-filter sentence carried a
  hard-coded count of 11 (there are 10) eighteen lines above this skill's own
  "never from a number written here" rule; `references/picker.md`'s worked
  sample listed `stack-scan` twice under two numbers, breaking the completeness
  rule it exists to illustrate; the "no bundles here" line at the install step
  forbade the suite shortcut the picker requires; the exhaustive-paging cost was
  billed at 5 calls / 20 questions in two files when the file's own 15-per-call
  rule gives 4 and 16; `references/signals.md` said three rows mirror
  `rules.tsv` when four do, and that all three had diverged when the `sql` row
  has not; `references/flags.md`'s Standing quoted wording ("that floor is
  absolute") that a previous commit had deleted; `references/picker.md` sent
  readers to SKILL.md for a definition that lives in `references/flags.md`; and
  the read-only detection rule was tagged `recorded` in Boundaries and
  `agent-graded` in Standing, which are mutually exclusive tiers.
- **`PICKED:` carries survivors only**, now said out loud in
  `references/picker.md`. Rejected tokens go to stderr, which that line does not
  carry, so the "list the unmatched tokens and ask once more" rule it inherits
  from Other had nothing to read. Compare against what was offered and re-offer
  what is missing; never read absence as a decline.

## 0.12.4

### Changed

- Regenerated catalog: four bundle descriptions now carry a 200k-window
  context requirement pointer. No behaviour change — skip on upgrade.
- **README and skill no longer oversell `taskmaster-suite`.** It was described
  as "installs most of the universal tier"; since that bundle's 32→10 trim it
  covers 2 of the 8 any-project-core picks, and the docs now say so. `/suggest`
  and the picker reference also stop special-casing the removed all-in bundle.

## 0.12.3

### Changed

- Regenerated catalog: the `everything` meta-bundle was removed from the
  marketplace, so its row is gone. No behaviour change here — skip on upgrade.
  Install a themed `*-suite` or the leaves you want instead.

## 0.12.2

### Changed
- **Meta-prose compressed to a one-line standing tag.** No change to detection,
  tiering, or the picker.

## 0.12.1

### Changed
- **Regenerated catalog**, no behaviour change — skip on upgrade. always-on-suite
  0.2.0 rewrote its description (dropped command-guard, added terse), and that row
  is one of the ones `references/catalog.md` carries.

## 0.12.0

### Fixed
- **The scout no longer suggests installing `i18n`, which does not exist.** That
  plugin was removed from the marketplace on 2026-08-26, but a second-tier signal
  row still mapped `lang/` and `locales/` to it — and since those rows join the
  `--yes` auto-install set, **every Laravel app ships `lang/`**, so `--yes` ran an
  install that could only fail. The row now says no plugin covers i18n and routes
  to vercel-skills-scout. A new `pc_scout_names` build gate fails any plugin name
  in this skill's three hand-written lists that is not a live marketplace entry;
  the existing removed-artifact check could not see this one, because a bare
  table cell matches none of its reference shapes.
- **The installed column and the picker filter were reading the wrong machine.**
  `claude plugin list` reports every plugin installed in *any* project on the
  machine. A plugin you installed in an unrelated repo was therefore marked
  installed here and silently dropped from the picker — never offered, never
  installed. Detection now filters `--json` output by project path and scope, and
  unions it with the settings files, which also makes `--persist` idempotent
  (a project-scope entry the CLI wrote is not always reported as an install, so
  re-runs used to re-offer and re-install the same set).
- **`--persist` no longer hand-writes `enabledPlugins`.** The CLI writes those
  entries itself at `--scope project`; the skill now verifies them and reports a
  missing one instead of authoring it. Authoring the key after a failed install
  produced a committed repo whose settings enable a plugin nobody has.
- **The uninstall note now names the scope.** `claude plugin uninstall` defaults
  to `--scope user`, so the bare command against a `--persist` install fails with
  "not installed at scope user" — the described failure was never reached.
- Headless + `--yes` with the marketplace absent: SKILL.md said continue,
  flags.md said stop. It stops — the marketplace-add trust decision is not
  skippable. "Headless" is now defined once (AskUserQuestion unavailable; a
  subagent is not headless) instead of being branched on six times undefined.
- `--persist` + `--global` now aborts before Preflight, so the conflict is caught
  before the marketplace-add prompt can fire rather than merely before installs.
- Detection reads `.env.example`, not only `.env` — the latter is gitignored in
  every Laravel and Next scaffold, so on this skill's headline case (a fresh
  clone) the DSN half of the mariadb signal never fired.
- Dependency signals are exact keys, not substrings: `next-auth` is no longer
  read as `next`, `react-native-web` no longer as `react-native`.

### Changed
- **The picker is one call instead of five.** Offering all ~51 rows as explicit
  checkboxes cost 5 AskUserQuestion calls and 20 blocking questions on every run —
  including a Django repo being paged through `laravel` and `mariadb`. The default
  is now one call: three questions of signal-backed and core rows, and a fourth
  that is a door into the remainder (browse / print commands / just these / stop).
  Every row still prints in the numbered inventory first and stays pickable by
  number, name or range, or via `scripts/pick.sh`. **`--all` restores the old
  exhaustive paging.**
- **The report is grouped, not tabulated.** The 51-row five-column table carried a
  constant in its evidence column for ~45 rows and a constant installed column;
  it is now a header line plus per-tier blocks with tier 3 grouped by keyword.
- **Overlap deprioritization now uses named pairs.** It compared catalog keywords,
  and `review` alone appears on 26 of 63 rows — so once `code-review` was
  installed (which `--yes` does on run one) 30 of 51 rows were flagged as
  conflicts, including the signal-backed `laravel` and `nextjs` recommendations.
  Tier-1 rows are never annotated as overlapping anything.
- **stack-scan is a supplement, not a replacement.** The skill used to hand
  detection over entirely when that plugin was installed; it probes nine
  dependency names, never reads `.env`, and does not know `react-native`, so an
  installed stack-scan strictly degraded detection. Its offer to fix red flags is
  now explicitly declined — accepting it deleted a lockfile inside a step this
  skill declares read-only.
- **`packages` moved out of the any-project core** into a signal-earned row: its
  own rubric is Composer/npm-specific, so a Python or Go repo was auto-installing
  a plugin about two manifests it does not have.
- **`command-guard` joined the any-project core.** Its destructive-command deny
  hook is the pair to secret-scanning's secret block, and the old exclusion rule
  ("member of always-on-suite") already contradicted itself by including
  secret-scanning and git-workflow, which are also members.
- The install summary now names the exit-code success criterion and prints the
  `/reload-plugins` line — nothing installed during a run is active until then,
  which nothing previously said.
- Detection resolves the `[path]` argument and scans workspace members one level
  deep. A Turborepo whose apps hold every framework used to report "no stack
  signals found".

### Added
- **`--all` flag** — offers every eligible row as an explicit picker option
  (the pre-0.12 default). Picker-only; no effect under `--yes`.
- **Eleven new detection signals** in `references/signals.md`: `threejs`,
  `ui-ux`, `registry-source`, `a11y`, `sql`, `security`, `packages`, plus
  dependency evidence for `payments`. Detection covered 6 of 52 leaf plugins;
  these are the cheap high-precision manifest signals the marketplace already
  trusts elsewhere.
- `lane.tsv` — the plugin declares its territory (`understand` phase,
  `marketplace-plugin-suggestion`), yielding to stack-scan for version truth and
  to vercel-skills-scout for stacks this marketplace does not cover.
- `scripts/__tests__/pick.test.sh` — the TTY picker's parser had never been
  tested. It lost its `PICKED:` line entirely on every abort path (fzf ESC, no
  match, Ctrl-D), leaving the caller with a bare non-zero exit and no contract;
  it leaked raw bash errors on `-2` and `2-`, silently no-opped on `3-1`, and
  accepted plugin names only when `fzf` happened to be installed.
- Standing sections on `SKILL.md` and `references/flags.md`, naming which of
  their rules are gated and which are agent-graded. The files carrying the
  absolute-sounding promises ("that floor is absolute", "never silent", "every
  unrelated existing key is preserved") were the ones declaring no standing.

## 0.11.3

### Changed
- Regenerated `catalog.md`: `taskmaster-suite` now reads "Meta-bundle (32 plugins)"
  after `comment-discipline` joined it. Catalog text is generated from each
  plugin's own description, so a scout suggestion quotes the live member count.

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
