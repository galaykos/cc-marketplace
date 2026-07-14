# node-backend

Server-side Node.js best practices for Express 5, NestJS 11, and Fastify 5:
middleware vs DI vs plugin-encapsulation architecture, async error propagation,
validation at the boundary (zod, class-validator, JSON Schema), streaming and
backpressure, graceful shutdown, config/env discipline, and per-framework
footguns.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install node-backend@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/node-backend:review [files-or-diff]` | Review server-side Node code against the skill, pinned to the installed framework and version from the lockfile |

## Example

```bash
/node-backend:review src/routes/orders.ts src/plugins/auth.ts
/node-backend:review         # reviews the current diff
```

Advice pins to the installed framework (express / @nestjs/* / fastify) and its
major version from the lockfile, so guidance matches the APIs your release
actually ships.

## Pairs well with

- **javascript / typescript** — the language layer underneath these frameworks
- **api-design** — REST contract shape for the routes these frameworks serve
- **sql / database** — the queries and connection pools under the handlers
- **security** — auth flows and OWASP review on top of boundary validation
