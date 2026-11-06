# Agent capability tags

Every card emits one `<agent>` tag from the closed vocabulary below (legacy cards'
`**Agent:**` too). `scripts/card-shape-lint.sh` reads THIS fenced list at run time to gate
the value: the single copy. The tag routes by **aptitude, not authority** (all workers
equally privileged). Sync it with **both** task-runner maps,
`skills/task-execution/references/routing.md` and `reviewer-routing.md`;
`scripts/validate.sh` checks each and fails per map.

## Closed vocabulary

```
database  frontend  ui-ux  backend  api  security
testing  devops  performance  observability  asset  generic
```

## Derivation rule

Choose it from the files the card touches:

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
| calls a generation or modelling tool (Meshy, Higgsfield, Blender; CLI or MCP) or creates .glb .gltf .blend .fbx .obj .usdz .stl outputs | `asset` |

## Tie-breakers

- **Styling vs component (`ui-ux` vs `frontend`):** a card touching *only*
  styling/design-token/layout files → `ui-ux`; a card touching any component/logic
  file, **even if it also changes styles** → `frontend`.
- **Asset vs api / generic:** a card whose own run calls a generation or modelling tool is
  `asset`, as is a script whose only job is that asset; server code calling it at runtime
  keeps `api`/`backend`.
- **Single-domain rule:** tag a specialist only when **all touched files share one
  domain**. A card whose files span more than one domain (or match no row) → `generic`.
- Always emit the field. The runner normalizes a missing or out-of-vocabulary value to
  `generic` (logged).
