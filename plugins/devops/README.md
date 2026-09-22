# devops

Infrastructure in one plugin: CI/CD ordering, container/image hygiene, Kubernetes
resource limits and probes, deploy strategy with rollback, and secrets handling
(`devops-practices`); Dockerfile and compose discipline (`docker-best-practices`); and
local dev environments generated from evidence via `/devops:init` (`compose-init`).
Ships a `devops-engineer` worker + `devops-reviewer` read-only pair and a PreToolUse
guard on workflow files. Owns infra-layer observability wiring, but defers in-code
instrumentation to **resilience** (its observability skill).

## What has teeth

| Rule | Standing |
|---|---|
| A write to `.github/workflows/` that triggers on `pull_request_target`/`workflow_run` **and** checks out the untrusted head ref | **gate** — PreToolUse deny; GitHub's own documented critical anti-pattern |
| A write to `.github/workflows/` **or `.github/actions/*/action.yml`** interpolating a `${{ github.event.* }}` field an author can type directly into a `run:` block | **gate** — PreToolUse deny; the shell substitution happens before the shell runs, and a composite runs with the calling workflow's token |
| A Terraform/OpenTofu plan that deletes or replaces a resource whose type holds data, or a `lifecycle.prevent_destroy = true` removed from the source since `--base` | **gate** — `scripts/plan-audit.sh` exits **2**; **1** means it could not read the input, so nothing was checked; **0** means none of those shapes. You run it (`/devops:review` does when `*.tf`/`*.tofu` or a plan JSON is in scope) — no hook fires, because a plan arrives as a file, not as a tool call |
| Every other CI/CD, Kubernetes, deploy and secrets rule in `devops-practices` | **agent-graded** — a reviewer applies them; no script does |
| The warn-level workflow findings (unpinned action tag, no top-level `permissions:`, self-hosted runner on a fork trigger, secrets in a `pull_request_target` workflow) | **recorded** — `scripts/workflow-audit.sh` prints them and **exits 0**; only a CRITICAL finding exits 2, and 3 means it could not read (bad argument, missing dir, no workflow files). Reached through the mechanical-check table in `devops-practices`, which `/devops:review` loads — never by a hook |

The guard blocks two shapes and nothing else. Everything the audit script finds
beyond them is a report you have to run — and a clean run means "none of the
shapes it knows are present in these files", not "this pipeline is safe": it is a
line scan, not a YAML parser. Composite actions under `.github/actions/` are read
for expression injection and unpinned `uses:` only; the trigger, `permissions:`
and runner rules are workflow-only, because a composite has none of those fields.
A composite elsewhere in the tree, one that shells out to a script file, or a
`secrets: inherit` reusable workflow still hides the sink where it cannot look.

The plan reader is a reader, not a terraform rubric: this plugin carries no terraform
advice, because a skill restating Terraform's docs is the shape
`rationale/measured-zero-shapes.md` records as measuring zero. What it misses is on
its own header — a resource type nobody put on the list, data loss inside an `update`
(a shrunk volume, `skip_final_snapshot` flipped), and whether a destroy is recoverable
at all. `--list-types` prints the list it does check. The `prevent_destroy` half reads
the `.tf` SOURCE against `--base`, because Terraform does not put `lifecycle` in the
JSON plan at all; with no git work tree to read it says `NOT CHECKED`, never "clean".

```bash
terraform show -json plan.out | bash scripts/plan-audit.sh          # 0 clean · 2 finding · 1 cannot read
bash scripts/plan-audit.sh --tf-dir infra --base origin/main plan.json
```

**Running headless / in CI.** Neither the audit script nor this guard asks anything —
the guard's only verdict is `deny`, so a headless run is unaffected by it. The plugins
that return `ask` are `command-guard` and `database`, and with no interactive prompt an
`ask` is auto-denied; see **Running headless / in CI** in `command-guard`'s README for
the automation profile. Standing: **recorded**.

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

The host's built-in `/init` writes a `CLAUDE.md` for the repository; `/devops:init`
generates `docker-compose.yml` — the names collide in the listing and nothing else does.

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
- **resilience** — in-code instrumentation (`/resilience:review --concern observability`); devops owns only the infra-layer wiring
- **secret-scanning** — sweeps for already-committed secrets while devops reviews secret injection
- **approaches** — its rollout-planning skill covers staged rollout planning around the deploy-with-rollback strategy this plugin reviews
- **database** — the services `/devops:init` wires up are the ones its review covers
