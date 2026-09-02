# Picker: one call by default, the remainder behind a door

The install picker's selection contract. `SKILL.md` Install step 1 is the
short pointer; this file is the source of truth a reviewer checks against.

## The constraint

AskUserQuestion is hard-capped at 4 options per question and 4 questions per
call — a tool limit, not a choice. One slot is reserved for stopping, so a call
offers **15 suggestions, not 16**. Each question also carries a required short
`header` (a few words, truncated hard in the UI): use the tier and group —
`Tier 1`, `Core 1/2`, `The rest`.

The eligible set is every catalog leaf minus the bundles and plugin-scout itself
— recount it, never write the number down. At 15 per call that is **4 calls and
16 blocking questions**, on every run, in every repo — including a Django repo
being asked to consider `laravel` and `mariadb` four pages deep. This file used
to require exactly that, under the name "full coverage". (It billed the cost at
5 and 20 for months, in two files, neither of which derived it from the 15-per-
call rule stated one paragraph up.)

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

   Picking `Browse` opts into the old behaviour for that run. `--all` opts into
   it from the start, skipping the door and paging every row explicitly.

Why the change: the blast radius of not check-boxing a tier-3 row is that the
user types its number, or installs it later in one command. The ceremony it cost
was 20 modal questions. That is the proportionality law, and the paging pages
survived the theater test only by asserting that a typed number is not a real
pick — stated in this file for months, never argued.

## Report layout

`SKILL.md`'s Report section is the short pointer; this is the shape it means. A
51-row five-column markdown table is the wrong rendering: the evidence column is
one of three constants in ~45 rows, the installed column is usually constant
across all of them, and the whole thing scrolls roughly two screens before the
first question — to carry real information in four rows.

```
51 marketplace plugins · 3 installed · Laravel + Inertia detected

TIER 1 — earned by a signal in this repo
   1  laravel   composer.json — laravel/framework ^11
   2  web-dev   package.json — vite ^5 + vite.config.ts
   3  devops    docker-compose.yml
TIER 2 — any-project core (7)
   4  code-review ✓  5  debugging  6  testing  7  git-workflow
   8  code-architecture  9  secret-scanning  10 command-guard
TIER 3 — no signal in this repo (40)
  stack, unfired:  12 web-dev  13 database  14 craft-layer  15 payments
  quality/review:  16 a11y  17 performance  18 resilience  19 security  20 system-design
  data:            21 database  22 sql  23 stack-scan
  tooling:         24 brain  25 hindsight  26 stack-scan  27 claude-authoring
  ...
  bundles:  php-suite (#1,#2,+2) · quality-suite (#4,#6,#16,+5)
```

- Header line: eligible count, installed count, detected stack. The installed
  count replaces a column that would otherwise repeat one value 51 times.
- Tier 3 groups by catalog keyword, one group per line, and is **never** truncated
  with "and N more" — the completeness rule is about the report, which is what
  makes the one-call picker honest. The `...` above elides groups for brevity in
  this sample only.
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
  consistent with `--yes` never touching it.
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
  filter rows installed in an unrelated repo) AND the dependency lists of any
  installed suite bundle (a leaf an installed suite provides is installed in
  effect). Filtered rows keep their ✓ in the report for inventory but never
  appear as an option; picked via Other anyway, they are skipped and counted as
  "skipped (already installed)".
- **Overlap deprioritizes, never hides — and only on a named pair.** Overlap
  means *same job*, not same keyword. Catalog keywords are marketplace taxonomy:
  `review` alone appears on 26 of 63 rows, so intersecting them flags 30 of the
  51 eligible rows as conflicts, `laravel` and `nextjs` included, the moment
  `code-review` is installed — which `--yes` does on the first run. Deprioritize
  only on an explicit pair:

  | Row | Overlaps |
  |---|---|
  | `ui-ux` | `craft-layer`, `shadcn-studio`, `design-preview`, `registry-source` |
  | `taskmaster` | `task-runner`, `orchestration` |
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
  row or a suite named in the under-report shortcut list.
- Already-installed rows picked via Other: skip, count as "skipped (already
  installed)" in the summary.
- Under `--all`, "Stop — skip remaining" combined with row picks on the same
  page: the row picks install, the stop ends further paging — both honored, say
  so in one line.

## Suites as shortcuts

Leaves do not depend on each other; a `*-suite` is a convenience bundle that
installs its members as dependencies. The picker treats a suite as a shortcut,
never a default:

- A not-installed suite whose `plugin.json` dependencies cover 3+ suggested
  not-installed rows is listed by name under the report and earns one explicit
  option on the first page it fits. Its description names **at most 4** covered
  rows plus a count ("php-suite — installs #1, #2, #4, #9 and 3 more as
  dependencies; clean removal via /php-suite:uninstall").
- An all-in bundle is never offered as a shortcut option. A bundle covering the
  entire remainder is not a shortcut, it is the opposite of a pick — name it in
  one line under the report and leave it there.
- Suites never enter the numbered report. They are pickable by the name shown in
  that under-report list, which is the one exception to "never install anything
  that is not a report row".
- Picking a suite is one explicit pick for the bundle: install it with the same
  scope rules; its members then count as installed for every later page
  (eligibility filters them out) and dedupe against individual picks of the same
  members. Within a single call a suite picked in question 1 cannot filter
  questions 2-4 — dedupe at install time covers that residual.
- `--yes` never auto-installs a suite — the auto-select set stays tier-1 and
  tier-2 core leaves only; a mass install of anything else must be a human pick.

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
