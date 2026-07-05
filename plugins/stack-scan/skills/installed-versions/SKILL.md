---
name: installed-versions
description: Use before giving version-dependent advice or starting work in an unfamiliar repo — inventory what is ACTUALLY installed from manifests, lockfiles, runtime binaries, and container images (composer.json/lock, package.json with npm/yarn/pnpm/bun lockfiles, engines fields, .nvmrc/.tool-versions, Dockerfiles). Reports required vs installed and flags drift.
---

## Constraint is a wish, lock is a fact

`^11.0` in a manifest tells you what is allowed; only the lockfile tells you what
is installed. Every version claim this skill produces cites its source, and lock
beats manifest, runtime beats lock, when they disagree — that disagreement itself
is a finding.

## Where versions live

Scan in this order; missing files are findings, not dead ends:

- **PHP**: `composer.json` (`require.php`, `config.platform.php`), `composer.lock`
  (`packages[].version`, `platform` block), `php -v` when runnable. Framework
  version = the locked `laravel/framework` (or equivalent), never the constraint.
- **JS/TS**: `package.json` (deps, `engines`, `packageManager`), plus exactly one
  of `package-lock.json` / `yarn.lock` / `pnpm-lock.yaml` / `bun.lock`(`.lockb`) —
  which one identifies the package manager; `node -v` / `bun -v` when runnable.
- **Runtime pins**: `.nvmrc`, `.node-version`, `.tool-versions` (asdf/mise),
  `volta` field, `.python-version` — these say what the team INTENDS to run.
- **Containers/CI**: `Dockerfile` FROM tags, `docker-compose.yml` service images
  (databases live here: `mysql:8.4`, `mariadb:11.4`, `postgres:17`), CI workflow
  `setup-*` versions — production truth often lives in these, not local binaries.
- **Env hints**: `.env`/`.env.example` DSNs name engines when compose does not.

## Reading the JS lockfile without drowning

Do not dump thousands of transitive entries. Resolve versions ONLY for: direct
dependencies, the frameworks/tools other plugins key on (react, vue, tailwind,
vite, typescript), and anything the current task touches. `bun.lockb` is binary —
prefer the textual `bun.lock`; if only the binary exists, use `bun pm ls` or
fall back to constraint + a "lock unreadable here" note.

## PHP specifics worth extracting

- `config.platform.php` in composer.json overrides the real binary for dependency
  resolution — when set, IT is the effective floor, not `php -v`.
- `ext-*` entries in `require` are deploy requirements: a locally-loaded extension
  missing from the production image is a release-day failure; compare against the
  Dockerfile's `docker-php-ext-install`/`pecl` lines when present.
- Local dev via Herd/Valet/brew frequently runs a different PHP than the container
  — report both when both are visible, and say which one CI uses.

## Monorepos and workspaces

- Workspace roots (`pnpm-workspace.yaml`, `workspaces` field, turbo/nx configs)
  mean per-package manifests with ONE root lockfile — resolve versions from the
  root lock, but read `engines` and framework deps from the package actually
  being worked on.
- Composer `path` repositories and split packages: the locked version of a
  path-symlinked package is whatever the working tree holds — cite the path, not
  the version number, and flag it as locally mutable.

## When to rescan

The inventory is a snapshot: rescan after any lockfile-touching command, branch
switch, or rebase — and always immediately before giving upgrade advice; stale
inventory produces confidently wrong version pinning.

## The report

One table, one row per layer, nothing speculative:

```
| Layer     | Tool/Package        | Required (source)      | Installed (source)     |
|-----------|---------------------|------------------------|------------------------|
| Runtime   | php                 | ^8.3 (composer.json)   | 8.3.14 (php -v)        |
| Runtime   | node                | >=20 (engines)         | 22.11.0 (.nvmrc)       |
| Framework | laravel/framework   | ^11.0 (composer.json)  | 11.34.2 (composer.lock)|
| DB        | mariadb             | —                      | 11.4 (docker-compose)  |
| PkgMgr    | pnpm                | 9.x (packageManager)   | pnpm-lock.yaml present |
```

Below the table: the flags section (next heading) and nothing else. The report is
input for other work — advice pinning, upgrade planning — not an essay.

## Red flags to raise

- **Multiple JS lockfiles** (`package-lock.json` + `bun.lock`): two installers
  have run; builds are nondeterministic until one is deleted.
- **No lockfile committed** for a manifest that has dependencies.
- **Constraint/lock drift**: lock far behind constraint ceiling (stale installs)
  or manifest changed without `composer update`/`npm install` run.
- **Runtime mismatch**: `php -v` or `node -v` outside `engines`/`platform` — CI
  and local are building different realities.
- **EOL majors**: runtime or framework past end-of-life (verify current EOL
  status against endoflife.date rather than memory when it matters).
- **Docker vs local divergence**: compose says `postgres:17`, local psql is 14 —
  name which one production follows.

## Feeding the other plugins

This inventory is the version input the review commands and version-aware skills
(php, mysql, mariadb, postgresql, react, vue) pin against, and what grill-me's
context-scout cites as hard constraints. Run it once per session in an unfamiliar
repo; cite `installed (source)` values, never bare version numbers from memory.

## Anti-patterns

- Answering "what version of X" from the constraint, memory, or the README.
- Running `npm install`/`composer update` to "check" — scanning is read-only;
  mutating lockfiles to observe them changes the thing observed.
- Reporting every transitive dependency — inventory the load-bearing stack, not
  the node_modules census.
- Trusting a local binary over the container image the app actually runs in.
