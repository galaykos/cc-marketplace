# Changelog — laravel

Consumer-facing changes only. Newest first. Started at 0.10.3; earlier versions have no entries rather than invented ones.

## 0.11.3 — 2026-11-23

- **backend-engineer reaches the rubric skills without a dispatcher.** When no dispatch injects a skill's Read path, the worker now Reads this plugin's skills at `${CLAUDE_PLUGIN_ROOT}/skills/<name>/SKILL.md` and another plugin's from its `installPath` in `claude plugin list --json`, falling back to the plugin cache. Only skills matching the detected stack are read, and one it cannot find or is denied is named in its return as not applied. Before, a direct dispatch with no skill-router evidence ran without its rubric and said nothing. A literal `CLAUDE_PLUGIN_ROOT` inside a skill it Reads is read as that skill's plugin root, so scripts a skill names resolve. Standing: recorded; `pc_agent_skill_reach` checks the body names each skill, not that the agent reads it.
- **backend-engineer names mariadb-best-practices for a MariaDB engine.** "(plus the detected dialect)" named no skill a worker could find. Standing: recorded.

## 0.11.2 — 2026-11-21

- **The queued-job example is idempotent now.** The "good" `ChargeOrder` in `laravel-best-practices`' `references/queue-payloads.md` guarded the charge with `if ($order->isPaid()) return;`, a check-then-act that lets two concurrent runs both charge. It now passes an idempotency key fixed per order to the payment provider and says what holds without one: a unique claimed row inserted before the charge. Stripe's key behaviour (`Idempotency-Key`, keys prunable after 24 hours) was checked against its API docs.
- The skill's pointer to that file no longer promises serialization edge cases and a retry/backoff matrix the file never held.
- The README labels `i18n_parity.py` "gate where run (exit 1); that it ran is recorded", as the skill already did.

## 0.11.1 — 2026-11-16

- **`backend-engineer` checks before writing new code and before handing back.** Before adding a helper, class, component, factory or status list it greps the repo for one and extends what exists; it extracts a shape on its second use; after fixing a pattern it greps sibling files for the same pattern; it keeps a card's `<invariant>`, `<reuse>` and `<interface>` lines and reports how each invariant holds. Before hand-back it runs the project's own linters and analyzers on every touched file, tests included, in addition to the tests, and reports an analyzer whose config skips one of them. Why: reviews of two real runs traced most post-build fix rounds to cross-card contract gaps and code rewritten beside an existing helper, and one run never ran its configured analyzer. Its own verify step now reads "tests and `php artisan` checks, then the project checks", no longer "or a static analyzer".
- Standing: agent-graded (agent text; no harness reads a worker's return).

## 0.11.0 — 2026-11-08

- **New `scripts/i18n_parity.py`, a translation parity checker.** It compares every locale under `lang/` (PHP and JSON) to the base locale and names missing keys, extra keys and placeholder sets that differ. It also reads i18next and vue-i18n JSON. It parses PHP and never runs it; a file it cannot read is reported, not guessed. It skips the `lang/php_<locale>.json` files laravel-vue-i18n generates. Exit 0 parity, 1 findings, 2 usage or no base locale, 3 no locale files. `laravel-best-practices` says when to run it.
- README lists `scripts/i18n_parity.py`.

## 0.10.4 — 2026-10-31

- **`laravel-best-practices` now warns that `->change()` drops every modifier you do not restate (Laravel 11+).** The leverage map's Laravel 11 section adds that rule. It also adds Carbon 3's float and possibly negative `diffIn*` results, the `mariadb` driver's native `uuid()` column, and 11's end of support (security fixes ended 2026-03-12).
- **`inertia-best-practices` says where v3 puts the page data**: a `<script type="application/json">` element, no longer the `data-page` attribute. Props stay visible in View Source either way.
- **New eval case `change-drops-modifiers`.** It is an unmeasured candidate: no control arm has run.

## 0.10.3 — 2026-10-28

- **The `inertia-best-practices` skill's description now reads in short, plain sentences.** Same adapters, topics and version note; it keeps the words the model matches it on.
