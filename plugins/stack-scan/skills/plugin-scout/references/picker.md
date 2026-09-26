# Picker: one call by default, the remainder behind a door

The install picker's selection contract. `SKILL.md` Install step 1 is the
short pointer; this file is the source of truth a reviewer checks against.

## The constraint

AskUserQuestion is hard-capped at 4 options per question and 4 questions per
call — a tool limit, not a choice. One slot is reserved for stopping, so a call
offers **15 suggestions, not 16**. Each question also carries a required short
`header` (a few words, truncated hard in the UI). Name what the group IS, not
which tier it is: `Your stack` (tier 1, signal-earned), `Any project 1/2`
(tier 2, the curated core), `Everything else` (tier 3, the remainder). A header
reading `Tier 1` is a number the user has no way to decode in the picker.

The eligible set is every catalog plugin minus stack-scan itself
— recount it, never write the number down. At 15 per call the bill is **one call
and four blocking questions per 15 eligible rows**, on every run, in every repo,
including a Django repo being asked to consider `laravel` and `database` two pages
deep. Derive the cost from the eligible count, never from a written number.

## The contract

1. **Max density on the offered set.** The default is ONE call using all 4
   questions. Questions 1-3 hold the tier-1 signal-backed rows (evidence cited in
   each option's description) and then the tier-2 core rows, 4 options each.
   Never ask a 3-option question while a tier-1 or core row waits unoffered.
2. **Coverage by reachability, not by paging.** Every eligible row is printed in
   the numbered report before the first question and is pickable by number, name
   or range through any question's Other, and through the `pick.sh` escape hatch.
   A row the user can see and type is offered; rendering it as a checkbox is not
   what makes it reachable.
3. **Tier 3 is a door, not a queue.** Question 4 is that door:
   - `Browse the remaining N` — pages tier 3 at 15 slots per call until
     exhausted or stopped
   - `Print the install commands for the rest` — no further questions
   - `Just the picks above` — install and stop
   - `Stop — install nothing`

   Picking `Browse` opts into exhaustive paging for that run. `--all` opts into
   it from the start, skipping the door and paging every row explicitly.

Why a door: the blast radius of not check-boxing a tier-3 row is that the user
types its number, or installs it later in one command, while paging every row costs
a modal question per four rows. A typed number is a real pick.

## Report layout

`SKILL.md`'s Report section is the short pointer; this is the shape it means. A
five-column markdown table over every eligible row is the wrong rendering: the
evidence column is one of three constants in all but the few signal-backed rows,
the installed column is usually constant across all of them, and the whole thing
scrolls roughly two screens before the first question — to carry real information
in four rows.

```
26 eligible · 3 installed · Laravel + Inertia detected

TIER 1 — earned by a signal in this repo
   1  laravel   composer.json — laravel/framework ^11
   2  web-dev   package.json — vite ^5 + vite.config.ts
   3  devops    docker-compose.yml
TIER 2 — any-project core (7)
   4  code-review ✓  5  debugging  6  testing  7  git-workflow
   8  code-architecture  9  secret-scanning  10 command-guard
TIER 3 — no signal in this repo
  worth a look here:  11 brain  12 approaches
  quality/review:     13 toolchain-experts  14 resilience  15 security  16 api-design
  process/planning:   17 taskmaster  18 task-runner  19 overseer
  session-wide:       20 candor  21 hindsight  22 skill-router
  ui:                 23 ui-ux ✓  24 craft-layer
  ...
  companion: ui-ux (#23 ✓) needs ui-libraries — claude plugin install ui-libraries@cc-plugins-marketplace --scope local
```

- Header line: eligible count, installed count, detected stack. The installed
  count replaces a column that would otherwise repeat one value on every row.
- Tier 3 groups by catalog keyword, one group per line, and is **never** truncated
  with "and N more" — the completeness rule is about the report, which is what
  makes the one-call picker honest. The `...` elides groups and every count above
  is illustrative: a run recounts from `references/catalog.md`, which is the only
  place the numbers are real.
- Numbers are stable across the whole run: the picker's option text, the Other
  channel and `pick.sh` all address rows by these numbers.

## Page layout

- The report prints first; every row carries a stable number, and question and
  option text reference those numbers (e.g. "taskmaster (#36)").
- Questions group rows — by tier first, then catalog keyword — so each
  multiSelect question reads as a coherent set.
- **Tier-1 signal-backed picks are the recommended set** and open question 1,
  each option's description citing its evidence (e.g. "laravel — composer.json:
  laravel/framework ^11"). Tier-2 core rows follow, described as "any-project
  core" (`references/any-core.md`). Tier 3 gets no recommended framing anywhere,
  consistent with `--yes` never touching it (`--full` bypasses this picker entirely).
- When coherence and density collide — 4 tier-1 rows and 8 core rows do not
  divide into 3 questions of 4 — **coherence wins**, the under-filled question is
  the last one on the page, and a question never mixes tiers. Without that
  tiebreak two runs on one repo produce different pages.
- Under `--all`, reserve exactly one option slot per call for **"Stop — skip
  remaining"** on the last question. Picking it ends the picker; rows already
  selected on any page still install. Selecting nothing on a page just advances.

## Eligibility and ordering

- **Installed is not a choice.** Before the first question, validate the
  suggestion list against the project-filtered installed set (`SKILL.md`
  Preflight — the raw `claude plugin list` is machine-wide and will wrongly
  filter rows installed in an unrelated repo). Filtered rows keep their ✓ in the report for inventory but never
  appear as an option; picked via Other anyway, they are skipped and counted as
  "skipped (already installed)".
- **Overlap deprioritizes, never hides — and only on a named pair.** Overlap
  means *same job*, not same keyword. Catalog keywords are marketplace taxonomy:
  `review` is the commonest one, carried by better than a third of the catalog, so
  intersecting keywords flags more than half the eligible rows as conflicts —
  `laravel` and `database` among them — the moment `code-review` is installed,
  which `--yes` does on the first run. Recount both figures from
  `references/catalog.md`; the ratio is the argument, not the integers.
  Deprioritize only on an explicit pair:

  | Row | Overlaps |
  |---|---|
  | `ui-ux` | `craft-layer` |
  | `taskmaster` | `task-runner` |
  | `web-dev` | `laravel` |

  A row on no pair is never annotated. A deprioritized row sorts last within its
  tier and its description names the overlap ("overlaps installed ui-ux"). Tier-1
  evidence outranks overlap and **suppresses the annotation entirely** — a
  signal-backed row is never described as overlapping anything.

## Other as the bulk channel

Every question's Other accepts row numbers, plugin names, and `N-M` ranges,
comma- or space-separated, case-insensitive; duplicates collapse. It is how
tier-3 rows are picked without opening the door, and it takes bulk picks like
`3-7, 12` in one line.

- A token matching nothing in the report: install every token that did match,
  list the unmatched tokens, and ask once more for just those — never guess a
  fuzzy match into an install, and never install anything that is not a report
  row.
- Already-installed rows picked via Other: skip, count as "skipped (already
  installed)" in the summary.
