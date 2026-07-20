---
description: Review a system design, RFC, or existing topology against system-design and domain-modeling
argument-hint: [design-doc-path-or-service-dir]
---

Review the target's system-level structure — you are auditing the shape, not
implementing it.

1. Determine scope from $ARGUMENTS — a design doc / RFC, a directory of services and
   manifests, or a diff. If empty, map the current system from the repo (compose/k8s
   specs, entrypoints, connection strings) and review that.

2. Invoke the `system-design` skill from this plugin, `domain-modeling` when the
   target defines a domain model, and `event-driven` when the target has
   async/messaging hops (brokers, queues, outbox, sagas, DLQ). Apply their checklists: service boundaries drawn on
   data ownership (not org chart), single-writer per datum, scaling path with a named
   bottleneck, cache placement with an invalidation/staleness answer, every async hop
   with its failure modes (loss, duplicates, ordering, poison), named SPOFs, and —
   for domain models — bounded-context integrity, aggregate size and transaction
   boundaries, references-by-ID, and anemic-model smell.

3. Output findings one line each:
   section-or-path — severity — problem — fix
   Order by severity: critical, high, medium, low. A design decision presented with
   no rejected alternative is itself a finding.

4. Defer, do not duplicate: code-level module structure → `/code-architecture:plan`;
   REST contract detail → `/api-design:review`; cache mechanics and load numbers →
   `/performance:review`.

5. Close with a coverage inventory and a self-refute pass: state `Checked: …` and
   `Not checked: … (why)` so it is explicit what was covered, what was clean, and what
   was skipped — not only what broke. Then run one adversarial self-refute pass over
   every `critical` finding; if a finding does not survive it, drop or downgrade it
   with a note.

6. When findings exist, offer the next step as a selectable choice (AskUserQuestion):
   "Have the system-architect implement the fixes now (Recommended)" / "Report only".
   On implement, dispatch the `system-architect` worker with the finding list. In
   headless or non-interactive runs, report only.
