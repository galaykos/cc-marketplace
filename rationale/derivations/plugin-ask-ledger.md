# ask-ledger: the comment text moved out of the code (2026-10-22)

The text below was moved verbatim on 2026-10-22 from the files named in the `##` headings, with only each comment's `# ` leader removed; the lines each file kept are not repeated here. A pointer by name was left in each file, `# Why, limits, history: rationale/derivations/plugin-ask-ledger.md § <heading>`. Standing: `recorded` — no gate reads this file, and its dates, measurements and citations are as they stood on the day it moved. One correction is recorded rather than silently made: the header's "(2D sprites, 3D model, i18n)" was wrong about `i18n` — the digit-letter pattern needs a leading digit, so `i18n` is never extracted.

## plugins/ask-ledger/hooks/ledger.sh

### Header

```text
UserPromptSubmit. On a work-shaped prompt (a making verb in an imperative clause — the
trigger candor's preamble and taskmaster's reminder share), destructure the ask into
the things it NAMES and keep them in a session ledger the Stop gate reads back:
  - quoted terms ("digimon", 'checkout total')
  - proper nouns not at a clause start (Laravel, React, Digimon, Stripe)
  - digit-letter tokens with their next word (2D sprites, 3D model, i18n)
The ledger is appended on every later work prompt (an "also add X" names X), deduped,
capped at 12 entries. It holds the names still OWED: the Stop gate removes a name once
a final message accounts for it, so a later prompt that names it again re-ledgers it.
The hook also tells the model, once per prompt that added entries, what the gate will
ask for at the end.

WHY THIS EXISTS (2026-09-19, rationale/fable-distillation-2026-09-18.md §4). Six
headless runs asked for "Digimon themed … 2D pixel-art sprites" all drew invented
creatures and said nothing — no hedge, no reason, so candor's avert guard (which fires
on a reason being written) saw nothing. A script cannot judge whether the sprites are
Digimon. It can insist the model say, per named thing, whether it delivered it as
named, substituted it, or omitted it — and the gate can refuse a final message that
does not. The truth of each line is the model's word; the shape is enforced.

A NAME THE REPO ALREADY HAS IS NOT A THING THE ASK INTRODUCES (2026-09-22). "Fix the
N+1 in OrderController when Laravel eager-loads Invoice and Payment relations under
Inertia" ledgered six entries and the Stop gate then blocked the turn until the model
wrote six lines about code it had been asked to REPAIR, not to deliver. Every
candidate is now checked against the session project's tracked tree (`git grep -qliF`,
`rg -qiF` when git grep errors out) and dropped when it is already there; a name the
repo has never heard of — Digimon, Stripe, a new library — still ledgers.

WHAT IT DOES NOT SEE (honest scope): lowercase features ("login", "register", "a
library") — the ledger sees names, not nouns; a name mentioned in passing ("like
Stripe does") is ledgered and must be accounted for, one line, cheap; anything in a
fenced or inline code span, or in a paste, is ignored. The existence filter carries three residuals of
its own, each real: it needs a git work tree, so a session opened outside one is
unfiltered exactly as before; `git grep` reads TRACKED files, so a name that exists
only in an untracked or ignored file still ledgers; and it cannot tell a name the repo
has from a name the ask ADDS to what the repo has ("also add a Stripe refund flow" in
a repo that already mentions Stripe drops Stripe). It trades those false negatives for
the false positives above, which were blocking turns.
Off switch: CC_ASK_LEDGER=off. Fail-open.
CC_ASK_LEDGER unset: the /config option cc_ask_ledger decides.
```

### Quoted spans: phrases and apostrophes

```text
A QUOTED SPAN OF FOUR OR MORE WORDS IS A PHRASE, NOT A NAME (2026-10-11: a review ask
quoting "take usage without any result" ledgered the whole description and the gate
blocked the turn over it). Names people quote run one to three words: "digimon",
'checkout total'.
AN IN-WORD APOSTROPHE IS NOT A QUOTE (2026-10-13: "doesn't or didn't" ledgered
`t or didn`). It is masked while quoted spans are found and put back inside them, so
"Stripe's checkout" still ledgers as typed. Misses: the second apostrophe of
rock'n'roll still opens a quote.
```

Negation cut (2026-10-22, review of 0.4.3). The first cut allowed any two words between the negation and the quote, so it reached across a clause: "no images and \"Digimon\" sprites" ledgered nothing, "not only \"Stripe\" but also \"PayPal\"" dropped Stripe. The cut now allows at most one word between them, from a fixed list of verbs and determiners that keep the negation on the quote (use, any, more, the, called, include, mention and kin). "the app has no \"dark mode\" toggle yet, add one" was cut by the bare-negation form itself, so the `no` after `has`/`have`/`had` is masked: there it names what is missing, which the ask usually fills. Residuals: `don't use any "neon"` (two listed words) no longer cuts; a `has no "x"` meant as an exclusion ledgers. Both cost one accounting line, the cheaper error for a gate whose job is catching a silent substitution. The unit filter became case-insensitive in the same review (`10GB`, `30Min` ledgered); `d` and `k` stay off its list so `2D sprites` and `4K` still ledger.
