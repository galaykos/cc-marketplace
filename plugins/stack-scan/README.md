# stack-scan

Inventory the actual stack from composer/npm/yarn/pnpm/bun manifests and
lockfiles, runtime pins, and docker/CI images; required-vs-installed table with
drift, missing-lock, and EOL flags.

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

## Example

```bash
/stack-scan:report
```

Run it once per session in an unfamiliar repo. The inventory feeds the
version-aware review plugins (php, mysql, mariadb, postgresql, react, vue),
taskmaster's context-scout, and dev-env's compose generator.

## Pairs well with

- **taskmaster** — hard constraints for the interrogation come from this inventory
- **dev-env** — `/dev-env:init` reuses the report instead of re-scanning
- **plugin-scout** — consumes stack-scan's inventory as detection input to suggest which marketplace plugins fit the project
