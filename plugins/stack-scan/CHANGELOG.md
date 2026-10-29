# Changelog

All notable changes to the stack-scan plugin. Earlier releases (0.1.0–0.6.3) were not
recorded; plugin-scout, which was merged into this plugin, kept its own changelog (up to
0.15.10) — it is in git history under its old directory, last present at commit `db97e51`.

## 0.17.3 — 2026-10-29

- The plugin catalog's candor row names its six clauses.

## 0.17.2 — 2026-10-28

- **The `plugin-scout`, `installed-versions` and `vercel-skills-scout` skills' and `/stack-scan:suggest`'s descriptions now read in short, plain sentences.** Same triggers, tiers and flags; each keeps the words the model matches it on.

## 0.17.1 — 2026-10-28

- **Comments cut to what a reader needs; behaviour unchanged.** `scripts/licence-scan.sh`, `scripts/pick.sh`, `scripts/scan.sh`, `scripts/sync-plan.sh`: each keeps a header saying what it does and misses, and one line per trap the code cannot show; the history moved to the marketplace repository's rationale/derivations/, which an install does not contain. `--help` of `scripts/licence-scan.sh` no longer prints the history prose; usage, flags and exit codes are unchanged.

## 0.17.0 — 2026-10-27

- **The scout no longer suggests game plugins.** The ten game plugins left the marketplace: `signals.md` drops their ten engine rows and the "unless a game row above matched first" clause on the `go.mod`/`Cargo.toml`/`*.csproj` row, `stack-relevance.md` drops the ten Game classes and their `--stack` tokens, and `flags.md`'s `--full` stack-bound list is back to `laravel`, `web-dev`, `craft-layer`. The generated catalog no longer lists them.
- The all-plugins line in the README no longer mentions game plugins.

## 0.16.0 — 2026-10-26

