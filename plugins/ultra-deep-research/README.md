# ultra-deep-research

A deep-research harness for Claude Code. Ask it a hard question and it fans out
parallel web searches, tiers sources by provenance, extracts date-stamped claims,
**adversarially refutes** them, surfaces contradictions instead of hiding them, and
synthesizes a cited report — inline and saved to `research/<topic>-<date>.md`.

Built to beat research's core failure mode: a plausible claim echoed across low-quality
pages that all copied one unverified origin.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install ultra-deep-research@cc-plugins-marketplace
```

## Trigger it

- Say **`ultra-deep-research <topic>`** — or "deep research", "research this
  thoroughly", "what's the latest on…", "fact-check this", a market/competitive/
  technical scan, a state-of-the-art or literature review — and the skill fires.
- **Or hand it one document.** "What does this contract/RFP/standard/filing/200-page
  PDF actually say" routes here too, and switches the engine (below). Those words were
  missing from the skill's description until 0.7.0 — the coverage engine landed
  2026-08-02 and spent 44 days reachable only by naming the plugin.
- Or run the command: **`/ultra-deep-research:research <topic> [--ultra|--standard]`**.

## Depth

| Depth | Engine | When |
|-------|--------|------|
| **standard** | Portable parallel-Agent fan-out, one refutation pass | Default; runs for any user, no opt-in. |
| **ultra** | Workflow `loop-until-dry` fan-out + multi-vote refutation panels + completeness critic | `ultra-deep-research` / `--ultra` / contested topics. Needs the Workflow tool; falls back to standard-with-extra-rounds if unavailable. |

## Two engines, one fork

| Subject | Engine | Deliverable |
|---|---|---|
| A question whose answer is spread across the web | **corroboration** — fan out, tier, cross-check, adversarially refute | cited report with a contradiction ledger |
| ONE authoritative document (contract, RFP, standard, filing, long PDF) | **coverage** — nothing can corroborate the only source, so refuting a clause against the web is a category error | coverage manifest FIRST (pages read, pages not read and why, pages unreadable), page/clause anchors on every load-bearing claim, "does not say X" kept apart from "says the opposite" |

The fork is declared at step 1 of the skill's loop; the recipe is
`skills/ultra-deep-research/references/local-corpus.md`. Both engines share the
verifier, the contradiction ledger (pointed inward for a document) and the report
template. Worth knowing before you hand over a long PDF: `Read` takes at most 20 PDF
pages per request, so one naive call returns a prefix and reports it as the whole —
which is what the manifest's request count exists to expose.

## What it ships

- **Skill** `ultra-deep-research` — the methodology and orchestration recipe: the
  loop, source tiers, the orchestrator's accuracy rules, the local-corpus fork.
  Detailed scripts and the report template live in its `references/`.
- **Command** `/ultra-deep-research:research` — one-shot entry point with a depth flag.
- **Agent** `researcher` — one shard of the fan-out: searches, fetches, and returns
  atomic, cited, date-stamped, tiered claims for a single facet.
- **Agent** `verifier` — adversarial refuter: tries to break each load-bearing claim
  before it is trusted.

## What you get back

A report that leads with the answer, carries inline `[n]` citations, states per-section
confidence with reasons, lists sources with their tier and date, keeps a contradiction
ledger for anything the sources disagree on, and names what it could **not** verify.

## Accuracy discipline (agent-graded, with one mechanical gate)

Every load-bearing claim is corroborated by ≥2 independent quality sources, date-stamped,
and attacked before it is trusted. No fabricated URLs, dates, or figures — an explicit
"not found" over a confident guess. Time-sensitive answers are stamped "as of <date>".

Since 0.5.0 the verdict FORMAT half has teeth: `scripts/verdict-lint.sh` rejects a
`confirmed` verdict missing a verbatim quote, retrieval timestamp, or corroborating
source (the skill demotes it to `contested`), with a fixture harness CI runs. Whether
the quote is real and the sources independent stays agent-graded — the lint cannot
know, and saying so is the point.

## Pairs well with

Two plugins call this one; neither is required by it:

- **craft-layer** — `creative-director` runs a live research pass through the skill when
  a dispatch opts in
- **code-architecture** — `coding-entry` routes "what is the state of X" and unfamiliar
  vendors to `/ultra-deep-research:research`

## Suite membership

None — standalone by design (recorded; nothing enforces this). A research run
fans out parallel web searches and can escalate to a Workflow-driven
loop-until-dry sweep — a token cost that should be chosen per install, not
ride in silently with a bundle (workflow-suite leaves it out for that reason).
