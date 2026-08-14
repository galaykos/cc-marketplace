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
| `composer.json` exists | `php:php-best-practices` |
| `composer.json` ~ `laravel/framework` | `laravel:laravel-best-practices` (and NOT the plain php row — they are stack-exclusive, same rule `rules.tsv` applies) |
| `composer.json` ~ `livewire/livewire` | `livewire:livewire-best-practices` |
| `composer.json` ~ `inertiajs/inertia-laravel`, or `package.json` ~ `@inertiajs/` | `inertia:inertia-best-practices` |
| `package.json` ~ `"express"`/`"fastify"`/`@nestjs/` | `node-backend:node-backend-best-practices` |

## Frontend

| Signal | Prime |
|---|---|
| `package.json` ~ `"react"`, no `"react-native"` | `react:react-server-state` |
| `package.json` ~ `"react-native"` | `react-native:react-native-best-practices` |
| `package.json` ~ `"vue"` at 3.x | `vue3:vue3-best-practices` |
| `package.json` ~ `"next"` | `nextjs:nextjs-best-practices` |
| `package.json` ~ `"nuxt"` | `nuxt:nuxt-best-practices` |
| `package.json` ~ `"vite"` | `vite:vite-best-practices` |
| `package.json` ~ `"tailwindcss"` | `ui-ux:tailwind-best-practices` |
| `components.json` present (shadcn/ReUI registry) | `ui-ux:shadcn-best-practices` |
| any `*.tsx` / `*.jsx` / `*.vue` / `*.blade.php` in the tree | `a11y:a11y-audit` |

## Data

| Signal | Prime |
|---|---|
| a `migrations/` directory, or any `*.sql` | `sql:sql-best-practices`, `database:database-design` |
| compose file ~ `image: *postgres*` | `postgresql:postgresql-best-practices` |
| compose file ~ `image: *mysql*` | `mysql:mysql-best-practices` |
| compose file ~ `image: *mariadb*` | `mariadb:mariadb-best-practices` |

Engine detection mirrors `rules.tsv`'s chain and inherits its stated misses — compose
image first, because it is the one signal that separates MySQL from MariaDB cleanly.

## Infrastructure and cross-cutting

| Signal | Prime |
|---|---|
| `Dockerfile*` or a compose file | `dev-env:docker-best-practices` |
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
