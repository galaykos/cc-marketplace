# typescript

TypeScript best practices: strict mode as the floor, `any` vs `unknown`
discipline, narrowing over assertions, generics restraint, `satisfies`, runtime
validation at boundaries, tsconfig hygiene.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install typescript@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/typescript:review [files-or-diff]` | Review TS code against the skill, pinned to the locked typescript version and the project's tsconfig |

## Example

```bash
/typescript:review src/composables/useOrders.ts
/typescript:review         # reviews the current diff
```

Advice is version-aware: `satisfies` is only suggested on 4.9+, const type
parameters on 5.0+, inferred type predicates on 5.5+ — resolved from the
lockfile, never assumed.

## Pairs well with

- **react / vue3** — framework review plugins; this one covers the type layer they skip
- **stack-scan** — supplies the locked compiler version the advice pins against
