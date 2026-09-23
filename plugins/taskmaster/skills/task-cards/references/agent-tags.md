# Agent capability tags

Every card emits `<agent>` with exactly one tag from the closed vocabulary below
(a legacy card carries `**Agent:**`; both are read). `scripts/card-shape-lint.sh`
reads THIS file's fenced list at run time to gate the value, so the list below is
the single copy.
The tag is a routing hint the runner resolves to a specialist worker; it selects
**aptitude, not authority** (all workers are equally privileged). Keep this vocabulary
in sync with **both** resolution maps —
`task-runner/skills/task-execution/references/routing.md` (implement side) and
`.../reviewer-routing.md` (verify side). `scripts/validate.sh` compares this list
against each map separately and fails with a different message per map, so editing
only one of the two goes red in CI even though the other still matches.

## Closed vocabulary

```
database  frontend  ui-ux  backend  api  security
testing  devops  performance  observability  generic
```

## Derivation rule

Choose the tag from the files the card touches:

| Touched files | Tag |
|---|---|
| DB schema, migrations, queries | `database` |
| component / view / client logic (React, Vue, Svelte, …) | `frontend` |
| **styling / design-token / layout files only** | `ui-ux` |
| server business logic / domain services | `backend` |
| server routes, controllers, API handlers | `api` |
| authn / authz / crypto / security headers | `security` |
| test files only | `testing` |
| CI, Dockerfile, k8s, deploy config | `devops` |
| profiling, caching, bundle-size work | `performance` |
| logging, metrics, tracing instrumentation | `observability` |

## Tie-breakers

- **Styling vs component (`ui-ux` vs `frontend`):** a card touching *only*
  styling/design-token/layout files → `ui-ux`; a card touching any component/logic
  file, **even if it also changes styles** → `frontend`.
- **Single-domain rule:** tag a specialist only when **all touched files share one
  domain**. A card whose files span more than one domain (or match no row) → `generic`.
- Always emit the field; never omit it. A missing or out-of-vocabulary value is
  normalized to `generic` by the runner (logged).
