---
description: Review a payments/billing integration for PCI scope, webhook idempotency, money handling, and subscription-race gaps against payments
argument-hint: [path-or-diff]
---

Review the target's payments integration — the failure class is double-charges, revenue
leaks, and PCI exposure.

1. Determine scope from $ARGUMENTS — checkout/webhook handlers, subscription logic,
   billing models, or a diff. If empty, locate the payment-provider integration in the
   repo (webhook routes, provider SDK usage) and review it.

2. Invoke the `payments` skill from this plugin and apply its checklist: no raw card
   data anywhere (bodies, logs, columns) — PCI scope minimized via tokenization; money
   as integer minor units with explicit currency, no floats; webhooks signature-verified
   on the raw body, deduped by event ID, effect+dedup in one transaction, fast 2xx;
   idempotent provisioning across success-page and webhook paths; subscription decisions
   refetching provider state; dunning window before revoke; an append-only ledger and a
   reconciliation job.

3. Output findings one line each:
   path:line — severity — problem — fix
   Order by severity. Card data on the server, an unverified webhook, or a
   non-idempotent charge/entitlement is always critical.

4. Defer, do not duplicate: general webhook/queue delivery semantics → `/event-driven
   :review`; API-key secret handling → `/security:review`; the activation-race mechanics
   → `/concurrency:review`.

5. When findings exist, offer the next step as a selectable choice (AskUserQuestion):
   "Apply the fixes now (Recommended)" / "Report only". On apply, hand the finding list
   to the shared `task-executor`. In headless or non-interactive runs, report only.
