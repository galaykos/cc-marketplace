# stack-scan

Know what is actually installed, then keep it healthy. `/stack-scan:report`
inventories the stack from composer/npm/yarn/pnpm/bun manifests and lockfiles,
runtime pins, and docker/CI images into a required-vs-installed table with drift,
missing-lock, and EOL flags. `/stack-scan:audit` runs the dependency hygiene pass —
vulnerabilities, outdated packages, and licences against the project's distribution
mode — from the same manifests.

Doctrine: constraint is a wish, lock is a fact — lock beats manifest, runtime
beats lock, and every version claim cites its source.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install stack-scan@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/stack-scan:report` | Produce the required-vs-installed table plus red flags (multiple lockfiles, drift, EOL majors, docker-vs-local divergence) |
| `/stack-scan:audit` | Audit composer/npm dependencies — vulnerabilities, outdated packages, and dependency licences against the project's distribution mode, severity-sorted with a fix lane per finding; report-only, ends by offering the patch-lane fixes as a choice |

```bash
/stack-scan:report
/stack-scan:audit     # audits composer.json and/or package.json at the project root
```

Run the report once per session in an unfamiliar repo. The inventory feeds the
version-aware review plugins (laravel, database, web-dev), taskmaster's
context-scout, and devops's compose generator.

## Skills

| Skill | Reach for it when |
|---|---|
| `installed-versions` | Before version-dependent advice: what the lockfile, runtime binary, and container image actually say |
| `package-hygiene` | Managing dependencies already in the project — semver constraint strategy, lockfile discipline, security-audit triage, licence checks, patch/minor/major upgrade lanes. Whether to add one is approaches' build-vs-buy |

## Pairs well with

- **taskmaster** — hard constraints for the interrogation come from this inventory
- **devops** — `/devops:init` reuses the report instead of re-scanning
- **plugin-scout** — consumes stack-scan's inventory as detection input to suggest which marketplace plugins fit the project
- **approaches** (build-vs-buy skill) — decides whether a dependency should be added at all
- **security** — broader security review beyond the dependency audit surface
