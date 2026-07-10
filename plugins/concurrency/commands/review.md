---
description: Audit code for concurrency hazards — check-then-act races, missing idempotency on retried paths, unguarded parallel writes, locks without TTL or fencing — one line per finding.
argument-hint: [path-diff-or-design-doc]
---

Review the target for concurrency hazards on every path that can run
twice at once or be retried.

1. Determine scope from $ARGUMENTS — a file or directory path, a diff/branch
   reference, or a design document. If empty, default to recent changes
   (`git diff` against the merge base, falling back to the latest commits).

2. Invoke the concurrency-safety skill from this plugin and apply it to
   every concurrent or retried path in scope. Audit for: check-then-act
   sequences (read-check-write without atomicity), missing idempotency on
   retried paths (payments, webhooks, queue handlers, HTTP retries),
   non-atomic upserts (SELECT-then-INSERT without a unique constraint),
   unguarded parallel writes (Promise.all or worker fan-out hitting the
   same rows), fire-and-forget async calls that lose errors, and
   distributed locks without TTL or fencing tokens.

3. Output findings one line each, in the form:
   path:line — severity — problem — fix
   (for design docs, use section/heading in place of path:line). Order by
   severity: critical, high, medium, low. No praise, no padding.

4. End with the coverage inventory: every concurrent or retried path that
   was checked, one per line, with a pass/finding status — so it is
   explicit what was covered and what was clean, not just what was broken.

5. When findings exist, offer the next step as a selectable choice
   (AskUserQuestion): "Apply the fixes now (Recommended)" / "Critical and
   high only" / "Stop here". On apply, hand the finding list to the shared
   `task-executor` (task-runner plugin) when installed — scope-locked, bounded
   verify-fix, evidence-returning — otherwise apply inline. In headless or
   non-interactive runs, skip the offer and output the report only.

6. Reliability family: `resilience` (failure modes), `error-handling` (catch-site
   correctness), and `concurrency` (race safety) are sibling reviews sharing this
   apply path — run the one matching the defect class.
