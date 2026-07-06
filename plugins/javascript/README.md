# javascript

Vanilla JavaScript best practices: version-aware ES feature floors, strict
equality and coercion traps, ESM vs CommonJS interop, async correctness and the
event loop, `this`-binding and closures, immutability, error handling, boundary
validation, number precision, security at boundaries.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install javascript@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/javascript:review [files-or-diff]` | Review plain JS against the skill, pinned to the project's Node/ES floor from `engines`/`browserslist`/lockfile |

## Example

```bash
/javascript:review src/lib/orders.js
/javascript:review         # reviews the current diff
```

Advice is version-aware: optional chaining and `??` only on an ES2020+ floor,
`.at()` and `Object.hasOwn` on ES2022+, the immutable `toSorted`/`with` methods
on ES2023+, `structuredClone` on Node 17+ — resolved from `engines`,
`browserslist`, and the lockfile, never assumed.

## Pairs well with

- **typescript** — the type layer this skips; add it when the project has a `tsconfig`
- **react / vue3** — framework review plugins; this one covers the plain-JS layer they skip
- **stack-scan** — supplies the Node/browser floor the advice pins against
