---
description: Run a deep, multi-source, fact-checked research pass — fan out searches, tier sources, refute claims, synthesize a cited report inline and to research/<topic>-<date>.md; --ultra forces the Workflow loop-until-dry engine, --standard the portable path.
argument-hint: <topic or question> [--ultra|--standard]
---

Deep-research the topic in `$ARGUMENTS`. Load the `ultra-deep-research` skill and
follow its loop; the recipes live in that skill's `references/`.

1. **Read the flags.** `--ultra` forces the Workflow loop-until-dry engine with
   refutation panels; `--standard` forces the portable parallel-Agent fan-out. With
   neither, infer depth from the ask (contested/high-stakes/"latest" → ultra) and state
   which you chose. The literal phrase `ultra-deep-research` anywhere in the topic also
   forces ultra.
2. **Scope.** Restate the question in one line and split it into 4–8 orthogonal facets.
   Carry any constraints in `$ARGUMENTS` (region, timeframe, language, jurisdiction)
   into every shard prompt. If the topic is too broad to research well, ask 2–3
   narrowing questions before fanning out.
3. **Fan out** one `researcher` per facet (parallel, or a Workflow pipeline for ultra).
   Require the return shape and prompt-hardening rules from the skill — verbatim quote,
   fetched URL, publication date, and source tier per claim; no fabricated URLs.
4. **Corroborate & refute.** Confirm a load-bearing claim only on ≥2 independent
   Tier-1/2 sources; route each to the `verifier` to be broken. Ledger every
   contradiction; adjudicate by provenance and recency, or ship it as open.
5. **Gap check.** For ultra, loop until two rounds add nothing new or the budget is
   spent; for standard, run one explicit gap pass. Name what stayed uncovered.
6. **Synthesize** using `references/report-template.md`: answer first, per-section
   confidence, inline `[n]` citations, contradiction ledger, tiered sources, open
   questions. Print it inline **and** write `research/<slugged-topic>-<YYYY-MM-DD>.md`
   (fall back to the scratchpad dir if the project is read-only), then report the path.

Do not fabricate sources, dates, or figures. An explicit "not found" beats a guess.
