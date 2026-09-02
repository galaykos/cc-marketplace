# Second-tier evidence signals

The SKILL's tier-1 signal table reads `composer.json`, `package.json`, `.env.example`
DSNs and docker images, and it names six framework plugins. That covers the PHP and
JS/TS *framework* surface and nothing else, so a Python, Go, Rust, Terraform or
infra-shaped repo produces **zero** tier-1 hits and falls through to tier 3 — the
universal remainder, dozens of rows all carrying the literal evidence string
`universal`.

The rows below are evidence-bearing signals for plugins otherwise stranded in
that remainder — a hit lifts the plugin into tier 1, same evidence rule and
same `--yes` auto-install eligibility: **cite the file and the line/key that
matched**, never suggest without one.

Four rows are also encoded as skill-router glob rows and are lifted here rather
than re-derived — the mechanism differs (suggest-at-install vs route-at-edit) but
the manifest→plugin mapping must not fork. Where a row says "mirrors rules.tsv",
change both or neither. **Three of the four have already forked** and each
divergence is recorded in that row's note; reconciling them is a `skill-router`
change, out of this plugin's scope.

## Reading a dependency row

"dep X" means an **exact key** in `dependencies` or `devDependencies`, not a
substring. `next-auth`, `nextra` and `@next/bundle-analyzer` are not `next`;
`react-native-web` is not `react-native`. Cite the key and its constraint.