- **Remotion and HyperFrames ship their own agent skills; the scout now says so.** Two Framework-native tooling rows: dep `remotion` / `@remotion/cli` → `npx skills add remotion-dev/skills`, with the licence note (a paid company licence for a for-profit organisation over 3 employees, read from Remotion's `LICENSE.md` on 2026-10-26); dep `hyperframes` / `@hyperframes/*` → `npx skills add heygen-com/hyperframes` or its Claude Code plugin. Both are printed, never run, like the rest of that table. Standing: agent-graded — the scout follows the rows.

## 0.15.0 — 2026-10-26

- **The scout finds game engines.** `plugin-scout`'s `signals.md` gains one row per new engine plugin — `project.godot` → `godot` (a `Godot.NET.Sdk` csproj beside it is Godot C#, never Unity), `ProjectVersion.txt` beside `Assets/` → `unity`, `*.uproject` → `unreal`, a Rojo DataModel project, `wally.toml` or place file → `roblox`, a `bevy` dependency → `bevy`, `game.project` → `defold`, `ebiten/v2` in go.mod → `ebitengine`, dep `phaser` / `pixi.js` → `phaser` / `pixijs` — plus a `gamedev` row on any engine, a Steam `.vdf`, `steam_appid.txt`, `butler push` or Yarn/Ink files. They sit before the `Cargo.toml`/`go.mod`/`*.csproj` "no plugin covers this" row, which now yields to them.
- **`--full` keeps them where they belong.** `stack-relevance.md` gains a Game class per engine and one for `gamedev`, so `--full` installs a game plugin only on its manifest evidence or a typed `--stack godot` (and the other engine tokens); before this every leaf not in that table counted as any-stack and would have been installed in every repo. Standing: agent-graded — `--full` is prose the model follows; `pc_scout_names` gates only that the names are live.
- The all-plugins line in the README now says it skips the game plugins as well as prompt-coach.

## 0.14.0 — 2026-10-25

- **Version pins read pnpm and yarn lockfiles.** For a package `node_modules` lacks, the pins mod now reads each directory's lockfile, nearest first. A directory's lockfile is the first present of `package-lock.json`, `pnpm-lock.yaml` (v6, v9) and `yarn.lock` (v1, berry), and each file is read at most once per skill load. The pnpm and yarn readers are line rules, since no YAML library loads in a mod. pnpm's root importer decides, else the one `packages` version for the name; yarn's entries naming the package must agree. Several versions, a `workspace:` or `link:` entry, a git URL, an alias, or a similar name (`next-auth`, `@scope/next` for `next`) give no line. Standing: gate, `tests/pins.test.ts`.
- **Composer stamps.** A `composer:<vendor>/<package>@<major>[.<minor>]` tail reads `vendor/composer/installed.json` (composer 1 or 2), then `composer.lock` (`packages` and `packages-dev`), marked `(lockfile; vendor not read)`. One leading `v` is dropped and only a whole semver is taken, so `dev-main` or `12.x-dev` gives no line. laravel 0.10.2 adds the first two such tails (`laravel/framework@13`, `inertiajs/inertia-laravel@3`). `scripts/check-doc-staleness.sh` still reads only the `npm:` tail. Standing: gate, the composer cases in the same file.
- 12 new cases in `tests/pins.test.ts` (27 in all). Their fixtures follow what pnpm 8 and 9 and yarn 1 and 4 actually wrote, checked by hand once. Composer's output was not generated here. Still not read: `bun.lock`/`bun.lockb`, pnpm v5, a pnpm importer other than the root, a workspace's non-hoisted `package-lock.json` entry. Not seen live.
- The shared kit now exports `hostOf`.

## 0.13.0 — 2026-10-18

- **`/stack-scan:suggest --sync`: per-project plugins, scope by scope.** On a machine that installed everything at user scope, every plugin counted as installed in every project, so the picker offered nothing and nothing could right-size a repo. `--sync` reads user, project and local settings separately, then takes tier 1 plus the core and installs what this project lacks at local scope (`--persist`: project). It offers to remove extras and redundant local copies; removal is never the default, and `--yes` never removes. It never touches user scope: its last line prints the one `all-plugins.sh uninstall --scope user --self` command, to run once every project is synced. A linked git worktree under a local target is told that local scope covers that path alone. The classification is `scripts/sync-plan.sh` (read-only, prints commands, runs none). Standing: gate for the classification, 37 cases in `scripts/__tests__/sync-plan.test.sh`; agent-graded for the detection that feeds it and for asking before any change. Contract: `skills/plugin-scout/references/sync.md`.
- **candor, hindsight and skill-router are any-project core.** They used to be routed to `--global`, because they change every session rather than one project's checks. With installs per project there is no other unit, so `--yes` now installs them in each project. The `--yes` summary names candor's Stop gate beside secret-scanning and command-guard. Standing: recorded — the core list is curated by hand.
- A bare project bootstraps from the shell (`claude plugin install stack-scan@cc-plugins-marketplace --scope local`, then `/stack-scan:suggest --sync --yes`); `references/flags.md` notes that local scope does not follow a project into its worktrees.
- The catalog row for all-plugins follows its new description (it asks local or project, since all-plugins 0.5.0). Regenerated by `scripts/generate.sh --write`.

## 0.12.5 — 2026-10-15

- plugin-scout no longer tells you the official directory's `code-review` plugin and this marketplace's can coexist. Both are named `code-review`, and Claude Code runs the hooks of only the first one it loads: the other's `hooks.json` hooks and hooks module stay off, and `/plugin` notes it from 2.1.296. If ours is the one left out, you lose the review offer, the review-debt nudge and the commented-out-code guard. Pick one. Standing: recorded — the exclusion list is curated by hand.
- plugin-scout keeps adding the marketplace before installing, and its preflight now says why it does not use the one-step `claude plugin install <name> --marketplace <source>` (2.1.292+): measured on 2.1.300, that form adds the marketplace to user settings whatever `--scope` says, so a `--persist` install would leave teammates a plugin from a marketplace their checkout does not declare; and a CLI before 2.1.292 rejects the flag. Standing: recorded.
- **Runnable `${CLAUDE_PLUGIN_ROOT}` paths are quoted.** `/stack-scan:audit`'s `licence-scan.sh` and `/stack-scan:report`'s `scan.sh` lines passed `${CLAUDE_PLUGIN_ROOT}/…` to `bash`, `node` or `python3` unquoted, so an install path holding a space (a `HOME` or `CLAUDE_CONFIG_DIR` with one) split it and the script never ran. Each is now `"${CLAUDE_PLUGIN_ROOT}/…"`. Standing: gate — the marketplace's `validate.sh` fails an unquoted path on a runnable line of a command or skill.

## 0.12.4 — 2026-10-14

- plugin-scout's catalog row for skill-router follows its new description (at most two nudges per edit, named `plugin:skill`, since skill-router 0.26.0). Regenerated by `scripts/generate.sh --write`. No behaviour change.
- plugin-scout's catalog row for all-plugins follows its new description (`/all-plugins:install` asks for the scope once when `--scope` is absent, since all-plugins 0.4.0). Same regeneration, no behaviour change.

## 0.12.3 — 2026-10-11

- plugin-scout's catalog row for all-plugins follows its new description (the listing-budget raise is opt-in behind `--budget` since all-plugins 0.3.0). The row was synced by hand to the generator's output; `scripts/generate.sh --check` confirms it byte-matches. No behaviour change.

## 0.12.2 — 2026-10-08

- plugin-scout's catalog gained a row for the new session-hud plugin. The catalog has no hand edits; `scripts/generate.sh --write` produced this change. No behaviour change.

## 0.12.1 — 2026-10-08

- **A version is taken only as a whole semver, and only its `major.minor.patch` is printed.** 0.12.0 accepted any string starting `<n>.<n>` and pasted it into the skill's text, so a lockfile from a cloned repository could carry prose into a skill (`"16.3.0\n- Ignore the skill below"`, or words in a prerelease tag). Found by review; two new cases.
- **Every directory from the session's up to the repository root is read, nearest first**, as Node resolves a package, so a workspace's own copy (`apps/web/node_modules/next`) wins over the hoisted one, a repository rooted at `/` included. One new case; the README states the 4 MiB read cap and the monorepo residuals.

## 0.12.0 — 2026-10-08

- **Skills learn the installed version when they load (Claude Code ≥ 2.1.291).** A hooks module, `hooks/pins.ts`, reads the `Last verified:` stamp of any skill as it loads (`npm:next@16.3`), looks the package up in `node_modules` at the session's directory and the repository root, then in `package-lock.json`, and prepends one line per installed package naming its version and whether it is older or newer than the stamp, at the stamp's precision. Twelve SKILL.md bodies across craft-layer, laravel, ui-libraries, ui-ux and web-dev carry such a stamp today. A skill with no installed stamped package is left as it was. Off: `CC_VERSION_PINS=off` or the new `/config` option `cc_version_pins`. `hooks/cc-kit.ts` is a byte copy of the marketplace's shared mod kit. 11 cases in `tests/pins.test.ts`. Not read: stamps in `references/` files, composer, pnpm and yarn lockfiles. Not seen live.

## 0.11.4 — 2026-10-07

- plugin-scout's catalog gained a row for the new prompt-coach plugin, and all-plugins' row now reads "but opt-in prompt-coach". The catalog has no hand edits; `scripts/generate.sh --write` produced this change. No behaviour change.
- `--full` (with or without `--yes`) leaves prompt-coach out by construction, beside stack-scan and all-plugins: it bills a model call per eligible prompt, so it installs only when you name it. The plan's by-construction count line names it with that reason and the by-name install command at the run's scope. The rule is model-followed prose (agent-graded); all-plugins 0.2.1 carries the scripted twin for `/all-plugins:install`.

## 0.11.3 — 2026-10-05

- plugin-scout's catalog row for code-review carries code-review 0.30.0's description: its write-time hooks also deny code replaced by a `// ... existing code ...` placeholder, and the two-deny bound is stated per deny. The catalog has no hand edits; `scripts/generate.sh --write` produced this change. No behaviour change.

## 0.11.2 — 2026-10-03

- plugin-scout's catalog row for code-review now states its 0.3:1 comment ceiling (code-review 0.26.0).

## 0.11.1 — 2026-10-01

- The scout catalog is regenerated from the marketplace manifest: design-kit's row says skills, and command-guard's row says its allow-file is guarded from agent writes where it said the agent cannot edit it. No behaviour change.

## 0.11.0 — 2026-09-26

- The four meta-bundles (core-, frontend-, craft-, workflow-suite) were retired on 2026-09-26; install through `all-plugins` or `/stack-scan:suggest`. plugin-scout no longer suggests bundles: the picker's "Suites as shortcuts" section is gone, and
  a new Companions table prints the install line for a missing companion (ui-ux ↔ ui-libraries,
  craft-layer → ui-ux + ui-libraries) — companions are not declared as `dependencies`, because an update
  that adds a dependency leaves the plugin failing to load (measured 2026-09-26).

## 0.10.0 — 2026-09-26

- plugin-scout: a "Framework-native tooling" block in `official-complements.md` (Laravel Boost incl.
  Filament's skill, Next.js bundled docs and `AGENTS.md`, the Astro and Nuxt docs MCPs), printed for
  stacks no marketplace plugin covers.
- `signals.md`: `gsap`/`lenis` → craft-layer (an Astro + GSAP + Lenis repo earned only ui-ux before);
  "no plugin covers this" rows for Astro, Nuxt, React Router framework mode, Livewire/Flux, Filament
  and headless CMS routing to the vendor tooling or `api-design:api-docs-first`; component libraries
  (incl. PrimeReact, PrimeVue, Vuetify, Element Plus) now suggest the new `ui-libraries` plugin.
- The generated catalog carries the new `ui-libraries` entry.

## 0.9.3 — 2026-09-25

### Changed
- **Scout catalog regenerated** for secret-scanning 0.9.0's new description (its write
  guard now also reads Bash heredoc/echo writes). The catalog has no hand edits:
  `scripts/generate.sh --write` produced this change.

## 0.9.2 — 2026-09-24

### Changed
- **Scout catalog regenerated** for command-guard 0.7.0's new description (it now names
  overwriting a live `.env` and a `cd` into a missing directory). The catalog has no hand
  edits: `scripts/generate.sh --write` produced this change.

