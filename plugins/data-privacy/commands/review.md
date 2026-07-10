---
description: Review code or a design for GDPR/CCPA data-handling gaps — PII mapping, erasure reach, consent, retention — against data-privacy
argument-hint: [path-or-design-doc]
---

Review the target for regulatory data-handling gaps (GDPR/CCPA).

1. Determine scope from $ARGUMENTS — models/migrations touching personal data, a
   feature design, consent/export/deletion flows, or a diff. If empty, locate where
   personal data is collected and stored in the repo and review that.

2. Invoke the `data-privacy` skill from this plugin and apply its checklist: a data map
   exists and this change updates it; only purpose-necessary data is collected (no
   hoarding); access/export/erasure can reach this data across logs, caches, backups,
   and third-party processors; consent (where the basis) is specific, unbundled,
   recorded, revocable; a retention period and automated deletion/anonymization exist;
   sensitive categories are classified and handled under stricter rules; cross-border
   transfer has a safeguard.

3. Output findings one line each:
   path-or-section:line — severity — problem — fix
   Order by severity. Personal data with no deletion path, erasure that misses copies,
   and pre-ticked/bundled consent are the critical classes.

4. Defer, do not duplicate: code-level security (injection, encryption, authz) →
   `/security:review`; credential handling → `/secret-scanning:scan`; deletion cascade
   schema → `/database:review`.

5. When findings exist, offer the next step as a selectable choice (AskUserQuestion):
   "Apply the fixes now (Recommended)" / "Report only". On apply, hand the finding list
   to the shared `task-executor`. In headless or non-interactive runs, report only.
