---
name: observability-design
description: Use when writing or reviewing code that emits telemetry — logging, metrics, tracing, health checks, alerting, error reporting — to design structured, correlated, bounded observability signals instead of print-statement archaeology at incident time.
---

## Core rule

You cannot fix what you cannot see. Every production incident is
resolved at the speed of the telemetry the code bothered to emit — the
log line written at 2pm decides the length of the 3am incident. Design
each signal at write time, deliberately: what gets logged, what gets
counted, what gets traced, and what the health endpoint actually checks.

## Structured logging

Emit machine-parseable JSON at service boundaries — fields, not prose.
`grep` finds a sentence on a good day; a query finds a field every day.

- One event per line. Stack traces go inside a field, not splattered
  across the stream where the aggregator shreds them into orphans.
- Attach a correlation/request ID to every event and propagate it
  across every outbound call, queue message, and background job. A
  request that crosses three services under three different IDs is
  three unrelated mysteries instead of one story.
- Log at boundaries and decision points — request in/out, external
  call made or failed, state changed — not every function entry.

When NOT: a CLI tool for humans, local dev output, a 50-line script —
human-readable text is fine there. JSON earns its ugliness where an
aggregator consumes it.

## Log levels with semantics

Levels are a contract, not decoration:

- error — a human must act. If nobody would act on it, it is not an
  error; downgrade it before the channel drowns in false alarms.
- warn — degraded but handled: fallback fired, retry succeeded,
  deprecated path used. The system coped; the trend is worth watching.
- info — an auditable state change: order placed, job finished, config
  reloaded. Someone reconstructing the day reads these.
- debug — development diagnostics; off in production, or the logging
  bill starts competing with the compute bill.

No log-and-rethrow. Handle an exception (log it, act, swallow
deliberately) or propagate it untouched — never both. Double reporting
makes one failure look like five and buries the real count.

## Log hygiene

- No secrets, tokens, passwords, or PII in log lines. Logs outlive
  databases, get shipped to third parties, and rarely honor deletion
  requests. Redact at the logging seam, not by hoping every call site
  remembers.
- Bound payload sizes. Logging the whole request body works until a
  10MB upload turns every log line into a 10MB log line.
- No logging inside hot loops. One log call per item at a million
  items a minute is a performance incident wearing an observability
  costume. Log the aggregate: count, duration, worst offender.

## Metrics

RED for services — rate, errors, duration of requests. USE for
resources — utilization, saturation, errors of pools, queues, disks.
Between them they answer "is it broken, and where" before any log is
opened.

Cardinality is the trap. Every distinct label value is a new time
series; an unbounded value is a slow-motion OOM for the backend:

    status_code, region, endpoint   -> fine, bounded sets
    user_id, request_id, email      -> cardinality bomb

Per-user detail belongs in logs and traces, which are built for high
cardinality. Metrics are for aggregates.

When NOT: do not wrap every internal function in histograms —
instrument the boundaries first, add interior metrics only where a
real question needs answering.

## Tracing

A trace is the correlation ID grown up: spans with timing, one per
hop. Open a span at every process boundary — inbound request, outbound
call, queue consume — and propagate trace context (W3C traceparent or
the platform equivalent) in headers and message metadata. A trace that
dies at the queue answers half the question.

When NOT: a single-service monolith gets most of the value from
correlation IDs alone; distributed tracing pays rent once requests
actually distribute.

## Alerting

Alert on symptoms, not causes: SLO breach, error-rate spike, latency
over budget — the user-visible facts. Cause-based alerts (CPU high,
disk 80%, pod restarted) page when nothing is wrong and sleep through
novel failures.

Every alert must be actionable — a named responder, a plausible
action, a real consequence of ignoring it. An alert nobody acts on is
noise that trains the team to ignore the one that matters; delete it
or demote it to a dashboard panel.

## Health checks

Two endpoints, two questions:

- Liveness: "should this process be restarted?" Checks the process
  itself — event loop responsive, not deadlocked. Never check
  dependencies here: a database blip becomes a restart storm.
- Readiness: "should traffic be routed here?" Checks what serving
  actually requires — DB reachable, cache warm, migrations applied.

An unconditional 200 is a health check in name only: it certifies the
web server can write bytes while every real request fails behind it.

## Worked micro-example: checkout request

    request in   -> info event, request_id minted, span opened
    call payment -> child span; traceparent + request_id propagated
    payment slow -> warn {request_id, latency_ms}; fallback counter
                    incremented
    order placed -> info {request_id, order_id, total_cents};
                    card PAN never logged
    metrics      -> http_requests_total{endpoint,status} + latency
                    histogram; no user_id label
    readiness    -> checks DB and payment config; liveness does not

## Boundaries

- Deploy-pipeline and infra observability — node metrics, ingress
  logs, pipeline dashboards — belong to the devops plugin. This skill
  owns what application code emits.
- Designing the failure paths that telemetry reports on is
  the `cmd-resilience-review` skill territory; this skill makes those paths visible.
- Secrets handling beyond keep-it-out-of-logs goes to the `cmd-security-review` skill.

## Anti-patterns

- printf archaeology — unstructured prose queried with grep and hope.
- Correlation IDs minted but never propagated — every service its own
  island.
- error-level everything — the log level that cried wolf.
- Silent catch blocks — an exception swallowed with no log, metric, or
  span event; the incident with no evidence.
- user_id as a metric label — the dashboard that OOMed the monitoring
  stack.
- The unconditional-200 health check — green while everything burns.
