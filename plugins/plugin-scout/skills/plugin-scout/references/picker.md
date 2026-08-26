# Picker: max-density paged selection over the numbered table

The install picker's selection contract. `SKILL.md` Install step 1 is the
short pointer; this file is the source of truth a reviewer checks against.

## The constraint and the contract

AskUserQuestion is hard-capped at 4 options per question and 4 questions
per call — a tool limit, not a choice. A single-question picker therefore
shows at most 4 options and silently relegates everything else to
free-text, and a suggestion the user never saw offered reads as a
non-suggestion. Two rules close that failure mode:

1. **Max density.** Every picker call uses all 4 questions x 4 options —
   up to 16 explicit slots — before anything falls back to free-text.
   Never ask a 3-option question while suggestions wait unoffered.
2. **Full coverage.** Page additional calls until every not-yet-installed
   suggestion has appeared as an explicit option, or the user stops.
   "The user could have typed it into Other" does not count as offered.

## Page layout

- The report table prints first; every row carries a stable number, and
  question/option text references those numbers (e.g. "taskmaster (#36)").
- Questions group rows — by tier first, then catalog keyword category —
  so each multiSelect question reads as a coherent set, up to 4 options
  each.
- **Tier-1 signal-backed picks are the recommended set**: they open the
  first page, each option's description citing its evidence (e.g.
  "laravel — composer.json: laravel/framework ^11"). They never wait for
  a later page. Tier-2 core rows follow directly, described as
  "any-project core" (`references/any-core.md`). Tier-3 has no
  recommended framing (consistent with `--yes` never touching tier-3;
  see `references/flags.md`) — but full coverage still applies to it:
  the paging ends only when every tier-3 row, including "no signal
  detected" completeness rows, has been offered or the user stopped.
- Reserve exactly one option slot per call: **"Stop — skip remaining"**
  on the last question. Picking it ends the picker; rows already selected
  on any page still install. Selecting nothing on a page just advances.

## Eligibility and ordering

- **Installed is not a choice.** Before the first page, validate the
  suggestion list against `claude plugin list` AND the dependency lists
  of any installed suite bundle (a leaf an installed suite provides is
  installed in effect — check the suite's `plugin.json` dependencies).
  Filtered rows keep their ✓ table row for inventory but never appear as
  a picker option; picked via Other anyway, they are skipped and counted
  as "skipped (already installed)".
- **Overlap deprioritizes, never hides.** A row whose catalog keywords
  intersect an installed plugin's keywords is a potential conflict: it
  sorts to the final pages within its tier, and its option description
  names the overlap (e.g. "overlaps installed code-review"). It is still
  offered — deprioritization orders pages, full coverage decides them.
  Tier-1 evidence outranks overlap: a signal-backed pick stays on the
  first page even when it overlaps something installed.

## Other as the bulk channel

Every question's Other accepts row numbers, plugin names, and `N-M`
ranges, comma- or space-separated, case-insensitive; duplicates collapse.
It complements the explicit options (bulk picks like `3-7, 12` in one
line) — it never substitutes for offering a row.

- A token matching nothing in the table: install every token that did
  match, list the unmatched tokens, and ask once more for just those —
  never guess a fuzzy match into an install, never install anything that
  is not a table row.
- Already-installed rows picked via Other: skip, count as "skipped
  (already installed)" in the summary.
- "Stop — skip remaining" combined with row picks on the same page: the
  row picks install, the stop ends further paging — both honored, say so
  in one line.

## Suites as shortcuts

Leaves do not depend on each other; a `*-suite` is a convenience bundle
that installs its members as dependencies. The picker treats a suite as a
shortcut, never a default:

- A not-installed suite whose `plugin.json` dependencies cover 3+
  suggested not-installed rows earns one explicit option on the first
  page it fits, described as "installs N of the suggested rows (#a, #b,
  …) as dependencies; clean removal via /<suite>:uninstall". Suites never
  enter the numbered table — the option is the whole surface.
- Picking a suite is one explicit pick for the bundle: install it with
  the same `claude plugin install <suite>@cc-plugins-marketplace` scope
  rules; its members then count as installed for every later page
  (eligibility filters them out) and dedupe against individual picks of
  the same members.
- `--yes` never auto-installs a suite — the auto-select set stays
  tier-1 and tier-2 core leaves only; a mass install of anything else
  must be a human pick.

## TTY picker escape hatch

For very long tables an unbounded interactive multi-select ships at
`scripts/pick.sh` (fzf with TAB-toggle when available, else a numbered
prompt with ranges). It needs a real TTY, which model-run Bash lacks, so
the flow is: write the eligible rows to a scratch file as
`<number><TAB><label>` lines, print the exact
`! bash <absolute path to pick.sh> <rows file>` command for the user to
run themselves (the `!` prefix runs it user-side and its output lands in
the conversation), then read the returned `PICKED: <numbers>` line and
treat those numbers as row picks under the same rules as Other. Offer it
when suggestions exceed two pages (>32 rows); never require it.

## Boundaries

- Headless: no picker at all — print the exact install command for every
  not-installed suggestion, then stop.
- Standing, per the marketplace's has-teeth convention: this contract is
  recorded and agent-graded at run time — no script gates it.
