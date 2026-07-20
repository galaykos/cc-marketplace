---
name: payments
description: Use when integrating or reviewing payments and billing (Stripe, Paddle, Braintree) — webhook idempotency and verification, subscription state machines and races, PCI scope minimization, money representation, proration and dunning, and reconciliation. The failure class here is double-charges and revenue leaks; design against them explicitly.
---

# Payments and billing

Money is the one domain where a bug is not a stack trace — it is a double-charged
customer or a silent revenue leak, and it is unforgiving and audited. Two rules carry
most of the safety: **never touch raw card data**, and **treat every webhook as
arriving more than once and out of order.**

## PCI scope — stay out of it

The cheapest PCI compliance is the card number never reaching your server. Use the
provider's tokenization — hosted fields, Checkout, PaymentElement — so the browser
sends the card to Stripe/Paddle directly and you store only a token. The moment raw
PAN touches your backend you are in PCI-DSS scope for your whole system. Never log a
card number, CVV, or full token; never persist them. If a review finds card data in
a request body, a log, or a database column, that is critical.

## Money representation

- **Integer minor units** (cents), never floats. `0.1 + 0.2 != 0.3` is a rounding bug
  that becomes a reconciliation nightmare at scale.
- **Currency travels with every amount** — an integer `1000` is meaningless without
  `USD` (and minor-unit exponents differ: JPY has none, so `1000` = ¥1000 not ¥10).
- **Round once, deliberately**, at display or at the charge boundary; never accumulate
  rounded intermediates.

## Webhooks — idempotent and verified

Providers deliver webhooks **at least once, out of order, and sometimes late**. Every
handler must:

1. **Verify the signature** on the raw request body before parsing — an unverified
   webhook is an attacker telling you they got paid. Use the provider's signing secret;
   reject on mismatch.
2. **Dedup by event ID** — record processed event IDs; a repeated `charge.succeeded`
   must not grant entitlement twice. Store the ID atomically with the effect.
3. **Tolerate out-of-order** — `subscription.updated` can arrive before
   `subscription.created`. Reconcile against the provider's current state (refetch the
   object) rather than trusting the event to be the latest truth.
4. **Return 2xx fast**; do slow work asynchronously, or the provider retries and you
   process again.

The shape of a safe handler:

```
verify_signature(raw_body, header, signing_secret)   # reject on mismatch
event = parse(raw_body)
if seen(event.id): return 200                         # dedup — already processed
in a transaction:
    apply_effect(event)                               # idempotent effect
    mark_seen(event.id)                               # atomic with the effect
return 200                                             # fast; heavy work goes async
```

## Subscription state and races

- The **provider is the source of truth** for subscription status, not your local
  cache. On any ambiguity, refetch. Your DB mirrors; it does not decide.
- **Guard the activation race** — checkout success page AND the `checkout.completed`
  webhook can both try to provision; make provisioning idempotent so whichever wins,
  the customer gets exactly one entitlement.
- **Grace and dunning** — a failed renewal is not an instant downgrade. Model a dunning
  window (retry schedule, emails) before revoking access; revoke on final failure, and
  restore cleanly on recovery.
- **Proration** — plan changes mid-cycle credit/charge the difference; let the provider
  compute it (its proration is the billed truth) rather than reimplementing and drifting.

## Reconciliation

Your ledger and the provider's will diverge — a missed webhook, a manual refund. Run a
periodic reconciliation that refetches provider state and flags mismatches, and keep an
**immutable local ledger** of every money event (append-only, event-sourced) so a
dispute can be reconstructed. "The webhook must have fired" is not an audit trail.

## Reviewing a payments integration

- No raw card data anywhere — request bodies, logs, DB columns, error reports.
- Amounts are integer minor units with an explicit currency; no float arithmetic.
- Every webhook: signature verified on the raw body, deduped by event ID, effect and
  dedup in one transaction, fast 2xx.
- Provisioning/entitlement is idempotent across the success-page and webhook paths.
- Subscription decisions refetch provider state rather than trusting a local cache.
- A failed renewal enters dunning, not an instant revoke; recovery restores cleanly.
- An append-only ledger exists and a reconciliation job flags drift.

## Defer rule

- Webhook *delivery* semantics as general messaging (idempotency, DLQ) →
  `system-design:event-driven`; this skill owns the payments-specific handling.
- The general secret handling for API keys → `secret-scanning` / `security`.
- Concurrency mechanics of the activation race → `/concurrency:review`.

## Anti-patterns

- **Card data on your server** — PAN/CVV in a body, log, or column; full PCI scope and
  a breach waiting.
- **Floats for money** — rounding drift that reconciliation can never close.
- **Unverified webhook** — trusting an unsigned "you got paid" event.
- **Non-idempotent webhook** — double entitlement or double fulfillment on redelivery.
- **Local status as truth** — acting on a stale cached subscription instead of refetching.
- **Instant downgrade on one failed charge** — no dunning window; churn you caused.
