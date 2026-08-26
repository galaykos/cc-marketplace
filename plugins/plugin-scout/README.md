# plugin-scout

Scan the current project's manifests — composer.json, package.json,
tsconfig.json, .env, Dockerfile/docker-compose — and suggest **every**
cc-plugins-marketplace plugin, in three tiers: stack-matched (with the evidence
file cited per suggestion), the curated any-project core (useful regardless of
stack — `skills/plugin-scout/references/any-core.md`), and the universal
remainder, paged list by list until the whole catalog has been offered. Already
installed plugins are marked and skipped. Picked suggestions are installed via
`claude plugin install <name>@cc-plugins-marketplace --scope local` after an
explicit confirm — repo-scoped by default (`--persist` upgrades the scope to
`project` for team sharing, `--global` to `user` for machine-wide).

Doctrine: suggestions cite evidence — every stack-matched row names the manifest
line that earned it, and without `--yes` nothing installs without your pick.

Flags: `--yes` is the auto-installer — installs tier-1 signal-backed plus the
tier-2 any-project core, not-yet-installed only (skips the picker; tier-3 never
auto-installs); `--persist` installs at project scope and writes the installed
set into the project's `.claude/settings.json`; `--global` installs at user
scope (every repo on the machine — mutually exclusive with `--persist`).
`--yes` combines with either. Full semantics:
`skills/plugin-scout/references/flags.md`.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install plugin-scout@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/plugin-scout:suggest [path] [--yes] [--persist \| --global]` | Detect the stack, print the three-tier suggestion table covering every marketplace plugin (plugin, tier, evidence, installed), then offer to install the plugins you pick page by page — or auto-install tier-1 + core picks (`--yes`), persist the installed set to project settings (`--persist`), or install machine-wide at user scope (`--global`) |

## Example

```bash
/plugin-scout:suggest
```

In a Laravel + Inertia repo this suggests laravel and inertia (tier 1, each
with its composer.json/package.json evidence), then the any-project core —
code-review, debugging, testing, git-workflow, and the rest of
`references/any-core.md` — then pages through the entire remaining catalog
(tier 3), minus whatever is already installed.

## Pairs well with

- **stack-scan** — when installed, its required-vs-installed inventory becomes
  the detection input instead of a fresh manifest scan
- **taskmaster-suite** — bundle alternative: installs most of the universal tier
  in one step (see its README for deliberate exclusions such as secret-scanning)
  instead of picking plugins individually
