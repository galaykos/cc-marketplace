# Second-tier evidence signals

The SKILL's tier-1 signal table reads `composer.json`, `package.json`, `.env.example`
DSNs and docker images, and it names three plugins across six signals. That covers the PHP and
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
| `.env` / `.env.example` key matching `STRIPE_`, `PADDLE_`, `BRAINTREE_`; or dep `stripe`, `@stripe/stripe-js`, `braintree`, `@paddle/*`; or composer require `stripe/stripe-php`, `laravel/cashier` | — | **no plugin covers this** — `security` and `resilience` skills co-fire on provider calls. Key name only — never read the value |
| dep `three` or `@react-three/fiber` | `craft-layer` | |
| dep `gsap`, `lenis` or `@studio-freight/lenis` | `craft-layer` | its `scroll-orchestration` skill owns GSAP ScrollTrigger + Lenis; without this row an Astro + GSAP + Lenis site earned only `ui-ux` |
| `tailwind.config.*`, `components.json`, or dep `tailwindcss` | `ui-ux` | |
| `components.json` carrying a `registries` or `aliases` key | `ui-ux` | a configured registry is what its stack skills read component APIs from; print shadcn's own MCP install line (`npx shadcn@latest mcp init --client claude`) with it — this marketplace ships no registry server |
| dep `@mui/material`, `@mantine/core`, `@chakra-ui/react`, `antd`, `@heroui/react`, `@base-ui/react`, `radix-ui`/`@radix-ui/*`, `react-aria-components`, `@ark-ui/react`, `@headlessui/react`, `@ariakit/react`, `@astryxdesign/core`, `primereact`, `@primereact/ui`, `primevue`, `vuetify`, `element-plus` | `ui-libraries` | a React or Vue component library in the manifest; MUI, Astryx and PrimeReact have sibling skills, the rest route to `component-libraries` (split out of `ui-ux` 2026-09-26 — suggest `ui-ux` too when it is not installed) |
| devDep `eslint-plugin-jsx-a11y` or `@axe-core/*` | `ui-ux` | the dep, not the presence of `.tsx` — every React repo has those |
| `*.sql`, `**/migrations/**`, `prisma/schema.prisma`, `knexfile.*`, `alembic.ini` | `database` | engine-agnostic floor; mirrors rules.tsv `*.sql` + `**/migrations/**`, which make it the decisive DB fallback |
| composer require `laravel/sanctum` or `laravel/passport`; or dep `next-auth`, `@auth/core`, `jsonwebtoken`, `passport` | `security` | an auth dependency is the app-shaped evidence its OWASP review wants |
| `phpstan.neon*`, `psalm.xml*`, `phpcs.xml*`, `rector.php`, `eslint.config.*`, `.eslintrc*`, `biome.json*`, `.oxlintrc.json`, `.stylelintrc*`, `lighthouserc*`, `.pa11yci*`, `tsconfig.json`; or the matching composer/npm devDependency | `toolchain-experts` | a configured analyzer is the whole signal: its five reviewers RUN that tool and report what the baseline forgives and which rules are off, and its own `detect-analyzers.sh` exits 1 when nothing is configured, so with no config there is nothing to suggest |
| a `package.json` or `composer.json` exists | — | the Composer/npm dependency-hygiene rubric ships IN the plugin running this scout, so there is no row to offer: name the lane instead — `/stack-scan:audit` for vulnerabilities, outdated packages and licences |
| `.env` key `ANTHROPIC_API_KEY` / `OPENAI_API_KEY`, or dep `langchain*`, `llamaindex`, `@anthropic-ai/*` | — | **no plugin covers this** — `security`'s write-scan keeps the LLM-sink patterns, and the host's built-in `claude-api` skill carries provider facts |
| `prometheus` / `grafana` / `otel-collector` service in compose, or `@opentelemetry/*` dep | `resilience` | |
| `pyproject.toml`, `go.mod`, `Cargo.toml`, `*.csproj`, `build.gradle*`, `Gemfile` | — | **no plugin covers this stack.** The version-truth lane is already installed — `/stack-scan:report` reads these manifests, and `references/ecosystems.md` carries their authority conflicts — so route the rest to `/stack-scan:suggest --skills` |
| dep `prisma`, `@prisma/client`, `typeorm`, `sequelize`, `mongoose`, `drizzle-orm`; or composer require `doctrine/orm`; or `**/migrations/**` | `database` | the schema/migration/pooling half, and it ships a PreToolUse guard. The `sql` row above fires on some of the same evidence and owns statements; `references/picker.md` already pairs the two as overlapping, so both rows firing is correct, not a duplicate |
| `components.json` **and** a `tailwind.config.*` or `tailwindcss` dep | `ui-ux` | a shadcn setup that already exists is what a real-component preview renders variants in (taskmaster's visual-decisions rung); the `components.json` row above fires on the same file, and one row is enough |
| devDep `lighthouse`, `@lhci/cli`, `k6`, `artillery`, `autocannon`, or dep `web-vitals` | `resilience` | a measurement tool already in the manifest is someone having decided performance is a concern here |
| dep `p-retry`, `cockatiel`, `opossum`, `bullmq`, `bull`; or composer require `laravel/horizon` | `resilience` | retry/breaker/queue libraries are integration points with failure modes, which is the whole subject |
| any of the above **plus** no tier-1 hit | — | say so explicitly: this marketplace has no plugin for that stack, and `/stack-scan:suggest --skills` (third-party skills on skills.sh) is the intended next step |
| `*.tf`, `*.tofu`, `.terraform/` | — | **no plugin covers this.** Do not pad the list; route to `/stack-scan:suggest --skills terraform` |
| `locales/`, `lang/`, `*.po`, `messages/*.json`, `i18n` dep | — | **no plugin covers this.** Route to `/stack-scan:suggest --skills i18n` <!-- removed-ok --> |
| dep `astro` | — | **no plugin covers Astro.** Print the Astro Docs MCP from `references/official-complements.md` § Framework-native tooling; route API questions to `api-design:api-docs-first` |
| dep `nuxt` | — | **no plugin covers Nuxt** (the one here was removed 2026-08-26). Print the Nuxt MCP from § Framework-native tooling; route to `api-design:api-docs-first` |
| dep `@react-router/dev` | — | **no plugin covers React Router framework mode**: the Vite row's `web-dev` fits the build layer only. Route loaders, actions and route modules to `api-design:api-docs-first` |
| composer require `livewire/livewire` or `livewire/flux` | — | **no plugin covers Livewire or Flux** (the Livewire one was removed 2026-08-26); `laravel` fires on the same repo and carries none of it. Print Laravel Boost from § Framework-native tooling: the vendor's version-matched `livewire-development` and `fluxui-development` skills |
| composer require `filament/filament` | — | **no plugin covers Filament**, and `laravel-best-practices`' controller and FormRequest rules do not fit its resources. Print Laravel Boost: Filament ships its own `filament-development` Boost skill |
| dep `sanity`, `next-sanity`, `@sanity/client`, `contentful`, or `@storyblok/*` | — | **no plugin covers headless CMS SDKs.** Route to `api-design:api-docs-first` (`/api-design:check` before integration code); the `context7` row in `references/official-complements.md` supplies the docs |

## Companions — print the missing half

No plugin here declares `dependencies`: an update that adds one leaves it uninstalled and
the plugin then fails to load (measured on CLI 2.1.283, 2026-09-26), so nothing pulls a
companion in. The scout says it instead. When a plugin in the first column is
**recommended** (tier 1, tier 2, or lifted into `worth a look here`), **picked**, or
**already installed**, and the plugin beside it is not installed, print one line under
the report (after the install summary for a pick), with this run's scope:

`craft-layer needs ui-ux — claude plugin install ui-ux@cc-plugins-marketplace --scope local`

| Recommended, picked or installed | Plugin | Why it is needed |
|---|---|---|
| `ui-ux` | `ui-libraries` | ui-ux's component-library skills (MUI, PrimeReact, Astryx, ReUI, Aceternity, `component-libraries`) live there since 2026-09-26; `/ui-ux:build` and the ui-ux agents name them as `ui-libraries:<skill>` |
| `craft-layer` | `ui-ux` | craft-layer themes and builds through `/ui-ux:theme` and `/ui-ux:build` |
| `craft-layer` | `ui-libraries` | the component-library layer those builds reach |
| `ui-libraries` | `ui-ux` | the foundations, and the agents that load its skills |

- **Printed, never run** — the companion is already a numbered report row, pickable like
  any other; the line only makes the pairing impossible to miss. `--yes` still never
  installs a tier-3 row: it prints the line after its summary instead.
- **`--full` rarely needs it**: `ui-ux` and `ui-libraries` are any-stack there
  (`references/stack-relevance.md`), so they install whenever `craft-layer` does. Print
  the line only for a companion whose install failed.
- Optional partners (`design-kit`, `skill-router` beside `craft-layer`) get no line —
  the plugin works without them.

## The uncovered-stack rows are the point

A scout that opens with "here are dozens of universally useful plugins" to a
Django repo is worse than one that says "this marketplace does not cover
Django; here is where to look". The second answer is short, true, and
actionable — lead with it. Tier 3 still follows, but it is the appendix, never
the headline, and under the default picker it is one door rather than four pages
(`references/picker.md`).

A `—` in the Suggest column is a real answer, not a gap: it means the signal
fired and this marketplace has nothing for it. Say so and route onward.

The framework rows (Astro, Nuxt, React Router, Livewire/Flux, Filament, headless CMS) print
whenever their key is present, **even beside tier-1 hits**. The "no tier-1 hit" row above
does not gate them. A Tailwind or `laravel/framework` hit does not make the framework
covered, and silencing the row there is how an Astro repo never heard it was uncovered.

## Standing

**Agent-graded, with one gate.** No script checks that the model cited the
evidence for these rows, that a signal was read from the file it names, or that
a `—` row routed onward instead of padding tier 3 — the same standing tier-1
carries.

The one mechanical check is `pc_scout_names` (`scripts/lib/plugin-checks.sh`):
it fails the build when a name in the Suggest column — or the Companions table's
`Plugin` column — is not a live `marketplace.json` entry. Whether the companion line was
printed, and whether the pairing is still true, is agent-graded like the rest. That gate exists because this table shipped a row
suggesting `i18n` for two days after the plugin was deleted, and `pc_removed_refs`
returned 0 on it — a bare backticked table cell matches none of its reference
shapes. **It gates the NAME only.** Whether the signal pattern is correct, whether
it fires on the right file, and whether the plugin is the right suggestion are all
still judgment nothing checks.

The `mirrors rules.tsv` rows have a mechanical counterpart but no comparison
between the two files; three of the four have already diverged, as noted per
row. The `sql` row is the one that still matches — which nothing checks either,
so it matches until someone edits one side.
