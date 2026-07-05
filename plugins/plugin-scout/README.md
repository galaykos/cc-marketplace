# plugin-scout

Scan the current project's manifests — composer.json, package.json,
tsconfig.json, .env, Dockerfile/docker-compose — and suggest which
cc-plugins-marketplace plugins to install, in two tiers: stack-matched (with the
evidence file cited per suggestion) and the universal always-useful set. Already
installed plugins are marked and skipped. Picked suggestions are installed via
`claude plugin install <name>@cc-plugins-marketplace` after an explicit confirm.

Doctrine: suggestions cite evidence — every stack-matched row names the manifest
line that earned it, and nothing installs without your pick.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install plugin-scout@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/plugin-scout:suggest` | Detect the stack, print the two-tier suggestion table (plugin, tier, evidence, installed), then offer to install the plugins you pick |

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
- **taskmaster-suite** — bundle alternative: installs the whole universal tier
  in one step instead of picking plugins individually