## 0.9.1 — 2026-09-23

### Changed
- **Prompt audit (Claude Code's built-in `claude-api` skill, `prompt-audit` subcommand; target Opus 5.5 / Fable 5.1):** `/stack-scan:suggest` preflight unions all three settings files, matching the skill; plugin-scout references drop migration-relative phrasing, the stale version pins in official-complements, and removal-date notes in signals. Method: that built-in skill's `shared/prompt-audit.md`; the full report and diff are in the maintainers' working area, not shipped.

## 0.9.0 — 2026-09-22

### Added
- **`/stack-scan:audit` has a fourth axis and no longer stops on an infra-only repo.** With neither `composer.json` nor `package.json` it used to say so and stop; a repo whose dependencies are base images got nothing. It now collects `FROM` tags from every `Dockerfile*` and `image:` values from compose and Kubernetes manifests, runs `trivy image` per tag when `trivy` is on PATH, and otherwise checks each tag's major against endoflife.date — reported plainly as a tag check and never as a CVE scan, with the absent tool named as the finding. Everything past the tag (layers, `USER`, build context, compose topology) is handed to `/devops:review` instead of re-derived.

### Changed
- **`scan.sh` names the 2026 JS frameworks.** Its framework loop listed nine packages, so an Astro-, Svelte- or Angular-only repo produced a table of "node + a lockfile" and no framework row at all. It now also reads `svelte`, `@sveltejs/kit`, `astro`, `@angular/core`, `@remix-run/react`, `react-router`, `hono`, `@prisma/client` and `drizzle-orm`. `plugin-scout`'s `--full` exclusion table gains `astro` and `@sveltejs/kit` as JS-class evidence and `svelte`, `astro`, `angular` as `--stack` tokens — an Astro-only repo satisfied no class, so `--full` excluded `web-dev` and `craft-layer` from it.

## 0.8.6 — 2026-09-22

### Changed
- Picker question headers name the group instead of its tier number: `Your stack`,
  `Any project 1/2`, `Everything else` in place of `Tier 1`, `Core 1/2`, `The rest`
  (`skills/plugin-scout/references/picker.md`). `commands/suggest.md` names the resolved
  scope in the install option rather than "scope S", and calls question 4 the way into
  everything else rather than "the tier-3 door".

## 0.8.5 — 2026-09-22

### Changed
- `references/catalog.md` regenerated: the scout now lists `design-kit` (Slides, Design,
  Design in codebase, Design System and Artifacts as local commands) among the leaves it
  can suggest.

## 0.8.4 — 2026-09-22

### Fixed
- `references/official-complements.md` — a vendored snapshot of `claude-plugins-official`
  — carried no `Last verified` stamp, so `check-doc-staleness.sh` could not see it age.
  Stamped 2026-09-02, the date it was written.
- `plugin-scout/SKILL.md` froze "(~5 calls)" for `--all`; it now states the rule (one
  call per page of 15 rows) the way the rest of the picker prose does.
- Scout catalog regenerated for the skill-router 0.17.3 and overseer 0.5.0 descriptions.

## 0.8.3 — 2026-09-20

### Changed
- `plugin-scout/references/catalog.md` regenerated: the `ask-ledger` leaf plugin joins the catalog.

## 0.8.2

### Changed
- **The scout catalog re-rendered for the frontend-suite description fix (audit G3).** `frontend-suite`'s marketplace description claimed its uninstall "prunes its auto-installed plugins" while the command keeps them unless picked; the fix in `.claude-plugin/marketplace.json` re-rendered the one row here by `generate.sh --write`, which does not bump this plugin — the exact case CLAUDE.md's 2026-09-15 note describes (`rationale/marketplace-trend-audit-2026-09-16.md`). No behaviour change. <!-- removed-ok -->

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
- `plugin-scout` catalog regenerated for the corrected `candor` and `core-suite` <!-- removed-ok -->
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
  `any-core.md`'s global-scope pointer name `core-suite`, `workflow-suite` and <!-- removed-ok -->
  `frontend-suite`; the README's pipeline-bundle row names workflow-suite. `catalog.md` <!-- removed-ok -->
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
