---
name: low-cognitive-load
description: Use when writing or reviewing for readability — small focused units, few live variables, shallow nesting, meaningful names, no cleverness.
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

```js
// Deep nesting — by the time you reach the core logic you're tracking 3 conditions
function processOrder(order) {
  if (order) {
    if (order.items.length > 0) {
      if (order.paymentConfirmed) {
        // actual logic, 4 levels deep
        return ship(order);
      }
    }
  }
  return null;
}

// Guard clauses — each precondition is handled and dismissed, main path is flat
function processOrder(order) {
  if (!order) return null;
  if (order.items.length === 0) return null;
  if (!order.paymentConfirmed) return null;
  return ship(order);
}
```

## Avoid boolean params

A boolean parameter forces the reader (and every call site) to decode what `true` means without
looking it up, and it silently signals the function does two different things depending on the
flag. Split into two named functions, or use a named-options object where the key documents
itself.

```js
// Call site is opaque — what does `true` mean here?
renderList(items, true);

// Split by behavior — self-documenting call sites
renderCompactList(items);
renderExpandedList(items);

// Or, when the branching is minor, a named option beats a bare boolean:
renderList(items, { expanded: true });
```

If the function starts accumulating multiple boolean flags, that's a stronger signal it's
secretly several functions glued together — split it before adding a third flag.

## Names carry meaning — no mental mapping

A reader shouldn't have to keep a private lookup table in their head ("`d` is the user, `x` is
the count of active sessions"). Name things for what they hold or do, in the vocabulary of the
problem domain, not the vocabulary of the implementation ("`temp`", "`data2`", "`flag`").

```js
// Reader must remember what each short name means for the rest of the function
function calc(u, d, f) {
  return f ? u.balance - d : u.balance + d;
}

// Names carry the meaning; no lookup table needed
function applyTransaction(user, amount, isWithdrawal) {
  return isWithdrawal ? user.balance - amount : user.balance + amount;
}
```

(Note `isWithdrawal` here is still a boolean param smell per above — in real code this would
likely split into `withdraw(user, amount)` / `deposit(user, amount)`.)

## Locality of behavior over scattered indirection

Prefer code where the behavior relevant to understanding a line is nearby — in the same
function or file — over code that's technically "clean" but forces the reader to jump through
four files and two levels of dependency injection to see what actually happens. Indirection
earns its cost only when it removes real duplication or isolates real variation (see
simplicity-principles); indirection added purely for "layering" makes the reader do the
integration work the code should have done for them.

- Prefer a slightly longer function with the logic visible over scattering it across
  many tiny one-line wrapper functions that exist only to satisfy a style rule.
  If the reader has to open several other files just to trace one call, the split has
  gone past the point of paying for itself.
- Keep configuration/constants near where they're used unless they're genuinely shared
  across many call sites — a single-use constant defined 300 lines away from its one usage
  costs a lookup for no benefit.

## Few live variables per scope

Every variable alive in a scope is something the reader must track for the rest of that scope.
Narrow variable lifetime: declare as close to first use as possible, and let variables go out
of scope (return early, use a block) as soon as they're no longer needed rather than keeping
a wide, long-lived set of mutable locals that all interact by the end of the function.

## When to apply

Apply these checks while writing new code and specifically during self-review before a change
is considered done: read the diff as a stranger would, and note every place you had to pause to
decode a name, hold extra state in your head, or trace into another file to understand a single
line. Each pause is a concrete, fixable instance of cognitive load.
