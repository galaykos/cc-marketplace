---
name: vue3-best-practices
description: Use when writing or reviewing Vue 3 code — script setup, composables design, ref vs reactive pitfalls, destructuring reactivity loss, watch vs watchEffect, Pinia stores.
---

> Last verified: 2026-08-12 — https://github.com/vuejs/core/releases

## Know the version before advising

- The locked `vue` entry (package-lock.json / pnpm-lock.yaml / yarn.lock / bun.lock)
  decides which rules apply — a `^3.4` constraint can resolve anywhere in 3.x; only the
  lock says whether 3.5 semantics are safe to advise.
- **3.4** — `defineModel` stable for two-way component binding.
- **3.5** (current stable line, 3.5.41 as of 2026-08) — reactive props destructure
  compiled and stable; `useTemplateRef`, `useId`; lazy hydration for async components.
- **3.6** (release candidate as of 2026-08 — NOT stable) — Vapor mode: `<script setup
  vapor>` compiles to direct DOM operations, opt-in per file; alien-signals reactivity
  rewrite. Never introduce Vapor unless the project already pins a 3.6 pre-release.

## `<script setup>` as the default authoring style

Prefer `<script setup>` over the Options API and plain `setup()`: top-level bindings are
template-visible automatically, imports need no `components:` entry, and there's no
`return { ... }` boilerplate.

## ref vs reactive — prefer ref

Prefer `ref` for most state, even objects: it's uniform for primitives and objects, survives
whole-value reassignment (`user.value = newUser`), and survives destructuring since access
goes through `.value`. `reactive` only wraps objects/arrays, reassigning the variable orphans
anything still bound to the old proxy, and stops tracking once a property is pulled out. `ref`
auto-unwraps in templates and inside `reactive()`, but not in plain JS — logging a ref logs
the object, not its value.

```js
let state = reactive({ count: 0 });
state = reactive({ count: 1 }); // Bad: detaches anything bound to the old proxy
const state = ref({ count: 0 });
state.value = { count: 1 }; // Good: same reactive connection across reassignment
```

## Destructuring reactive() loses reactivity

Pulling a property off a `reactive()` object copies its current value into a plain
variable — the proxy connection is gone, so later mutations don't update it. This is the
most common Vue 3 reactivity bug, and why `storeToRefs` exists for Pinia (below): a store
is a reactive object, so destructuring its state directly fails the same way.

```js
const state = reactive({ name: 'Ada' });
const { name } = state; // Bad: frozen snapshot, never updates again
const { name } = toRefs(state); // Good: still linked, name.value updates with state.name
```

## Composable conventions

- Name composables `useX` (`useFetch`, `useMousePosition`) — signals the composition
  function contract.
- Return a plain object of refs, not a bare reactive object, so callers can destructure
  without losing reactivity.
- Call composables only at the top level of `setup()`/`<script setup>`, synchronously —
  never in a conditional, loop, or after an `await` — since some register lifecycle hooks
  during setup.

```js
export function useCounter() { return reactive({ count: 0 }); } // Bad: breaks on destructure
export function useCounter() { const count = ref(0); return { count }; } // Good: refs
```

## Props: defineProps and the destructure caveat

Destructuring `defineProps` in plain JS loses reactivity the same way `reactive()` does —
the extracted value is a snapshot, so `watch` on it never fires. Vue 3.5 introduced
**reactive props destructure**, compiling `const { userId } = defineProps(...)` into
reactivity-preserving code — doesn't apply on 3.4 and earlier. Confirm the project's Vue
version; `props.x` or `toRefs(props)` works regardless.

```js
const { userId } = defineProps(['userId']);
watch(userId, () => {}); // Bad: snapshot — never fires
const props = defineProps(['userId']);
watch(() => props.userId, () => {}); // Good: watches the live source
```

## watch vs watchEffect vs computed

- **`computed`** — a value derived purely from other reactive state. Cached, lazy, most
  declarative when there's no side effect.
- **`watch`** — explicit side effects on specific sources (API calls, logging, imperative
  DOM work) needing old/new values or timing control (`immediate`, `deep`, `flush`); the
  dependency is explicit in the call.
- **`watchEffect`** — auto-tracks whatever reactive state the callback reads, runs
  immediately, reruns on any tracked change. Good for intertwined sources, but the trigger
  list isn't visible without reading the body.

```js
const fullName = computed(() => `${first.value} ${last.value}`); // pure derivation
watch(userId, async (id, prev) => { if (id !== prev) user.value = await fetchUser(id); });
watchEffect(() => { document.title = `${page.value} — ${count.value} items`; });
```

## Pinia over Vuex

Prefer Pinia for new stores: officially recommended, full TypeScript inference, no Vuex
mutations layer. Either **option stores** (`state`/`getters`/`actions`) or **setup stores**
(a function using `ref`/`computed`, same shape as a composable) work. A store's state and
getters are reactive — destructuring them directly loses reactivity like `reactive()`; use
`storeToRefs(store)` for linked refs. **Actions are plain functions**, not reactive state —
destructure them directly, since `storeToRefs` doesn't wrap them.

```js
export const useCounterStore = defineStore('counter', () => {
  const count = ref(0);
  return { count, doubled: computed(() => count.value * 2), inc: () => count.value++ };
});

const { count } = useCounterStore(); // Bad: snapshot, doesn't track store updates
const store = useCounterStore();
const { count, doubled } = storeToRefs(store); // Good: linked refs for state/getters
const { inc } = store; // Good: actions are plain functions, destructure directly
```

## provide/inject with InjectionKey typing

Use a typed `InjectionKey<T>` instead of a bare string key, so `inject()` infers the
correct type and a mismatched `provide` is a compile error, not an `undefined` surprise.

```ts
provide('user', currentUser);
const user = inject('user'); // Bad: string key, inject() type is unknown

const UserKey: InjectionKey<Ref<User>> = Symbol('user');
provide(UserKey, currentUser);
const user = inject(UserKey); // Good: typed as Ref<User> | undefined
```

## Common mistakes

- Destructuring a `reactive()` object or Pinia store directly, silently losing reactivity.
- Destructuring `defineProps()` and expecting the result to stay live in a `watch`.
- Reassigning a `reactive()` binding to a new object, detaching the template from it.
- Calling a composable conditionally or after an `await`, breaking lifecycle-hook setup.
- Reaching for `watchEffect` when an explicit `watch` source would be clearer, or `watch`
  when `computed` was all that was needed.
- Using string keys for `provide`/`inject` in TypeScript instead of an `InjectionKey`.
- Assuming reactive props destructure works pre-3.5 without checking the Vue version.
- Advising Vapor mode against a 3.5 lockfile, or treating 3.6 RC features as stable.
