---
description: Review CI/CD pipelines, Kubernetes manifests, and deploy/secret config against devops-practices
argument-hint: [path-or-diff]
---

Review the target's pipeline and infrastructure configuration — you audit the config,
you do not run deploys.

1. Determine scope from $ARGUMENTS — CI configs, Dockerfiles/compose, k8s manifests or
   Helm charts, deploy scripts, or a diff. If empty, locate them across the repo
   (`.github/workflows/`, `Dockerfile*`, `*.yaml` under k8s/helm dirs) and review what
   exists.

2. Invoke the `devops-practices` skill from this plugin and apply its checklist:
   pipeline ordering (fail-fast, one-way deploy gates, caching, reproducibility),
   image hygiene (pinned bases, multi-stage, non-root, `.dockerignore`), Kubernetes
   (resource requests+limits on every container, liveness/readiness/startup probes,
   explicit rollout strategy), deploy strategy (a justified choice WITH its rollback
   path), and secrets (nothing baked into images or committed). For Dockerfile
   specifics defer to `docker-best-practices`.

3. Run the mechanical check for each artifact where available (`docker compose
   config`, `kubectl apply --dry-run=client`, `hadolint`, `actionlint`) and cite the
   output. Flag a finding as verified only when a check backs it.

4. Output findings one line each:
   path:line — severity — problem — fix
   Order by severity: critical, high, medium, low. A committed secret is always
   critical.

5. Defer, do not duplicate: local compose generation → `/dev-env:init`; in-code
   instrumentation → `/observability:review`; source-code security → `/security:review`.

6. When findings exist, offer the next step as a selectable choice (AskUserQuestion):
   "Have the devops-engineer apply the fixes now (Recommended)" / "Report only". On
   apply, dispatch the `devops-engineer` worker with the finding list. In headless or
   non-interactive runs, report only.
