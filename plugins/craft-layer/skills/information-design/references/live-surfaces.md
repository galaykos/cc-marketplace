# Live surfaces — data that changes while the user reads

This file covers live lists and feeds, queues with timers, live charts, log streams and chat.
It is about what the screen does when an update arrives. Transport belongs to the stack skills:
- sockets, polling, and resync after a reconnect: `laravel:inertia-best-practices` for Inertia
  apps, `web-dev:nextjs-best-practices` for Next.js;
- live-region mechanics: `ui-ux:a11y-audit`.

**Standing.** Each rule carries a tag:
- `recorded`: reached through `information-design`'s pointer. Nothing reads it back.
- `agent-graded`: the rule cites a WCAG 2.2 success criterion, which `/ui-ux:audit` judges.

The "without it" failures are an inference from the shape of live products, not a
measurement.

## Lists and feeds

1. **Buffer. Never re-sort under the user.**
   - New records go into a buffer, surfaced as a "N new · Show" button at the top of the list.
   - The list re-sorts only when that button is used, or when the user scrolls to the top.
   - While the pointer is over the list, or focus is inside it, stop applying updates.
   - *Without it:* the row the user is about to click moves, and they act on the wrong record.
   - `recorded`
2. **Anchor the scroll.**
   - An insert above the viewport must not move what the user is reading.
   - CSS scroll anchoring (`overflow-anchor`) did not reach Safari until version 27, so keep a
     manual fallback: measure the top visible row before the insert and restore its offset
     after.
   - A virtualized list always needs the manual path.
   - `recorded`
3. **Key rows by record id.**
   - Keys come from the record id, never from the index.
   - An update patches the row in place, so focus, selection, expansion and any half-typed
     inline edit survive.
   - When the focused record moves, focus follows it. When it is removed, focus goes to a
     neighbouring row, never to `<body>`.
   - `agent-graded` (SC 2.4.3)
4. **One polite summary.**
   - Never announce each insert.
   - Use one status region that already exists in the page, and send at most one message every
     few seconds, as a summary ("3 new orders").
   - Assertive announcements are only for an error that interrupts the user.
   - `agent-graded` (SC 4.1.3)
5. **Bounded ring buffers.**
   - Every collection a stream feeds has a cap that drops the oldest item. Older data comes back
     through paging or history.
   - *Without it:* a dashboard left open overnight runs out of memory.
   - `recorded`
6. **Motion on change, not on every tick.**
   - A changed row gets a brief highlight. A re-sort gets a shared-layout move
     (`app-craft-floors.md` §4).
   - Both become instant under reduced motion.
   - `recorded`

## Live charts

- **Rendering.** Keep a sliding window of fixed length. Batch updates to one draw per animation
  frame, and move from SVG to canvas past a few thousand points. `recorded`
- **Freeze under a tooltip.** While a tooltip is open or a point has focus, stop the chart
  moving, and resume when it closes. A tooltip whose point slides away cannot be read.
  `agent-graded` (SC 1.4.13)
- **Pause control.** A chart that moves continuously for more than 5 s beside other content has
  one. `agent-graded` (SC 2.2.2)
- **Text alternative.** The text summary or table twin updates at the summary cadence, not per
  point. `recorded`

## Timers, countdowns and SLA clocks

- **One shared ticker.** Run one interval or animation-frame loop per page and let every row
  subscribe to it. Never run one `setInterval` per row. `recorded`
- **Server-offset time.**
  - Compute `offset = serverNow − clientNow` from a server timestamp, and count down against
    `Date.now() + offset`.
  - A client clock can be minutes off, and that skew reorders an SLA queue.
  - `recorded`
- **Derive, never decrement.**
  - Background tabs throttle timers. On every tick, and on `visibilitychange`, recompute the
    remaining time from the deadline.
  - A counter that is decremented drifts.
  - `recorded`
- **Render.**
  - The deadline goes in `<time datetime>`, in tabular figures so the digits do not jitter.
  - Thresholds are stated as text ("Overdue · 3 min"), not only as a colour change.
  - `agent-graded` (SC 1.4.1)
- **Never a ticking live region.**
  - A countdown inside `aria-live` announces every second.
  - Announce thresholds once instead ("5 minutes left on your hold").
  - `agent-graded` (SC 4.1.3)
- **Holds and session limits.**
  - Warn before a hold expires, and let the user extend it with a simple action: at least 20 s
    to respond, at least ten times.
  - The exception is a limit that is a real-time event or is essential.
  - `agent-graded` (SC 2.2.1)
- *Without it:* one interval per row, the raw client clock, counters that drift in a background
  tab, and a live region that ticks.

## Log streams

Follow, pause, resume and the level column are in `console-patterns.md`. The list rules above
apply too: a bounded buffer, and the stream is never a live region that reads each line.

## Chat and threads

- **The message list is `role="log"`.** Its implicit polite announcement suits discrete,
  human-paced messages.
  - A streamed reply is announced once, when it completes. Render the partial text outside the
    log, then append the finished message.
  - `agent-graded` (SC 4.1.3)
- **Auto-scroll only at the bottom.** Scroll to new messages only when the user is already at
  the bottom. Otherwise keep their position and show a "N new messages" button.
  - *Without it:* reading history is yanked back to the bottom by every incoming message.
  - `recorded`
- **Arrivals never move focus.** A message arriving while the user types does not move focus.
  - Mark unread messages with a divider.
  - Every message carries `<time datetime>`.
  - The composer follows `ai-surfaces.md` (Enter, Shift+Enter, IME).
  - `recorded`
