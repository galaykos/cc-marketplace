---
name: ultra-deep-research
description: Use when a question needs a deep, fact-checked answer with the latest data — deep research, competitive/market/technical scans — or when ONE long document (contract, RFP, standard, filing, PDF) is the subject.
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

**Fork at step 1.** If the subject is ONE authoritative document rather than a
question distributed across the web, read `references/local-corpus.md` and run the
coverage engine described under "Local corpus" below in place of steps 2–6. Steps 1
and 7 are the same either way.

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
   the rest are downgraded or dropped — an unfetchable source lands `unconfirmed`,
   never `contested` (unreadable is not disagreement). **Capped at 24 verifier
   dispatches per round** (claims × votes): rank by how much the answer leans on each,
   verify down to the cap, carry the rest `unconfirmed`, and name the deferred count.
   **Lint every verdict before trusting it:** pipe each verifier return through
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/verdict-lint.sh` — a `confirmed` that fails
   the lint (no verbatim quote, no retrieval timestamp, or empty corroboration) is
   DEMOTED to `contested`, never patched up on the verifier's behalf. The lint is a
   format gate only; whether the quote is real stays your judgment. Stated limitation:
   verification is one-directional — the researcher never sees or answers a
   refutation, so a claim killed on a misread source dies undefended. The
   majority-vote panel is the mitigation, not a cure.
5. **Ledger contradictions.** Where sources disagree, never silently average. Record
   the disagreement, then adjudicate by an ordered rule: (1) for volatile facts
   (versions, prices, dates, live status) the more recent of two Tier-1/2 sources wins,
   even one tier step lower; (2) otherwise the higher tier wins; (3) within the same
   tier, primary beats secondary; (4) still tied → ship it as an open `contested`
   contradiction, never a silent pick.
6. **Gap check (ultra: loop-until-dry).** A completeness critic asks: which facet is
   thin, which claim is still unconfirmed, which fact is stale? Spawn another round on
   the gaps. Repeat until two consecutive rounds surface nothing new, **capped at 3
   rounds**, or the budget is spent — then say what was left uncovered rather than
   implying full coverage. The cap is the enforceable ceiling; two-dry is the quality
   exit and the budget check is advisory, so a run that keeps finding gaps still ends.
7. **Synthesize.** Write the report per `references/report-template.md`: direct answer
   first, per-section confidence, inline `[n]` citations, contradiction ledger, tiered
   source list, and open questions. Print it inline **and** write it to
   `research/<slugged-topic>-<YYYY-MM-DD>.md` (create `research/`; use the scratchpad
   dir if the project is read-only).

## Local corpus, one authoritative source

The fork declared at the top of the loop. When the subject is a document — a contract,
an RFP, a standard, a filing, a long PDF — swap the corroboration engine for a coverage
engine; the recipe is `references/local-corpus.md`. Refuting a clause against the open
web is a category error: there is one source and it is authoritative by definition. The
deliverable becomes a coverage manifest (pages read, pages NOT read and why, pages
unreadable) written before any claim, page/clause anchors on everything load-bearing,
and "the document does not say X" kept strictly apart from "the document says the
opposite". Note the harness cap while planning: `Read` takes at most 20 PDF pages per
request, so one naive call returns a prefix and reports it as the whole.

## Source tiers

**1** primary/authoritative — official docs, standards, filings, court records,
datasets, original research, first-party statements, the code/spec itself ·
**2** reputable secondary — editorial press, peer-reviewed literature, recognized
institutions · **3** tertiary — blogs, forums, wikis, vendor marketing: leads and
colour only, never sole support for a load-bearing claim · **4** low-trust — SEO
farms, undated content, unattributed AI text, circular aggregators: use to locate a
primary source, never cite as evidence.

Resolve a claim to where it **originated**, never to whoever echoed it last. The
writer's copy of this rubric is `references/report-template.md`; keep the two in step.

## Accuracy rules — who owns which

The SHARD-facing hardening (primary sources, verbatim quote or no claim, only pages
actually opened, label inference, trace a conflict to its origin, absence is data)
lives ONCE, in `agents/researcher.md` and `agents/verifier.md`. Both dispatch paths
bind those files — `subagent_type` on the standard path, `agentType` on the Workflow
path since 0.6.0 — so a shard already carries them. Do not re-paste them into a shard
prompt; a third copy only drifts from the two that reach the model. A shard dispatched
with NEITHER key inherits none of it, and an unbound run's transcript is
indistinguishable from a bound one (the 0.6.0 bug).

What the ORCHESTRATOR owes on top, because no agent file can supply it:

- **Pass the caller's domain constraints** — region, timeframe, language,
  jurisdiction — into every shard prompt. An unscoped query drifts to the loudest
  result, not the most relevant.
- **Date everything.** Lead a time-sensitive answer with "as of <date>"; an undated
  page is low-trust.
- **Report the negative space** as plainly as the findings. "Not found" is a result.
- **Confidence is earned:** High = multiple independent Tier-1/2, survived
  refutation; Medium = limited corroboration or minor conflict; Low = single/weak
  source or contested. Show the reason, never a bare label; the writer's full rubric
  is in `references/report-template.md`.
- **Never launder a labelled inference into a fact.** The shards label their own
  inference and speculation; the synthesis is where those labels get dropped. The
  writer's remaining rules (no citation → no load-bearing claim, no padding, every
  URL in Sources actually fetched) are in the report template, not repeated here.

## When to stop

Stop when every load-bearing claim is `confirmed` or explicitly flagged
`unconfirmed`/`contested`, the contradiction ledger is settled or surfaced, and the
gap check comes back dry. Ship the report with its open questions — do not pad thin
findings into false certainty.
