# Queued job payloads — the worked pair

Cited from the SKILL body's "Queue slow work" rule. The rule is there; this file
is the code, because a 17-line example loaded on every Laravel edit is a cost the
rule does not need to carry.

## Bad → good: hydrated model, non-idempotent handler

```php
// Bad: hydrated model in the constructor, non-idempotent charge
class ChargeOrder implements ShouldQueue {
    public function __construct(public Order $order) {}
    public function handle(): void { Payment::charge($this->order); } // charges again on retry
}

// Good: pass the id, guard against duplicate execution
class ChargeOrder implements ShouldQueue {
    public function __construct(public int $orderId) {}
    public function handle(): void {
        $order = Order::findOrFail($this->orderId);
        if ($order->isPaid()) return;
        Payment::charge($order);
    }
}
```

Why each half matters:

- **The constructor.** `SerializesModels` re-fetches the model on execution, so a
  hydrated model buys nothing and serializes its loaded relations recursively —
  that is the payload-bloat path, not the id.
- **The guard.** A queue retries. `handle()` that charges unconditionally charges
  twice the first time a worker dies mid-run, and the second charge looks exactly
  like the first in the logs.
