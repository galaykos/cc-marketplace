# The clock in tests — inject it, freeze it, pin the zone

> Last verified: not fetched — written 2026-09-10 from training knowledge (model cutoff
> June 2026); Laravel 11/12, Vitest 2–3, Jest 29, freezegun/time-machine assumed.

Standing: **recorded** — read when a test touches "now", a TTL, a schedule, or a
date boundary; `/testing:flake-hunt` classifies the flake, this file names the fix.

## Inject at the boundary, not inside the unit

Code that calls `now()`, `Date.now()`, `time.time()` in its body owns a hidden
dependency on the host. The seam is a clock the caller hands in — PSR-20
`Psr\Clock\ClockInterface` (`symfony/clock`'s `MockClock`), Laravel's `Date`/`Carbon`
facade, a `now: () => Date` option, Go's `func() time.Time` (or `testing/synctest`
from Go 1.25, experimental in 1.24), Java's `java.time.Clock`. Two rules that are
routinely inverted:

- Freeze **before** arranging fixtures. `Order::factory()->create()` stamps
  `created_at = now()`; freezing after creation gives the arrange and act phases two
  different nows, and a `->travel(31)->days()` afterwards moves only one of them.
- Global freezes reach only what reads the abstraction. `Carbon::setTestNow()` freezes
  `now()`, `Carbon::now()`, `Date::now()` and Eloquent timestamps — **not** `time()`,
  `date()`, `new DateTime()`, `microtime()`, or a database `DEFAULT CURRENT_TIMESTAMP`,
  which is the database's clock. `vi.useFakeTimers()` fakes `Date`, `setTimeout`,
  `setInterval`, `performance` — not `process.nextTick`/`queueMicrotask` by default,
  and never the network. freezegun patches `datetime`/`time` in Python code; C-level
  callers (some pandas/numpy paths) read the real clock — `time-machine` patches
  lower. A column whose default is the DB's `now()` is asserted with a tolerance or
  set explicitly from the app clock; equality against a frozen value fails at
  midnight, on DST, and whenever the DB and app hosts disagree by a second.

## Frozen time per test, with teardown

Every freeze has a matching restore in the SAME test's teardown, or the frozen time
leaks into the next test — and the flake appears in another file, ordered-dependent,
which `/testing:flake-hunt` classifies but cannot locate. Laravel's base `TestCase`
already resets `Carbon::setTestNow()` in `tearDown`; plain PHPUnit/Pest, Vitest and
Jest do not:

    afterEach(() => { vi.useRealTimers(); });          // Vitest
    afterEach(fn () => Carbon::setTestNow());          // Pest without Laravel's TestCase

- `vi.setSystemTime(t)` moves `Date` and nothing else — timers scheduled before it
  do not fire. Advance with `vi.advanceTimersByTimeAsync(ms)` (the async form flushes
  promise callbacks; the sync one leaves them pending) or `vi.runOnlyPendingTimersAsync()`.
- `@testing-library`'s `waitFor` auto-advances **Jest** fake timers and does not
  detect Vitest's — under Vitest, `vi.useFakeTimers({ shouldAdvanceTime: true })` or
  the wait hangs until the test timeout. The frozen-timers-plus-real-network hang is in
  the SKILL body; this is its sibling.
- Freeze to a **whole second** when the code truncates: a JWT `exp`, a Redis TTL, a
  MySQL `DATETIME` without precision all drop fractions. Frozen at `12:00:00.500`, the
  stored expiry reads `12:00:00` and the "still valid at T−0.5s" assertion flips.

## Boundary fixtures — named, not incidental

A suite that freezes to "some Tuesday in June" never exercises the branches that
break in production. Name these fixtures and run the date-sensitive tests through each:

