---
name: react-best-practices
description: Use when writing or reviewing React code — hooks rules and dependencies, avoiding unnecessary re-renders, state colocation and lifting, component composition patterns, effect misuse.
---

## Rules of hooks + exhaustive deps

Hooks must run in the same order every render: call them only at the top level of a component or
custom hook, never inside conditionals, loops, or after an early return. React tracks hook state
by call order, not by name, so skipping one shifts every hook after it.

The dependency array of `useEffect`/`useMemo`/`useCallback` must list every reactive value the
callback reads. Hand-editing the array to silence `exhaustive-deps` is how effects go stale: the
closure keeps referencing an old value instead of the current one.

```jsx
// Bad: hook called conditionally — breaks hook order between renders
if (user) useEffect(() => track(user.id), [user.id]);
// Good: hook always runs; the condition lives inside it
useEffect(() => { if (user) track(user.id); }, [user]);

// Bad: `count` read but omitted — effect closes over a stale value
useEffect(() => {
  const id = setInterval(() => setCount(count + 1), 1000);
  return () => clearInterval(id);
}, []);
// Good: updater form removes the stale dependency entirely
useEffect(() => {
  const id = setInterval(() => setCount((c) => c + 1), 1000);
  return () => clearInterval(id);
}, []);
```

## Derive, don't sync — compute during render, not in an effect

If a value can be calculated from existing props/state, calculate it inline during render.
Effects run *after* render and commit, so mirroring one piece of state into another via
`useEffect` costs an extra render pass and is a frequent source of bugs and flicker. Effects
exist to synchronize with something outside React (network, DOM, subscriptions) — not to keep
in-app state in sync with other in-app state.

```jsx
// Bad: redundant state + effect just to derive a value
const [fullName, setFullName] = useState("");
useEffect(() => setFullName(`${first} ${last}`), [first, last]);
// Good: derive it during render — no effect, no extra state
const fullName = `${first} ${last}`;
```

Setting state *during* render is legal only for this derive pattern (or the documented "adjust
state when a prop changes" escape hatch) — never as a general substitute for an event handler.

## Memoization: when it helps, when it's noise

`useMemo`/`useCallback`/`React.memo` trade CPU now (compute + compare) for CPU later (skip a
re-render). They pay off when the computation is genuinely expensive, or the referential identity
feeds a memoized child or a dependency array. `React.memo` does a *shallow* prop comparison — new
object/array/function literals passed as props defeat it unless memoized upstream.

They're noise around cheap calculations or fast components — the bookkeeping cost is paid every
render, but the payoff only exists if profiling shows a re-render was actually slow. Add
memoization after measuring, not by default.

```jsx
// Noise: trivial computation, memo overhead exceeds the work saved
const doubled = useMemo(() => value * 2, [value]);
// Justified: expensive, and its identity feeds a memoized child
const sorted = useMemo(() => bigList.toSorted(cmp), [bigList]);

// Bad: new object literal every render defeats MemoChild's shallow comparison
<MemoChild config={{ mode: "dark" }} />
// Good: stable reference so the shallow comparison actually skips work
const config = useMemo(() => ({ mode: "dark" }), []);
<MemoChild config={config} />
```

## State colocation, lifting, and context boundaries

Keep state as close as possible to where it's used; lift it only when a sibling or ancestor
genuinely needs it — hoisting "just in case" forces the whole subtree to re-render on every
update. Split context by change frequency and readership: one context mixing fast-changing
values (e.g. cursor position) with stable ones (e.g. theme) forces every consumer to re-render
on any change.

```jsx
// Bad: one context mixes fast-changing and stable values
<AppContext.Provider value={{ theme, mousePos, user }}>
// Good: split so consumers only re-render for what they actually use
<ThemeContext.Provider value={theme}>
  <MouseContext.Provider value={mousePos}>{children}</MouseContext.Provider>
</ThemeContext.Provider>
```

## Controlled vs uncontrolled inputs

Pick one model per input for its whole lifetime. Controlled (`value` + `onChange` from state)
gives per-keystroke validation but re-renders on every keystroke. Uncontrolled (`defaultValue` +
refs) skips that cost for large or rarely-validated forms. Never flip an input between the two
across renders — React warns because `value` going from `undefined` to a string mid-lifecycle
breaks the DOM's own input state.

```jsx
// Bad: undefined until data loads, then becomes a string — React warns
<input value={user?.name} onChange={onChange} />
// Good: always a string, controlled from the first render
<input value={user?.name ?? ""} onChange={onChange} />
```

## Composition over prop drilling

When a prop passes through layers that don't use it, restructure with composition (children or
render props) instead of threading it through every intermediate signature — drilling couples
unrelated components to a shape they don't care about.

```jsx
// Bad: Layout doesn't use `user`, but must forward it
<Layout user={user}><Header user={user} /></Layout>
// Good: pass the already-built element down; Layout owns no user-shaped prop
<Layout><Header user={user} /></Layout>
```

## Keys and list identity

Keys must be stable, unique among siblings, and tied to the data — not the array index, unless
the list is static and never reordered/filtered/inserted. An index key makes React match the
wrong previous instance to a new item after a reorder, leaking state (an open accordion, an
input's contents) onto the wrong row.

```jsx
// Bad: index key breaks identity across insertions/removals
{items.map((item, i) => <Row key={i} item={item} />)}
// Good: a stable id ties the key to the actual data
{items.map((item) => <Row key={item.id} item={item} />)}
```

## Common mistakes

- Calling hooks conditionally or after an early return, breaking hook call order.
- Silencing `exhaustive-deps` instead of fixing the closure or restructuring the effect.
- Using an effect to derive state that could be computed directly during render.
- Wrapping every value in `useMemo`/`useCallback` without evidence it changes a render outcome.
- Passing new object/array/function literals into `React.memo` children, defeating the memo.
- One giant context re-rendering every consumer on any field change.
- Switching an input between controlled and uncontrolled across the component's lifetime.
- Using array index as `key` for lists that can reorder, filter, or insert.
- Lifting state to a common ancestor "just in case" instead of colocating it.

## Verify Against Current Docs

Hook semantics, `React.memo`/`useMemo`/`useCallback` guidance, and compiler-driven optimizations
(e.g., the React Compiler auto-memoizing components) have shifted across React versions. Before
relying on memory for version-sensitive APIs, check the current docs: https://react.dev
