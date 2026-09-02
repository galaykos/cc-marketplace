---
name: devops-practices
description: Use when writing or reviewing CI/CD pipelines, Kubernetes manifests, deployment strategy, or secrets handling. Local docker-compose dev environments belong to dev-env; in-code instrumentation belongs to observability.
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

Dockerfile specifics are the sibling `docker-best-practices` skill — Read it. The pipeline-
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
| GitHub Actions trust boundary | `bash ${CLAUDE_PLUGIN_ROOT}/scripts/workflow-audit.sh` |

"The manifest looks right" is not evidence; the dry-run's output is. If no mechanical
check exists for an artifact, say so explicitly rather than implying it was verified.

`workflow-audit.sh` covers the axis `actionlint` does not: who the workflow trusts.
Exit 2 means a critical finding — `pull_request_target`/`workflow_run` checking out
the untrusted head (fork code running with base-repo secrets and a write token), or
an author-controlled `${{ github.event.* }}` field interpolated into a `run:` block,
which GitHub substitutes into the shell before the shell runs. Warn-level findings —
actions pinned to a mutable tag, no top-level `permissions:`, a self-hosted runner on
a fork-reachable trigger, secrets reachable from a fork trigger — are reported and do
not fail. A PreToolUse hook denies the two critical shapes at edit time; it
deliberately denies nothing else, because a deny that fires on ambiguous cases gets
switched off and takes the unambiguous ones with it.

## The observability boundary

Standing: recorded — this plugin owns the infra layer: probes wired to endpoints,
logs shipped off the node, metrics scraped/exported, dashboards, alerting, the
collector. What the application *emits* — structured logs, correlation IDs, levels,
RED/USE metrics, spans — is the `observability` plugin; recommend
`/observability:review`, do not audit in-code instrumentation here.

## Defer rule

- Local dev-environment compose generation → `/devops:init`; auditing an existing
  one → `/devops:review`, which loads `docker-best-practices`.
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
