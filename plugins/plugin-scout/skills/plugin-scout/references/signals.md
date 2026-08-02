# Second-tier evidence signals

The SKILL's tier-1 signal table reads `composer.json`, `package.json`, `.env`
DSNs and docker images. That covers the PHP and JS/TS surface and nothing else,
so a Python, Go, Rust, Terraform or infra-shaped repo produces **zero** tier-1
hits and falls through to tier 2 — which is "every catalog plugin except tier-1,
the bundles and itself", ~43 rows all carrying the literal evidence string
`universal`. That is the no-evidence path the SKILL's own rule forbids, and at 16
options per AskUserQuestion it is three paged calls of undifferentiated noise.

The rows below are evidence-bearing signals for plugins currently stranded in
that tier. Same rule as tier 1: **cite the file and the line/key that matched**,
never suggest without one.

Four of these are already encoded as skill-router glob rows and are lifted here
rather than re-derived — the mechanism differs (suggest-at-install vs
route-at-edit) but the manifest→plugin mapping must not fork. Where a row says
"mirrors rules.tsv", change both or neither.

| Signal (evidence file / key) | Suggest | Note |
|---|---|---|
| `.github/workflows/*.yml`, `.gitlab-ci.yml`, `Jenkinsfile` | `devops` | mirrors rules.tsv `**/workflows/**` |
| `k8s/`, `helm/`, `*.yaml` with `apiVersion:` + `kind:` | `devops` | |
| `Dockerfile*`, `docker-compose*.y{a,}ml`, `compose*.y{a,}ml` | `dev-env` | mirrors rules.tsv |
| `openapi*.y{a,}ml`, `swagger*.json`, `*.proto`, `*.graphql` | `api-design` | mirrors rules.tsv |
| `.env` / `.env.example` key matching `STRIPE_`, `PADDLE_`, `BRAINTREE_` | `payments` | key name only — never read the value |
| `locales/`, `lang/`, `*.po`, `messages/*.json`, `i18n` dep | `i18n` | |
| `.env` key `ANTHROPIC_API_KEY` / `OPENAI_API_KEY`, or dep `langchain*`, `llamaindex`, `@anthropic-ai/*` | `llm-app` | |
| `prometheus` / `grafana` / `otel-collector` service in compose, or `@opentelemetry/*` dep | `observability` | |
| `pyproject.toml`, `go.mod`, `Cargo.toml`, `*.csproj`, `build.gradle*`, `Gemfile` | `stack-scan` | the version-truth plugin is the ONE always-right answer for a stack this marketplace does not cover |
| any of the above **plus** no tier-1 hit | also `vercel-skills-scout` | say so explicitly: this marketplace has no plugin for that stack, and the scout for third-party skills is the intended next step |
| `*.tf`, `*.tofu`, `.terraform/` | — | **no plugin covers this.** Do not pad the list; route to `/vercel-skills-scout:suggest terraform` |

## The last two rows are the point

A scout that returns "here are 43 universally useful plugins" to a Django repo is
worse than one that says "this marketplace does not cover Django; here is where
to look". The second answer is short, true, and actionable. Prefer it.

## Standing

**Agent-graded.** No script checks that the model cited the evidence for these
rows, the same standing tier-1 carries. The four `mirrors rules.tsv` rows are the
only ones with a mechanical counterpart, and even there nothing compares the two
files — a divergence is caught by a human reading both, or not at all.
