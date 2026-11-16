# Spec contracts: shared state, invariants and the module map

Two spec sections that settle **before cards exist** what each card would otherwise guess
alone. Reviews of two real runs (62 findings) traced the largest share to a gap here: one
card's state change broke an assumption another card relied on (a status with no way out, two
writers of one snapshot, a poll that enqueued a job on every tick), and a sibling file already
held the helper a card rewrote. Cards copy their rows from these sections; they do not invent them.

Written by the plan check in `commands/task.md` step 6 (code-architecture `plan-before-code`
when installed, inline otherwise). The planner derives them from the scout report and the
decisions. They are not new questions for the user.

## `## Shared state & invariants`

Required when two or more cards touch one entity or flow, or when the spec has a background
job, a poll, a retry, a lock or money. Otherwise the section is one line: `None: <why>`.

```markdown
## Shared state & invariants

| ID | Entity / flow | States & transitions | Writer(s) | Invariant | Error meaning |
|---|---|---|---|---|---|
| I1 | Order | draft → purchasing → settled · purchasing → orphaned (hold expiry) | OrderSettler only | Every state but settled/orphaned has an exit; lock order Batch → Order → Line | `OrderLocked` = retry later, never refund |
| I2 | Import status poll | GET /imports/{id} | none (read-only) | A GET or poll never enqueues work; the poll stops at done/failed or after 10 min | 404 = import deleted, stop polling |
```

Rules for a row:

- `ID` is `I<n>`, unique in the spec. Cards cite it as `<invariant id="I2">`.
- `Writer(s)` names the one unit allowed to change the state. Two writers is a finding to
  settle now, not a row.
- `Invariant` is one sentence a reviewer can check against a diff: lock order, idempotency key,
  money conservation, "never side-effecting", every state has an exit. A card copies this cell
  **verbatim** into `<invariant id="…">`; `card-set-lint.sh` blocks a card whose text differs.
- `Error meaning` says what each failure means to the caller, so producer and consumer agree.

## `## Module map`

Every multi-card spec. One row per unit the spec creates or extends.

```markdown
## Module map

| Module | Owns | Extension point | Reuse (path:symbol) |
|---|---|---|---|
| `app/Imports/Detectors/` | framework detection for one repo | a new detector class registered in `DetectorRegistry` | `app/Support/RepoReader.php:RepoReader::files` |
```

- `Extension point` is where the next variant plugs in without editing the others. A spec that
  detects one framework by a hard-coded check has no extension point, and the second framework
  becomes a rework card.
- `Reuse` lists existing code the cards must extend instead of rewriting, taken from the scout's
  **Reuse candidates**. A card working in that module carries it as `<reuse path= symbol=>`.

## Standing

| Rule | Standing |
|---|---|
| Rows carry `I<n>` ids and six cells; `None:` carries a reason | **gate**: `spec-ledger-lint.sh` `invariants-shape` |
| A spec with no `## Shared state & invariants` section | **WARN**: `spec-ledger-lint.sh` `no-invariants` |
| A card's `<invariant>` text equals the spec row; the id exists | **gate**: `card-set-lint.sh` `invariant-drift` / `invariant-unknown` |
| A spec invariant no card cites | **WARN**: `card-set-lint.sh` `invariant-orphan` |
| A `<reuse>` path exists; its symbol is in the file | **gate** / **WARN**: `card-paths-lint.sh` `reuse-missing` / `reuse-symbol` |
| The section is needed, complete and true; the module map's extension points are real | **agent-graded**: spec-redteam lens 2 and 4; no script can tell a missing row |
