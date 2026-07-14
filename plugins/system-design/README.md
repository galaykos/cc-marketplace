# system-design

System-level design: service boundaries drawn on data ownership, scaling paths,
cache placement, sync vs async integration and its failure modes, single points
of failure, plus domain modeling (bounded contexts, aggregates, ubiquitous
language). Ships the `system-design` and `domain-modeling` skills, a review
command, and a `system-architect` worker + `system-design-reviewer` read-only
pair. Complements code-architecture (code-level structure) without overlapping
it.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install system-design@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/system-design:review [design-doc-path-or-service-dir]` | Review a system design, RFC, or existing topology against system-design and domain-modeling |

## Example

```bash
/system-design:review docs/rfc/order-service.md
/system-design:review        # no args: maps the current system from the repo
```

The `system-architect` agent handles system-level design work proactively;
`system-design-reviewer` is its read-only counterpart, returning
severity-ranked findings on boundaries, data ownership, scaling, caching
placement, async failure modes, and domain-model integrity.

## Pairs well with

- **code-architecture** — the code-level structure layer this plugin explicitly stops short of
- **database** — engine-agnostic schema and migration review for the data each service owns
- **event-driven** — delivery semantics, idempotency, and saga review for the async integrations
- **resilience** — failure-mode gaps (timeouts, retries, degradation) in the resulting topology
