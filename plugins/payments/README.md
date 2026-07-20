# payments

Payments and billing where a bug is a double-charged customer, not a stack trace.

- **`payments` skill** — stay out of PCI scope (tokenization, never touch raw card
  data), integer-minor-unit money, signature-verified idempotent webhooks, subscription
  state and the activation race, dunning and proration, and reconciliation against an
  append-only ledger.
- **`/payments:review`** — audit a Stripe/Paddle/Braintree integration for the exact
  failure class that hurts most: double-charges, revenue leaks, and PCI exposure.

Defers general webhook/queue delivery semantics to system-design's event-driven
skill, API-key handling to security, and the activation-race mechanics to concurrency.
