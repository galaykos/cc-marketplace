---
name: low-cognitive-load
description: Use when writing or reviewing for readability or simplicity — KISS, DRY, the rule of three, duplication vs over-abstraction, small focused units, few live variables, shallow nesting, meaningful names, no cleverness.
---

## The goal: minimize what a reader has to hold in their head

Code is read far more often than it's written, and a reader has a small working-memory budget.
Every extra live variable, nesting level, hidden side effect, or ambiguous name spends part of
that budget before the reader gets to the actual logic. Low-cognitive-load code spends that
budget on the problem, not on decoding the code.

## Function fits on screen

If a function doesn't fit on one screen without scrolling, the reader has to hold the top of
the function in memory while reading the bottom — that's a direct tax on comprehension. Long
functions are usually doing more than one job; split by responsibility (see plan-before-code),
not by arbitrary line count. Extract named sub-steps: `validateInput()`, `applyDiscount()`,
`buildReceipt()` reads as a summary of what the function does, in order, versus 150 inlined
lines the reader must simulate to understand.

## Guard clauses over nesting

Deep nesting forces the reader to track multiple simultaneously-true conditions to understand
any inner line. Invert conditions and return/continue early so the main body is flat and
represents the "normal" path with preconditions handled up front.

## Avoid boolean params

A boolean parameter forces the reader (and every call site) to decode what `true` means without
looking it up, and it silently signals the function does two different things depending on the
flag. Split into two named functions, or use a named-options object where the key documents
itself — `renderList(items, true)` against `renderCompactList(items)`.

If the function starts accumulating multiple boolean flags, that's a stronger signal it's
secretly several functions glued together — split it before adding a third flag. The
named-options object is the boolean-param fix only when every field has a concrete consumer
today; yagni-check's options-object red flag targets speculative fields, not this.

## Names carry meaning — no mental mapping

A reader shouldn't have to keep a private lookup table in their head ("`d` is the user, `x` is
the count of active sessions"). Name things for what they hold or do, in the vocabulary of the
problem domain, not the vocabulary of the implementation ("`temp`", "`data2`", "`flag`").

When the code's bounded context keeps a glossary (a `GLOSSARY.md` at the context's root, or the
repo root for a single context), take its canonical term over any synonym it retires, and over
a neighbour's naming too: that neighbour is a local convention that is itself the problem, so
flag it for a deliberate rename, as the next paragraph says. Standing: **recorded**.

Names also read against their neighbors: match the surrounding file's naming and idiom
rather than importing a house style of your own. A file where one function speaks a
different dialect makes the reader ask what the difference MEANS — and the answer
"nothing, different author" is pure load. When the local convention is itself the problem,
change it deliberately and everywhere, not as a side effect of one edit. Comment density is
the one neighbour habit NOT to match: the default is no comment, and a heavily commented
file is drift, not a specification — code-review's `comment-discipline` owns that rule.

## Locality of behavior over scattered indirection

Prefer code where the behavior relevant to understanding a line is nearby — in the same
function or file — over code that's technically "clean" but forces the reader to jump through
four files and two levels of dependency injection to see what actually happens. Indirection
earns its cost only when it removes real duplication or isolates real variation (see
`references/kiss-dry.md`); indirection added purely for "layering" makes the reader do the
integration work the code should have done for them.

- Prefer a slightly longer function with the logic visible over scattering it across
  many tiny one-line wrapper functions that exist only to satisfy a style rule.
  If the reader has to open several other files just to trace one call, the split has
  gone past the point of paying for itself. Weigh a split by its depth: what a caller must
  learn to use the unit — its signature, the call order it requires, its error modes, the
  config it needs — against what the unit gets done for them. A unit whose interface is as
  wide as its body is a pass-through: inline it — unless it is the seam at a genuine boundary
  (a vendor, a process edge, a slot a test fills), which solid-principles keeps. Standing:
  **recorded**.
- Keep configuration/constants near where they're used unless they're genuinely shared
  across many call sites — a single-use constant defined 300 lines away from its one usage
  costs a lookup for no benefit.

## Few live variables per scope

Every variable alive in a scope is something the reader must track for the rest of that scope.
Narrow variable lifetime: declare as close to first use as possible, and let variables go out
of scope (return early, use a block) as soon as they're no longer needed rather than keeping
a wide, long-lived set of mutable locals that all interact by the end of the function.

## Before new code: the reach order

Read the code the change touches first, then build on the first step below that covers the
need; the order picks what to build on and never excuses skipping the read.

1. **Nothing** — the need is not real yet; `yagni-check` decides.
2. **This repository** — search for a function, type or pattern that already does it, then
   confirm it is alive (`reuse-hygiene`, when code-review is installed).
3. **The standard library, then the platform under it** — what the browser, the database or
   the OS already does.
4. **An already-installed dependency** — adding a new one is a build-vs-buy decision, which
   the `approaches` plugin covers when installed.
5. **New code** — the least that satisfies the ask (`plan-before-code`'s surgical-edits reference).

A step covers the need only when it is right on the edge cases the requirement has. The order
never cuts a trust-boundary check, handling that guards against data loss, a security control,
a baseline accessibility behaviour, or a thing the user named. Shorter is not a step: a plain
longer version beats a terse one (`references/kiss-dry.md`).

```
// Hand-rolled: two concurrent sign-ups both pass the check
if (await users.findByEmail(email)) throw new EmailTaken();
await users.insert({ email });

// Step 3, the database — needs a unique index on users.email, which holds under the race
try { await users.insert({ email }); }
catch (e) { throw isUniqueViolation(e) ? new EmailTaken() : e; }
```

Standing: **recorded** — nothing checks that the order was walked (adapted from
dietrichgebert/ponytail v4.10.0, MIT). Reach: before code exists, only `coding-entry` loads this
section, beside the description's own match; after an edit, skill-router (when installed)
suggests it on .ts and .js source files (not config, .d.ts, .min.js or dotfiles), .tsx, .jsx and
.vue files (not dotfiles), .php files (not Blade views or dotfiles), and .py, .go, .rb and .rs files — not .java.

## KISS and DRY

Read `references/kiss-dry.md` when the specific question is duplication or over-design:
simplest thing that works, the rule of three before extracting, DRY of knowledge rather
than of text, and the precedence order when those pull against SOLID or YAGNI.

## When to apply

Apply these checks while writing new code and specifically during self-review before a change
is considered done: read the diff as a stranger would, and note every place you had to pause to
decode a name, hold extra state in your head, or trace into another file to understand a single
line. Each pause is a concrete, fixable instance of cognitive load.
