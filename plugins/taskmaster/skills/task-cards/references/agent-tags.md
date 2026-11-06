# Agent capability tags

Every card emits one `<agent>` tag from the closed list below (legacy cards'
`**Agent:**` too). `scripts/card-shape-lint.sh` reads THIS fenced list at run time to gate
the value: the single copy. The tag routes by **aptitude, not authority** (all workers
equally privileged). Sync it with **both** task-runner maps,
`skills/task-execution/references/routing.md` and `reviewer-routing.md`;
`scripts/validate.sh` checks each, failing per map.

## Closed vocabulary

```
database  frontend  ui-ux  backend  api  security
testing  devops  performance  observability  asset  generic
```

## Derivation rule

From touched files (agent-graded):

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
| its own run calls a generation or modelling tool (Meshy, Higgsfield, Blender; CLI/MCP) or creates .glb .gltf .blend .fbx .obj .usdz .stl files | `asset` |

## Tie-breakers

- **Styling vs component (`ui-ux` vs `frontend`):** *only* styling/design-token/layout
  files → `ui-ux`; any component/logic file, **even with style changes** → `frontend`.
- **Asset vs api / generic:** a card whose own run calls such a tool is `asset`, as
  is a script whose only job is that asset; server code calling one at runtime keeps
  `api`/`backend`. Importing or testing an existing asset is not `asset`
  (a Godot import test → `testing`).
- **Single-domain rule:** a specialist tag only when **all touched files share one
  domain**; files spanning domains (or matching no row) → `generic`.
- Always emit the field; the runner logs and normalizes a missing or unknown value to
  `generic`.
