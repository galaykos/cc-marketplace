# react

React best practices: rules of hooks and exhaustive deps, deriving state instead
of syncing it in effects, memoization that helps vs noise, state colocation and
context boundaries, controlled vs uncontrolled inputs, composition over prop
drilling, and list keys.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install react@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/react:review [files-or-diff]` | Review components and hooks against the skill, pinned to the installed React version from the lockfile |

## Example

```bash
/react:review src/components/OrderList.jsx src/hooks/useOrders.tsx
/react:review         # reviews the current diff
```

Advice pins to the installed React version, so guidance matches the APIs your
release actually ships.

## Pairs well with

- **typescript** — the type layer this component review skips
- **ui-ux** — styling and accessibility review for the markup these components render
- **inertia** — bridge-level review when React is your Inertia adapter
