---
name: devops-practices
description: Use when writing or reviewing CI/CD pipelines, Kubernetes manifests, deployment strategy, or secrets handling — pipeline ordering, image hygiene, resource limits and probes, rollout+rollback strategy, and secret injection. Local docker-compose dev environments belong to dev-env; in-code instrumentation belongs to observability.
---

# DevOps practices

Infrastructure and pipeline configuration has a blast radius the code does not: a bad
manifest takes down every pod, a leaked secret is permanent. Inventory what exists
before writing — CI configs (`.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`),
Dockerfiles, compose files, deploy scripts, k8s manifests, Helm charts, Makefile
targets — and build on it. Pin to the project's *actual* stack and versions, read
from its manifests and lockfiles, never assumed.

## CI/CD pipeline

- **Order fail-fast, cheapest first:** lint → test → build → deploy. A 2-second lint
  that fails should never wait behind a 10-minute build.
- **Cache** dependencies and build layers between runs; an uncached pipeline pays
  full install cost every push.
- **One-way gates:** deploy stages depend on test stages passing — never a pipeline
  that can ship on a red test because the deploy job is independent.
- **Reproducible:** the same commit builds the same artifact; no `latest` base images,
  no floating tool versions that drift the build under you.

## Container image hygiene

Dockerfile specifics are `docker-best-practices` (dev-env) — Read it. The pipeline-
level rules that live here:

- Pinned base images (digest or exact tag), multi-stage builds separating build from
  runtime, a non-root user in the final stage.
- A `.dockerignore` excluding secrets, VCS metadata, and build artifacts — the image
  is a distribution surface, not a backup of your working tree.

## Kubernetes

- **Resource requests AND limits on every container** — no requests means the
  scheduler guesses and the node OOMs; no limits means one pod starves its neighbors.
- **Probes:** liveness (restart when wedged), readiness (pull from the load balancer
  when not ready), startup (protect slow-booting apps from liveness killing them
  mid-boot). Wiring probes to real health endpoints is here; what those endpoints
  *report* is the app's job.
- **Explicit rollout strategy** — `maxSurge`/`maxUnavailable` set deliberately, not
  defaulted.

## Deploy strategy

Choose blue-green, canary, or rolling **deliberately and justify it**, and every
deploy-strategy decision **states its rollback path** alongside it. A deploy you
cannot cleanly roll back is an outage you have pre-committed to. Canary needs a
metric and an automatic abort threshold, or it is just a slow full rollout.

## Secrets

- Never baked into images or committed. Environment injection or a secret store
  (Kubernetes Secrets sealed/external, Vault, a cloud secret manager) with
  least-privilege access.
- A secret found already committed is flagged to the user with its location — never
  moved, copied, or rewritten silently (that just spreads it and rewrites history
  someone is relying on). Rotation is the real fix; removal from history is secondary.

## Validate mechanically, report evidence

Config is code; check it before shipping and paste the output:

| Artifact | Check |
|---|---|
| Dockerfile | `docker build` (or `hadolint`) |
| compose | `docker compose config` |
| k8s manifest | `kubectl apply --dry-run=client -f` (or `kubeconform`) |
| Helm chart | `helm template \| kubeconform`, `helm lint` |
| CI workflow | the CI system's lint/dry-run (`actionlint`, `gitlab-ci lint`) |

"The manifest looks right" is not evidence; the dry-run's output is. If no mechanical
check exists for an artifact, say so explicitly rather than implying it was verified.

## The observability boundary

Two plugins touch observability; the split is by layer:

- **This plugin (infra):** wire probes to endpoints, ship logs off the node, scrape/
  export metrics, provision dashboards and alerting rules, set up the collector.
- **`observability` plugin (code):** what the application *emits* — structured logs,
  correlation IDs, log levels, RED/USE metrics in code, trace spans. Do not audit
  in-code instrumentation here; recommend `/observability:review`.

## Defer rule

- Local dev-environment compose generation → `/dev-env:init`; auditing an existing
  one → `/dev-env:review`.
- Stack/dependency inventory → `/stack-scan:report` — use its output.
- Application-code security → `/security:review`; you handle infra and pipeline
  config, not source audits.
- In-code instrumentation → `/observability:review` (see the boundary above).

## Anti-patterns

- **Ship-on-red:** a deploy stage that can run when tests failed.
- **No resource limits:** one greedy pod starving a node.
- **`latest` base image:** an unreproducible build that changes under you.
- **Deploy with no rollback path:** an outage pre-committed.
- **Secret in image or repo:** permanent leakage; env-inject or a store instead.
- **Unvalidated manifest:** shipped on "looks right" with no dry-run output attached.
