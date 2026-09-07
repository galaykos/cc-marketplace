# A single authoritative document is a different problem

The engine this plugin runs on is **corroboration**: many sources, tiered by
provenance, claims cross-checked and adversarially refuted. That engine is the
right one for a question with an answer distributed across the web.

It is the wrong one for a contract, an RFP, a standard, a filing, or a 200-page
PDF someone handed you. There is exactly one source, it is authoritative by
definition, and nothing can corroborate it. Refuting a clause against the open web
is not verification — it is a category error, and it produces a confident report
about a document nobody checked against the document.

Swap the corroboration engine for a **coverage** engine. Everything else in the
plugin — the verifier agent, the contradiction ledger, `references/report-template.md`
— is reused unchanged.

## The coverage manifest is the deliverable

Not a section of the report. The first artifact, written before any claim:

    ## Coverage
    Document: Master Services Agreement, 214 pages (Read: pages 1-214, 11 requests)
    Read in full:      1-96, 120-214
    NOT read:          97-119  (Exhibit C, pricing schedules — out of scope per the question)
    Unreadable:        pages 188-190 (scanned images, no text layer)
    Search-only:       none

The point is that a reader can check the manifest against the document's real
length. That is the same move that makes a lockfile-reading skill non-redundant:
it produces a claim about the world that can be falsified without trusting the
agent's self-report. A report with no manifest is a report whose coverage is
whatever the reader assumes, and the assumption is always "all of it".

**The harness caps PDF reads.** `Read` takes at most 20 pages per request and
requires an explicit page range past 10 pages. A single naive `Read` on a long
document silently returns a prefix. Page through deliberately, record every range
requested, and count the requests in the manifest — the count is the evidence that
paging actually happened.

## Anchor every load-bearing claim

"The contract says X" is unusable. "§7.3, p. 41: 'the Supplier shall…'" is
checkable. Every claim that carries weight gets a page or clause anchor and, where
the wording matters, a verbatim quote. If an anchor cannot be produced, the claim
is not established — say so rather than softening the phrasing until it sounds
established.

## Keep three lists apart

Merging these is the most common failure in single-document analysis, and each
merge produces a different wrong answer:

| List | Means | Wrong reading if merged |
|---|---|---|
| The document SAYS | stated, with an anchor | — |
| The document does NOT say | searched for, absent | reads as "prohibited" |
| The document says the OPPOSITE | stated, contradicts the premise | reads as "silent" |

Silence is not permission and it is not prohibition; it is silence, and which one
it implies is a question for whoever owns the document. Report it as absence, and
say what was searched for to establish that absence — "no clause matching
'termination for convenience', searched: convenience, without cause, at will".

## Internal contradiction, not external refutation

The contradiction ledger still applies, pointed inward: a definition in §2 that
conflicts with its use in §14, an exhibit that restates a term differently, a date
that cannot be satisfied alongside another clause. Those are findings of the
highest value in a single-document read, and they are invisible to any process
that reads only the section the question is about.

## When corroboration DOES return

If the document makes a checkable external claim — cites a standard, quotes a
regulation, states a market figure — that claim leaves the coverage engine and
enters the plugin's ordinary corroboration path. Say which claims took that route,
so a reader can tell what was verified against the world and what was only read
accurately.
