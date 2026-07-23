# plugin-scout

Scan the current project's manifests — composer.json, package.json,
tsconfig.json, .env, Dockerfile/docker-compose — and suggest which
cc-plugins-marketplace plugins to install, in two tiers: stack-matched (with the
evidence file cited per suggestion) and the universal always-useful set. Already
installed plugins are marked and skipped. Picked suggestions are installed via
`claude plugin install <name>@cc-plugins-marketplace` after an explicit confirm.

Doctrine: suggestions cite evidence — every stack-matched row names the manifest
line that earned it, and nothing installs without your pick.

Flags: `--yes` auto-installs tier-1 signal-backed, not-yet-installed picks
(skips the picker; tier-2 never auto-installs); `--persist` writes the
installed set into the project's `.claude/settings.json`. Combinable. Full
semantics: `skills/plugin-scout/references/flags.md`.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install plugin-scout@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/plugin-scout:suggest [--yes] [--persist]` | Detect the stack, print the two-tier suggestion table (plugin, tier, evidence, installed), then offer to install the plugins you pick — or auto-install tier-1 picks (`--yes`) and/or persist the installed set to project settings (`--persist`) |

## Example

```bash
/plugin-scout:suggest
```

In a Laravel + Vue 3 repo this suggests php, laravel, vue3 (tier 1, each with
its composer.json/package.json evidence) plus the universal tier — debugging,
git-workflow, testing, security, code-review, and the rest — minus whatever is
already installed.

## Pairs well with

- **stack-scan** — when installed, its required-vs-installed inventory becomes
  the detection input instead of a fresh manifest scan
- **taskmaster-suite** — bundle alternative: installs most of the universal tier
  in one step (see its README for deliberate exclusions such as secret-scanning
  and intent-guard) instead of picking plugins individually
