# Provider divergences — Stripe / Paddle / Braintree

> Last verified: 2026-08-12 — https://developer.paddle.com/webhooks/about/signature-verification/
> (Paddle verified this session; Stripe/Braintree idioms are years-stable APIs —
> re-verify against stripe.com/docs/webhooks and developer.paypal.com/braintree
> before pinning an exact SDK call in code.)

The SKILL's rules (raw body, signature first, idempotent effects) are provider-neutral;
the implementations are NOT interchangeable. The classic Opus failure is writing one
provider's verification idiom against another's headers — it fails closed at best and
verifies nothing at worst.

## Webhook verification — the three shapes

| | Stripe | Paddle (Billing) | Braintree |
|---|---|---|---|
| Header/fields | `Stripe-Signature: t=...,v1=...` | `Paddle-Signature: ts=...;h1=...` | POST form fields `bt_signature` + `bt_payload` (no header) |
| Algorithm | HMAC-SHA256 over `t + "." + rawBody` | HMAC-SHA256 over raw body | SDK-internal (public/private key) |
| SDK call | `stripe.webhooks.constructEvent(rawBody, sig, whsec)` | SDK `unmarshal`/verify helper, or manual HMAC | `gateway.webhookNotification.parse(btSignature, btPayload)` |
| Secret | per-endpoint `whsec_...` | per-notification-destination secret | account keypair (no per-endpoint secret) |
| Replay guard | timestamp tolerance (default 300s) — check it | `ts` field — enforce your own tolerance | SDK handles |
| Dedup key | `event.id` (`evt_...`) | `event_id` | `webhookNotification.timestamp` + kind (no stable id — build your own) |

## The raw-body trap (all three, worst on Paddle)

Verification is over the RAW request bytes. Any framework middleware that parses and
re-serializes JSON first (Express `express.json()` without a `verify` hook, Laravel
middleware that touches the body, a proxy normalizing whitespace) produces a payload
whose signature can never match. Symptoms: every webhook "invalid signature" while the
dashboard shows deliveries succeeding. Fix at the framework edge: capture `req.rawBody`
before parsing (Express `verify` callback; Laravel `$request->getContent()`), never
`JSON.stringify(req.body)`.

## Merchant-of-record vs gateway — different books

- **Paddle is the merchant of record**: Paddle owns the customer transaction, computes
  and remits sales tax/VAT globally, and pays you out on a schedule. Your ledger
  records Paddle's payout as revenue, not each customer charge; refunds route through
  Paddle's dashboard/API, not a card gateway.
- **Stripe and Braintree are gateways**: you are the merchant. Tax is YOUR problem
  (Stripe Tax exists but is opt-in and billed), chargebacks land on you, and each
  charge is your ledger entry.
- Consequence for the SKILL's ledger rule: with Paddle, reconcile against payout
  reports; with Stripe/Braintree, reconcile against balance transactions / settlement
  batches. Mixing the two models double-counts revenue.

## Idiom divergences that break naive ports

- **Amounts**: Stripe and Paddle Billing take integer minor units as strings/ints;
  Braintree takes DECIMAL STRINGS in major units (`"10.00"`) — porting integer-cents
  code to Braintree without conversion charges 100x.
- **Subscription state**: Stripe exposes `status` transitions via distinct events
  (`customer.subscription.updated` with `previous_attributes`); Paddle sends typed
  events (`subscription.activated`, `.paused`, `.canceled`); Braintree sends
  `subscription_charged_successfully` / `_unsuccessfully` kinds. Map each into YOUR
  state machine — never mirror a provider's state names into your schema, or a
  provider migration becomes a data migration.
- **Test traffic**: Stripe has separate test-mode keys and the CLI's
  `stripe listen --forward-to`; Paddle has a full sandbox environment (separate
  domain and secrets); Braintree has a sandbox gateway plus `WebhookTesting` to
  fabricate signed notifications locally. Never point one environment's secret at
  another's traffic — signatures will fail and it reads as an outage.

## When NOT to use this file

Single-provider apps only need their own column; read it and stop. And if the choice
of provider is still open, that is a build-vs-buy/architecture question
(approaches:build-vs-buy), not a webhook-idiom question.
