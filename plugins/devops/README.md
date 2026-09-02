# devops

Infrastructure in one plugin: CI/CD ordering, container/image hygiene, Kubernetes
resource limits and probes, deploy strategy with rollback, and secrets handling
(`devops-practices`); Dockerfile and compose discipline (`docker-best-practices`); and
local dev environments generated from evidence via `/devops:init` (`compose-init`).
Ships a `devops-engineer` worker + `devops-reviewer` read-only pair and a PreToolUse
guard on workflow files. Owns infra-layer observability wiring, but defers in-code
instrumentation to **resilience** (its observability skill).

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install devops@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/devops:review [path-or-diff]` | Review CI/CD pipelines, Kubernetes manifests, deploy/secret config against `devops-practices`, and any Dockerfile or compose file in scope against `docker-best-practices` |
| `/devops:init [path]` | Scan the project, propose a service plan as a diagram, generate compose + Dockerfile pinned to the evidence, then boot and smoke-test it |

```bash
/devops:review k8s/deployment.yaml
/devops:review docker-compose.yml Dockerfile
/devops:review          # reviews the current diff (merge base with fallback)
/devops:init            # generate compose + Dockerfile from evidence
```

Findings come back one line each, severity-sorted, and are marked CONFIRMED
only when a mechanical check backs them (`docker compose config`,
`kubectl apply --dry-run=client`, `hadolint`, `actionlint`); the review audits
configuration and never runs deploys.

## Skills

| Skill | Reach for it when |
|---|---|
| `devops-practices` | Pipelines, manifests, deploy strategy, secrets — anything that reaches production |
| `docker-best-practices` | A Dockerfile or compose file, dev or prod — layer order, pinned tags, healthchecks, non-root, image size |
| `compose-init` | The `/devops:init` procedure: PHP version from `composer.json` (`config.platform.php` beats the `require` floor), extensions from `ext-*` requires, the database engine from `.env` DSNs and CI images — every choice cites its source, guesses are marked ASSUMED; topology shown as a diagram before any YAML; never overwrites an existing file without a diff; not done until `docker compose up -d --wait` plus a smoke check pass |

## Pairs well with

- **stack-scan** — when installed, `/devops:init` reuses its inventory instead of re-scanning
- **resilience** — in-code instrumentation (`/resilience:observability-review`); devops owns only the infra-layer wiring
- **secret-scanning** — sweeps for already-committed secrets while devops reviews secret injection
- **approaches** — its rollout-planning skill covers staged rollout planning around the deploy-with-rollback strategy this plugin reviews
- **database** — the services `/devops:init` wires up are the ones its review covers
