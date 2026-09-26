# ultra-deep-research

A deep-research harness for Claude Code. Ask it a hard question and it fans out
parallel web searches, tiers sources by provenance, extracts date-stamped claims,
**adversarially refutes** them, surfaces contradictions instead of hiding them, and
synthesizes a cited report — inline and saved to `research/<topic>-<date>.md`.

Built to beat research's core failure mode: a plausible claim echoed across low-quality
pages that all copied one unverified origin.

## Boundary with Claude Code's built-in `/deep-research`

Claude Code bundles a `deep-research` **workflow**, and the trigger phrase collides:
"deep research" is the built-in's name and this skill's opening trigger, and both
descriptions sit in the same listing. They are not substitutes. Read from the 2.1.273
binary (one build; re-read before trusting on another): the built-in is one fixed
pass — scope the question into 5 search angles, 5 parallel WebSearch agents, URL-dedup
and fetch the top 15 sources, extract up to 5 falsifiable claims per source with a
quality label, put the top 25 claims to a 3-vote adversarial panel (2 of 3 refutes
kills; an errored panel is `unverified`, never refuted), then synthesize findings with
a confidence level, caveats and open questions. It returns a structured object into
the session and writes nothing to disk. It fires only when asked — the host's own
system prompt says not to use workflows "unless the user, a CLAUDE.md file, or a skill
asks for it".

This plugin adds what that pass lacks: a **contradiction ledger** with an ordered
adjudication rule, so two surviving sources that disagree are recorded and settled
rather than averaged (the built-in kills claims; it never records a disagreement); a
**verifier pass** whose `confirmed` is gated on a verbatim quote, a retrieval timestamp
and an independent Tier-1/2 corroborating source, format-checked by
`scripts/verdict-lint.sh` (the built-in's verdict is a boolean plus an evidence
string); **`--ultra` loop-until-dry** — a completeness critic spawns further rounds
until two in a row surface nothing new, capped at 3, with multi-vote panels; a
**cited report file**, `research/<topic>-<date>.md`, with per-section confidence,
source tiers and dates, and what it could NOT verify, so the answer outlives the
session; and the **coverage engine** for one long document, which a web-only
workflow cannot do at all.

Reach for the built-in when a one-shot web question with an in-session answer is
enough and 15 sources / 25 claims covers it. Reach for this one when the answer must
survive scrutiny later (a file with citations), when sources are expected to disagree,
when the subject is a single document, or when the run should keep going until the
gaps close. Standing: **recorded** — which of the two fires on "deep research" has not
been measured with a control arm; the endgame review's "measure" item is still open.

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

## Accuracy discipline (agent-graded, lint included)

Every load-bearing claim is corroborated by ≥2 independent quality sources, date-stamped,
and attacked before it is trusted. No fabricated URLs, dates, or figures — an explicit
"not found" over a confident guess. Time-sensitive answers are stamped "as of <date>".

Since 0.5.0 the verdict FORMAT half has a lint: `scripts/verdict-lint.sh` rejects a
`confirmed` verdict missing a verbatim quote, retrieval timestamp, or corroborating
source (the skill demotes it to `contested`), with a fixture harness CI runs. Its
standing is **agent-graded**, not a gate: only the skill's and the command's prose tells
the orchestrator to pipe each verdict through it, no hook or CI step runs it over a
live run, and the harness proves the script, not that a run invoked it. Whether the
quote is real and the sources independent is agent-graded too — the lint cannot know,
and saying so is the point.

## Pairs well with

Two plugins call this one; neither is required by it:

- **craft-layer** — `creative-director` runs a live research pass through the skill when
  a dispatch opts in
- **code-architecture** — `coding-entry` routes "what is the state of X" and unfamiliar
  vendors to `/ultra-deep-research:research`

## Suite membership

None — there are no suites (retired 2026-09-26), and it was standalone by design before
that. A research run fans out parallel web searches and can escalate to a
Workflow-driven loop-until-dry sweep — a token cost that should be chosen per install,
not ride in silently with anything else.
