# Changelog

All notable changes to the `ask-ledger` plugin.

## 0.4.2 — 2026-10-14

### Fixed
- **A paste is no longer read as the ask.** `<pasted_content id="…">` blocks fed both the
  work-shape test and name extraction: in five reviewed sessions the host's paste id, log
  tokens and a pasted dialog's quoted label were ledgered, a paste's own `update` made a
  question work-shaped, and every one of the five blocks was a false positive (in two the
  model told the user to turn the gate off). Each `<pasted_content …>…</pasted_content …>`
  span is now cut first; ask text on the same line as either tag still counts. Residual: a
  name that appears only inside a paste no longer ledgers. Harness cases 13h, 13i and 13k
  in `ledger-hook.test.sh` pin it; each fails against 0.4.1.
- **One harness-frame list, shared.** The prompt prefixes this hook skips (system reminder,
  task notification, Stop hook feedback, another session's message, a hand-back) and the
  paste cut now come from the byte-locked `templates/blocks/prompt-shape.md`, the copy
  skill-router and code-review paste too, so the three lists cannot drift apart again.
  One widening: a `<task-notification` that carries attributes is also skipped. Case 13n
  pins it and fails against 0.4.1. Two narrowings: an opening `<pasted_content` tag with no
  closing tag after it now cuts only itself, where the cut used to swallow the rest of the
  prompt and its ask; and the hand-back marker makes a frame only where a line opens with
  it, so an ask quoting it mid-sentence ledgers. Cases 13o and 13p pin them; each fails
  against 0.4.1. Standing: gate (`ledger-hook.test.sh`; the byte lock is `validate.sh`'s
  shared-block check).
- **A `/loop` wakeup writes no ledger.** A scheduled fire reaches the hook as plain prompt
  text. In two reviewed sessions it was always text the model had written for
  ScheduleWakeup, so its names were the model's own. The `/loop` that sets a user's loop
  is a slash command this hook already skips. A host `/loop` tick (`# Autonomous loop …`,
  `# /loop tick …`) is now a frame. A prompt equal to a ScheduleWakeup or CronCreate call's
  `prompt` in this context's transcript is skipped (the shared block's
  `cc_prompt_scheduled`; the payload does not mark it). Residual: a prompt the user retypes
  verbatim while its call is in the transcript is skipped too. Cases 13q and 13r fail
  against the hook before this change; 13s, a typed ask beside the call, still ledgers.
- **An in-word apostrophe no longer opens a quote.** In "doesn't or didn't" the span
  between the two apostrophes ledgered as the name `t or didn`. Apostrophes between two
  letters are masked while quoted terms are found and restored inside them, so
  `"Stripe's checkout"` still ledgers as typed. Residual: the second apostrophe of
  `rock'n'roll` still opens a quote. Cases 13j, 13l and 13m pin it; each fails against 0.4.1.
- **A block asks for the answer's verdict before the accounting lines.** The retry a block
  forces is the last thing the user reads, and when it held only `<name>: …` lines users
  re-asked the question already answered above it. The block now says to restate the
  answer's one-line verdict first. Whether the retry does so is agent-graded; case 4b in
  `gate-hook.test.sh` pins the wording only.

## 0.4.1 — 2026-10-11

### Fixed
- **A quoted phrase is no longer ledgered as a name.** Any quoted span of 2-40 characters
  counted, so a review ask quoting the axis "take usage without any result" ledgered the
  whole description and the Stop gate blocked the turn until the model wrote an
  accounting line for it — a full extra turn for a name that was never a deliverable. A
  quoted span now ledgers only at one to three words (`"digimon"`, `'checkout total'`).
  Residual: a quoted name of four or more words is no longer ledgered. Harness case 1b in
  `ledger-hook.test.sh` pins it and fails against 0.4.0.

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
