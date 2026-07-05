---
description: Review code or a design for failure-mode gaps — missing timeouts, unsafe retries, absent degradation paths — one line per finding.
argument-hint: [path-diff-or-design-doc]
---

Review the target for failure-mode gaps at every integration point.

1. Determine scope from $ARGUMENTS — a file or directory path, a diff/branch
   reference, or a design document. If empty, default to recent changes
   (`git diff` against the merge base, falling back to the latest commits).

2. Invoke the resilience-design skill from this plugin and apply its
   checklist to every integration point found in scope: HTTP/API calls,
   database access, queue producers and consumers, third-party SDK calls,
   and background jobs. For each one check timeouts (explicit, connect vs
   read, budget propagation), retries (idempotency first, backoff + jitter,
   capped), circuit breaking / fail-fast behavior, graceful degradation
   paths, backpressure and queue bounds, delivery semantics, blast-radius
   containment, and observability on failure paths.

3. Output findings one line each, in the form:
   path:line — severity — problem — fix
   (for design docs, use section/heading in place of path:line). Order by
   severity: critical, high, medium, low. No praise, no padding.

4. End with the integration-point inventory: every integration point that
   was checked, one per line, with a pass/finding status — so it is
   explicit what was covered and what was clean, not just what was broken.

5. When findings exist, offer the next step as a selectable choice
   (AskUserQuestion): "Apply the fixes now (Recommended)" / "Critical and
   high only" / "Stop here". Never leave the user to retype findings as
   instructions.