| fixture | instant | what it breaks |
|---|---|---|
| DST gap | `2026-03-29 02:30 Europe/Berlin` (does not exist); US `2026-03-08 02:30` | local-time parsing, "same time tomorrow" arithmetic, cron in local zone |
| DST fold | `2026-10-25 02:30 Europe/Berlin` (happens twice); US `2026-11-01 01:30` | ambiguous local time, durations across the fold (23h/25h days) |
| month end | `2026-01-31` + 1 month | Carbon `addMonth()` overflows to Mar 3 (`addMonthNoOverflow` clamps); billing anchors, "same day next month" |
| leap day | `2028-02-29` (2026 is not a leap year; 2100 is not either) | yearly anniversaries, age, `+1 year` |
| ISO week/year | `2025-12-29` is ISO week 1 of **2026** | `YYYY` (week-year) vs `yyyy` in format strings — the classic New Year bug |
| year boundary | `2026-12-31 23:59:59.999Z` | year rollover, retention "this year" filters, fiscal-year math |
| epoch zero / 2038 | `1970-01-01T00:00:00Z`, `2038-01-19 03:14:07Z` | `if (timestamp)` falsy checks; 32-bit and MySQL `TIMESTAMP` overflow |
| local midnight vs UTC | a date-only value at `00:00` in a UTC−5 zone | a `DATE` rendered as the previous day; "today" filters off by one |

## `sleep` is never a synchronisation primitive

`sleep(2)` encodes a guess about the scheduler; it passes on the laptop, flakes on a
loaded CI runner, and costs two seconds every green run. It is not a wait, it is a
race with a head start. The replacement depends on what the test is actually waiting for:

| waiting for | use |
|---|---|
| a promise or job the code returns | `await` the returned promise; make the seam return it (`onFlushed`, `Bus::fake` + assert dispatched, run the queue `sync`) |
| a timer inside the code | fake timers + `advanceTimersByTimeAsync` / `travel()` — never real elapsed time |
| a UI or external state change | polling with a deadline: `findBy*`/`waitFor`, `expect.poll`, Playwright `expect(locator)`, `retry_until`; the assertion re-runs until true or the deadline names what did not happen |
| a queue/worker to drain | drive it synchronously in test, or poll the persisted effect — never wait for "long enough" |

A polling wait with a deadline **fails with a message**; a sleep fails with a wrong
assertion two lines later. The sleep survives review because it works — until it does not.

## TTL and expiry: assert at T−1 and T+1

An expiry test that checks only "expired after a long time" proves nothing about the
boundary. Freeze at creation, then travel to `ttl − 1s` (valid), `ttl` (whichever the
spec says — pin it, inclusive or exclusive is a decision, not an accident), and
`ttl + 1s` (expired):

    $this->freezeTime();
    $token = Token::issue(ttl: 3600);
    $this->travel(3599)->seconds();  expect($token->isValid())->toBeTrue();
    $this->travel(2)->seconds();     expect($token->isValid())->toBeFalse();

Same for caches, sessions, rate-limit windows, signed URLs. If the store enforces
the TTL itself (Redis `EX`, a database `expires_at`), the test still runs in the app
clock — and a store that keeps real time (Redis does) sees no travel at all; assert
against the value the app wrote, or test the expiry branch with an already-past
`expires_at`.

## CI timezone pinning — and the second run that proves it

- Pin `TZ=UTC` in the CI job (`env:` at workflow level; `process.env.TZ = 'UTC'` in a
  Vitest `globalSetup`/`env` config or a Jest `globalSetup` — Node honours a runtime
  change to `TZ`). PHP's `date_default_timezone_set` and Laravel's `config('app.timezone')`
  set the app clock only, never the database session's zone; the database plugin's
  `sql-best-practices/references/time.md` has the engine side.
- A test that passes only under one zone is **broken, not environment-sensitive**: the
  code under test reads the host zone somewhere the test never controls. Run the
  date-sensitive subset a second time under a hostile zone — `TZ=America/Sao_Paulo`
  (negative offset, a DST history that changed), `TZ=Asia/Kolkata` (+05:30, breaks
  whole-hour assumptions), or `TZ=Pacific/Chatham` (+12:45) — and fix the code, not
  the fixture, when it fails.
- The developer's laptop zone is the default nobody set. A suite green locally and red
  in CI (or the reverse) on a date test has found real production behaviour: users
  live in the zone CI happens to have.
