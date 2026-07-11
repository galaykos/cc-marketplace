---
name: ultra-deep-research
description: Use when a question needs a deep, multi-source, fact-checked answer with the latest data — "ultra-deep-research", "deep research", "research this thoroughly", "what's the latest on", "fact-check this", "find and refute", competitive/market/technical scans, or any claim that must be corroborated and dated. Fans out parallel searches, tiers sources by provenance, extracts date-stamped claims, adversarially refutes them, surfaces contradictions, and synthesizes a cited report. Adversarial verification discipline is orchestration:verification-panels; fan-out prompt contracts are orchestration:delegation-contracts.
---

# Ultra Deep Research

Produce answers that survive scrutiny: every load-bearing claim corroborated by
independent quality sources, date-stamped, and attacked before it is trusted.
The failure mode of research is confident wrongness — a plausible claim echoed
across low-quality pages that all copied one unverified origin. This harness is
built to catch exactly that.

## Depth ladder

Pick depth from the ask; `ultra-deep-research` (or `--ultra`) forces the top rung.

- **standard** — portable parallel-Agent fan-out, one refutation pass. Default.
- **ultra** — Workflow-driven `loop-until-dry` fan-out with multi-vote refutation
  panels and a completeness critic. Fires on the `ultra-deep-research` trigger, on
  `--ultra`, or when the topic is high-stakes/contested. Needs the Workflow tool
  (ultracode / explicit opt-in); if unavailable, run the standard path with extra
  rounds instead of failing.

Read `references/orchestration.md` for the exact fan-out and Workflow scripts.

## The loop

1. **Scope & decompose.** Restate the question in one line. Split it into 4–8
   orthogonal facets (sub-questions) that together cover it with no overlap. Mark
   each facet `time-sensitive` if its answer depends on recent events — those
   demand fresh sources and an explicit "as of <date>".
2. **Fan out.** One `researcher` subagent per facet, in parallel (standard) or as a
   Workflow pipeline (ultra). Each shard runs several search angles, fetches the top
   3–5 sources, and returns **atomic claims** — one fact each, with a verbatim-grounded
   quote, the source URL, its publication date, and a source tier. No claim without a
   page the shard actually fetched. Fabricated or unfetched URLs are disqualifying.
3. **Tier & corroborate.** Weight every claim by source tier (see below). A
   load-bearing claim needs **≥2 independent Tier-1/2 sources** that do not trace to
   the same origin. One source, or many that circularly cite one blog, is `unconfirmed`.
4. **Refute.** Route each load-bearing claim to the `verifier` subagent, which tries
   to *break* it: does the cited page actually say this, is it current, is the
   citation circular, is there stronger counter-evidence? Standard = one refuter;
   ultra = a panel voting, majority-refute kills the claim. Survivors are `confirmed`;
   the rest are downgraded or dropped.
5. **Ledger contradictions.** Where sources disagree, never silently average. Record
   the disagreement, then adjudicate by provenance: prefer the primary source, the
   higher tier, and the more recent — and if it stays unresolved, ship it as an open
   contradiction, not a fake consensus.
6. **Gap check (ultra: loop-until-dry).** A completeness critic asks: which facet is
   thin, which claim is still unconfirmed, which fact is stale? Spawn another round on
   the gaps. Repeat until two consecutive rounds surface nothing new, or the budget is
   spent — then say what was left uncovered rather than implying full coverage.
7. **Synthesize.** Write the report per `references/report-template.md`: direct answer
   first, per-section confidence, inline `[n]` citations, contradiction ledger, tiered
   source list, and open questions. Print it inline **and** write it to
   `research/<slugged-topic>-<YYYY-MM-DD>.md` (create `research/`; use the scratchpad
   dir if the project is read-only).

## Source tiers

Rank every source and let the tier drive its weight:

- **Tier 1 — primary/authoritative.** Official docs, standards, filings, court records,
  datasets, original research, first-party statements, the actual code/spec.
- **Tier 2 — reputable secondary.** Established press with editorial standards,
  peer-reviewed literature, recognized domain institutions.
- **Tier 3 — tertiary.** Blogs, forums, wikis, vendor marketing — usable for leads and
  color, never as sole support for a load-bearing claim.
- **Tier 4 — low-trust.** SEO farms, undated content, unattributed AI text, circular
  aggregators. Use only to locate a primary source; never cite as evidence.

Always resolve a claim to where it **originated**, not to whoever echoed it last.

## Accuracy rules (non-negotiable)

- **Date everything.** Stamp each claim with its source date; lead time-sensitive
  answers with "as of <date>". Treat undated pages as low-trust.
- **Ground every claim** in text the source actually contains; if the page doesn't
  support it on re-read, drop it.
- **Separate fact from inference from speculation** — label the latter two.
- **Report the negative space.** State what you could not verify or find as plainly as
  what you confirmed. "Not found" is a result.
- **Confidence is earned:** High = multiple independent Tier-1/2, survived refutation;
  Medium = limited corroboration or minor conflict; Low = single/weak source or
  contested. Show the reason, never a bare label.
- **No fabrication.** Never invent URLs, dates, quotes, or figures. An honest gap beats
  a confident guess.

## Prompt hardening

Every fan-out shard and refuter inherits these instructions verbatim — they are
what turns a generic web summary into a defensible finding:

- "Prefer primary sources. Name each source's publication date. If you cannot
  confirm a claim, say so — do not fill the gap with a guess."
- "Quote the exact sentence that supports each claim. If the page does not contain
  it, discard the claim."
- "Only cite pages you actually opened. Never construct a plausible-looking URL."
- "Distinguish what the source *states* from what you *infer*. Label inference."
- "When two sources conflict, report both and trace each to its origin — do not
  pick one silently."
- "State what you searched for and found nothing on. Absence is data."

Pass the caller's domain constraints too (region, timeframe, language, jurisdiction);
an unscoped query drifts to the loudest, not the most relevant, result.

## When to stop

Stop when every load-bearing claim is `confirmed` or explicitly flagged
`unconfirmed`/`contested`, the contradiction ledger is settled or surfaced, and the
gap check comes back dry. Ship the report with its open questions — do not pad thin
findings into false certainty.
