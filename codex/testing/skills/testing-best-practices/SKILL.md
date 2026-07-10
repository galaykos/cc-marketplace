---
name: testing-best-practices
description: Use when writing or reviewing tests in any stack — what to test (behavior at public boundaries, not implementation), pyramid pragmatics, Pest/PHPUnit feature tests with factories and framework fakes, Vitest/Jest with testing-library and msw, Playwright/Dusk e2e discipline, mocking at owned boundaries, flaky-test root causes, determinism via frozen clocks and seeded randomness, coverage traps.
---

## What to test

Behavior at public boundaries — the HTTP response, the return value, the
emitted event, the persisted row — never private methods, internal state, or
which collaborator got called. The contract: a refactor that preserves
behavior must not break a test. Corollaries:

- One logical assertion focus per test. Several `expect` lines are fine when
  they describe one outcome (status + payload shape); three unrelated
  behaviors under one name are three tests hiding a failure each.
- Test names are specs: `it rejects expired coupons at checkout`, not
  `test_coupon_2`. A red name should say what broke before the body is read.
- Unhappy paths first in review: validation failures, authorization denials,
  empty collections, boundary values. The happy path was manually run anyway.

## Pyramid pragmatics

Many millisecond unit/feature tests at the bottom, a handful of e2e at the
top. An e2e test earns its seconds only when integration itself is the risk:
signup-to-first-value, checkout-and-payment, login/SSO. Everything else
belongs a layer down, where failure output names the cause instead of
"element not found". In Laravel the workhorse is the feature test — real HTTP
kernel, container, and test database; reserve unit tests for pure logic
(money math, parsers, date rules). Do not unit-test controllers against
mocked requests: integration is that layer's entire job.

## PHP: Pest / PHPUnit

- `RefreshDatabase` is the default: migrate once, wrap each test in a
  transaction. It cannot cover a second connection or code that commits —
  those need `DatabaseTruncation`, as does Dusk, whose browser process
  cannot see inside another process's open transaction.
- Model factories over manual inserts: `Order::factory()->paid()->has(...)`
  reads as intent, survives schema drift, and centralizes defaults in
  states. A `DB::table(...)->insert([...19 columns...])` block is a finding.
- Fake the framework's own edges — `Queue::fake()`, `Mail::fake()`,
  `Storage::fake()`, `Http::fake()` — then assert with `Mail::assertQueued`
  and friends. Mocking mailer/queue internals couples the test to plumbing
  the fake already isolates.
- Scope `Event::fake([OrderShipped::class])` to the events under test; a
  blanket fake silently disables the model observers the code relies on.
- Case tables go in Pest datasets (`->with([...])`) or `#[DataProvider]`,
  not copy-pasted test methods that drift apart one edit at a time.

## JS/TS: Vitest / Jest

- Query the accessible surface: `getByRole('button', {name: /save/i})`,
  `getByLabelText` — fall back to `data-testid` only when no accessible
  handle exists, which is itself an a11y finding.
- Assert what the user sees, not the mechanism: no reaching into component
  state, spying on internal handlers, or snapshotting whole trees (a
  300-line snapshot gets approved by reflex, which asserts nothing).
- Network via `msw` at the fetch boundary — the real client code runs, and
  handlers double as API documentation. Mocking `axios`/`fetch` module-wide
  tests the stub, not the client.
- Async UI through `await findByText(...)` / `waitFor`, never bare timeouts.
- Fake timers: advance with `vi.advanceTimersByTimeAsync`, restore in
  teardown, and never combine frozen timers with a pending real-network
  wait — the response callback is queued behind time that no longer passes.

## E2E: Playwright / Dusk

- Selectors by role/label/text (`getByRole`, `dusk="..."` attributes), never
  CSS chains like `.card > div:nth-child(2)` that break on a class rename.
- Auto-waiting assertions (`expect(locator).toBeVisible()`, `waitForText`)
  over sleeps. Every `sleep(2)` is a flake under load and two wasted seconds
  otherwise; disable animations in the test environment rather than waiting
  them out.
- Fresh state per test: new browser context/session, seed through factories
  or an API call — not by clicking through the UI to arrange preconditions,
  which makes every test transitively depend on every screen it crosses.
  Reserve UI-driven setup for the one test whose subject IS that flow.

## Mocking discipline

Mock at architectural boundaries you own — the payment-gateway port, the
clock, the outbound HTTP client — and run the real thing everywhere inward.
Never mock the class under test or its value objects. A test that stubs five
collaborators to assert a sixth was called verifies wiring, not behavior: it
passes when the code is wrong and fails when the code is refactored — the
exact inverse of useful. When a unit needs that many stubs, the design wants
fewer dependencies, not a better mocking library.

## Determinism

- Freeze the clock: `Carbon::setTestNow()` / `$this->travel()` in Laravel,
  `vi.useFakeTimers()` + `vi.setSystemTime()` in Vitest. Any test that
  computes "now" twice can straddle a second, a month boundary, or DST.
- Seed randomness: Faker with a fixed seed, seeded RNG where code rolls
  dice. A generator that "sometimes" collides on unique emails is a flake
  on a delay timer.
- Order independence: every test builds and owns its state. If the suite
  only passes in file order, shared state is the bug — run shuffled
  (PHPUnit `--order-by=random`, Vitest `sequence.shuffle`) to keep it honest.

## Flaky tests

Root causes are finite: real time, real network, shared mutable state, order
dependence, animation and render races. Each has a fix above — frozen clock,
msw or `Http::fake`, per-test state, shuffled order, auto-waiting assertions.
Policy: quarantine a flake the day it appears, fix or delete it within the
sprint. A retried-until-green test is a deleted test with extra steps — it
still spends CI minutes but can no longer fail, and it teaches the team that
red does not mean broken.

## Coverage traps

Line coverage is a floor, not a target: it proves code ran, not that
anything was checked. Chasing a percentage manufactures assertion-free tests
that execute code and verify nothing. Watch for untested branches in review
instead, and spot-check the suite's teeth with mutation testing (Infection,
Stryker) on core domain modules — a surviving mutant is a missing assertion
with an address.

## Anti-patterns

- Asserting implementation: private state, call counts on internals,
  full-tree snapshots nobody reads.
- Mocking the ORM or query builder instead of using the test database.
- Sleeps standing in for waits, in any layer.
- Test interdependence: fixtures mutated across tests, suites that fail
  under shuffle.
- Assertion-free "coverage tests" and tests named `test_it_works`.
- Auto-retry as policy instead of a quarantine list with owners.
- One e2e per user story while the domain logic underneath sits untested.
