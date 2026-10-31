# Changelog — api-design

Consumer-facing changes only. Newest first. Started at 0.11.4; earlier versions have no entries rather than invented ones.

## 0.11.5 — 2026-10-31

- **A reused `Idempotency-Key` with a different payload is now 422, not 409.** The `api-design` skill said 409. IETF `draft-ietf-httpapi-idempotency-key-header-08` (2026-10-22, an Internet-Draft, not an RFC) says 422 for a changed payload, 409 for a duplicate still in flight, and 400 for a missing required key. The skill now also says to claim the key with an atomic unique insert, never a lookup then an insert, and points to the resilience plugin's `concurrency-safety`.
- **A first eval case, `evals/idempotency-mismatch`.** It has not been run, and its control arm is unmeasured. If a run without the plugin passes, the case cannot measure the skill and should be deleted.

## 0.11.4 — 2026-10-28

- **Comments cut to what a reader needs; behaviour unchanged.** `hooks/remind.sh` (generated hook): each keeps a header saying what it does and misses, and one line per trap the code cannot show; the history moved to the marketplace repository's rationale/derivations/, which an install does not contain.
