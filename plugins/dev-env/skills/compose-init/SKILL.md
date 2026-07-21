---
name: compose-init
description: Use when generating a docker-compose.yml and Dockerfile to run a project locally — derive every service and image tag from evidence (composer.json config.platform/require floors, ext-* requires, engines/.nvmrc, .env DSNs, CI images), pin exact minor tags, wire healthchecks and volumes, then boot and verify. Consumes the stack-scan inventory when that plugin is installed.
---

## Evidence before generation

Every service, image tag, and extension in the generated files traces to a
file in the repo. The doctrine is inherited from stack-scan: lock beats
manifest, runtime beats lock — a compose file written from memory is fiction
with YAML syntax. Cite the source for every choice in the proposal
(`php:8.5-fpm — config.platform.php`), and anything unverifiable gets an
explicit `ASSUMED` marker in the output plus one line saying why.

When the stack-scan plugin is installed, run its installed-versions inventory
first and consume that report instead of re-scanning — map its
`Installed (source)` column straight into image tags and extension lists.

## Version resolution

- **PHP**: `composer.json` `config.platform.php` wins; otherwise the floor of
  `require.php` (`^8.2` means 8.2, not whatever is newest). The lock's
  `platform` block confirms. That number becomes the image minor tag.
- **PHP extensions**: every `ext-*` in `require` becomes a
  `docker-php-ext-install` line (`pecl install` for redis/xdebug/imagick).
  Built-in defaults (json, pdo, ctype) need no line — installing them breaks
  the build. Missing an `ext-*` here is a release-day failure later.
- **Node**: `engines.node`, then `.nvmrc`/`.node-version`/`.tool-versions`,
  then the `packageManager` field for the tool (enable via corepack).
- **Database**: `.env`/`.env.example` `DB_CONNECTION` and DSNs name the
  engine; CI workflow service images or an existing compose name the version;
  `config/database.php` `default` breaks ties. No version anywhere: pin the
  current stable minor and mark it `ASSUMED`.

## Service derivation

Generate a service only when evidence demands it:

| Evidence                                     | Services                                       |
|----------------------------------------------|------------------------------------------------|
| `laravel/framework` locked                   | `app` (php-fpm) + `nginx`                      |
| `laravel/octane` locked                      | single `app` running octane — no nginx         |
| Small API, no fpm need                       | `app` on `php:X.Y-cli` via `artisan serve`     |
| `QUEUE_CONNECTION=redis` / horizon locked    | `redis` + `worker` (same image, `queue:work`)  |
| `CACHE_STORE`/`SESSION_DRIVER` = redis       | `redis` (shared with queue)                    |
| `MAIL_MAILER=smtp` at a local host           | `mailpit` (SMTP 1025, UI 8025)                 |
| `FILESYSTEM_DISK=s3` + local endpoint in env | `minio` — only if code points at it            |
| `vite` in devDependencies                    | `node` service, or a note to run Vite on host (HMR is simpler there) |

A production S3 bucket in .env is NOT evidence for minio. `QUEUE_CONNECTION=sync`
is NOT evidence for a worker. When in doubt, leave the service out and say so.

## Diagram before YAML

A service table reads as a list; topology mistakes hide in lists. Alongside
the service-plan table, render the proposed stack as a diagram — inline SVG in
one self-contained HTML (boxes per service with pinned image tag and source
citation; arrows for connections with ports; volume cylinders on stateful
services) — served on the live preview pattern (port `${PREVIEW_PORT:-8123}`, `diagram.html`,
auto-reload — see taskmaster's visual-decisions skill) or opened via `file://`. "Why is there a
minio box?" asked at the picture costs nothing; asked after generation it
costs a regeneration round. ASCII boxes in chat are an acceptable fallback
for 3 services or fewer.

## Image pinning

Exact minor tags, always: `php:8.5-fpm`, `mysql:9.7`, `postgres:18.4`,
`redis:8.8-alpine`, `node:24.13-alpine`. Never `latest`, never a bare major —
both change under you on the next pull. When CI or a production Dockerfile
reveals the version actually deployed, match it exactly: local/prod version
skew is the bug class this skill exists to kill.

## Compose shape

- Healthchecks on stateful services, and dependents gate on them:
  `mysqladmin ping` / `pg_isready` / `redis-cli ping`, consumed via
  `depends_on: { db: { condition: service_healthy } }`. Bare `depends_on`
  orders startup, not readiness — migrations race the DB without this.
- Named volumes for data (`dbdata:/var/lib/mysql`); bind mount only the code.
  On macOS bind mounts are slow — note it, and keep `vendor/`/`node_modules`
  in a container-local volume when the project is large.
- `env_file: .env` wires app config; compose `environment:` only for the
  container-specific overrides (`DB_HOST=db`, `REDIS_HOST=redis`).
- Host ports that avoid the common defaults if something already squats on
  them; document that personal port changes go in `compose.override.yml`
  (gitignored), never edits to the committed file.

## Dockerfile: dev and prod are targets, not copies

One multi-stage file when a Dockerfile is needed at all:

- `base`: pinned image, system packages, the derived
  `docker-php-ext-install` list, workdir.
- `dev` target: xdebug via pecl (default `XDEBUG_MODE=off`), composer install
  WITH dev deps using `--mount=type=cache,target=/root/.composer`, and a
  non-root user created from `UID`/`GID` build args matching the host user —
  root-owned files appearing in the bind mount is the top dev-container
  complaint, solve it up front.
- `prod` target: `--no-dev` install, opcache on, no xdebug, source `COPY`d
  not mounted. Compose builds `target: dev`; prod exists for parity but this
  skill does not deploy it.

## Verification protocol

Generated-but-unbooted is not done. Run, in order:

```
docker compose config -q                        # syntax + interpolation
docker compose up -d --wait                     # healthchecks actually pass
docker compose exec app php artisan migrate     # DB reachable, creds right
curl -fsS http://localhost:<port>/              # the app answers
```

On any failure read `docker compose logs <service>`, fix, re-run from the
failed step. Report each command with its actual result — never "should work".

## What NOT to generate

- Services nothing references: no elasticsearch "just in case", no minio for
  a production-only bucket, no worker for a sync queue.
- Production concerns: TLS termination, orchestrator manifests, replicas,
  logging drivers. This is a dev environment, not a deployment.
- A replacement for a working setup: if compose/Dockerfile already exist,
  audit them (docker-best-practices skill) and propose diffs — never
  overwrite without showing the diff and getting an explicit yes.

## Anti-patterns

- `latest` or major-only image tags — rebuilds silently change versions.
- Guessing extensions from framework docs instead of the `ext-*` requires.
- Bare `depends_on` without health conditions, then shrugging at flaky boots.
- Copying .env values into committed `environment:` blocks — secrets in YAML.
- Declaring done when `docker compose config -q` passes without booting.
- Re-scanning the repo when a stack-scan inventory from this session exists.
