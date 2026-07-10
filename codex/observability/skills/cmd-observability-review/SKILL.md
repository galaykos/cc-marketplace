---
name: cmd-observability-review
description: "Use when the user asks to audit code for observability gaps — unstructured logs, missing correlation IDs, secrets in logs, silent catch blocks — one line per finding."
---

_This skill wraps the `/observability:review` command; pass the command's input as the skill's argument (`$ARGUMENTS`)._


Review the target for observability gaps in what the application code emits.

1. Determine scope from $ARGUMENTS — a file or directory path, a diff/branch
   reference, or a design document. If empty, default to recent changes
   (`git diff` against the merge base, falling back to the latest commits).

2. Invoke the observability-design skill from this plugin and apply its
   checklist across the scope: structured logging (machine-parseable JSON at
   boundaries, one event per line), correlation/request IDs propagated across
   calls, queue messages, and background jobs, log-level semantics (error
   means a human acts; no log-and-rethrow double reporting), log hygiene (no
   secrets/PII/tokens, bounded payload sizes, no hot-loop logging), metrics
   (RED/USE coverage, no unbounded label cardinality such as user IDs),
   tracing (spans and trace-context propagation across process boundaries),
   silent catch blocks with no telemetry, and health checks (liveness vs
   readiness, real dependency checks vs unconditional 200).

3. Output findings one line each, in the form:
   path:line — severity — problem — fix
   (for design docs, use section/heading in place of path:line). Order by
   severity: critical, high, medium, low. No praise, no padding.

4. End with the coverage inventory: every spot checked — logging call sites,
   catch blocks, metric registrations, trace boundaries, health endpoints —
   one per line, with a pass/finding status, so it is explicit what was
   covered and what was clean, not just what was broken.

5. When findings exist, offer the next step as a selectable choice
   (AskUserQuestion): "Apply the fixes now (Recommended)" / "Critical and
   high only" / "Stop here". Never leave the user to retype findings as
   instructions. In headless or non-interactive runs, report only — apply
   nothing.
