# Voice contract — the concept's editorial voice, made buildable

The concept deck names an **editorial voice** and, until this file existed, that name
reached the build as a typographic role (`concept-deck.md` Part 5) and nothing else. Brand
voice was a slot name, not a capability: the whole marketplace held one operational rule
about copy craft — the `Copy voice:` line in
`../../design-research/references/brief-templates.md` — and it lived inside a per-section
brief the audit never reads. This file promotes it to a run-level contract and gives the
gate something to grade.

It decides WHAT THE COPY SOUNDS LIKE. It never writes the copy: the words come from
`content-source.md`'s captured blocks, and inventing a claim to fit a voice is that file's
named failure, not a style choice.

## The four dimensions

A voice is buildable only when every dimension survives into a sentence. An adjective does
not: "confident", "warm" and "human" are the three most common values written on a voice
line and none of them changes a word of the output.

1. **Person and address.** Who speaks, and to whom — first person plural to a named buyer,
   third person about the product, second person direct. One choice, held everywhere.
2. **Sentence-length band.** A floor and a ceiling in words (`6–14`, `4–9`, `12–28`). The
   band is the single dimension that moves the rhythm of a page, and the one a build
   defaults on hardest — generated copy converges on 15–22 words whatever it is selling.
3. **What it does with fragments, questions and imperatives.** Each allowed, allowed in one
   position, or banned: "fragments as list items, never as headings"; "no rhetorical
   questions"; "imperative only on the CTA".
4. **Two to three literal NEVERs.** Exact strings this product does not say — the
   product-specific half, distinct from the registry's category-wide lexicon. They are
   literal because they are the only dimension a script can check.

## The line the build task carries

One line, the same shape and the same lane as `Banned vocabulary:`, written by
`/craft-layer:craft` step 5 onto `craft/build-task.md`:

```
Voice: first person plural to a named crew lead · 6–14 words a sentence · fragments as list
items, never as headings; imperative only on the CTA · NEVER "everything you need", NEVER
"simple, powerful, flexible", NEVER "we're excited to announce"
```

Dimensions are separated by `·`; the NEVERs are `NEVER "<literal>"` items, comma separated,
anywhere on the line. Nothing to ban is NOT a legitimate value here — a voice with no
NEVERs has no machine-readable half, so the gate says so rather than passing.

**Where the NEVERs come from.** The concept's own vocabulary, not a category list. Take the
three phrases a competitor's page in this category uses that this concept has explicitly
rejected. A NEVER copied from `sameness-fingerprint.md` is already checked by the
`copy-register` lexicon and buys nothing.

## Standing

| claim | standing | who enforces it |
|---|---|---|
| the `Voice:` line EXISTS on the build task and carries at least one `NEVER "…"` | **gate** | `divergence.mjs`'s `voice-contract` assertion — FAIL when a build task resolved and the line is absent or NEVER-less |
| no `NEVER "…"` literal appears in reader-visible copy | **gate** | `divergence.mjs`'s `copy-register` assertion — the literals join the registry lexicon as extra rows |
| the person, the sentence band and the fragment/question/imperative rules are HONOURED | **agent-graded** | `craft-reviewer` reading rendered copy; no script counts a sentence |
| the voice matches the concept's metaphor | **agent-graded** | the same reviewer, against `concept-deck.md` |

No build task at all is `SKIP`, never a FAIL: a build is never failed for not having saved
a file — the same rule `spine-register` and `craft-stamp` ride.

**What the gate does NOT catch.** It reads literal strings, so a NEVER honoured in spirit
and broken in synonym passes ("everything you need" banned, "all you need" shipped). It
reads the copy chunks `copy-register` reads, so a NEVER inside an image, an SVG `<text>`
node the extractor flattens away, or copy fetched at runtime is invisible. And it cannot
tell a voice that was DECIDED from one that was typed to clear the assertion — that is the
reviewer's half, and it is the larger half.

## Anti-patterns

- **An adjective as a value.** `Voice: confident and human` clears no dimension.
- **A NEVER that is a word.** `NEVER "seamless"` bans a word honest copy may need; the
  registry's own lexicon is multi-word for this reason. Ban a phrase.
- **A different voice per section.** The line is run-level. A section that genuinely needs
  another register (a legal block, a status page) says so in the section ledger.
- **Writing the line after the build.** Then it describes what shipped, and the gate grades
  the copy against itself.
