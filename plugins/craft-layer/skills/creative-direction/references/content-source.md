# Content source — the copy that already exists, ingested before any is written

A rebuild, a redesign, or a front-door refresh usually arrives with the words already
written: a live marketing site, a deck, a PDF, a page the client pasted into the brief.
The flow used to assume page copy was GENERATED — so it had no step that asked whether
copy existed and no lane that ingested it when it did. The failure that follows is
specific and expensive: a run that cannot reach the client's own copy substitutes
whatever facts it does have — endpoints, auth scopes, rate limits — and ships a sales
page that reads as documentation, clearing every gate on the way.

This file owns the artifact that closes it: **`craft/content-source.md`**, persisted at
step 0/1 beside `craft/offer-contract.md` and `craft/divergence-record.md`, in the run's
working area (the taskmaster docs area when the project has one, otherwise the session
scratch) — never in the shipped tree. The audit globs for it by that exact name.

## It costs no exchange

`one-shot` is pinned at exactly ONE exchange — the concept fork (Part 6 of
`offer-contract.md`) — and this step does not add a second one. Two rules discharge it:

- **The question rides the fork.** The content-source question is an ADDITIONAL question
  inside the fork's existing single `AskUserQuestion` call, never a call of its own:
  *"is there copy for this page already?"* — the live site named in the brief, a doc or
  deck the user can paste, or none. One exchange, two questions.
- **A brief-named URL or path is not a question at all.** It is a SUPPLIED INPUT: read it,
  do not ask permission to. The ask exists for the case where the brief names no source.

**Headless, unattended, or unanswered → `source: none-located`**, and the build proceeds
with visible `{{lorem}}` slots for every prose slot nobody supplied. That is the stated
default, not a degraded path: an unattended run must never invent the client's claims
because nobody was there to hand it theirs.

## Locating the copy

In order, stopping at the first that yields the page's words:

1. **What the brief hands you** — a URL, a repo path, a pasted block, an attached file.
2. **The target's own brand assets** — Lane C of `design-research/references/mining-method.md`
   already directs the run at the existing marketing site; this artifact is where what it
   finds is written DOWN.
3. **What the user supplies at the fork** — the answer to the question above.

