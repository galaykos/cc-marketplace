# ultra-deep-research

A deep-research harness for Claude Code. Ask it a hard question and it fans out
parallel web searches, tiers sources by provenance, extracts date-stamped claims,
**adversarially refutes** them, surfaces contradictions instead of hiding them, and
synthesizes a cited report — inline and saved to `research/<topic>-<date>.md`.

Built to beat research's core failure mode: a plausible claim echoed across low-quality
pages that all copied one unverified origin.

## Trigger it

- Say **`ultra-deep-research <topic>`** — or "deep research", "research this
  thoroughly", "what's the latest on…", "fact-check this" — and the skill fires.
- Or run the command: **`/ultra-deep-research:research <topic> [--ultra|--standard]`**.

## Depth

| Depth | Engine | When |
|-------|--------|------|
| **standard** | Portable parallel-Agent fan-out, one refutation pass | Default; runs for any user, no opt-in. |
| **ultra** | Workflow `loop-until-dry` fan-out + multi-vote refutation panels + completeness critic | `ultra-deep-research` / `--ultra` / contested topics. Needs the Workflow tool; falls back to standard-with-extra-rounds if unavailable. |

## What it ships

- **Skill** `ultra-deep-research` — the methodology and orchestration recipe (the
  loop, source tiers, accuracy rules, prompt hardening). Detailed scripts and the report
  template live in its `references/`.
- **Command** `/ultra-deep-research:research` — one-shot entry point with a depth flag.
- **Agent** `researcher` — one shard of the fan-out: searches, fetches, and returns
  atomic, cited, date-stamped, tiered claims for a single facet.
- **Agent** `verifier` — adversarial refuter: tries to break each load-bearing claim
  before it is trusted.

## What you get back

A report that leads with the answer, carries inline `[n]` citations, states per-section
confidence with reasons, lists sources with their tier and date, keeps a contradiction
ledger for anything the sources disagree on, and names what it could **not** verify.

## Accuracy guarantees

Every load-bearing claim is corroborated by ≥2 independent quality sources, date-stamped,
and attacked before it is trusted. No fabricated URLs, dates, or figures — an explicit
"not found" over a confident guess. Time-sensitive answers are stamped "as of <date>".
