# dev-env

Dev environment initiator: scan composer/npm manifests, lockfiles, `.env` DSNs,
and CI images, then generate a `docker-compose.yml` and `Dockerfile` matched to
the actual stack — PHP version and extensions, Node, database engine, Redis,
queues, mail.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install dev-env@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/dev-env:init` | Scan the project, propose a service plan, generate compose + Dockerfile, then boot and smoke-test it |
| `/dev-env:review [docker-files]` | Audit existing Dockerfile / compose files against docker best practices |

## Example

```bash
/dev-env:init
```

The generator works evidence-first: PHP version from `composer.json`
(`config.platform.php` beats the `require` floor), extensions from `ext-*`
requires, the database engine from `.env` DSNs and CI images — every choice
cites its source, guesses are marked ASSUMED. It never overwrites an existing
`docker-compose.yml` or `Dockerfile` without showing a diff first, and it isn't
done until `docker compose up -d --wait` plus a smoke check actually pass.

## Pairs well with

- **stack-scan** — when installed, `/dev-env:init` reuses its inventory instead of re-scanning
- **laravel / mysql / postgresql** — the services it wires up are the ones those plugins review
