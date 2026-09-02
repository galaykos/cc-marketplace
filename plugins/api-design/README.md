# api-design

APIs in both directions. **Designing your own:** REST resource naming, status-code
discipline, pagination/filtering/sorting conventions, versioning strategy, RFC 9457
error format, idempotency, Laravel API Resources, plus the `graphql-grpc` skill —
GraphQL (N+1/DataLoader, per-field resolver authz, depth/complexity limits, cursor
pagination) and gRPC (proto field-number safety, streaming, deadlines, status codes) —
applied when the surface is non-REST. **Consuming others':** verify current official
API/SDK docs before writing integration code (the `api-docs-first` skill and a
UserPromptSubmit reminder), and keep your own docs true after a change with the
`docs-upkeep` drift scan.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install api-design@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/api-design:review [routes-controllers-or-spec]` | Review route files, controllers, FormRequests, API Resources, or an OpenAPI spec against the skill |
| `/api-design:scaffold [openapi-spec-path]` | Scaffold Laravel routes, FormRequests, API Resources, and controllers from an approved OpenAPI spec (spec-first) |
| `/api-design:check [library-sdk-or-api]` | Check that current API docs back the integration code you are about to write or review: the exact installed version from the lockfile, the docs source located, the symbols/endpoints verified — or asks for a docs URL or file and refuses to write integration code from memory until one is provided |
| `/api-design:drift [path-range-or-repo]` | Scan the current change (or repo) for documentation drift — README claims, changelog gaps, stale examples, dead links — and list exact fixes |

```bash
/api-design:review routes/api.php app/Http/Resources/
/api-design:review openapi.yaml
/api-design:check stripe
/api-design:drift
```

Uncertain semantics are verified against RFC 9110/9457 rather than answered
from memory; the small honest status-code set beats creative 200-with-error
responses every time. For endpoints that don't exist yet, the skill renders a
**contract preview** — a live HTML page with every proposed endpoint, real example
request/response payloads, and problem+json error bodies — approved before
implementation and reused as the fixture source for tests.

## Skills

| Skill | Reach for it when |
|---|---|
| `api-design` | Designing or reviewing your own REST API |
| `graphql-grpc` | The surface is GraphQL or gRPC |
| `api-docs-first` | About to write code that calls an external API, SDK, or library — identify the exact installed version from the lockfile, verify against current official docs, stop and ask for a URL or file when none are accessible |
| `docs-upkeep` | A change altered behavior, interfaces, setup steps, or commands that the docs describe — fix the docs in the same change |

The **UserPromptSubmit hook** watches prompts for integration keywords (sdk,
endpoint, integrate, webhook, oauth, graphql) with a making verb and prints a
one-line reminder to verify docs first. It never blocks the prompt and skips slash
commands.

## Pairs well with

- **database** — its sql skill's keyset-pagination rule backs this plugin's cursor-pagination advice
- **laravel** — apiResource routes, FormRequest → 422 shape, policies → 403
- **security** (api-auth skill) — reviewing the auth model of the API you are integrating
- **stack-scan** — inventories the installed versions the docs check verifies against
- **task-runner** — `/api-design:drift` joins its completion gate when installed
