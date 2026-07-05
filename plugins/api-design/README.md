# api-design

REST API design: resource naming, status-code discipline, pagination/filtering/
sorting conventions, versioning strategy, RFC 9457 error format, idempotency,
Laravel API Resources.

Designing your own API. For *consuming* third-party APIs, see the sibling
`api-docs-first` plugin.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install api-design@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/api-design:review [routes-controllers-or-spec]` | Review route files, controllers, FormRequests, API Resources, or an OpenAPI spec against the skill |

## Example

```bash
/api-design:review routes/api.php app/Http/Resources/
/api-design:review openapi.yaml
```

Uncertain semantics are verified against RFC 9110/9457 rather than answered
from memory; the small honest status-code set beats creative 200-with-error
responses every time.

For endpoints that don't exist yet, the skill renders a **contract preview** —
a live HTML page with every proposed endpoint, real example request/response
payloads, and problem+json error bodies — approved before implementation and
reused as the fixture source for tests.

## Pairs well with

- **sql** — its keyset-pagination rule backs this plugin's cursor-pagination advice
- **laravel** — apiResource routes, FormRequest → 422 shape, policies → 403
