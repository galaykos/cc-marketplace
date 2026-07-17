# Report template

The report is the product. It is written inline in chat **and** to
`research/<slugged-topic>-<YYYY-MM-DD>.md`. Structure:

```markdown
# <Question restated as a title>
_Researched <YYYY-MM-DD> · depth: standard|ultra · <N> facets · <M> sources_

## Answer
<The direct answer in 2–5 sentences. Lead with the conclusion. For time-sensitive
topics, open with "As of <date>, ...". If the honest answer is "it depends" or
"unknown", say that first, then explain.>

## Key findings
- **<Finding>.** <One line.> `[1][2]` — confidence: High
- **<Finding>.** <One line.> `[3]` — confidence: Medium (single Tier-2 source)
- ...

## Detail
### <Facet 1>
<Prose grounded in citations. Every load-bearing sentence carries a [n]. Label
inference and speculation as such. State what could not be verified.>

### <Facet 2>
...

## Contradiction ledger
| Claim | Source A (tier/date) | Source B (tier/date) | Resolution |
|-------|----------------------|----------------------|------------|
| <fact> | <says X> | <says Y> | <primary/newer wins → Z, or "unresolved — reported as open"> |

## Confidence & coverage
- Overall confidence: High | Medium | Low — <why>.
- Coverage: <facets covered; what was left thin or out of scope>.
- Recency: <newest and oldest load-bearing source dates; any staleness risk>.

## Open questions
- <What remains unverified or unknown, and what source would settle it.>

## Sources
1. <Title> — <URL> — Tier <n> — <date> — <one-line what it supports>
2. ...
```

## Rubrics

**Source tier** (drives weight; resolve to origin, not echo):
- **1** primary/authoritative — docs, standards, filings, datasets, first-party, source.
- **2** reputable secondary — editorial press, peer-review, recognized institutions.
- **3** tertiary — blogs, forums, wikis, vendor marketing. Leads only.
- **4** low-trust — SEO farms, undated, unattributed AI text, circular aggregators.

**Confidence:**
- **High** — multiple independent Tier-1/2 sources, survived refutation, current.
- **Medium** — limited corroboration, minor unresolved conflict, or aging sources.
- **Low** — single/weak source, contested, or could not be independently confirmed.

**Claim status** (internal ledger, not all shown): `confirmed` (≥2 independent
Tier-1/2, survived refutation) · `unconfirmed` (single/weak, or the source could not
be fetched — a verifier `unverifiable-this-session` verdict lands here) · `contested`
(sources genuinely disagree) · `refuted` (broken by the verifier — dropped, or shown
as a corrected misconception if the myth is itself notable). The Contradiction ledger
takes only real source-vs-source disagreements — an unfetchable source is never
rendered as a disagreement row.

## Rules the writer must not break

- No citation, no load-bearing claim. Inference is allowed but must be labeled.
- Never merge conflicting facts into a false average — surface them in the ledger.
- Never pad. A short honest report beats a long confident-wrong one.
- Every URL in Sources is a page that was actually fetched during the run.
