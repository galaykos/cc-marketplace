# Changelog

All notable changes to the `ask-ledger` plugin.

## 0.4.0 — 2026-10-08

### Fixed
- **An accounted name is no longer owed by every later turn.** The ledger was
  session-cumulative: in a measured session the prompt "lets check if it works,
  Iinstalled it" ledgered `Iinstalled`, the turn's final message wrote
  `Iinstalled: as named`, and `hooks/gate.sh` still blocked two later turns whose prompts
  never named it ("resume the survey" among them) — spending the session's two blocks on
  it, so the model wrote the line at the end of every turn after. Each Stop now rewrites
  the ledger to the names its final message did not account for. A retry after a block
  owes only the names the block listed (it had to repeat the lines it already wrote); a
  later prompt that names an accounted name again owes it again; the give-up after two
  blocks drops the names it warned about instead of warning about them every turn after.
  The 12-name cap now counts names still owed, not every name the session ever ledgered.
  Residual: a later turn that undoes an accounted name without naming it is not asked
  about. Harness cases 6b and 10-12 in `gate-hook.test.sh` pin it; each fails against
  0.3.1.
- **`hooks/ledger.sh` no longer takes a capital `I` glued to the next word for a name.**
  `I` before a word starting with `i` (`Iinstalled`), an apostrophe-less contraction (`Im`,
  `Ive`) or a listed word that follows `I` (`Ithink`, `Ineed`) is dropped; names that only
  start with `I` (`Inertia`, `Ionic`) still ledger, and so does a glued `I` before an
  unlisted word. Harness cases 13e-13g; 13e and 13f fail against 0.3.1.

## 0.3.1 — 2026-10-04

- **Hook comments cut to contract and limits; behaviour unchanged.** The shared block in `hooks/ledger.sh` and `hooks/gate.sh` keeps its function's contract and limits in a few lines; the derivation and history moved to the marketplace repository's `rationale/`. Both hooks parse to the same code as before, compared by bash's own parser with comments ignored.

## 0.3.0 — 2026-09-30

- **Off-switches are now `/config` options:** `cc_ask_ledger`, under `/config` (or `/plugin configure ask-ledger`), each with today's default. The environment variable (`CC_ASK_LEDGER`) still overrides its option. An interactive `/plugin install` now shows a Configure dialog for these options; it is optional — Esc keeps the defaults.

## 0.2.2 — 2026-09-25

- `hooks/hooks.json` quotes `${CLAUDE_PLUGIN_ROOT}` in every hook command. Claude Code 2.1.282's `plugin validate --strict` rejects the unquoted form (an install path with a space splits into several words); the marketplace's CI pin moved to 2.1.282 with it.

### Fixed
- **`hooks/ledger.sh` no longer ledgers a subagent's hand-back.** A SendMessage report
  arrives as a prompt opening `Another Claude session sent a message:` /
  `<agent-message from="…">` with a `[Subagent hand-back]` frame, and the skip list held
  only `<task-notification>`, `<system-reminder>`, `[SYSTEM NOTIFICATION` and
  `Stop hook feedback:`. In two measured sessions agent ids, their fragments,
  `SubagentHandback`, `NOT` and `PopoverContent` became "things the user asked for"; the
  Stop gate blocked 6 turns and 32+ `<id>: as named` lines reached the user
  (`rationale/2026-09-25-session-plugin-usage-review.md`, finding 3). Three harness cases
  (13b-13d) pin it; each fails against 0.2.1 with the session's own false names.

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
