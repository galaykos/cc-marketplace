# observability

Application observability with judgment: structured JSON logs with correlation
IDs, log levels that mean something, RED/USE metrics without cardinality bombs,
trace-context propagation, symptom-based alerting, and honest health checks.
Ships the `observability-design` skill, an `/observability:review` audit
command, and an `observability-engineer` worker agent that adds the
instrumentation (deferring infra-layer wiring to devops).

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install observability@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/observability:review [path-diff-or-design-doc]` | Audit code for observability gaps — unstructured logs, missing correlation IDs, secrets in logs, silent catch blocks — one line per finding |

## Example

```bash
/observability:review src/api/
/observability:review        # audits the current diff
```

Findings are report-only; the `observability-engineer` agent can then apply the
fix list as a diff — structured logs, request IDs, RED/USE metrics, trace
spans, health signals — leaving infra-layer wiring to the devops plugin.

## Pairs well with

- **devops** — infra-layer wiring (collectors, dashboards, deploy config) the engineer defers to
- **error-handling** — the catch-block and exception-flow discipline that feeds clean error telemetry
- **resilience** — timeouts, retries, and degradation paths that your alerts should be watching
- **performance** — hotspot and cache review the metrics you emit help you find
