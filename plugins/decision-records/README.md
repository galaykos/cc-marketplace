# decision-records

Architecture Decision Records: persist every significant technical choice —
approach picks, schema shapes, dependency adoptions — to `docs/adr/` with
context, rejected options, consequences, and a revisit-when trigger. Status
lifecycle proposed/accepted/superseded.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install decision-records@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/decision-records:new [decision]` | Create a new Architecture Decision Record in `docs/adr/` from the decision just made or described in arguments |

## How it works

The `decision-records` skill fires when a significant decision lands in
conversation — an approach pick, schema or API shape, dependency adoption,
pattern choice — and offers to persist it before the reasoning evaporates.
Records are numbered `NNN-kebab-slug.md`, one decision per record, and are
immutable history: changing course means a new ADR that marks the old one
`superseded by NNN`. Before proposing a decision in an area, the skill checks
`docs/adr/` for standing records so accepted choices aren't re-litigated.

## Example

```bash
/decision-records:new           # captures the most recent significant decision in this conversation
/decision-records:new store report exports on disk, not in the database
```

## Pairs well with

- **approaches** — a deliberation pick's options table and kill-trigger map one-to-one onto the ADR template
- **build-vs-buy** — take/wrap/write verdicts are exactly the dependency-adoption decisions worth recording
- **taskmaster** — grill ledger rows with architectural weight get the same persist offer
- **retrospective** — learnings route into their sinks; decisions route into ADRs
