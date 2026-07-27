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
  a later page. Tier-2 has no recommended framing (consistent with
  `--yes` never touching tier-2; see `references/flags.md`).
- Reserve exactly one option slot per call: **"Stop — skip remaining"**
  on the last question. Picking it ends the picker; rows already selected
  on any page still install. Selecting nothing on a page just advances.
- Already-installed rows are never offered — they are not choices.

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

## Boundaries

- Headless: no picker at all — print the exact install command for every
  not-installed suggestion, then stop.
- Standing, per the marketplace's has-teeth convention: this contract is
  recorded and agent-graded at run time — no script gates it.
