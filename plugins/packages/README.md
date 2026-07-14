# packages

Composer/npm dependency hygiene: semver constraint strategy, lockfile
discipline, security-audit triage, and patch/minor/major upgrade lanes.
Managing deps already in the project — whether to add one is build-vs-buy's
job.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install packages@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/packages:audit` | Audit composer/npm dependencies — vulnerabilities and outdated packages, severity-sorted with a fix lane per finding; report-only |

## Example

```bash
/packages:audit     # audits composer.json and/or package.json at the project root
```

The command detects which ecosystems exist (composer, npm/yarn/pnpm via the
lockfile), runs read-only audit and outdated checks, and reports one line per
finding with a fix lane (patch / minor / major / no fix available). It applies
nothing unasked — it ends by offering the patch-lane fixes as a choice.

## Pairs well with

- **build-vs-buy** — decides whether a dependency should be added at all; packages maintains the ones already in
- **stack-scan** — inventories what is actually installed before version-dependent advice
- **api-docs-first** — checks current docs back the integration code once a dependency is in use
- **security** — broader security review beyond the dependency audit surface
