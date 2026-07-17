# Orchestration recipes

Two engines, same discipline. Pick by depth; both end in the same cited report.

## Standard — portable parallel-Agent fan-out

Runs anywhere, no opt-in. One round of shards, one refutation pass.

1. **Decompose** the question into 4–8 facets. Write them down.
2. **Fan out** — spawn one `researcher` per facet in a *single* message (parallel
   tool calls) so they run concurrently. Each prompt is self-contained: the facet, the
   parent question for context, any domain constraints (region, timeframe, language),
   the prompt-hardening rules from the skill, and the required return shape below.
3. **Collect** the claim lists. Merge into one ledger keyed by claim; note which facet
   and which sources back each.
4. **Corroborate** — mark every load-bearing claim `confirmed` only if ≥2 independent
   Tier-1/2 sources support it and they do not trace to one origin.
5. **Refute** — spawn `verifier` agents (parallel) over the load-bearing claims. Drop
   or downgrade whatever a refuter breaks.
6. **Synthesize** the report and write the file.

### researcher return shape (require this in the prompt)

```
FACET: <the sub-question>
CLAIMS:
- claim: <one atomic fact>
  quote: "<verbatim sentence from the source>"
  url: <page actually fetched>
  date: <publication date or "undated">
  tier: <1|2|3|4>
UNVERIFIED: <leads that could not be confirmed, and what was missing>
NOT_FOUND: <what was searched for with no result>
```

## Ultra — Workflow loop-until-dry

Use when the trigger is `ultra-deep-research`, `--ultra` is passed, or the topic is
contested/high-stakes — and the Workflow tool is available. If it is not, run the
standard path with 2–3 extra gap rounds instead.

Shape the script as a **pipeline** (no barrier between facets) so a facet can be in
refutation while another is still searching:

```
pipeline(
  facets,
  facet   => agent(researcherPrompt(facet), {schema: CLAIMS, phase: 'Search'}),
  claims  => parallel(claims.loadBearing.map(c => () =>
               parallel([1, 2, 3].map(() => () =>                 // 3-vote refuter panel per load-bearing claim
                 agent(refutePrompt(c), {schema: VERDICT, phase: 'Refute'})))
                 .then(votes => ({...c, verdict: reduceRefutePanel(votes)})))),
)

// reduceRefutePanel — three VERDICT objects in, one outcome out; every split is defined.
// Votes are the verifier's structured returns, so tally on v.VERDICT — and a 'confirmed'
// vote whose FETCH carries no verbatim-quote+timestamp evidence is discounted: the
// reducer is the enforcement point for the verifier's confirmed-gate.
function reduceRefutePanel(votes) {
  const n = t => votes.filter(v => v.VERDICT === t).length
  const evidencedConfirms = votes.filter(v =>
    v.VERDICT === 'confirmed' && v.FETCH && v.FETCH.includes('retrieved')).length
  if (n('refuted') >= 2)                                   return 'refuted'      // majority-refute kills the claim
  if (evidencedConfirms >= 2 && n('refuted') === 0)        return 'confirmed'    // ≥2 evidence-backed confirms, 0 refuted
  if (n('unverifiable-this-session') === votes.length)     return 'unconfirmed'  // nobody could read the source — not a disagreement
  return 'contested'                                                             // any other split
}
```

Then loop-until-dry: a completeness-critic `agent` inspects the merged ledger for thin
facets / unconfirmed claims / stale dates and returns the next round's facets. Repeat
until two consecutive rounds add nothing, or `budget.remaining()` is low. The refute
stage above already fans each load-bearing claim to a 3-vote panel and folds the votes
through `reduceRefutePanel`: majority-refute kills the claim, a clean evidence-backed
confirm-majority with zero refutes confirms it, an all-unverifiable panel lands as
`unconfirmed` (unreadable is not disagreement), and every other split lands as contested.

Barrier only where a stage genuinely needs *all* prior results — deduping the ledger
before the final synthesis, or early-exit when a round finds zero claims. Everything
else stays in the pipeline.

## Cost discipline

Fan-out width tracks stakes: a quick factual scan is 3–4 shards and one refuter; a
contested market/technical audit is 6–8 shards and the full 3-vote panel. The
single-refuter shortcut is a quick-scan/standard-depth allowance only — an ultra-depth
load-bearing claim always runs the 3-vote panel above, never one refuter. Do not run
panel theater on trivia, and do not single-pass a decision that matters. Say, in the
report, how wide you actually went — silent narrow coverage reads as thoroughness it
isn't.
