# Changelog — api-design

Consumer-facing changes only. Newest first. Started at 0.11.4; earlier versions have no entries rather than invented ones.

## 0.11.6 — 2026-11-08

- **`/api-design:review` runs `oasdiff breaking` on a changed OpenAPI spec when oasdiff is already installed.** It runs `oasdiff breaking --format json <base>:<spec> <spec>` from the repository root. The `<ref>:<path>` form needs oasdiff 1.11.11 or later, and an older oasdiff compares a `git show` copy instead, for single-file specs only. It never passes `--fetch` or `--open`. Each breaking change becomes a finding at its spec line, ERR ranked above WARN, with the fix taken from the skill's Versioning section. When oasdiff is not installed, the coverage line says so and the review goes on. It never installs oasdiff. Standing: recorded — nothing checks the run happened.
- The `api-design` skill names the oasdiff route too, so `/code-review:review`'s skill fan-in reaches it.

## 0.11.5 — 2026-10-31

- **A reused `Idempotency-Key` with a different payload is now 422, not 409.** The `api-design` skill said 409. IETF `draft-ietf-httpapi-idempotency-key-header-08` (2026-10-22, an Internet-Draft, not an RFC) says 422 for a changed payload, 409 for a duplicate still in flight, and 400 for a missing required key. The skill now also says to claim the key with an atomic unique insert, never a lookup then an insert, and points to the resilience plugin's `concurrency-safety`.
- **A first eval case, `evals/idempotency-mismatch`.** It has not been run, and its control arm is unmeasured. If a run without the plugin passes, the case cannot measure the skill and should be deleted.

## 0.11.4 — 2026-10-28

- **Comments cut to what a reader needs; behaviour unchanged.** `hooks/remind.sh` (generated hook): each keeps a header saying what it does and misses, and one line per trap the code cannot show; the history moved to the marketplace repository's rationale/derivations/, which an install does not contain.
