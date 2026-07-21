---
name: docker-best-practices
description: Use when writing or auditing Dockerfiles and compose files — layer caching order, .dockerignore hygiene, multi-stage builds, exact base tags with alpine/slim trade-offs, non-root USER, HEALTHCHECK, secrets kept out of layers and build args, PID 1 signal handling, compose profiles, dev resource limits, EOL base images treated as vulnerabilities. CI/CD pipelines and production deployment belong to the devops plugin.
---

## Layer order is cache strategy

Docker rebuilds every layer after the first changed one. Order instructions
from least to most volatile: base image, system packages, dependency
manifests (`COPY composer.json composer.lock ./` then install), and source
code LAST. `COPY . .` before the install line means every source edit
reinstalls all dependencies — the single most common self-inflicted slow
build. Verify by touching a source file and rebuilding: dependency layers
must report `CACHED`.

## .dockerignore is first-class

No `.dockerignore` means `node_modules/`, `vendor/`, `.git/`, and `.env` all
ship into the build context — slow uploads, cache busts from files that never
mattered, and secrets one `COPY . .` away from a layer. Minimum entries:
`.git`, `node_modules`, `vendor`, `.env*` (allow `.env.example`), build
output dirs, and the compose/docker files themselves. An audit that finds a
`COPY . .` with no `.dockerignore` has found a finding, full stop.

## Multi-stage builds

Build tools do not belong in the runtime image. Compile/install in a builder
stage, `COPY --from=builder` only artifacts into a slim final stage. For dev
vs prod, prefer named targets in one file (`target: dev` in compose) over two
drifting Dockerfiles. Each stage `FROM` a pinned tag — stages inherit no
pinning from each other.

## Base image choice

Exact minor tags: `php:8.5-fpm`, `node:24-alpine`, `postgres:18`. `latest`
and bare majors make builds nondeterministic. Slim/alpine trade-offs are
real, not aesthetic: alpine is musl, not glibc — native Node modules may need
recompiling or fail silently, PHP extension builds need `apk` package name
translation, and DNS behavior differs under musl. Debian-slim costs tens of
MB more and dodges the whole category; choose alpine deliberately, not by
default. Match the image family that production uses.

## Non-root USER

Final stages end with a `USER` that is not root — a container escape from
root is a host problem. Create the user with explicit UID/GID; for dev
targets accept `UID`/`GID` build args matching the host user so bind-mounted
files are not root-owned on the host. Files that must be writable get
`chown` at build time, not `chmod 777` at runtime.

## HEALTHCHECK

Stateful services define health: `mysqladmin ping`, `pg_isready`,
`redis-cli ping`, or an app-level endpoint hit with `curl -f`. Compose
dependents consume it via `depends_on: { condition: service_healthy }` —
without the condition, `depends_on` is startup ordering, not readiness, and
"works on second try" is the symptom. Health intervals belong in seconds, not
the 30s default, for dev boot speed.

## Secrets never land in layers

`ARG TOKEN` then `RUN` using it leaks: build args persist in `docker history`
and intermediate layers even when the final stage drops them. So does a
`COPY .env`. Correct channels: BuildKit `--mount=type=secret` for build-time
credentials, runtime `env_file`/environment for app config, and nothing
secret in the image at all when avoidable. Audit check:
`docker history --no-trunc` on the built image grep'd for anything
credential-shaped.

## One process per container

A container runs one process; supervisord bundling fpm + nginx + cron in one
image hides crashes from the orchestrator and the `restart:` policy. Split
into services; the worker is the same image as the app with a different
command. Exception threshold: high — s6/supervisord needs a written reason.

## PID 1 and signals

PID 1 does not get default signal handlers: a shell-form `CMD` wraps the app
in `sh`, which swallows SIGTERM, so every stop waits out the 10s kill
timeout. Exec-form `CMD ["php-fpm"]` always; add `init: true` in compose (or
tini) when the process forks children that need reaping. If `docker compose
stop` takes 10 seconds, signals are broken — that is a test, run it.

## Compose profiles for optional services

Services not needed every boot (minio, mailpit, admin UIs, one-off seeders)
get `profiles: ["extras"]` so `docker compose up` stays lean and
`--profile extras` opts in. Personal port remaps and resource tweaks live in
`compose.override.yml`, gitignored — the committed file is the contract.

## Resource limits for dev sanity

An unbounded MySQL or Elasticsearch will happily eat the laptop.
`mem_limit`/`cpus` (or `deploy.resources.limits`) on the known hogs keeps
`docker compose up` from freezing the host. Dev-tune the loud ones: disable
ES swap, cap innodb buffer pool — defaults assume a server, not a laptop
sharing RAM with an IDE.

## EOL base images are vulnerabilities

A base image past end-of-life receives no security patches: `php:8.0-*`,
`node:16-*`, `debian:buster` are findings regardless of how well the rest of
the file is written. Check tags against endoflife.date rather than memory
when it matters, and flag anything within six months of EOL as
"upgrade-now". Same rule for pinned DB majors in compose.

## Anti-patterns

- `COPY . .` before dependency install — cache death by layer order.
- No `.dockerignore`, or one missing `.git`/`.env`/`node_modules`.
- `latest`/major-only tags, or dev and prod built from different files that
  have already drifted.
- Root as the final `USER`; `chmod -R 777` as a permissions strategy.
- Secrets via `ARG`/`ENV`/`COPY .env` — visible in `docker history`.
- Shell-form `CMD`, no init, 10-second stops accepted as normal.
- `depends_on` without `service_healthy`, retry loops in app code as a fix.
- Alpine chosen by reflex, then hours lost to a musl-only native-module bug.
