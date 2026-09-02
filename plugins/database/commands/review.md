---
description: Review SQL, schemas, and migrations against sql-best-practices — and against mariadb-best-practices when the engine is MariaDB — with the engine and version detected first, never assumed from a .sql file
argument-hint: [files-or-diff]
---

Review the target in $ARGUMENTS against this plugin's rubrics — audit it, do not rewrite it.

1. Determine scope from $ARGUMENTS — a file, directory, diff/branch reference, or
   design document. If empty, default to recent changes (`git diff` against the merge
   base, falling back to the latest commits).

2. Run a triage pass before the deep read. A trivial, single-file, or purely mechanical
   change earns a one-line verdict — state it and stop. Treat the change as risky and
   take the deep pass when it touches auth, data, migrations, or concurrency, OR spans
   more than 5 files, OR exceeds 300 changed lines (a NEW file counts its full length as
   changed).

   **Hand up when the scope is not this plugin's alone.** This plugin's surface is SQL
   files, migrations, schema definitions, and the query-building code that produces
   statements. If the resolved scope contains files outside it and `/code-review:review`
   is installed, hand the WHOLE scope to it and stop. It is the fan-in for overlapping
   review surfaces and loads every matching stack skill in one pass; running the
   per-stack commands separately is what produces the duplicate findings the fan-in
   exists to prevent, and leaves the stacks nobody happened to invoke unreviewed.
   Deferring is not a smaller answer — the aggregator reaches this plugin's rubrics too.

3. Detect the engine and version BEFORE loading anything — `SELECT version()` output
   when a connection exists, docker-compose/CI image tags, `.env.example`
   `DB_CONNECTION`, or migration-tool config. A `.sql` file alone proves nothing. Then
   load from this plugin and apply each across every statement in scope:

   | Engine detected | Skills |
   |---|---|
   | any, or unknown | `sql-best-practices` |
   | MariaDB (image tag or DSN says `mariadb`) | `sql-best-practices` + `mariadb-best-practices` |

   Keep `sql-best-practices` findings engine-agnostic. On MariaDB, pin every dialect
   finding to the detected version — nothing the version already solves, nothing above
   it — and verify uncertain APIs against https://mariadb.com/kb for that version. Other
   engines have no dialect skill here: their dialect concerns stay in this review, named
   as such. Known miss: a repo whose `DB_CONNECTION=mysql` actually runs MariaDB is
   reviewed engine-agnostic unless the compose image says otherwise.

4. Report findings one line each, sorted by severity (critical, high, medium, low):
   `locator — severity — [CONFIRMED|PLAUSIBLE] problem — fix` — the locator is
   `path:line`, or the section/heading for a design-doc review. Mark a finding
   `CONFIRMED` only with a traced call path, an executed check, or a reproduction;
   absent the ability to execute, findings stay `PLAUSIBLE` — that is acceptable, not a
   failure. No finding without evidence and a concrete fix; no praise, no padding.

   Report every issue you find at this step, including ones you are uncertain about or
   consider low-severity. Do not filter for importance or confidence here — step 5 is
   the filter, and a finding it drops costs less than a real bug silently withheld. The
   `[CONFIRMED|PLAUSIBLE]` tag and the severity are what that filter ranks on.

5. Close with a coverage inventory and a self-refute pass. State `Checked: …` and
   `Not checked: … (why)` so it is explicit what was covered, what was clean, and what
   was skipped — not only what broke. Then run one adversarial self-refute pass over
   every critical finding; if a finding does not survive it, drop or downgrade it with a
   note.

6. When findings exist, offer the next step as a selectable choice (AskUserQuestion):
   Apply all / Apply critical+high only / Report only. On an apply
   pick, dispatch the finding list down the static chain database:database-engineer if installed → task-runner:task-executor if installed → inline — never leave
   the user to retype findings as instructions. In a headless or non-interactive run,
   report only and print the apply command instead of dispatching.

You may close by recommending an ultra-assess re-run when the change was large or
high-risk — recommend it only, never self-execute it.
