# performance

Performance tuning with measure-first discipline: N+1/index/payload/bundle/Core
Web Vitals hotspots, cache correctness (stampede, TTL, eviction, staleness), and
percentile load testing. Ships the `performance-tuning` skill, a
`/performance:review` command, and a `performance-engineer` worker agent that
optimizes only what a measurement proves slow.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install performance@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/performance:review [path-diff-or-endpoint]` | Review code or a change for performance hotspots and cache-correctness gaps against the `performance-tuning` skill |

## Example

```bash
/performance:review app/Services/ReportBuilder.php
/performance:review         # reviews recent changes (diff against merge base)
```

The review is static — each finding is a single line, marked **measured** when
a real number backs it or **suspected** with the measurement that would confirm
it. When findings exist you pick apply now, measure first, or report only. The
`performance-engineer` agent does the hands-on work — profiling, bundle size,
caching, Core Web Vitals, N+1 queries, load testing — and never ships an
optimization without a before/after measurement.

## Pairs well with

- **sql** — SQL statement and index idioms the review defers to instead of duplicating
- **database** — schema, index, and pooling design underneath query hotspots
- **observability** — the telemetry that turns suspected findings into measured ones
- **task-runner** — the apply-now path hands findings to its executor when installed