| Signal (evidence file / key) | Suggest | Note |
|---|---|---|
| `.github/workflows/*.yml`, `.gitlab-ci.yml`, `Jenkinsfile` | `devops` | mirrors rules.tsv `**/workflows/**` — which matches any path segment case-insensitively, so the router also fires on `app/Workflows/`; this row does not |
| `k8s/`, `helm/`, `*.yaml` with `apiVersion:` + `kind:` | `devops` | |
| `Dockerfile*`, `docker-compose*.y{a,}ml`, `compose*.y{a,}ml` | `devops` | mirrors rules.tsv, which covers `.yml` only — a repo with `compose.yaml` (the Compose Spec's preferred name) is suggested here and not routed there |
| `openapi*.y{a,}ml`, `swagger*.json`, `*.proto`, `*.graphql` | `api-design` | mirrors rules.tsv, forked both ways: `swagger*.json` is only here, `api.php` is only there |
| `.env` / `.env.example` key matching `STRIPE_`, `PADDLE_`, `BRAINTREE_`; or dep `stripe`, `@stripe/stripe-js`, `braintree`, `@paddle/*`; or composer require `stripe/stripe-php`, `laravel/cashier` | `payments` | key name only — never read the value |
| dep `three` or `@react-three/fiber` | `craft-layer` | |
| `tailwind.config.*`, `components.json`, or dep `tailwindcss` | `ui-ux` | |
| `components.json` carrying a `registries` or `aliases` key | `registry-source` | the same file also earns `ui-ux`; both are correct |
| devDep `eslint-plugin-jsx-a11y` or `@axe-core/*` | `ui-ux` | the dep, not the presence of `.tsx` — every React repo has those |
| `*.sql`, `**/migrations/**`, `prisma/schema.prisma`, `knexfile.*`, `alembic.ini` | `database` | engine-agnostic floor; mirrors rules.tsv `*.sql` + `**/migrations/**`, which make it the decisive DB fallback |
| composer require `laravel/sanctum` or `laravel/passport`; or dep `next-auth`, `@auth/core`, `jsonwebtoken`, `passport` | `security` | an auth dependency is the app-shaped evidence its OWASP review wants |
| a `package.json` or `composer.json` exists | `stack-scan` | its package-hygiene rubric is Composer/npm-specific, so it is signal-earned rather than any-project core — a Python repo must not auto-install it |
| `.env` key `ANTHROPIC_API_KEY` / `OPENAI_API_KEY`, or dep `langchain*`, `llamaindex`, `@anthropic-ai/*` | `llm-app` | |
| `prometheus` / `grafana` / `otel-collector` service in compose, or `@opentelemetry/*` dep | `resilience` | |
| `pyproject.toml`, `go.mod`, `Cargo.toml`, `*.csproj`, `build.gradle*`, `Gemfile` | `stack-scan` | the version-truth plugin is the ONE always-right answer for a stack this marketplace does not cover |
| `.claude-plugin/plugin.json` or `.claude-plugin/marketplace.json` | `claude-authoring` | the repo SHIPS Claude Code artifacts, which is what this plugin's rubric is about. Deliberately not `.claude/` — that directory means the repo *uses* Claude Code, which is not the same claim and would fire nearly everywhere |
| dep `prisma`, `@prisma/client`, `typeorm`, `sequelize`, `mongoose`, `drizzle-orm`; or composer require `doctrine/orm`; or `**/migrations/**` | `database` | the schema/migration/pooling half, and it ships a PreToolUse guard. The `sql` row above fires on some of the same evidence and owns statements; `references/picker.md` already pairs the two as overlapping, so both rows firing is correct, not a duplicate |
| `components.json` **and** a `tailwind.config.*` or `tailwindcss` dep | `shadcn-studio` | the sandbox is for staging new components against a shadcn setup that already exists; `components.json` alone also earns `ui-ux` and possibly `registry-source`, and all three are correct together |
| devDep `lighthouse`, `@lhci/cli`, `k6`, `artillery`, `autocannon`, or dep `web-vitals` | `resilience` | a measurement tool already in the manifest is someone having decided performance is a concern here |
| dep `p-retry`, `cockatiel`, `opossum`, `bullmq`, `bull`; or composer require `laravel/horizon` | `resilience` | retry/breaker/queue libraries are integration points with failure modes, which is the whole subject |
| any of the above **plus** no tier-1 hit | also `vercel-skills-scout` | say so explicitly: this marketplace has no plugin for that stack, and the scout for third-party skills is the intended next step |
| `*.tf`, `*.tofu`, `.terraform/` | — | **no plugin covers this.** Do not pad the list; route to `/vercel-skills-scout:suggest terraform` |
| `locales/`, `lang/`, `*.po`, `messages/*.json`, `i18n` dep | — | **no plugin covers this** — the i18n plugin was removed from this marketplace on 2026-08-26. Route to `/vercel-skills-scout:suggest i18n` |

## The uncovered-stack rows are the point

A scout that opens with "here are dozens of universally useful plugins" to a
Django repo is worse than one that says "this marketplace does not cover
Django; here is where to look". The second answer is short, true, and
actionable — lead with it. Tier 3 still follows, but it is the appendix, never
the headline, and under the default picker it is one door rather than four pages
(`references/picker.md`).

A `—` in the Suggest column is a real answer, not a gap: it means the signal
fired and this marketplace has nothing for it. Say so and route onward.

## Standing

**Agent-graded, with one gate.** No script checks that the model cited the
evidence for these rows, that a signal was read from the file it names, or that
a `—` row routed onward instead of padding tier 3 — the same standing tier-1
carries.

The one mechanical check is `pc_scout_names` (`scripts/lib/plugin-checks.sh`):
it fails the build when a name in the Suggest column is not a live
`marketplace.json` entry. That gate exists because this table shipped a row
suggesting `i18n` for two days after the plugin was deleted, and `pc_removed_refs`
returned 0 on it — a bare backticked table cell matches none of its reference
shapes. **It gates the NAME only.** Whether the signal pattern is correct, whether
it fires on the right file, and whether the plugin is the right suggestion are all
still judgment nothing checks.

The `mirrors rules.tsv` rows have a mechanical counterpart but no comparison
between the two files; three of the four have already diverged, as noted per
row. The `sql` row is the one that still matches — which nothing checks either,
so it matches until someone edits one side.
