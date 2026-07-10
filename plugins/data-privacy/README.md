# data-privacy

The regulatory data-handling layer above code-level security.

- **`data-privacy` skill** — know your data (the map), minimize collection, build the
  data-subject rights (access, erasure with reach across logs/caches/backups/processors,
  portability), consent and lawful basis, retention and deletion, pseudonymization, and
  audit trails. Includes a four-question design-time assessment.
- **`/data-privacy:review`** — flag personal data with no deletion path, erasure that
  misses copies, pre-ticked/bundled consent, missing retention, and unclassified
  sensitive data.

Defers code-level security to security, credential handling to secret-scanning, and
deletion-cascade schema to database.
