# vue2

Vue 2.7 best practices: Composition API backport (composables over mixins),
`Object.defineProperty` reactivity caveats and `Vue.set`, `.sync` and
`$listeners`, deprecated filters, and writing forward-compatible code for the
Vue 3 migration.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install vue2@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/vue2:review [files-or-diff]` | Review single-file components against the skill, pinned to the installed Vue 2.7 version from the lockfile |

## Example

```bash
/vue2:review src/components/OrderList.vue
/vue2:review         # reviews the current diff
```

Advice pins to the installed Vue 2.x version, so Composition API backport
guidance matches what 2.7 actually ships.

## Pairs well with

- **vue3** — the migration target this skill writes forward-compatible code toward
- **typescript** — the type layer this component review skips