**Every brief-named source owes a ROW, fetched or failed.** This is the artifact that gives
Lane C its teeth (`design-research/references/mining-method.md` § "Lane C is the ENFORCED
lane"): the lane already directs the run at the target's own marketing site at every tier,
and what was missing when a run walked past a `403` was not the rule but the record. So the
Sources table below carries ONE ROW per URL, repo path or attached file the brief named,
with its `Method` and its date, whether or not it came back. `fetch-failed` with a reason is
a complete row; an absent row is not, and the audit rebuilds the expected list from the
contract's `Raw brief:` — stored verbatim, so every URL the user typed is still there to
compare against. A named source with no row is one finding naming the source. It binds at
EVERY tier, because this artifact is written at every tier; a boosted run's reference board
carries the same source a second time as a brand-assets row, which is an addition on top,
never the thing that carries this elsewhere.

**When a retrieval fails, escalate before concluding the source is unavailable.** The
ladder — `403 || 5xx || empty document` → a real browser when one is available → only then
substitute or record the gap — is stated once, in
`craft-layer/skills/ultra-craft/references/research-mandate.md` § "When a fetch fails",
and binds at EVERY tier including this step. Do not restate it here and do not invent a
second version of it. Recording an obstacle is not the same as clearing one.

## The rules that bind ingested copy

- **Claims, numbers, prices and names are VERBATIM.** They are the client's assertions
  about their own product, and the build has no standing to restate them. Copy may be
  re-broken across sections, re-ordered, and headings may be re-worded to fit the concept's
  voice — the claim itself may not be rewritten, softened, sharpened, or "improved".
- **Legal blocks reproduce IN FULL** — risk warnings, disclaimers, regulatory notices,
  terms excerpts. Never trimmed, never softened, never hidden behind an accordion, a modal,
  or a "read more". They are also usually the best answer the page will ever get for the
  offer spine's **objection** slot ("what is the catch?"): they state the limits in the
  client's own approved words, which is exactly what the build must not write for itself.
- **No copy for a slot → a visible `{{lorem}}`, never an invented substitute.** A plausible
  marketing sentence the run wrote is indistinguishable, to every later reader, from a
  sentence the client approved — so it ships as their claim. A placeholder is visible,
  cheap to fill, and honest. Record every one of them in the artifact's gaps table.
- **A `{{lorem}}` slot is not the raw-mustache failure.** `content-depth.md` requires a
  typed CLAIM slot (`{{metric:*}}`, `{{capability:*}}`) to render as a labeled illustrative
  sample, because a plausible sample value is both honest and finished. Prose the CLIENT
  owns is the opposite case: there is no honest sample of someone else's positioning. So
  the two coexist — typed claim slots render as labeled samples, unsupplied prose slots
  stay visibly empty — and a `{{lorem}}` this artifact accounts for is never counted as
  raw mustache shipped.
- **Ingestion is implementation, not authorship.** Placing a client's already-published
  copy into a redesign of their own page is not writing persuasive copy for them. A refusal
  to AUTHOR new claims is correct and unchanged; extending it into "write no persuasive
  content at all" is what turns a sales page into a spec sheet.

## What cannot be captured, and says so

Some copy is on the page but not in the document: FAQ answers collapsed behind JS, prices
assembled from a database, a testimonial in a carousel that renders one slide, text baked
into an image. Mark each one `uncapturable` with its reason rather than paraphrasing what
it probably said. An uncapturable slot falls back to `{{lorem}}` like any other gap.

## Staleness — a fetch date the audit reads

Every source row carries `Last verified: <fetch date>`, the repo's existing convention for
a file asserting something observed. Prices, tiers and claims move, and copy captured a
season ago can ship as a live commitment the client no longer makes.

The artifact declares `Staleness window: <n> days` — **30 by default** for live-site copy.
A fetch date older than the declared window is a **FINDING at audit**, not a note: it is
reported on the same list as a failed gate, and it is cleared by re-fetching, not by
explaining. Where the copy genuinely cannot be re-fetched, say so in the row and let the
finding stand.

## Posture

Ingested copy is the client's own material, reproduced at their instruction — the same
standing as their logo, their brand palette, or a repo they pointed the run at. Copy from
an origin the user neither owns nor named as theirs is a third-party source: cite it as a
reference, never paste it into the page.

## The artifact

```markdown
# Content source — <product>
Run: 2026-07-26T14:32Z · clickinator · /Users/dev/src/clickinator-craft-test
source: located | partial | none-located
Staleness window: 30 days

## Sources
| # | Origin (URL / path / "pasted by user") | Method | Last verified: <fetch date> | Owned by user |
| 1 | https://…/product | browser (escalated ← 403) | 2026-07-26 | yes |
| 2 | brand-deck.pdf (attached) | file | 2026-07-26 | yes |

## Captured copy — VERBATIM
### Hero
<the words, exactly as published>
### Pricing — 3 tiers
<tier names, prices, per-tier lines, exactly as published>
### Risk warning  ·  reproduce IN FULL
<the complete block>

## Gaps — shipping as {{lorem}}
| Spine slot | Why | Placeholder |
| proof | no testimonial published | {{lorem:proof_quote}} |
| how it works | FAQ answers collapsed behind JS — uncapturable | {{lorem:steps}} |

## Notes
- <anything re-broken across sections, and where each block landed>
```

`Method` is the same retrieval-method vocabulary the reference board uses — `fetch`,
`browser (escalated ← <status>)`, `file`, `pasted`, or `fetch-failed` with its reason — so a
browser-retrieved row is distinguishable from a plain fetch on both artifacts. `fetch-failed`
is not optional here: the every-source-owes-a-row rule above is what gives Lane C its teeth,
and a source that never came back still owes a row saying so. `search-layer` is the one value
that does NOT cross over — it records a search discharged with no page retrieved, which is a
research lane's half-result and never a capture of the client's published words.

## What the audit checks (teeth)

`/craft-layer:audit` globs `**/craft/content-source.md` with the other artifacts and, when
one exists, verifies:

- every claim, price, tier name and product name on the page traces to a captured block —
  a rewritten claim is one finding naming the block it came from;
- every legal block in the artifact appears in the shipped tree IN FULL and is not behind
  an interaction (a disclaimer inside an accordion is a finding);
- every gaps-table row shipped as a visible `{{lorem}}` rather than as invented copy, and
  no gaps row quietly acquired a sentence the run wrote;
- every source row's `Last verified:` date is inside the declared staleness window;
- every URL, repo path and attachment named in the contract's `Raw brief:` (and its
  `Upgraded brief:`) has a row here carrying a `Method` — fetched or failed. A named source
  with no row is one finding naming the source, at every tier: it is the shape a run leaves
  behind when it read the brief's URL, met a refusal, and built around it;
- `source: none-located` with page copy that reads as authored marketing prose is a
  finding — the run wrote what it said it had not located.

No artifact persisted → `not checked (no content source persisted)`, never a pass and
never a fail. A build that never ran the ingestion step is not a build that failed it.

## Anti-patterns

- **Substituted register** — the client's marketing copy unreachable, so the page is built
  from whatever facts were to hand (endpoints, schemas, rate limits). Dense, specific, and
  selling nothing.
- **Obstacle recorded as outcome** — a 403 written into a findings list and the run
  carrying on without the content, with a browser one command away.
- **Improved claim** — a verbatim line "tightened" into something the client never said.
- **Trimmed disclaimer** — a risk warning shortened, softened, or folded behind a toggle
  because it was long.
- **Invented filler** — a plausible sentence written into an unsupplied slot instead of a
  visible `{{lorem}}`, indistinguishable ever after from approved copy.
- **Never asked** — the cheapest question in the flow ("what content do you have?") skipped
  for a whole run, and raised by the user at the end.
- **Handed a URL, left no row** — the brief named a live site or a source repo and the
  Sources table has nothing about it. Read-and-not-recorded and never-read are the same
  artifact, which is why the missing row is the finding rather than the missing reading.
