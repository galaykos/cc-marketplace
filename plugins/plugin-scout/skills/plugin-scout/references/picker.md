# Picker: full-coverage selection over the numbered table

The install picker's selection contract. `SKILL.md` Install step 1 is the
short pointer; this file is the source of truth a reviewer checks against.

## Why the table is the picker surface

AskUserQuestion is hard-capped at 4 options per question and 4 questions
per call — a tool limit, not a choice. A curated-options picker therefore
silently drops suggestions, and a dropped suggestion reads as a
non-suggestion: the user cannot pick what they never saw offered. The fix
is to make the report table itself the selection surface: every suggestion
carries a stable row number, and selection is free-text over those
numbers, so no suggestion is ever unreachable. "The user could have typed
it into Other unprompted" does not count as offered — that is the failure
mode this contract exists to close.

## The question

One AskUserQuestion call, one multiSelect question, asked after the table
prints:

- **"Install recommended set (Recommended)"** — first option, present only
  when at least one tier-1 signal-backed suggestion is not yet installed.
  Its description names every tier-1 pick with its evidence (e.g.
  "laravel — composer.json: laravel/framework ^11"). Picking it selects
  exactly that set: all tier-1, nothing tier-2.
- **"Skip — report only"** — always present. Alone, it ends the run with
  no installs.
- Up to two more option slots may name standout individual picks (e.g. a
  single tier-1 plugin when the recommended set has only one member) —
  optional, never required for coverage, since the table already covers
  everything.
- **Other** is the row-selection channel: numbers and/or plugin names,
  comma- or space-separated, ranges allowed (`3-7`). Combinable with the
  options above — "recommended set" plus `12, 15` installs both.

## Parsing the Other text

- Accept row numbers, plugin names, and `N-M` ranges; case-insensitive
  names; duplicates collapse.
- Rows already installed: skip them, count them in the final summary's
  "skipped (already installed)".
- A token matching nothing in the table: install every token that did
  match, list the unmatched tokens, and ask once more for just those —
  never guess a fuzzy match into an install, and never install anything
  that is not a table row.
- "Skip — report only" combined with row picks is a contradiction:
  the row picks win (an explicit selection is stronger evidence of intent
  than a skip), and say so in one line.

## Boundaries

- Zero tier-1 suggestions: the recommended-set option is omitted, not
  renamed — tier-2 has no "recommended" framing under any flag
  (consistent with `--yes` never touching tier-2; see
  `references/flags.md`).
- Headless: no picker at all — print the exact install command for every
  not-installed suggestion, then stop (same as before this contract).
- Standing, per the marketplace's has-teeth convention: this contract is
  recorded and agent-graded at run time — no script gates it.
