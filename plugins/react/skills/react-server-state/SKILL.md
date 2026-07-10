---
name: react-server-state
description: Use when fetching, caching, or synchronizing server data in React — choosing and using TanStack Query / SWR / RTK Query for server state, keeping it out of client state (useState/Redux), cache keys and invalidation, mutations and optimistic updates, and avoiding refetch storms and stale-key bugs. The dominant modern data concern web-developer says to keep separate but no skill taught how.
---

# React server state

The single most common React data bug is treating **server state** — data that lives on
a backend and is shared, cached, and asynchronously stale — like **client state** —
data your app owns (form inputs, toggles, wizard step). They have opposite rules.
Server state is not owned by your component; it is a cache of someone else's truth, and
that reframing is the whole skill.

## The two kinds of state

- **Client state** — `useState`, `useReducer`, Zustand, Redux for UI you own. Synchronous,
  authoritative, yours.
- **Server state** — data fetched over the network. Asynchronous, shared, can go stale
  under you, needs caching/retry/dedup. Storing it in `useState` + `useEffect` forces you
  to hand-build caching, loading/error tracking, dedup, and invalidation — badly. Use a
  server-cache library instead.

Never mirror fetched data into `useState`; that fork is where staleness bugs breed.

## Pick the tool

| Situation | Reach for |
|---|---|
| Any real server data in React | TanStack Query (React Query) — the default |
| Lighter, simpler needs | SWR |
| Already all-in on Redux Toolkit | RTK Query |
| Client state that is complex/global | Zustand or Redux — NOT a data-fetching lib |

Do not reach for Redux to hold server data (that is what the query libs solve), and do
not reach for a query lib to hold a modal's open/closed flag.

## Cache keys are the model

The query key IS the cache identity. Get it right and everything else follows:

- **Include every input** that changes the result: `['todos', {status, page}]`, not
  `['todos']`. A key missing a variable serves one query's data for another's — the
  classic stale-key bug.
- **Structure hierarchically** so you can invalidate broadly (`['todos']`) or narrowly
  (`['todos', id]`).

## Invalidation and mutations

- After a mutation, **invalidate the affected keys** so dependent queries refetch — do
  not manually poke the cache unless you have a reason.
- **Optimistic updates** — apply the expected result immediately, roll back on error.
  Powerful and dangerous: always implement the rollback, or a failed mutation leaves a
  lie on screen.
- **`staleTime` vs `gcTime`** — `staleTime` controls how long data is fresh (no refetch);
  `gcTime` how long unused data lingers in cache. Tuning `staleTime` up is the main lever
  against refetch storms.

## Avoiding the common failures

- **Refetch storms** — default `staleTime: 0` refetches on every mount/focus; raise it
  for data that does not change every second.
- **Waterfalls** — dependent queries that could run in parallel run in series; prefetch
  or restructure.
- **Over-fetching on focus/reconnect** — sensible defaults, but audit them for expensive
  queries.

## The shape, minimally

```jsx
// read — the lib owns loading/error/cache/dedup/retry
const { data, isPending, error } = useQuery({
  queryKey: ['todos', { status }],           // every input in the key
  queryFn: () => fetchTodos(status),
  staleTime: 60_000,                          // fresh for a minute — no refetch storm
})

// write — invalidate, don't hand-poke the cache
const qc = useQueryClient()
const add = useMutation({
  mutationFn: createTodo,
  onSuccess: () => qc.invalidateQueries({ queryKey: ['todos'] }),
})
```

No `useState` for `data`, no `useEffect` to fetch, no manual loading flag — the library
is the cache.

## Reviewing server-state code

- Server data flows through a query lib, not `useState` + `useEffect`.
- Fetched data is never copied into local state.
- Query keys include every variable that changes the result.
- Mutations invalidate affected keys; optimistic updates have rollback.
- `staleTime` is tuned for data that does not change constantly (no refetch storms).

## Defer rule

- General React idioms (effects, keys, memoization) → `react-best-practices`.
- The backend endpoint the query hits (N+1, payload) → `/performance:review`,
  `/api-design:review`.
- Client-state architecture (global UI state shape) → `react-best-practices`.

## Anti-patterns

- **`useEffect` + `useState` fetch** — hand-rolling caching a library does correctly.
- **Fetched data copied into `useState`** — two sources of truth, guaranteed staleness.
- **Redux for server data** — reimplementing a cache library by hand.
- **Incomplete query key** — one query serving another's cached data.
- **Optimistic update with no rollback** — a failed mutation leaves a false UI.
- **`staleTime: 0` everywhere** — refetch storms on every focus and mount.