- Under `--all`, "Stop — skip remaining" combined with row picks on the same
  page: the row picks install, the stop ends further paging — both honored, say
  so in one line.

## Companions, not shortcuts

There are no suites to offer: the four were retired 2026-09-26, and no plugin may declare
`dependencies` (an update that adds one leaves it uninstalled and the plugin fails to
load). A pair that must travel together — `craft-layer` with `ui-ux` and `ui-libraries`,
`ui-ux` with `ui-libraries` — is a **companion line** under the report
(`references/signals.md` Companions), never an extra option: the companion is already a
numbered row, so the user picks it by number like any other. `--yes` never installs a
companion that is not itself in tier 1 or 2; it prints the line instead. A mass install of
the remaining rows is `--full`'s job, behind its own confirm (`--full --yes` skips it).

## TTY picker escape hatch

For long tables an unbounded interactive multi-select ships at `scripts/pick.sh`
(fzf with TAB-toggle when available, else a numbered prompt with names and
ranges). It needs a real TTY, which model-run Bash lacks, so the flow is: write
the eligible rows to a scratch file as `<number><TAB><label>` lines, print the
exact `! bash <absolute path to pick.sh> <rows file>` command for the user to run
themselves (the `!` prefix runs it user-side and its output lands in the
conversation), then read the returned `PICKED: <numbers>` line and treat those
numbers as row picks under the same rules as Other.

- The script prints `PICKED:` on **every** path that reaches the picker,
  including an fzf abort and an empty selection. A bare `PICKED:` with no numbers
  means "selected nothing" — advance, do not treat it as an error. A non-zero
  exit means the script never ran (bad usage, an unreadable rows file, or no
  TTY), which is different.
- **`PICKED:` carries survivors only.** Rejected tokens go to stderr, which the
  line does not carry, so Other's "list the unmatched tokens and ask once more"
  rule has nothing to read here. Compare the returned numbers against what the
  user was offered and re-offer anything missing; never read absence as a
  decline. Row numbers need not be contiguous — a range spans whatever numbers
  the rows file carries, so filtering installed rows out does not renumber the
  rest.
- Offer it when suggestions exceed two pages (>30 rows); never require it. Under
  the default one-call picker this is the practical way to take many tier-3 rows
  at once, so offer it alongside the `Browse` door rather than only under `--all`.

## Boundaries

- Headless (`references/flags.md` defines the term): no picker at all — print the exact
  install command for every not-installed suggestion, then stop.
- **Standing: recorded and agent-graded — no script gates this contract.** Nothing
  checks that the model used all 4 questions, honored the overlap pairs, or
  offered the door. The one exception is `scripts/pick.sh` itself, which is code:
  `pc_pick_parity` gates that its two copies stay byte-identical, and
  `scripts/__tests__/pick.test.sh` exercises its parser. Neither says anything
  about the prose above.
