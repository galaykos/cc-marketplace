# Queued job payloads — the worked pair

Cited from the SKILL body's "Queue slow work" rule. The rule is there; this file
is the code, because an example this long loaded on every Laravel edit is a cost the
rule does not need to carry.

## Bad → good: hydrated model, non-idempotent handler

```php
// Bad: hydrated model in the constructor, non-idempotent charge
class ChargeOrder implements ShouldQueue {
    public function __construct(public Order $order) {}
    public function handle(): void { Payment::charge($this->order); } // charges again on retry
}

// Good: pass the id; the provider dedupes the charge on a key fixed per order
class ChargeOrder implements ShouldQueue {
    public function __construct(public int $orderId) {}
    public function handle(): void {
        $order = Order::findOrFail($this->orderId);
        if ($order->isPaid()) return; // skips finished work only: two runs at once both pass it
        $charge = Payment::charge($order, idempotencyKey: "order-{$order->id}-charge");
        $order->markPaid($charge->id);
    }
}
```

Why each half matters:

- **The constructor.** `SerializesModels` re-fetches the model on execution, so a
  hydrated model buys nothing and serializes its loaded relations recursively —
  that is the payload-bloat path, not the id.
- **The guard.** A queue retries. `handle()` that charges unconditionally charges
  twice the first time a worker dies mid-run, and the second charge looks exactly
  like the first in the logs. `isPaid()` alone is check-then-act: a retry that starts
  while the first run is still charging passes it too, and a run that dies after the
  charge but before `markPaid()` leaves nothing for it to see. The key is what holds:
  the provider answers a repeat with the first charge (Stripe API v1: the
  `Idempotency-Key` header; it may prune a key once it is 24 hours old, so a retry after that charges
  again). With no provider key, claim a row first, a unique `order_id` in an
  `order_charges` table inserted before the charge, so a second run's insert fails and
  it stops. A claimed row with no charge id after a crash needs a check with the
  provider, never a second charge.
