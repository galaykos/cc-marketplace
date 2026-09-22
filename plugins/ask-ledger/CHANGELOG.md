# Changelog

All notable changes to the `ask-ledger` plugin.

## 0.1.1 — 2026-09-22

### Fixed
- `hooks/ledger.sh` mined harness-injected turns — a subagent's completion notification,
  a Stop-hook relay, a system reminder — as if they were the user's ask, so a review
  report's "NULL", "WHERE", "FAIL" became ledger names the Stop gate then blocked on
  (two blocked turns in one session on 2026-09-22). Those turns are skipped; two
  harness cases pin it.

## 0.1.0 — 2026-09-20

### Added
- `hooks/ledger.sh` (UserPromptSubmit): destructures a work-shaped prompt into the things
  it names — proper nouns, quoted terms, digit-letter tokens — into a session ledger, and
  states the gate shape once per prompt that added entries.
- `hooks/gate.sh` (Stop): refuses a final message without an accounting line per ledgered
  name (`as named` | `substituted → what, why` | `omitted → why`); at most two blocks per
  session. Gate on the shape, agent-graded on the truth, said in its header.
- Eval `named-things-accounted` (the Digimon prompt; control arm recorded at 6/6 silent
  substitution), two harnesses. Built at the user's request after
  `rationale/fable-distillation-2026-09-18.md` §4 measured the silent avert that candor's
  reason-triggered guard cannot see.
