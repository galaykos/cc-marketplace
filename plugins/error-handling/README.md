# error-handling

Language-agnostic error-handling discipline: crash on programmer errors, handle
operational errors where you can act, typed errors over message-string matching,
cause chains preserved across boundaries, one report per failure — no swallowed
exceptions, no catch-log-continue towers.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install error-handling@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/error-handling:review [path-diff-or-design-doc]` | Audit error handling — empty or over-broad catches, swallowed exceptions, message-string branching, missing cause chains, internals leaking to users — one line per finding |

## Example

```bash
/error-handling:review src/services/PaymentService.ts
/error-handling:review          # reviews the current diff
```

The review applies the bundled `error-handling-design` skill's rubric — bug vs
event triage, catch placement, rethrow and cause chains — and reports findings
sorted by severity with a concrete fix each.

## Pairs well with

- **resilience** — timeouts, retries, and degradation paths around the errors this plugin disciplines
- **observability** — structured logging and correlation for the failures you do report
- **concurrency** — races and retry-idempotency hazards that often hide behind broad catches
- **debugging** — systematic root-cause work when a reported error actually fires
