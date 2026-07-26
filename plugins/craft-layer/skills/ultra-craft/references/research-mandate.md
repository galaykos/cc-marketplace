# Research mandate — fetch it, date it, show it before you build

`design-research` tells the flow to mine live products, pattern galleries and the
target's own brand assets. It never says *fetch*. So a run can produce a confident
brief entirely from model memory, name Linear and Stripe and Mobbin, and pass every
gate the plugin has — while the "research" is recall of how those sites looked
whenever the weights were frozen. Design moves; recall does not. This file is what
makes the mining real when the run is boosted.

Binding at `ultra-craft` only, with ONE exception: the **"When a fetch fails"**
section below binds at EVERY tier, because being refused a page is not a
research-depth question and the craft flow's content ingestion cites that section
directly. Otherwise, at `standard` and `maximal` the mining method is unchanged.

## Minimums

- **Six live sources**, at least **two per lane** — live products in the category,
  pattern galleries, the target's own brand assets. One lane at six is a survey of
  one opinion. Where a lane genuinely has nothing (no existing brand for a new
  product), record the lane as empty with that reason and raise the other two.
- **Fetched, not searched.** A search-result title and snippet is a LEAD. The
  source counts once the page itself was retrieved. A result list is not evidence.
- **Every source carries three things**: the URL, the fetch date, and one line on
  what it earns a place for — the specific pattern or feel being borrowed. A URL
  with no why-line is a citation, not a finding.
- **Both kinds of extraction per source**, as `design-research` already requires:
  an interaction/layout pattern AND token direction. A source mined for colour only
  produces a recoloured default, which is the failure the skill opens with.

## The three named galleries — a SEARCH floor

Naming a lane is not naming a source. "Pattern galleries" as a lane lets a run satisfy
the count from whichever gallery it happened to think of, and skip the ones that hold the
work worth borrowing. So three are named, and all three get SEARCHED — scoped to the
brief's category, with the query recorded:

| Gallery | Search it for | Trust it for |
| --- | --- | --- |
| `land-book.com` | shipped landing pages, filterable by category and style | section ORDER, offer spine, real page structure — these are live pages that ship |
| `awwwards.com` | award-graded sites, motion and art direction at the top of the field | signature-interaction candidates, and the calibration for what `maximal` reach looks like |
| `dribbble.com` | concepts, shots, visual explorations | palette, type and composition DIRECTION only — see the caveat below |

A search is discharged by running a category-scoped query at the gallery and recording it
— the query string, the URL, and the date. A search that surfaces nothing worth opening is
still discharged; it just yields no source. **The search floor and the source floor are
separate counts**: all three searched, and six fetched sources total with two per lane. A
run that searched all three and opened nothing has done half the work and says so.

These three are a FLOOR, not a ceiling. Mobbin, Godly, SiteInspire, Page Flows and
Refactoring UI remain worth pulling from and count as gallery-lane sources like any other.

### The dribbble caveat, which is a correctness rule

A dribbble shot is often a concept that was never built. It has no live page behind it, no
performance profile, no accessibility behaviour, and frequently no state beyond the one
frame that was rendered. Cite a shot as DIRECTION — a palette relationship, a type pairing,
a composition idea — and never as evidence that a pattern ships, converts, or performs.
Copying interaction structure from a shot is copying something nobody has built, and the
build inherits every problem the shot never had to solve. Awwwards and land-book entries are
live pages; walk them.

### When a gallery blocks the fetch

Awwwards and dribbble are heavily client-rendered and may refuse retrieval outright. Falling
back to the search layer — a `site:` query whose result titles and snippets are all that came
back — discharges the SEARCH and yields no source, and the board records it as
`search-layer only, fetch blocked <date>`. That is an honest half-result. Recording the
gallery as searched while presenting recalled entries as findings is not.

A gallery is a THIRD-PARTY origin, so the browser escalation below does NOT apply to it:
the ownership condition is exactly what separates the two cases, and the search layer is
the whole remedy here.

## Dating, because trends decay

Stamp the fetch date on every row. A source whose content is older than roughly
eighteen months is a HISTORY source: label it, use it for structure and convention,
and never let it be the sole backing for a claim about what the category looks like
*now*. Two history sources and no current one is a research gap, not a research pass.

Where the run needs the state of the field rather than one site — what a category's
pages are doing this year, which motion conventions have turned into cliché — search
for it, fetch what the search returns, and cite it the same way. `sameness-fingerprint.md`
holds the defaults worth breaking; live sources are how the run learns which ones
the category has already worn out.

## Recall is a lead, never a backing

Model memory may propose what to look at. It is labeled `unverified` wherever it
appears, and it cannot be the only thing behind a pattern the build copies. The
honest form is "recall suggests X — fetched Y to check, which shows Z". The
dishonest form is a board of plausible URLs nobody opened.

## When a fetch fails — ESCALATE first, substitute second

**This section is the one part of this file that binds at EVERY tier**, boosted or
not, and the craft flow's step-1 content ingestion cites it directly. The rest of
the mandate is `ultra-craft`-only; a refused retrieval is not, because the source a
`standard` run gets refused is most often the one the brief HANDED it.

The order is the rule:

1. **Escalate to a real browser** when the failure is `403`, any `5xx`, or an empty /
   shell document — the three shapes that mean *this client was refused*, not *there
   is nothing here*. A page that is PUBLIC is public to a browser: **rendering one in
   a browser is the same access, not a circumvention.** Drive whatever the environment
   ALREADY has — a Playwright/Puppeteer install in the target project, a connected
   browser extension, the project's own e2e runner.
2. **Only then substitute.** If the escalation also fails, or no browser path exists,
   record the attempt AND the escalation outcome, then substitute another source in
   that lane. Never silently drop it — an unexplained gap in a lane reads as a lane
   nobody tried.

