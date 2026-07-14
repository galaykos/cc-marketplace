# devops

DevOps pipeline and infrastructure: CI/CD ordering, container/image hygiene,
Kubernetes resource limits and probes, deploy strategy with rollback, and
secrets handling. Ships the `devops-practices` skill, a `/devops:review`
command, and a `devops-engineer` worker + `devops-reviewer` read-only pair.
Owns infra-layer observability wiring, but defers in-code instrumentation to
**observability** and local docker-compose dev environments to **dev-env**.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install devops@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/devops:review [path-or-diff]` | Review CI/CD pipelines, Kubernetes manifests, deploy/secret config against devops-practices |

## Example

```bash
/devops:review k8s/deployment.yaml
/devops:review          # reviews the current diff (merge base with fallback)
```

Findings come back one line each, severity-sorted, and are marked CONFIRMED
only when a mechanical check backs them (`docker compose config`,
`kubectl apply --dry-run=client`, `hadolint`, `actionlint`); the review audits
configuration and never runs deploys.

## Pairs well with

- **dev-env** — generating local docker-compose dev environments, which this plugin explicitly defers to
- **observability** — in-code instrumentation; devops owns only the infra-layer wiring
- **secret-scanning** — sweeps for already-committed secrets while devops reviews secret injection
- **rollout** — staged rollout planning around the deploy-with-rollback strategy this plugin reviews
