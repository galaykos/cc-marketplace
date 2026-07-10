---
name: vue2-best-practices
description: Use when writing or reviewing Vue 2.7 code — Composition API backport usage, defineProperty reactivity caveats (array index/object property assignment), Vue.set, mixins vs composables, Vue 3 migration readiness.
---

## Composition API composables over mixins

Vue 2.7 ships the Composition API built in (`setup()`, `ref`, `reactive`, `computed`,
`watch`) — no `@vue/composition-api` plugin needed. Prefer composables over mixins for
shared logic. Mixins merge into the component's own namespace, so two mixins (or a mixin
and the component) can silently clash on a property name, and `this.foo` gives no clue
whether `foo` came from the component or from which mixin. Composables return an explicit
object, so call sites see exactly where each value comes from.

```js
// Bad: mixin — silent merge, unclear property origin
const paginationMixin = {
  data() { return { page: 1 }; },
  methods: { nextPage() { this.page++; } },
};
export default { mixins: [paginationMixin] }; // where does `page` come from?

// Good: composable — explicit source, no namespace collision
function usePagination() {
  const page = ref(1);
  function nextPage() { page.value++; }
  return { page, nextPage };
}
export default { setup() { return usePagination(); } };
```

## Reactivity caveats: Object.defineProperty limits

Vue 2's reactivity (Options API `data()`, and `reactive()`/`ref()` under the hood) walks an
object's existing keys at creation time and converts each to a getter/setter via
`Object.defineProperty`. Properties that don't exist yet, and array indices, are invisible
to that walk, so assigning them doesn't trigger the setter and the view doesn't update.

- `this.obj.newProp = x` is **not reactive** if `newProp` wasn't present on `obj` when it
  was returned from `data()`.
- `this.arr[i] = x` (index assignment) and `this.arr.length = n` are **not reactive**.

Fix with `Vue.set` / `this.$set`, the patched array mutation methods (`push`, `splice`,
`pop`, `shift`, `unshift`, `sort`, `reverse`), or by replacing the whole object/array so a
new reference triggers the parent-level setter.

```js
// Bad: newProp didn't exist at data() time — not reactive
this.user.newProp = 'x';
// Good
this.$set(this.user, 'newProp', 'x');
// Good: replace the object so the reference itself changes
this.user = { ...this.user, newProp: 'x' };

// Bad: index assignment — not reactive
this.items[0] = updated;
// Good: splice is a patched array method
this.items.splice(0, 1, updated);
```

Vue 3's proxy-based reactivity has no such caveat — index and new-property assignment are
reactive there, so `Vue.set`-only code is a signal of Vue-2-specific logic to simplify
during migration.

## `.sync` modifier and `$listeners`

`.sync` is sugar for a prop plus an `update:prop` event; `$listeners` bundles all
non-native listeners a parent attached, useful for a wrapper that forwards events it
doesn't itself declare.

```html
<!-- Bad: manual prop + event wiring for a two-way binding -->
<Child :title="title" @update:title="title = $event" />
<!-- Good: .sync sugar; child emits update:title -->
<Child :title.sync="title" />
<input v-bind="$attrs" v-on="$listeners" />
```

Vue 3 merges attrs and listener fallthrough into `$attrs` (so `$listeners` is removed) and
replaces `.sync` with `v-model:propName`. Keep `.sync`/`$listeners` usage localized to as
few components as possible so migration touches minimal surface.

## Filters are deprecated — use methods or computed

Filters (`{{ value | filterName }}`) were removed in Vue 3. Prefer a computed property or
method even on 2.7: ordinary JavaScript, debuggable and testable, no special syntax.

```html
<!-- Bad: filter — removed in Vue 3 -->
{{ price | currency }}
<!-- Good: computed for reactive state, method when it needs an argument -->
{{ formattedPrice }} / {{ formatCurrency(price) }}
```

## Write forward-compatible code for the Vue 3 migration

Vue 2 is end-of-life (final release; extended support ended December 31, 2023). New code
should avoid patterns removed outright in Vue 3 so migration is mechanical, not a rewrite:

- **Avoid `this.$children`** — removed in Vue 3; it encouraged reaching into child
  internals instead of props/emits or provide/inject.
- **Avoid the event-bus pattern** (a shared empty Vue instance for cross-component
  `$on`/`$off`/`$emit`). Instance `$on`/`$off`/`$once` are removed in Vue 3; use a small
  pub/sub utility (e.g. `mitt`), or props/emits and provide/inject.
- **Prefer the Composition API** for non-trivial components — it maps directly onto Vue 3
  and avoids `this`-binding ambiguity in Options API mixins.
- **Use `provide`/`inject`** for deeply passed values instead of `$parent`/`$root` chains.
- **Declare explicit `props` and `emits`** — an explicit `emits` list documents the
  component's contract and lets Vue validate it.

```js
// Bad: event bus — $on/$off removed on instances in Vue 3
export const eventBus = new Vue();
eventBus.$on('refresh', handler);

// Good: plug-in pub/sub, works unchanged after migration
import mitt from 'mitt';
export const emitter = mitt();
emitter.on('refresh', handler);

// Bad: reaching into a child instance directly
this.$children[0].someMethod();
// Good: explicit contract via ref
this.$refs.child.someMethod();
```

## Common mistakes

- Assigning a new object property or array index directly and expecting the template to
  update (see reactivity caveats above).
- Reaching for a mixin when a composable would make the data source explicit.
- Leaving filters in templates instead of migrating them to computed/methods.
- Using `this.$children` or `$parent`/`$root` chains to reach into other components.
- Wiring a global event bus instead of props/emits or provide/inject.
- Mutating a prop directly instead of emitting an update — breaks one-way data flow and
  Vue warns at runtime.
- Assuming `@vue/composition-api` is required on 2.7 — it's built in, and installing the
  plugin alongside the built-in version can conflict.

## Verify Against Current Docs

Vue 2 has been end-of-life since December 31, 2023 — no further bug fixes or security
patches ship for it, so pin the documentation version you consult and treat any new
project on Vue 2 as a migration candidate. Before relying on memory for API details, check
https://v2.vuejs.org and confirm behavior against the actual Vue version in
`package.json`, since 2.6 vs 2.7 differ on Composition API availability.
