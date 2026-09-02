# Detection map — project signals to primed skills

The **manifest-shaped** half of routing. The file-shaped half already exists and is NOT
duplicated here: `skill-router`'s `rules.tsv` maps edited file patterns to skills and
fires on every write. Two copies of one matcher guarantees that one goes stale — the same
reasoning `scripts/validate.sh` states about its own shared patterns — so this file covers
only what the router cannot see at prompt time: what the PROJECT is, before any file has
been touched.

Read a signal, prime the skills on its row. Priming is one `Read <abs-path>` line, not a
body load; § Priming in the skill body has the form.

## Backend / language

| Signal | Prime |
|---|---|
| `composer.json` ~ `laravel/framework` | `laravel:laravel-best-practices` |
| `composer.json` ~ `inertiajs/inertia-laravel`, or `package.json` ~ `@inertiajs/` | `laravel:inertia-best-practices` |

## Frontend

| Signal | Prime |
|---|---|
| `package.json` ~ `"react-native"` | `web-dev:react-native-best-practices` |
| `package.json` ~ `"next"` | `web-dev:nextjs-best-practices` |
| `package.json` ~ `"vite"` | `web-dev:vite-best-practices` |
| `package.json` ~ `"tailwindcss"` | `ui-ux:tailwind-best-practices` |
| `components.json` present (shadcn/ReUI registry) | `ui-ux:shadcn-best-practices` |
| any `*.tsx` / `*.jsx` / `*.vue` / `*.blade.php` in the tree | `a11y:a11y-audit` |

## Stack-neutral

Signals that say nothing about the stack, only that the surface exists. Both rows were
already emitted by `skill-router/hooks/prime.sh` and missing here — the drift this map's
own header warns about, found by `pc_prime_coverage` rather than by reading.

| Signal | Prime |
|---|---|
| any `composer.json` or `package.json` | `stack-scan:package-hygiene` |
| a `tests/` directory, or any `*.test.*` / `*.spec.*` | `testing:testing-best-practices` |

## Data

| Signal | Prime |
|---|---|
| a `migrations/` directory, or any `*.sql` | `database:sql-best-practices` |
| compose file ~ `image: *mariadb*` | `database:mariadb-best-practices` |

Engine detection mirrors `rules.tsv`'s chain and inherits its stated misses — compose
image first, because it is the one signal that separates MySQL from MariaDB cleanly.
Engines without a dialect plugin (MySQL, PostgreSQL, …) prime only the sql row.

## Infrastructure and cross-cutting

| Signal | Prime |
|---|---|
| `Dockerfile*` or a compose file | `devops:docker-best-practices` |
| `.github/workflows/` | `devops:devops-practices` |
| the ASK mentions auth, login, token, session, permission, or payment | `security:security-review` |
| the ASK mentions Stripe, billing, subscription, invoice, or checkout | `payments:payments` |
| the ASK mentions an external API, webhook, retry, or queue | `resilience:resilience-design` |

The last four rows key off the request, not the repository — they are the surfaces where
getting it wrong is expensive and the file that would trigger the router does not exist
yet, which is exactly the window this command covers.

## Degradation

A signal whose plugin is not installed primes nothing and is **named in the output**:
`not primed: laravel-best-practices (laravel plugin not installed)`. Silence would read as
"nothing applies here", which is the opposite of true. Same reasoning as
`task-execution/references/routing.md`'s degraded-worker line.

A repo with no recognisable manifest gets tier 1 only, and the command says so rather
than guessing from directory names.
