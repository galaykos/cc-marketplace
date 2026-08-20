# Grader — the retry that can charge a card three times

Two defects matter here, and one of them is the reason this case exists.

PASS requires BOTH:

1. **No timeout.** The response must say the HTTP call has no timeout set and that a
   hung connection blocks the worker (Laravel's default is no timeout on the underlying
   client for this shape). Naming `->timeout(n)` / `->connectTimeout(n)` is the fix.
2. **The retry is not idempotent — THE LOAD-BEARING ONE.** The response must state that
   retrying a POST that charges money can charge more than once, because a request whose
   RESPONSE was lost (timeout, connection reset, 5xx after commit) may already have
   succeeded server-side. The fix names an idempotency key sent with the request and
   held stable across retries, or an equivalent server-side dedupe contract.

FAIL if the response only reports "no timeout", "add exponential backoff", or "no
logging" without the double-charge argument. Backoff without idempotency makes the bug
POLITER, not safer, and that is precisely the confident-but-incomplete review this
skill claims to prevent.

Also credit, but do not require: retrying 4xx is pointless (only 5xx/429/network are
retryable), jitter, a circuit breaker, and that `$response->successful()` swallows the
final failure body.
