# plugin-scout

Scan the current project's manifests — composer.json, package.json, `.env` /
`.env.example`, Dockerfile/docker-compose, plus workspace members one level deep —
and suggest **every** cc-plugins-marketplace plugin, in three tiers: stack-matched
(with the evidence file and key cited per suggestion), the curated any-project
core (useful regardless of stack — `skills/plugin-scout/references/any-core.md`),
and the universal remainder. Already-installed plugins are marked and skipped.
Picked suggestions are installed via
`claude plugin install <name>@cc-plugins-marketplace --scope local` after an
explicit confirm — repo-scoped by default (`--persist` upgrades the scope to
`project` for team sharing, `--global` to `user` for machine-wide).

Doctrine: suggestions cite evidence — every stack-matched row names the manifest
line that earned it, and without `--yes` nothing installs without your pick. Where
this marketplace has no plugin for your stack (Terraform, i18n, Django), the scout
says so and routes you onward instead of padding the list.

Flags: `--yes` is the auto-installer — installs tier-1 signal-backed plus the
tier-2 any-project core, not-yet-installed only (skips the picker; tier 3 never
auto-installs); `--all` offers every eligible row as an explicit picker option
instead of the default single question set; `--persist` installs at project scope
and verifies the installed set in the project's `.claude/settings.json`; `--global`
installs at user scope (every repo on the machine — mutually exclusive with
`--persist`). `--yes` combines with either scope flag. Full semantics:
`skills/plugin-scout/references/flags.md`.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install plugin-scout@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/plugin-scout:suggest [path] [--yes] [--all] [--persist \| --global]` | Detect the stack, print the numbered three-tier inventory covering every marketplace plugin, then offer the plugins you pick — one question set for the signal-backed and core rows plus a door into the remainder (`--all` pages every row explicitly), or auto-install tier-1 + core picks (`--yes`), at project scope (`--persist`) or machine-wide user scope (`--global`) |

## Example

```bash
/plugin-scout:suggest
```

In a Laravel + Inertia repo this suggests laravel and inertia (tier 1, each with
its composer.json evidence), then the any-project core — code-review, debugging,
testing, git-workflow, and the rest of `references/any-core.md` — then lists the
remaining catalog as numbered rows you can take by number, name or range, minus
whatever is already installed.

## Picking, and why it is one call

The remainder is ~40 rows. Offering every one as an explicit checkbox costs five
AskUserQuestion calls and twenty blocking questions, in every repo, including a
Django repo being asked to consider `laravel`. So the default offers the rows a
signal or the core list earned, and puts the remainder behind one door — every row
still prints in the numbered inventory first and stays pickable by number, name or
range, or through the unbounded `scripts/pick.sh` TTY picker. `--all` restores
exhaustive paging. Full contract: `skills/plugin-scout/references/picker.md`.

## After installing

Nothing installed during a run is active in that session until you run
`/reload-plugins` (or restart Claude Code) — the scout says so in its summary. A
`--yes` run may install write-time hooks (`secret-scanning` blocks secrets,
`command-guard` denies destructive commands); the summary names them, because you
did not see a picker for those.

## Pairs well with

- **stack-scan** — when installed, its inventory supplements detection with
  version truth (EOL majors, lockfile drift); the manifest signal table still runs
- **vercel-skills-scout** — where this marketplace has no plugin for your stack,
  the scout for third-party skills is the intended next step
- **taskmaster-suite** — bundle alternative: installs most of the universal tier
  in one step (see its README for deliberate exclusions such as secret-scanning)
  instead of picking plugins individually
