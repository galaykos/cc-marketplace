# Real-time on Inertia: Echo + Reverb, polling, and keeping props true

> Last verified: 2026-09-26 — https://laravel.com/docs/13.x/broadcasting — npm:laravel-echo@2.5

Read with the SKILL's version gates: `usePoll` needs Inertia v2+, `router.replaceProp` and its
siblings need v2.2+, the `useEcho` hooks come from `@laravel/echo-react` / `@laravel/echo-vue`
(2.x), and on Inertia v3 there is no axios — which changes how `X-Socket-ID` travels (below).

## Pick the transport

| The page needs | Use |
|---|---|
| data that changes on a clock, where N seconds stale is fine (dashboards, job status, counts) | `usePoll(ms, { only: [...] })` — nothing extra to run; it throttles hidden tabs by 90% and stops on unmount |
| another user's change on screen within a second or two (chat, presence, a board several people edit, alerts) | Echo + Reverb (or Pusher / Ably) |
| both — fresh, and correct after a gap | Echo as the nudge, a reload of the affected props as the truth |

Echo + Reverb costs a long-running `php artisan reverb:start` under a process manager, a proxy
serving `/app` and `/apps`, a queue worker (a `ShouldBroadcast` event is queued unless it is
`ShouldBroadcastNow`), and past one server `REVERB_SCALING_ENABLED` with a shared Redis. Polling
costs requests. Choose the socket when latency is the requirement, not by default.

## An event is a nudge; props stay the truth

- **Reload (default)** — `router.reload({ only: ['orders'] })`. The server recomputes the prop
  with its own authorization, scoping and shaping, so nothing the event carried can be wrong for
  long. One request per event: coalesce a burst into one reload (debounce ~250 ms).
- **Local patch** — `router.replaceProp('orders', (current) => apply(current, e.order))` (v2.2+;
  also `appendToProp` / `prependToProp`), no request. Only when the payload is the complete row
  the page renders, the event rate makes per-event reloads too expensive, and the apply is
  idempotent (below). The next visit or reload overwrites the patch, so the patch must converge
  on what the server would have sent.
- A broadcast payload is as public as its channel: `broadcastWith()` returns what the page
  renders, never the model — the SKILL's prop-contract rule applies to events too.

## Don't echo the actor's own change back

The actor already sees the change (optimistic update or the visit's response). Applying the
broadcast again in their tab double-counts: a comment appears twice, a counter jumps by two.

- Server: `broadcast(new OrderUpdated($order))->toOthers()`, with `use InteractsWithSockets` on
  the event. Model broadcasting (`BroadcastsEvents`) gets the same from
  `dontBroadcastToCurrentUser()` in `newBroadcastableEvent()`.
- `toOthers()` skips the socket named by the request's `X-Socket-ID` header. Echo attaches it
  only to a global `axios` (and jQuery / Turbo). Inertia v3 has no axios and `configureEcho`
  adds no header, so the header is missing until you add it once:

```js
import { http } from '@inertiajs/react' // or @inertiajs/vue3 / @inertiajs/svelte
import { echo } from '@laravel/echo-react' // or @laravel/echo-vue

http.onRequest((config) => {
  const id = echo().socketId()
  if (id) config.headers['X-Socket-ID'] = id
  return config
})
```

  On v1/v2 without a shared global axios, set `event.detail.visit.headers['X-Socket-ID']` in a
  `router.on('before', ...)` listener instead.
- Prove it with two tabs: act in one; the actor's tab must receive nothing (watch the socket
  frames in devtools, or `php artisan reverb:start --debug`).

## One listener per channel, owned by the page

- Subscribe once per channel in the page component or a persistent layout and pass the data
  down. `useEcho` inside each of 50 rows attaches 50 handlers: the hooks share one subscription
  and leave only when the last user unmounts, but every handler still runs, so one event fires
  50 reloads.
- Cleanup on unmount: `useEcho`, `useEchoPresence` and `useEchoModel` leave by themselves. Raw
  `Echo.private(...).listen(...)` needs `stopListening` and `leave` in the effect cleanup or
  `onUnmounted`; without it every visit back to the page stacks another handler.
- A persistent layout does not remount on navigation, so its listener lives for the session; a
  page's lives for the visit. Pick the owner by how long the data matters.

## Missed events: resync after reconnect

A Pusher-protocol socket (Reverb included) delivers to whoever is connected at that moment; the
Reverb docs describe no history or replay. Laptop sleep, a network switch, a `reverb:restart` on
deploy — every event in the gap is gone. When the connection returns, reload the props the
channel feeds:

```js
const status = useConnectionStatus() // connected | connecting | reconnecting | disconnected | failed
const wasDown = useRef(false)
useEffect(() => {
  if (status === 'reconnecting' || status === 'disconnected') wasDown.current = true
  if (status === 'connected' && wasDown.current) {
    wasDown.current = false
    router.reload({ only: ['orders'] })
  }
}, [status])
```

Vue: the same with `watch` over `useConnectionStatus()` from `@laravel/echo-vue`.

## Apply idempotently: id plus version

The same change can arrive twice (the event and a reload race) and out of order (queued
broadcasts on several workers). Carry `id` and a version that only grows — an integer `version`
column bumped per write, or `updated_at` if second precision cannot tie — and drop anything not
newer:

```js
function apply(list, incoming) {
  const i = list.findIndex((row) => row.id === incoming.id)
  if (i === -1) return [...list, incoming]
  if (list[i].version >= incoming.version) return list // duplicate or stale
  return list.map((row, j) => (j === i ? incoming : row))
}
```

A delete carries id and version too, and the page remembers ids deleted this visit, so a late
`updated` event cannot resurrect the row.

## Private and presence channels: authorize the join

- Anything not public rides a private or presence channel (`useEcho` subscribes private by
  default; `useEchoPublic` is the opt-out), authorized in `routes/channels.php` with the same
  policy the page uses:

```php
Broadcast::channel('orders.{order}', fn (User $user, Order $order) => $user->can('view', $order));
```

- A presence callback returns the member array every other member receives
  (`['id' => $user->id, 'name' => $user->name]`) — only what you would render, never the model;
  return `false` or `null` to refuse.
- Multi-tenant apps: tenant-scoped channel names, and what a connection keeps after membership
  ends, are in the security plugin's `security-review` skill, `references/multi-tenancy.md`
  ("Contexts that lose the tenant", Websockets). Read it there; it is not restated here.

## Hidden tabs

- `usePoll` already throttles a background tab by 90%; `keepAlive: true` switches that off —
  leave it off unless the tab is a wall display.
- Echo handlers keep firing in a hidden tab. While `document.hidden`, set a dirty flag instead
  of reloading, and run one `router.reload({ only: [...] })` on `visibilitychange` back to
  visible.

## Standing

| Rule | Standing |
|---|---|
| transport choice, reload vs patch, one listener per channel, resync, idempotent apply, hidden-tab deferral | **agent-graded** when a review loads this reference; otherwise **recorded** — no script reads it |
| the actor's tab not receiving its own event | **unenforceable** statically — only the two-tab run above shows whether `X-Socket-ID` reached the server |
| channel authorization | **agent-graded** by a security review that loads `multi-tenancy.md`; no script reads `routes/channels.php` |
