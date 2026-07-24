# The section ledger — where picks live, and what enforces them

A pick the build does not read is a wasted exchange. The ledger is the artifact
that carries decisions from the user to `/ui-ux:build` and then to the audit, and
it is the reason a guided run produces a different page from a one-shot run.

It is the section-level sibling of taskmaster's `## Visual contract`: same job,
same teeth, different granularity. Where a visual contract binds a spec's staged
picks, this binds a page's per-section treatment.

## Where it lives

The ledger is WORKING material, not a shipped file. It lives with the run's other
working artifacts — a taskmaster docs area when the project has one, otherwise the
session's scratch area — and never inside a plugin or a shipped `src/` tree. When
a taskmaster spec exists, the ledger belongs in that task's directory beside the
spec it elaborates.

Never write it into the built application. A landing page that ships a table of
the decisions behind it is the kit-page-as-route mistake in another form.

## Schema

One row per agenda item, in spine order:

| Field | Holds |
| --- | --- |
| `slot` | the offer-contract spine slot (`plain-what`, `audience`, `problem`, `how-it-works`, `price`, `proof`, `objection`, `cta`, or `order-and-rhythm`) |
| `section` | the section this became, by id/anchor — the handle the audit greps for |
| `choice` | the picked option, one line: what the section IS |
| `locks` | what the pick commits: a component, an instrument, a data need, a copy slot |
| `why` | the one-line tradeoff that decided it |
| `source` | `user` (picked) or `auto` (decided at the cap, or headless) |

A `long-scroll` run adds one `order-and-rhythm` row covering sequence, section-shape
variety, CTA cadence, and where the heavy instruments sit.

Rows are append-only within a run. A revision replaces `choice`/`why` in place and
keeps the row — the audit checks the FINAL state, not the history.

## How it reaches the build

`design-research`'s build task is the only channel into `/ui-ux:build`, so the
ledger travels in it: each section's `choice` and `locks` become that section's
line in the build task, alongside the patterns mining supplied. The build task
already names which spine slots each section carries
(`design-research/references/brief-templates.md`); the ledger makes those lines
DECIDED rather than inferred.

A ledger written and left in the working directory, with a build task that does
not carry it, is the same failure mode as a concept generated and never threaded
into the briefs — the artifact exists, the build defaults anyway.

## What the audit checks (teeth)

When a ledger exists for the run, `/craft-layer:audit` reads it and verifies
CONFORMANCE — the built page against what was chosen:

- every ledger row has a corresponding section in the build (grep the `section`
  id/anchor); a row with no section is a dropped decision;
- no marketing section exists that no row accounts for; an unledgered section is
  scope the user never approved;
- each row's `locks` is present — the named instrument, component, or copy slot
  actually ships;
- `source: auto` rows are REPORTED, not flagged: they are legitimate (the cap, a
  headless run) but the user should see which parts of the page they did not
  choose.

A mismatch is one finding per row, naming the slot. Absent ledger → this gate does
not run at all; a one-shot build is not a finding, it simply was not guided.

The conformance check is presence and correspondence, never a judgement about
whether the chosen treatment was good — that decision was the user's.

## Anti-patterns

- **Ledger in the shipped tree** — committing decision material into `src/` or a
  plugin directory; it is working material.
- **Ledger not threaded** — picks recorded but the build task written from the
  concept alone.
- **Retro-fitting** — writing ledger rows after the build to describe what was
  made; the ledger records DECISIONS, and a retro-fitted one makes the
  conformance gate tautological.
- **Auto rows hidden** — omitting `source` so the user cannot tell which sections
  they actually chose.
- **Rows without `locks`** — a pick that commits nothing checkable, which the
  build can satisfy with anything.
