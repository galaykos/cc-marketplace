# ask-ledger hooks: the comment text moved out of the code (2026-10-28)

The text below was moved verbatim on 2026-10-28 from the files named in the `##` headings, with only each comment's `# ` leader (and the indentation before it) removed; the lines each file kept are not repeated here. A pointer by name was left in each file, `# Why, limits, history: rationale/derivations/plugin-ask-ledger.md § <heading>`. Standing: `recorded` — no gate reads this file, and its dates, measurements and citations are as they stood on the day it moved.

## plugins/ask-ledger/hooks/gate.sh

### Header

```text
Absolute-path shebang: fail-open must hold under a stripped PATH.

Stop. Reads the session ledger ledger.sh wrote and the final assistant message from the
transcript; refuses the turn (a JSON block on stdout: the reason reaches the model and
systemMessage the person, probed on CLI 2.1.310) when any ledgered name has no accounting
line: a line naming it and one of `as named`, `substituted`, `omitted`. Blocks at most
twice per session, so a model that will not comply cannot be held forever; after that
the missing names are printed as a warning and the turn ends.

AN ACCOUNTED NAME LEAVES THE LEDGER (2026-10-08). Every Stop rewrites the ledger to the
names its final message did not account for, so a name is owed by the turn that named
it (and by the retry a block asks for, which owes only the names the block listed) —
not by every turn after. The ledger was session-cumulative before: `Iinstalled`,
written `as named` in the turn that named it, was demanded again at the end of
"PR + Merge" and "resume the survey" and blocked both. A later prompt that names it
again re-ledgers it, and that turn owes it again. The give-up drops its names too: the
warning is their record. Residual: a later turn that quietly undoes an accounted name
without naming it again is not asked about.

STANDING: gate on the SHAPE — the line must exist. Whether "as named" is true is
agent-graded: the model's word, and the reader's eye on the lines it was made to
write. That is the whole design: a silent substitution has to be written down as
"as named" — a lie — or as "substituted" — the confession — and neither is silence.
No ledger (no work-shaped prompt this session), no final message, or
CC_ASK_LEDGER=off: silent. Fail-open on missing jq or a bad payload.
CC_ASK_LEDGER unset: the /config option cc_ask_ledger decides.
```

### The retry's opening verdict

```text
The retry is the last thing the user reads; when it held only these lines, users re-asked
the question the turn had already answered above them.
```

## plugins/ask-ledger/hooks/ledger.sh

### Header

```text
Absolute-path shebang: fail-open must hold under a stripped PATH.

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

### Harness frames and subagent hand-backs

```text
Harness-injected turns reach UserPromptSubmit as prompts: a subagent's completion
notification, a Stop-hook relay, a system reminder. None is the user's ask, and a
subagent report is dense with capitalised tokens (a review's "NULL", "WHERE",
"FAIL") that would become ledger entries the Stop gate then demands lines for
(measured 2026-09-22: twelve false names from one notification, two blocked turns).
Anchored to the start: a real ask that merely QUOTES a marker mid-sentence is an ask.

SUBAGENT HAND-BACKS (2026-09-25). A SendMessage report arrives as its own prompt,
`Another Claude session sent a message:` then `<agent-message from="<id>">` then a
`[Subagent hand-back]` frame, and none of those three was on the list. Measured in two
sessions (rationale/2026-09-25-session-plugin-usage-review.md, finding 3): agent ids
(`ac61f13cc0e92d08a`), their fragments (`430c`), `SubagentHandback`, `NOT`,
`PopoverContent` ledgered; the gate blocked 6 turns and 32+ `<id>: as named` lines
reached the user. The opening line and the tag are matched at the start; the frame
marker at a line start, because the harness may put a note above it. The list is the
shared prompt-shape block's cc_prompt_frame (one copy for this hook, skill-router's and
code-review's); since 0.4.2 it also matches `<task-notification` carrying attributes
and a host /loop tick (`# Autonomous loop …`, `# /loop tick …`).
```

### Pastes

```text
A PASTE IS REFERENCE, NOT THE ASK (2026-10-13: a pasted package-manager log and a
pasted console dialog ledgered the host's paste id, log tokens and dialog labels, and
the paste's own `update` made a question work-shaped). Each <pasted_content …> …
</pasted_content …> span is cut (cc_prompt_unpaste) before the work-shape test and
extraction; the ask text on the same line as either tag stays. Residual: a name that
appears only inside a paste no longer ledgers.
```

### Scheduled re-fires

```text
A SCHEDULED RE-FIRE IS NOT A NEW ASK (2026-10-15). A /loop or ScheduleWakeup prompt comes
back on a timer as plain text; the /loop that set it was a slash command this hook skips,
and a model-written wakeup names the model's own words. The payload does not mark it, so
the transcript is read for the call that scheduled it (cc_prompt_scheduled).
```

### Quoted spans and in-word apostrophes

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

### A glued capital I

```text
A CAPITAL I GLUED TO THE NEXT WORD is the pronoun missing a space, not a name
(2026-10-07: "lets check if it works,  Iinstalled it" ledgered `Iinstalled`, and the
gate blocked two later turns over it). Dropped: I before a word starting with i, an
apostrophe-less contraction (Im, Ive), or one of the words that most often follow I.
Names that merely start with I (Inertia, Ionic, Iran) keep their shape and still
ledger; so does a glued I before a word not listed here (`Iwrote` goes, `Iforked` stays).
```

### Dropping what the repo already has

```text
DROP WHAT THE REPO ALREADY HAS. Scoped to the git work tree of the payload cwd: no
work tree, no filter (fail-open — the pre-2026-09-22 behaviour). `git grep` exits 0
on a hit, 1 on a clean miss, >1 on an error (bare repo, no index), and only that
last case falls through to rg, so an unmatched name is never re-searched twice.
BOUNDED AT 24 GREPS, and candidates past that pass UNFILTERED — the honest residual
of a bound inside a 5-second hook. 24 is twice the ledger's own 12-name cap so a
prompt whose first names are all pre-existing still gets its later ones checked;
measured 2026-09-22, 12 tree-wide greps on this marketplace cost 0.32 s.
```

### Case-insensitive grep

```text
-i: the ask writes a name in prose ("Laravel", "Payment") and the repo writes
it as a slug, a column or a class (`laravel/framework`, `payments`). Case is
not the signal for "this already exists here", and a case-sensitive miss put
`Laravel` back in the ledger of a Laravel project.
```
