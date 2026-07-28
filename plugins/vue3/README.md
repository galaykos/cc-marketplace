# vue3

Vue 3 best practices: `<script setup>` as the default, `ref` vs `reactive` and
the destructuring reactivity trap, composable conventions, `defineProps`
caveats, `watch` vs `watchEffect` vs `computed`, Pinia over Vuex, and typed
`provide`/`inject`.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install vue3@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/vue3:review [files-or-diff]` | Review single-file components and composables against the skill, pinned to the installed Vue 3 version from the lockfile |

## Example

```bash
/vue3:review src/components/OrderList.vue
/vue3:review         # reviews the current diff
```

Advice pins to the installed Vue 3 version, so guidance matches the APIs your
release actually ships.

## Pairs well with

- **inertia** — bridge-level review when Vue 3 is your Inertia adapter
- **nuxt** — framework-level review when these components live in a Nuxt app
- **vite** — the build layer under most Vue 3 projects
