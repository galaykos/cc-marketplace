# react

React server-state discipline: choosing and using TanStack Query / SWR /
RTK Query for server caches, cache keys and invalidation, mutations and
optimistic updates, keeping server data out of `useState`/Redux, and avoiding
refetch storms and stale-key bugs. The `react-server-state` skill fires on
`.tsx`/`.jsx` edits (via skill-router) and by description whenever React data
fetching is in play.

General React idioms — hooks rules, memoization, composition, list keys — were
removed from this plugin after baseline tests showed the model reviews them at
full strength unaided (the skill actually narrowed review coverage). Evidence:
`rationale/stack-skill-baselines.md`. Server-state remains because it encodes a
library-choice discipline, not idioms.

## Skills

| Skill | Use when |
|-------|----------|
| `react-server-state` | Fetching, caching, or synchronizing server data — TanStack Query / SWR / RTK Query, cache keys and invalidation, mutations, paginated and infinite data |
| `react-data-grid` | Building or reviewing data tables/grids — TanStack Table matched to the installed major (v8 vs v9), server-side data, row selection identity, TanStack Virtual, shadcn DataTable composition |

`react-data-grid` extends the same charter: which library, which major, and how
its state model composes with TanStack Query — not table idioms.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install react@cc-plugins-marketplace
```

## Pairs well with

- **web-dev** — the frontend-reviewer agent consults react-server-state on data-fetching diffs
- **ui-ux** — styling and accessibility review for the markup these components render
- **inertia** — bridge-level review when React is your Inertia adapter
