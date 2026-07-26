# Research mandate — fetch it, date it, show it before you build

`design-research` tells the flow to mine live products, pattern galleries and the
target's own brand assets. It never says *fetch*. So a run can produce a confident
brief entirely from model memory, name Linear and Stripe and Mobbin, and pass every
gate the plugin has — while the "research" is recall of how those sites looked
whenever the weights were frozen. Design moves; recall does not. This file is what
makes the mining real when the run is boosted.

Binding at `ultra-craft` only. At `standard` and `maximal` the mining method is
unchanged.

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

## When a fetch fails

Paywalled, blocked, JS-only, 404: record the attempt and the failure in the board,
then substitute another source in that lane. Never silently drop it — an
unexplained gap in a lane reads as a lane nobody tried.

## The reference board

Persist at `craft/reference-board.md`, beside the offer contract and the divergence
record, in the run's working area (the taskmaster docs area when the project has
one, otherwise session scratch — never the shipped tree). Echo it to the user
BEFORE tokens are generated. This is the walkthrough: the user sees what the build
is about to be, while changing it still costs nothing.

```markdown
# Reference board — <product>
Boost: ultra-craft · Ambition: maximal · Compiled <date>

## Searches run
| Gallery | Query | Searched | Result |
| land-book.com | <category + style filter> | 2026-07-26 | 3 opened, 2 kept (#4, #5) |
| awwwards.com | <category query> | 2026-07-26 | search-layer only, fetch blocked |
| dribbble.com | <category query> | 2026-07-26 | 1 kept (#6, direction only) |

## Sources
| # | URL | Lane | Fetched | Age | Why it earns a place |
| 1 | https://… | live product | 2026-07-26 | current | how the pricing table carries the objection |
| 6 | https://dribbble.com/… | gallery (shot) | 2026-07-26 | current | palette relationship only — concept, not a shipped page |

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