Either way the row records what happened: the method that finally retrieved it, or the
attempt and the escalation that also failed. A blocked source with no escalation noted
is indistinguishable from one nobody tried.

**Two conditions bound this, and both are binding.**

- **Ownership.** Escalation applies to origins the user OWNS or has named as their own
  property — their marketing site, their docs, their repo, the URL in their brief. It
  does NOT apply to a third-party origin that refused a request: a gallery, a
  competitor, a paywalled publication. There the refusal IS the answer, and the
  search-layer fallback above is what discharges it.
- **`when-available`, NEVER mandatory.** Browser paths are absent in headless runs, and
  nothing here makes installing one a precondition for a source, a lane, or a step. No
  browser reachable → record `browser unavailable` on the row and go straight to move 2.
  A run that installed a browser in order to satisfy this rule has read it backwards.
  Worth checking first, though: the craft flow's step-7 gate suite installs Playwright +
  chromium into the target project, so a browser is often already present one step after
  the step that needed it.

`404` is not an escalation case — nothing was refused, the page is gone. Record and
substitute. Paywalled and login-walled are not escalation cases either: the wall is the
owner's decision, and this rule is about a refusal aimed at the CLIENT, not at the
reader.

Recording an obstacle is not the same as clearing it. A failure written down and then
built around, with an escalation available and untried, is the most expensive shape this
file exists to prevent: the run proceeds without the content and fills the gap with
whatever facts it happened to have.

## The reference board

Persist at `craft/reference-board.md`, beside the offer contract and the divergence
record, in the run's working area (the taskmaster docs area when the project has
one, otherwise session scratch — never the shipped tree), carrying the run's `Run:`
stamp on its first line like every other artifact there
(`craft-layer/skills/creative-direction/references/offer-contract.md` Part 8 —
fixed names are findable and collidable in the same move). Echo it to the user
BEFORE tokens are generated. This is the walkthrough: the user sees what the build
is about to be, while changing it still costs nothing.

```markdown
# Reference board — <product>
Run: 2026-07-26T14:32Z · clickinator · /Users/dev/src/clickinator-craft-test
Boost: ultra-craft · Ambition: maximal · Compiled <date>

## Searches run
| Gallery | Query | Searched | Result |
| land-book.com | <category + style filter> | 2026-07-26 | 3 opened, 2 kept (#4, #5) |
| awwwards.com | <category query> | 2026-07-26 | search-layer only, fetch blocked |
| dribbble.com | <category query> | 2026-07-26 | 1 kept (#6, direction only) |

## Sources
| # | URL | Lane | Fetched | Age | Why it earns a place | Method |
| 1 | https://… | live product | 2026-07-26 | current | how the pricing table carries the objection | fetch |
| 2 | https://… | brand assets | 2026-07-26 | current | the client's own hero and pricing copy | browser (escalated ← 403) |
| 5 | https://… | live product | 2026-07-26 | — | 403, browser unavailable — substituted by #4 | fetch-failed |
| 6 | https://dribbble.com/… | gallery (shot) | 2026-07-26 | current | palette relationship only — concept, not a shipped page | fetch |

## Patterns pulled
| Pattern | From | Carried into |
| pinned scroll act on the proof section | 3 | signature candidate |

## Direction implied
- Palette — <mood, not values; handed to /ui-ux:theme>
- Type — <pairing direction and why>
- Motion — <energy, what animates, what stays still>
- Density — <archetype's content-depth leaning>

## Sameness defaults being broken
| Default | Registry says | This build does instead |

## Section agenda — what gets built
| # | Section | Spine slot | Treatment leaning |

## Open questions
- <the calls the sources did not settle>
```

The agenda column is the same agenda `section-decisions` will run the guided rounds
against — showing it here means the user agrees to the SHAPE before spending
exchanges on treatment.

**`Method` is the retrieval column**, and it is APPENDED at the end of the row so a board
written before it existed still reads positionally. Its vocabulary: `fetch` (a plain
retrieval), `browser (escalated ← <status>)` (the escalation above succeeded),
`search-layer` (the search discharged, no page retrieved), `fetch-failed` (both the fetch
and the escalation failed, or no browser was available). `browser` rows are FETCHED
sources and count as such — the column exists so an escalation is visible, not so it is
discounted. `search-layer` and `fetch-failed` rows are not sources and count toward no
floor; they are the record that the lane was tried. `craft/content-source.md` uses the
same vocabulary, so one glance answers "how did this actually get here?" on both
artifacts.

## Anti-patterns

- **Board of leads** — six URLs from a search page, none retrieved.
- **Undated board** — every row current by implication, none by evidence.
- **Colour-only mining** — token direction with no interaction pattern, which is a
  recoloured default wearing a research report.
- **Board after tokens** — echoed once the palette exists, so it reports instead of
  deciding.
- **Lane collapse** — six sources, all live products, no gallery spread and no
  brand assets, so the build borrows one site's whole opinion instead of a
  convention.
- **Gallery skipped, count still met** — six sources with land-book, awwwards or dribbble
  never searched. The count is a floor on volume; the named searches are a floor on where
  you looked, and one does not buy the other.
- **Shot as pattern** — a dribbble concept cited as evidence that an interaction ships,
  then rebuilt with all the state, performance and accessibility work the shot skipped.
- **Refusal read as absence** — a `403` on the client's own public page recorded as a
  finding, the run carrying on without the content, with a browser in the project the
  whole time. The obstacle was logged; it was never cleared.
- **Escalation as a requirement** — treating a browser as a precondition, so a headless
  run reports a lane it could have filled from the search layer as impossible.
