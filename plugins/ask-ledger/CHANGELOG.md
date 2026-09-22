# Changelog

All notable changes to the `ask-ledger` plugin.

## 0.2.1 — 2026-09-22

### Changed
- **`hooks/gate.sh`'s blocking reason names `CC_ASK_LEDGER=off`.** `hooks/ledger.sh`
  already printed its off switch; the Stop gate — the one that actually refuses the turn
  — did not, so the only message a blocked reader sees was the one message that never
  said how to turn it off.

## 0.2.0 — 2026-09-22

### Added
- `hooks/ledger.sh` drops every candidate the session project's tracked tree already
  carries before it reaches the ledger (`git grep -qliF`, falling back to `rg -qiF` when
  git grep errors out; no git work tree → no filter, the previous behaviour). "Fix the
  N+1 in OrderController when Laravel eager-loads Invoice and Payment relations under
  Inertia" ledgered six entries and the Stop gate then demanded an accounting line for
  every class the ask had asked it to REPAIR; against a Laravel fixture repo the same
  prompt now ledgers one (`N+1`), while "add a Stripe checkout" in a repo with no Stripe
  still ledgers Stripe. Bounded to the ledger's own 12-name cap — 12 tree-wide greps on
  this marketplace measured 0.32 s against a 5 s hook timeout. Three residuals, stated in
  the hook header and the README: no work tree means no filter, `git grep` reads tracked
  files only, and a name the ask ADDS to something the repo already mentions is dropped
  with the rest. Three harness cases pin it.

### Changed
- README: the `claude plugin eval` invocation now shows the `--allow-tools Write Edit`
  grant as mandatory and states what the ungranted command actually does — the suite
  loads and then declines the case (`not granted … Write, Edit`, CLI 2.1.278), so a run
  that looks clean has measured nothing.

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
