---
name: error-handling-design
description: Use when writing or reviewing exception and error handling — try/catch placement, error boundaries, error propagation, custom error types, rethrow and cause chains — to decide fail-fast vs recover, where to catch, and what to report, instead of catch-log-continue at every layer.
---

## Core rule

Every error is one of two things: a bug or an event. A broken invariant
— null where the contract says never-null, an enum case that cannot
happen — is a bug; the only correct response is to crash loudly and fix
the code. A failed network call, a missing file, invalid user input:
these are events the program was always going to meet, and they deserve
designed handling. Most bad error handling comes from conflating the
two — recovering from bugs (hiding corruption) or crashing on events
(fragile software). Classify first; everything else follows.

## Fail fast vs recover

- Programmer errors (violated preconditions, impossible states, broken
  invariants): assert and crash. There is no meaningful recovery from
  "the code is wrong" — continuing runs the rest of the program on
  corrupted assumptions. A crash with a clean stack trace at the
  violation point is a gift; the same corruption surfacing three
  modules later is a week of debugging.
- Operational errors (I/O failures, timeouts, bad input, resource
  exhaustion): expected in production, so handle deliberately — retry,
  degrade, reject the request, or surface a clear failure.
- Never wrap the fail-fast path in a recover path. A catch-all that
  "keeps the service up" through assertion failures converts crashes
  into silent data corruption.

## Catch placement

Catch where you can act, and nowhere else. "Act" means one of: retry
meaningfully, substitute a fallback, translate for a boundary, or
complete the failure (respond 500, abort the job, reject the message).

- A layer that can do none of those lets the error propagate. That is
  not negligence — propagation IS the correct handling for that layer.
- Catch-log-continue at every level produces the log where one failure
  appears five times with five stack traces, and nobody can say where
  it was actually handled — usually because it never was.
- The natural catch sites are few: the top-level request/job/message
  handler, integration-point wrappers, and the rare mid-layer with a
  real fallback. A catch block that only logs and rethrows at a layer
  with no boundary role is a candidate for deletion.

## No swallowing

An empty catch block is a defect, not a style choice. It converts a
failure into a mystery: the operation silently didn't happen, and the
first symptom is downstream — wrong totals, missing records, a user
asking where their data went.

- Minimum bar for any catch: rethrow, or record with enough context to
  reconstruct what failed.
- "This can never fail" is not a reason to swallow — if it truly
  cannot fail, the catch is dead code; if it can, you just hid it.
- Intentionally-ignored errors (best-effort cache warm, optional
  telemetry) are the one exception, and they earn a comment saying WHY
  ignoring is safe, plus a counter so the ignoring stays observable.

## Wrap and rethrow across boundaries

When an error crosses an abstraction boundary, translate it. The
caller of a repository's find() should see "user lookup failed for
id=42", not a raw driver error exposing a connection-pool internal.

- Add what the boundary knows: the operation attempted, the key
  inputs, the resource involved.
- Preserve the cause chain — exception chaining, error wrapping; every
  mainstream language has a mechanism. A wrap that discards the
  original error deletes the stack trace that names the bug.
- Wrap once per boundary, not once per function. Re-wrapping at every
  frame builds a ten-layer onion with the real error at the center.

## Typed errors

Define error types along the axes callers actually branch on:

    retryable vs terminal        -> the retry loop needs this
    user-caused vs system-caused -> 4xx vs 5xx, blame and message
    domain-specific cases        -> InsufficientFunds vs AccountFrozen

Callers branch on type, never on message strings. Matching
message.includes("timeout") is a contract with wording — it breaks on
rephrasing, translation, and library upgrades, silently. If a caller
must distinguish two failures, that distinction is a type (or an error
code field), and the message is for humans only.

## Report once

A failure is logged at exactly one place — normally the top-level
boundary that completes it. Every frame between the throw and that
boundary passes the error along in silence; the cause chain and stack
trace already carry the path. Log-and-rethrow at each layer turns one
failure into six log entries, inflates error-rate metrics sixfold, and
buries the one line that matters. One failure, one report, full context.

## Error messages

Write the message for the operator reading it at 3am, not for the
developer who already knows the code.

    bad:  "operation failed"
    good: "charge failed for order=ord_8912 user=u_442
           amount=1999 EUR gateway=stripe: card_declined"

Include identifiers, the attempted operation, and the state that shaped
the outcome. Exclude secrets, tokens, passwords, full card numbers —
logs outlive access controls.

## User-facing vs internal

Two audiences, two messages, never one string for both. Users get a
safe, actionable sentence: what failed from their perspective and what
they can do ("payment declined — try another card"). Stack traces, SQL
fragments, file paths, and dependency names never reach a response
body — reconnaissance for attackers, confusion for users. Correlate the
two with a request id: the user-facing error carries the id, the
internal log entry carries the same id plus everything else.

## Worked micro-example: order placement handler

    handler receives request
      validate input -> invalid: typed ValidationError, 400 with
        field-level user message; user-caused, so no error-log spam
      charge payment -> gateway throws raw driver error
        payment layer wraps: PaymentFailed(order, amount, cause),
        marked terminal (card declined -- retry will not help)
      handler catches PaymentFailed (it can act: respond)
        user gets "payment declined" + request id
        one log line at the boundary: full context + cause chain
      invariant check fails (total < 0) -> assertion crashes the
        request loudly; nothing catches it but the crash reporter

## Boundaries

- Retry, timeout, and circuit-breaker policy at integration points is
  the resilience plugin's territory (the `cmd-resilience-review` skill); this skill
  decides how the resulting errors are typed, propagated, and reported.
- Which error events become logs and metrics, and their shape, belongs
  to the observability plugin; this skill fixes where reporting happens
  (once, at the boundary), not the telemetry pipeline.

## Anti-patterns

- Empty catch blocks — failures converted into mysteries.
- catch (Exception) around whole methods — bugs handled as events.
- Log-and-rethrow at every layer — one failure, six reports.
- Branching on message contents — control flow coupled to wording.
- Wrapping with the cause discarded — the stack trace that named the
  bug, deleted at the boundary.
- Stack traces in HTTP responses — internals as a public API.
