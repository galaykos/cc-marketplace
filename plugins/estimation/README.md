# estimation

Task sizing and effort estimation: S/M/L/XL classes with concrete anchors,
reference-class calibration against work actually completed, uncertainty
multipliers for unknowns, split triggers for oversized work, and
estimate-vs-actual tracking persisted to a durable append-only ledger (with
deferred-work parking) so calibration accumulates across runs.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install estimation@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/estimation:size [task-or-list]` | Size a task or task list — S/M/L/XL class per item with anchor comparison, uncertainty flag, and split recommendation for anything L+ |

## Example

```bash
/estimation:size "add rate limiting to the public API"
/estimation:size taskmaster-docs/tasks/   # size a whole card directory
/estimation:size                          # sizes the active task list in this session
```

Output is one row per task (class, the completed anchor it resembles,
uncertainty flag, split verdict) plus a weighted totals line (S=1, M=3, L=8;
XL is never weighted — it gets a split or spike instead). Sized items are
appended to `taskmaster-docs/estimation-ledger.md` so the next run inherits
real local anchors. For lists of three-plus items, the command offers to hand
the weights to `/task-runner:plan`.

## Pairs well with

- **task-runner** — `/task-runner:plan` consumes the classes directly as
  weights for its critical-path and speedup math
- **taskmaster** — L and XL items route to a card split via the taskmaster
  pipeline instead of being estimated whole
- **hindsight** — misses that repeat across sessions surface as friction
  findings via `/hindsight:harvest`
- **approaches** — spikes and design-uncertainty go through
  `/approaches:compare` before a class is assigned
