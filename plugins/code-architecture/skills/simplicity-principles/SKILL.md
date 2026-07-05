---
name: simplicity-principles
description: Use when writing or reviewing any code — KISS and DRY applied with judgment: simplest thing that works, duplication removed only after the rule of three, DRY of knowledge not of incidental text.
---

## KISS: simplest design that meets today's requirement

Keep It Simple: solve the problem you actually have, with the least mechanism that correctly
and clearly solves it. Simplicity is not the absence of skill — it's the discipline to stop
adding once the requirement is met.

- **Clever code is a cost, not an achievement.** A one-liner that requires a comment explaining
  what it does has traded write-time cleverness for every future reader's comprehension time.
  If a straightforward, slightly longer version is just as correct, prefer it.
- **Prefer boring technology.** The well-understood library, the standard-library function, the
  pattern every engineer on the team already knows costs less over the system's lifetime than
  the novel, elegant, or trendy option — even when the novel option is technically superior on
  paper. Boring is a feature: it means fewer surprises, more Stack Overflow answers, easier
  onboarding, and code review that catches real issues instead of explaining the mechanism.
- **Simplest design that meets today's requirement** — not the simplest design that could ever
  be imagined meeting *every* future requirement. That's YAGNI's job to catch; KISS's job is to
  stop you from over-engineering the current requirement itself (e.g., a generic rule engine
  where a single `if` would do).

```
// Clever: works, but every reader has to decode it
const isEven = n => !(n & 1);

// Simple: equally correct, zero decode time
const isEven = n => n % 2 === 0;
```

## DRY done right: duplicate knowledge, not text

Don't Repeat Yourself is about knowledge, not characters. Two pieces of code that happen to
look similar are not automatically a duplication problem — they're only a problem if they
encode the *same rule* and would need to change together, in lockstep, every time that rule
changes.

- **Ask "if this changes, must the other one change too?"** If yes — it's the same knowledge,
  wearing two outfits, and belongs in one place. If no — it's incidental similarity, and forcing
  it into a shared abstraction couples two things that should be free to evolve independently.
- **Rule of three: don't extract on the second occurrence.** The first duplication is often
  coincidence. The second might still be coincidence. By the third occurrence you have enough
  evidence of a real, recurring pattern to justify the cost of an abstraction — and enough
  examples to shape its interface correctly instead of guessing from a sample size of one.
- **A wrong abstraction costs more than the duplication it replaced.** If a shared function
  starts sprouting `if (caseA) { ... } else if (caseB) { ... }` branches, or a boolean flag to
  bend its behavior for a new caller, that's the abstraction fighting reality — it was built on
  a false premise that the cases were the same knowledge. Inline it back into separate,
  duplicated, but honest implementations. Duplicated-but-clear beats shared-but-wrong.

```
// Incidental similarity, NOT the same knowledge — don't merge these:
function formatUserName(u) { return `${u.first} ${u.last}`; }
function formatCityState(c) { return `${c.city}, ${c.state}`; }
// Both are "join two strings with a separator" but they don't share a business rule;
// forcing a shared `joinTwo(a, b, sep)` helper adds indirection for no real reuse benefit
// beyond what the language's template strings already give you.

// Real duplicated knowledge — the tax rule itself, copy-pasted three call sites in:
function orderTotal(o) { return o.subtotal * 1.0825; }
function invoiceTotal(i) { return i.subtotal * 1.0825; }
function quoteTotal(q)   { return q.subtotal * 1.0825; }
// Extract: the *rate* and the *rule* are the shared knowledge.
const SALES_TAX_RATE = 0.0825;
function applyTax(subtotal) { return subtotal * (1 + SALES_TAX_RATE); }
```

## Conflict precedence: when principles disagree

These principles occasionally pull in different directions. When they do:

- **YAGNI beats DRY for speculative reuse.** Don't build a shared abstraction to serve a second
  caller that doesn't exist yet just because you can foresee the shape of it. Wait for the real
  third occurrence (rule of three) before you have enough evidence to abstract correctly.
- **KISS beats DRY when the abstraction reads worse than the duplication.** If removing
  duplication requires a generic function with three boolean flags, a config object, or a layer
  of indirection that makes the reader trace through multiple files to understand one call site,
  the duplication was cheaper. A little repetition is far less costly than the wrong
  abstraction (see above).
- **DRY still wins when the duplicated knowledge is a business rule, a formula, a validation
  constraint, or anything that must change consistently everywhere it appears.** Letting a tax
  rate or a security check drift out of sync across copies is a correctness bug waiting to
  happen, and no amount of "the duplication was simpler" excuses it.

In short: reach for DRY only once duplication is proven (rule of three) and the abstraction it
produces is simpler to read than the repetition (KISS), and only for knowledge that genuinely
must stay in sync (real duplication, not incidental similarity). Everything else stays simple
and, if needed, duplicated.

## Quick self-check before extracting or simplifying

Before extracting a shared abstraction, ask in order:

1. **Is this the third occurrence, not the second?** If not, wait.
2. **Do the occurrences share knowledge, or just shape?** If they'd change for different
   reasons, don't merge them (see the tax-rate vs. name-formatting example above).
3. **Does the resulting abstraction read more simply than the duplication it replaces?** If the
   shared function needs flags, an options object, or an `if (case)` branch per caller to
   handle the "reuse," it's not actually simpler — it's the duplication relocated and disguised.
4. **Is there a real second caller today**, or are you building the abstraction for a
   hypothetical one? If hypothetical, that's YAGNI's territory — stop.

Before adding cleverness in the name of fewer lines or a "smarter" approach, ask: would a
mid-level engineer unfamiliar with this trick understand it on first read, at normal reading
speed, without a comment? If not, the clever version isn't paying for itself — write the
boring one.

## When to apply

Apply KISS continuously while writing any code — it's a bias, not a one-time check. Apply the
DRY judgment specifically at the moment you're tempted to extract a shared function/class, and
again whenever a shared abstraction grows a new conditional branch or flag for a new caller —
that's the signal to re-evaluate whether it's still the same knowledge.
